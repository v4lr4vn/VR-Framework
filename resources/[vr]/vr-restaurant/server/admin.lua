-- Admin tools: create restaurants, choose owners and the wage limit. Used by /restaurantcreator.

local function reachable(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if not at then return nil end
    local x, y, z = Rest.num(at.x), Rest.num(at.y), Rest.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (Rest.num(at.w) or 0.0) + 0.0 }
end

lib.callback.register('vr-restaurant:isAdmin', function(src)
    return Rest.admin(src)
end)

local function view(b)
    return {
        id = b.id, label = b.label, x = b.x, y = b.y, z = b.z, w = b.w,
        owner = b.owner ~= '' and b.ownerName or nil, maxWage = b.maxWage, ownerWage = b.ownerWage,
        staff = (function() local n = 0 for _ in pairs(b.staff) do n = n + 1 end return n end)(),
        balance = Rest.bank.balance(b),
        price = b.price, licenceDays = b.licenceDays, status = b.status,
        stations = (function() local n = 0 for _ in pairs(b.stations) do n = n + 1 end return n end)(),
    }
end

local function adminList()
    local out = {}
    for _, b in pairs(Rest.biz) do out[#out + 1] = view(b) end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

local function setOwner(b, target)
    if target == false then
        if b.owner ~= '' then Rest.duty[b.owner] = nil end
        b.owner, b.ownerName = '', ''
        return true
    end
    local other = Rest.info(target)
    if not other then return nil, 'not_found' end
    local at = Rest.byCid[other.cid]
    if at and at ~= b.id then return nil, 'has_job' end
    if b.owner ~= '' and b.owner ~= other.cid then Rest.duty[b.owner] = nil end
    if b.staff[other.cid] then Rest.removeStaff(b, other.cid) end
    b.owner, b.ownerName = other.cid, other.name
    return true
end

lib.callback.register('vr-restaurant:admin', function(src, action, d)
    if not Rest.admin(src) then return Rest.fail('not_admin') end
    if not Rest.loaded then return Rest.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return Rest.fail('bad_request') end

    if action == 'list' then
        return { ok = true, data = { list = adminList() } }
    end

    if action == 'add' then
        local n = 0
        for _ in pairs(Rest.biz) do n = n + 1 end
        if n >= 60 then return Rest.fail('limit') end
        local pos = reachable(src, d)
        if not pos then return Rest.fail('too_far') end
        local label = Rest.text(d.label, 2, 48) or 'Restaurant'
        local maxWage = Config.Business.defaultMaxWage
        if d.maxWage ~= nil then maxWage = Rest.int(d.maxWage, 0, 10000000) end
        if not maxWage then return Rest.fail('bad_value') end
        local price, days = 0, Config.Licence.defaultDays
        if d.price ~= nil then price = Rest.int(d.price, 0, 1000000000) end
        if d.licenceDays ~= nil then days = Rest.int(d.licenceDays, Config.Licence.minDays, Config.Licence.maxDays) end
        if not price or not days then return Rest.fail('bad_value', { min = Config.Licence.minDays, max = Config.Licence.maxDays }) end
        local id = MySQL.insert.await('INSERT INTO vr_rest_businesses (label, x, y, z, w, max_wage, owner_wage, price, licence_days) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { label, pos.x, pos.y, pos.z, pos.w, maxWage, maxWage, price, days })
        if not id then return Rest.fail('failed') end
        local b = {
            id = id, label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w, owner = '', ownerName = '', maxWage = maxWage, ownerWage = maxWage,
            price = price, licenceDays = days, licenceNumber = '', licenceExpires = 0, status = 'open', closedUntil = 0, closedReason = '',
            strikes = 0, lastStrike = 0, lastInspected = 0, balance = 0, ranks = {}, staff = {}, stations = {}, history = {},
        }
        Rest.biz[id] = b
        for _, def in ipairs(Config.DefaultRanks) do
            Rest.addRank(b, { label = def.label, level = def.level, wage = math.min(def.wage or 0, maxWage), perms = def.perms })
        end
        Rest.push()
        return { ok = true, data = { business = view(b) } }
    end

    local b = Rest.biz[tonumber(d.id) or -1]
    if not b then return Rest.fail('not_found') end

    if action == 'set' then
        local patch = type(d.patch) == 'table' and d.patch or {}
        if patch.label ~= nil then
            local label = Rest.text(patch.label, 2, 48)
            if not label then return Rest.fail('bad_value') end
            b.label = label
        end
        if patch.maxWage ~= nil then
            local wage = Rest.int(patch.maxWage, 0, 10000000)
            if not wage then return Rest.fail('bad_value') end
            b.maxWage = wage
            Rest.clampWages(b)
        end
        if patch.price ~= nil then
            local price = Rest.int(patch.price, 0, 1000000000)
            if not price then return Rest.fail('bad_value') end
            b.price = price
        end
        if patch.licenceDays ~= nil then
            local days = Rest.int(patch.licenceDays, Config.Licence.minDays, Config.Licence.maxDays)
            if not days then return Rest.fail('bad_value', { min = Config.Licence.minDays, max = Config.Licence.maxDays }) end
            b.licenceDays = days
        end
        if patch.owner ~= nil then
            local ok, err = setOwner(b, patch.owner == false and false or Rest.int(patch.owner, 1, 65535))
            if not ok then return Rest.fail(err or 'bad_value') end
            Rest.index()
        end
        Rest.saveBusiness(b)
        Rest.push()
        return { ok = true, data = { business = view(b) } }
    elseif action == 'move' then
        local pos = reachable(src, d)
        if not pos then return Rest.fail('too_far') end
        b.x, b.y, b.z, b.w = pos.x, pos.y, pos.z, pos.w
        Rest.saveBusiness(b)
        Rest.push()
        return { ok = true, data = { business = view(b) } }
    elseif action == 'remove' then
        local balance = Rest.bank.balance(b)
        for cid in pairs(b.staff) do Rest.duty[cid] = nil end
        if b.owner ~= '' then Rest.duty[b.owner] = nil end
        MySQL.query.await('DELETE FROM vr_rest_staff WHERE business = ?', { b.id })
        MySQL.query.await('DELETE FROM vr_rest_ranks WHERE business = ?', { b.id })
        MySQL.query.await('DELETE FROM vr_rest_businesses WHERE id = ?', { b.id })
        MySQL.query.await('DELETE FROM vr_rest_stations WHERE business = ?', { b.id })
        MySQL.query.await('DELETE FROM vr_rest_inspections WHERE business = ?', { b.id })
        for sid in pairs(b.stations) do
            Rest.stations[sid] = nil
            if Rest.dropStorage then Rest.dropStorage(sid) end
        end
        if Rest.dropKitchen then Rest.dropKitchen(b.id) end
        Rest.biz[b.id] = nil
        Rest.index()
        Rest.push()
        Rest.pushStations()
        return { ok = true, data = { id = b.id, balance = balance } }
    end
    return Rest.fail('bad_request')
end)

RegisterCommand(Config.Admin.command, function(src)
    if src == 0 then return end
    if not Rest.admin(src) then return Rest.notify(src, 'You cannot use this', 'error') end
    TriggerClientEvent('vr-restaurant:client:creator', src)
end, false)
