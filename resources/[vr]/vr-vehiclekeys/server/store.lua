Keys = { owners = {}, shared = {}, temp = {}, pending = {}, cool = {}, claims = {} }

local OWNER_TTL, MISS_TTL = 60, 10

local function now() return os.time() end

function Keys.ownerOf(plate)
    plate = KU.plate(plate)
    if not plate then return nil end
    local c = Keys.owners[plate]
    local t = now()
    if c and t < c.till then return c.cid or nil end
    local cid = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    Keys.owners[plate] = { cid = cid or false, till = t + (cid and OWNER_TTL or MISS_TTL) }
    return cid or nil
end

function Keys.forget(plate)
    plate = KU.plate(plate)
    if plate then Keys.owners[plate] = nil end
end

function Keys.modelOf(plate)
    plate = KU.plate(plate)
    if not plate then return nil end
    return MySQL.scalar.await('SELECT vehicle FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
end

function Keys.loadShared(cid)
    local rows = MySQL.query.await('SELECT plate, expires FROM vr_vehicle_keys WHERE citizenid = ?', { cid }) or {}
    local t, out = now(), {}
    for _, r in ipairs(rows) do
        local e = tonumber(r.expires) or 0
        if e == 0 or e > t then out[r.plate] = e end
    end
    Keys.shared[cid] = out
    return out
end

function Keys.sharedOf(cid)
    return Keys.shared[cid] or Keys.loadShared(cid)
end

function Keys.kind(cid, plate)
    plate = KU.plate(plate)
    if not plate or not cid then return nil end
    if Keys.ownerOf(plate) == cid then return 'owner' end
    local t = now()
    local mine = Keys.sharedOf(cid)
    local e = mine[plate]
    if e ~= nil then
        if e == 0 then return 'shared' end
        if e > t then return 'lent' end
        mine[plate] = nil
    end
    local tmp = Keys.temp[cid]
    local v = tmp and tmp[plate]
    if v then
        if v == true or v > t then return 'temp' end
        tmp[plate] = nil
    end
    return nil
end

function Keys.platesOf(veh)
    local a = KU.plate(GetVehicleNumberPlateText(veh))
    local ok, bag = pcall(function() return Entity(veh).state.vr_plate end)
    local b = ok and KU.plate(bag) or nil
    if b == a then b = nil end
    return a, b
end

local function tagOf(veh)
    local ok, tag = pcall(function() return Entity(veh).state.vr_jobveh end)
    return ok and type(tag) == 'table' and tag or nil
end

function Keys.forVehicle(info, veh)
    local a, b = Keys.platesOf(veh)
    local kind = (a and Keys.kind(info.cid, a)) or (b and Keys.kind(info.cid, b)) or nil
    if kind then return kind end
    if Config.Group.jobVehicles then
        local tag = tagOf(veh)
        local group = tag and type(tag.group) == 'string' and tag.group or nil
        local what, name = (group or ''):match('^(%a+):(.+)$')
        if what == 'job' and info.job.name == name and (not Config.Group.requireDuty or info.job.onduty) then return 'group' end
        if what == 'gang' and info.gang.name == name then return 'group' end
    end
    return nil
end

function Keys.isLocked(veh)
    local ok, st = pcall(function() return Entity(veh).state.vr_locked end)
    if ok and type(st) == 'boolean' then return st end
    if GetVehicleDoorLockStatus then return (tonumber(GetVehicleDoorLockStatus(veh)) or 0) >= 2 end
    return false
end

function Keys.setLocked(veh, locked)
    locked = locked == true
    Entity(veh).state:set('vr_locked', locked, true)
    if SetVehicleDoorsLocked then SetVehicleDoorsLocked(veh, locked and 2 or 1) end
    TriggerEvent('vr-vehiclekeys:server:lockChanged', NetworkGetNetworkIdFromEntity(veh), locked)
end

function Keys.entityFor(plate)
    plate = KU.plate(plate)
    if not plate then return nil end
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local a, b = Keys.platesOf(veh)
            if a == plate or b == plate then return veh end
        end
    end
    return nil
end

function Keys.count(plate)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM vr_vehicle_keys WHERE plate = ? AND (expires = 0 OR expires > ?)', { plate, now() })) or 0
end

function Keys.share(cid, plate, holder, by, minutes)
    plate = KU.plate(plate)
    local t = now()
    local expires = minutes and (t + math.floor(minutes * 60)) or 0
    MySQL.update.await('INSERT INTO vr_vehicle_keys (plate, citizenid, holder, given_by, expires, created) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE holder = VALUES(holder), given_by = VALUES(given_by), expires = VALUES(expires)',
        { plate, cid, holder, by, expires, t })
    Keys.sharedOf(cid)[plate] = expires
    return expires
end

function Keys.revoke(cid, plate)
    plate = KU.plate(plate)
    if not plate or not cid then return false end
    local n = MySQL.update.await('DELETE FROM vr_vehicle_keys WHERE plate = ? AND citizenid = ?', { plate, cid })
    local mine = Keys.shared[cid]
    if mine then mine[plate] = nil end
    local tmp = Keys.temp[cid]
    local had = tmp and tmp[plate] ~= nil
    if tmp then tmp[plate] = nil end
    return (tonumber(n) or 0) > 0 or had == true
end

function Keys.grantTemp(cid, plate, minutes)
    plate = KU.plate(plate)
    if not plate or not cid then return false end
    local tmp = Keys.temp[cid]
    if not tmp then tmp = {} Keys.temp[cid] = tmp end
    local m = tonumber(minutes)
    tmp[plate] = m and (now() + math.floor(m * 60)) or true
    return true
end

function Keys.clearTemp(plate)
    plate = KU.plate(plate)
    if not plate then return {} end
    local who = {}
    for cid, tmp in pairs(Keys.temp) do
        if tmp[plate] ~= nil then
            tmp[plate] = nil
            who[#who + 1] = cid
        end
    end
    return who
end

function Keys.clearPlate(plate)
    plate = KU.plate(plate)
    if not plate then return {} end
    local seen, who = {}, {}
    local rows = MySQL.query.await('SELECT citizenid FROM vr_vehicle_keys WHERE plate = ?', { plate }) or {}
    for _, r in ipairs(rows) do
        if not seen[r.citizenid] then seen[r.citizenid] = true who[#who + 1] = r.citizenid end
    end
    MySQL.update.await('DELETE FROM vr_vehicle_keys WHERE plate = ?', { plate })
    for _, cid in ipairs(who) do
        local mine = Keys.shared[cid]
        if mine then mine[plate] = nil end
    end
    for _, cid in ipairs(Keys.clearTemp(plate)) do
        if not seen[cid] then seen[cid] = true who[#who + 1] = cid end
    end
    local veh = Keys.entityFor(plate)
    if veh then Entity(veh).state:set('vr_hotwired', nil, true) end
    return who
end

function Keys.holders(plate)
    plate = KU.plate(plate)
    local t = now()
    local rows = MySQL.query.await('SELECT citizenid, holder, expires FROM vr_vehicle_keys WHERE plate = ? ORDER BY id', { plate }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local e = tonumber(r.expires) or 0
        if e == 0 or e > t then
            out[#out + 1] = { cid = r.citizenid, name = r.holder or r.citizenid, lent = e > 0, expires = e }
        end
    end
    return out
end

function Keys.snapshot(cid)
    local held, t = {}, now()
    local rows = MySQL.query.await('SELECT plate FROM player_vehicles WHERE citizenid = ?', { cid }) or {}
    for _, r in ipairs(rows) do
        local p = KU.plate(r.plate)
        if p then held[p] = 'owner' end
    end
    for plate, e in pairs(Keys.sharedOf(cid)) do
        if held[plate] == nil and (e == 0 or e > t) then held[plate] = e == 0 and 'shared' or 'lent' end
    end
    for plate, v in pairs(Keys.temp[cid] or {}) do
        if held[plate] == nil and (v == true or v > t) then held[plate] = 'temp' end
    end
    return held
end

function Keys.push(src)
    local info = Core.info(src)
    if not info then return end
    TriggerClientEvent('vr-vehiclekeys:client:sync', src, Keys.snapshot(info.cid))
end

function Keys.pushCid(cid)
    local src = Core.sourceOf(cid)
    if src then Keys.push(src) end
end

function Keys.pushAll(cids)
    for _, cid in ipairs(cids or {}) do Keys.pushCid(cid) end
end

function Keys.sweep()
    local t = now()
    local rows = MySQL.query.await('SELECT DISTINCT citizenid FROM vr_vehicle_keys WHERE expires > 0 AND expires <= ?', { t }) or {}
    if #rows == 0 then return end
    MySQL.update.await('DELETE FROM vr_vehicle_keys WHERE expires > 0 AND expires <= ?', { t })
    for _, r in ipairs(rows) do
        Keys.shared[r.citizenid] = nil
        Keys.pushCid(r.citizenid)
    end
end
