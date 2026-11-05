-- Crafting areas: placed by admins for each business. Cleaning points work now; the rest are
-- placed ready for the kitchen update.

local function kindInfo(id)
    for _, k in ipairs(Config.Stations) do
        if k.id == id then return k end
    end
end
Rest.kindInfo = kindInfo

local function reachable(src, at)
    if type(at) ~= 'table' then return nil end
    local x, y, z = Rest.num(at.x), Rest.num(at.y), Rest.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (Rest.num(at.w) or 0.0) + 0.0 }
end

local function count(b)
    local n = 0
    for _ in pairs(b.stations) do n = n + 1 end
    return n
end

local function adminView(s)
    local info = kindInfo(s.kind)
    return {
        id = s.id, business = s.business, kind = s.kind, kindLabel = info and info.label or s.kind,
        label = s.label, x = s.x, y = s.y, z = s.z, w = s.w, radius = s.radius, dirt = math.floor(s.dirt + 0.5),
    }
end

local function listFor(b)
    local out = {}
    for _, s in pairs(b.stations) do out[#out + 1] = adminView(s) end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

local function save(s)
    MySQL.query('UPDATE vr_rest_stations SET kind = ?, label = ?, x = ?, y = ?, z = ?, w = ?, radius = ? WHERE id = ?', { s.kind, s.label, s.x, s.y, s.z, s.w, s.radius, s.id })
end

lib.callback.register('vr-restaurant:adminStations', function(src, action, d)
    if not Rest.admin(src) then return Rest.fail('not_admin') end
    if not Rest.loaded then return Rest.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return Rest.fail('bad_request') end

    if action == 'kinds' then
        return { ok = true, data = { kinds = Config.Stations } }
    end

    if action == 'list' then
        local b = Rest.biz[tonumber(d.business) or -1]
        if not b then return Rest.fail('not_found') end
        return { ok = true, data = { list = listFor(b) } }
    end

    if action == 'add' then
        local b = Rest.biz[tonumber(d.business) or -1]
        if not b then return Rest.fail('not_found') end
        if count(b) >= Config.MaxStations then return Rest.fail('limit') end
        local info = type(d.kind) == 'string' and kindInfo(d.kind)
        if not info then return Rest.fail('bad_value') end
        local pos = reachable(src, d.at)
        if not pos then return Rest.fail('too_far') end
        local label = ''
        if d.label ~= nil and d.label ~= '' then label = Rest.text(d.label, 1, 32) end
        local radius = info.radius
        if d.radius ~= nil then radius = Rest.num(d.radius) end
        if not label then return Rest.fail('bad_value') end
        if not radius or radius < 0.3 or radius > 6.0 then return Rest.fail('bad_value') end
        local id = MySQL.insert.await('INSERT INTO vr_rest_stations (business, kind, label, x, y, z, w, radius, dirt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)', { b.id, info.id, label, pos.x, pos.y, pos.z, pos.w, radius + 0.0 })
        if not id then return Rest.fail('failed') end
        local s = { id = id, business = b.id, kind = info.id, label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w, radius = radius + 0.0, dirt = 0.0 }
        b.stations[id] = s
        Rest.stations[id] = s
        if Rest.syncStash then Rest.syncStash(s) end
        Rest.pushStations()
        return { ok = true, data = { station = adminView(s), list = listFor(b) } }
    end

    local s = Rest.stations[tonumber(d.id) or -1]
    if not s then return Rest.fail('not_found') end
    local b = Rest.biz[s.business]
    if not b then return Rest.fail('not_found') end

    if action == 'set' then
        local patch = type(d.patch) == 'table' and d.patch or {}
        if patch.label ~= nil then
            local label = patch.label == '' and '' or Rest.text(patch.label, 1, 32)
            if not label then return Rest.fail('bad_value') end
            s.label = label
        end
        if patch.radius ~= nil then
            local r = Rest.num(patch.radius)
            if not r or r < 0.3 or r > 6.0 then return Rest.fail('bad_value') end
            s.radius = r + 0.0
        end
        local oldKind = s.kind
        if patch.kind ~= nil then
            if type(patch.kind) ~= 'string' or not kindInfo(patch.kind) then return Rest.fail('bad_value') end
            s.kind = patch.kind
        end
        if Rest.syncStash then
            if Config.Storage[s.kind] then
                Rest.syncStash(s)
            elseif Config.Storage[oldKind] and Rest.dropStorage then
                Rest.dropStorage(s.id)
            end
        end
        save(s)
        Rest.pushStations()
        return { ok = true, data = { station = adminView(s), list = listFor(b) } }
    elseif action == 'move' then
        local pos = reachable(src, d.at)
        if not pos then return Rest.fail('too_far') end
        s.x, s.y, s.z, s.w = pos.x, pos.y, pos.z, pos.w
        if d.radius ~= nil then
            local r = Rest.num(d.radius)
            if not r or r < 0.3 or r > 6.0 then return Rest.fail('bad_value') end
            s.radius = r + 0.0
        end
        save(s)
        Rest.pushStations()
        return { ok = true, data = { station = adminView(s), list = listFor(b) } }
    elseif action == 'remove' then
        MySQL.query.await('DELETE FROM vr_rest_stations WHERE id = ?', { s.id })
        b.stations[s.id] = nil
        Rest.stations[s.id] = nil
        if Rest.dropStorage then Rest.dropStorage(s.id) end
        Rest.pushStations()
        return { ok = true, data = { list = listFor(b) } }
    end
    return Rest.fail('bad_request')
end)

---------------------------------------------------------------------------
-- Cleaning
---------------------------------------------------------------------------

local cleaning = {}

local function allowed(src, id)
    local who = Rest.info(src)
    if not who then return nil, 'no_player' end
    local s = Rest.stations[tonumber(id) or -1]
    if not s or s.kind ~= 'clean' then return nil, 'not_found' end
    local b = Rest.biz[s.business]
    if not b then return nil, 'not_found' end
    if Rest.byCid[who.cid] ~= b.id then return nil, 'not_staff' end
    local d = Rest.distance(src, s.x, s.y, s.z)
    if not d or d > s.radius + 3.0 then return nil, 'too_far' end
    return who, s, b
end

lib.callback.register('vr-restaurant:cleanBegin', function(src, id)
    if Rest.throttle(src, 'clean', Config.Business.minGapMs) then return Rest.fail('slow_down') end
    if not Rest.loaded then return Rest.fail('not_ready') end
    local who, s = allowed(src, id)
    if not who then return Rest.fail(s) end
    if s.dirt < Config.Hygiene.minDirtToClean then return Rest.fail('already_clean') end
    local ms = math.floor(Config.Hygiene.cleanSeconds * 1000)
    cleaning[src] = { id = s.id, at = GetGameTimer(), ms = ms }
    return { ok = true, data = { ms = ms, dirt = math.floor(s.dirt + 0.5) } }
end)

lib.callback.register('vr-restaurant:cleanFinish', function(src, id)
    if not Rest.loaded then return Rest.fail('not_ready') end
    local job = cleaning[src]
    cleaning[src] = nil
    if not job or job.id ~= tonumber(id) then return Rest.fail('bad_request') end
    if GetGameTimer() - job.at < job.ms * 0.8 then return Rest.fail('bad_request') end
    local who, s = allowed(src, id)
    if not who then return Rest.fail(s) end
    Rest.markClean(s)
    return { ok = true, data = { id = s.id } }
end)

lib.callback.register('vr-restaurant:cleanCancel', function(src)
    cleaning[src] = nil
    return true
end)

AddEventHandler('playerDropped', function() cleaning[source] = nil end)
