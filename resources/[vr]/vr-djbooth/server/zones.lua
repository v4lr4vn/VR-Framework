lib.addCommand('djzones', { help = 'Manage the business areas where speakers can be placed (admin)', restricted = true }, function(source)
    if source <= 0 then return end
    TriggerClientEvent('vr-djbooth:client:zonesMenu', source)
end)

local function jobExists(job)
    return Bridge.isJob(job)
end

lib.callback.register('vr-djbooth:zones:create', function(src, data)
    if not IsAdmin(src) then return false, 'not_allowed' end
    if type(data) ~= 'table' then return false, 'bad_request' end
    local label = DJ.cleanText(data.label, 48)
    local job = type(data.job) == 'string' and data.job:lower():match('^[%w_%-]+$')
    local max = math.floor(tonumber(data.max) or Config.Limits.perBusiness)
    local minZ, maxZ = DJ.num(data.minZ), DJ.num(data.maxZ)
    if not label or not job then return false, 'bad_request' end
    if not jobExists(job) then return false, 'unknown_job' end
    if max < 1 or max > Config.Limits.maxPerZone then return false, 'bad_value' end
    if not minZ or not maxZ or maxZ <= minZ then return false, 'zone_heights' end
    if maxZ - minZ > 200 then return false, 'zone_too_tall' end

    local points = {}
    if type(data.points) ~= 'table' or #data.points < 3 or #data.points > 40 then return false, 'bad_value' end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #data.points do
        local p = data.points[i]
        local x, y = DJ.num(type(p) == 'table' and p.x), DJ.num(type(p) == 'table' and p.y)
        if not x or not y then return false, 'bad_value' end
        minX, minY, maxX, maxY = math.min(minX, x), math.min(minY, y), math.max(maxX, x), math.max(maxY, y)
        points[i] = { x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100 }
    end
    if maxX - minX > 2000 or maxY - minY > 2000 then return false, 'zone_too_big' end

    local id = DbAwait('insert', 'INSERT INTO `vr_djbooth_zones` (`label`, `job`, `max_speakers`, `min_z`, `max_z`, `points`) VALUES (?, ?, ?, ?, ?, ?)',
        { label, job, max, minZ, maxZ, json.encode(points) })
    if not id then return false, 'save_failed' end
    local key = 'z' .. id
    Zones[key] = { key = key, dbId = id, label = label, job = job, max = max, minZ = minZ, maxZ = maxZ, points = points }
    PushZones()
    return true, key
end)

lib.callback.register('vr-djbooth:zones:edit', function(src, key, data)
    if not IsAdmin(src) then return false, 'not_allowed' end
    local zone = type(key) == 'string' and Zones[key]
    if not zone then return false, 'gone' end
    if not zone.dbId then return false, 'config_zone_edit' end
    if type(data) ~= 'table' then return false, 'bad_request' end
    local label = DJ.cleanText(data.label, 48)
    local max = tonumber(data.max) and math.floor(tonumber(data.max))
    if not label or not max then return false, 'bad_request' end
    if max < 1 or max > Config.Limits.maxPerZone then return false, 'bad_value' end
    if not DbAwait('update', 'UPDATE `vr_djbooth_zones` SET `label` = ?, `max_speakers` = ? WHERE `id` = ?', { label, max, zone.dbId }) then
        return false, 'save_failed'
    end
    if Zones[key] ~= zone then return false, 'gone' end
    zone.label, zone.max = label, max
    PushZones()
    return true, CountInPlace('biz:' .. key)
end)

lib.callback.register('vr-djbooth:zones:delete', function(src, key)
    if not IsAdmin(src) then return false, 'not_allowed' end
    local zone = type(key) == 'string' and Zones[key]
    if not zone then return false, 'gone' end
    if not zone.dbId then return false, 'config_zone' end
    local n = CountInPlace('biz:' .. key) + BoostersInPlace('biz:' .. key)
    if n > 0 then return false, 'zone_has_speakers', n end
    MySQL.update('DELETE FROM `vr_djbooth_zones` WHERE `id` = ?', { zone.dbId })
    Zones[key] = nil
    PushZones()
    return true
end)

lib.callback.register('vr-djbooth:adminRemove', function(src, speakerId)
    if not IsAdmin(src) then return false, 'not_allowed' end
    local booster = type(speakerId) == 'string' and Boosters[speakerId]
    if booster then
        RemoveBooster(booster, nil)
        return true
    end
    local sp = type(speakerId) == 'string' and Speakers[speakerId]
    if not sp then return false, 'gone' end
    if sp.ownerCid then
        RemoveBoombox(sp.ownerCid)
        return true
    end
    local sys = Systems[sp.system]
    Speakers[sp.id] = nil
    MySQL.update('DELETE FROM `vr_djbooth_speakers` WHERE `id` = ?', { sp.dbId })
    PushSpeakerRemoved(sp.id)
    if sys then
        sys.speakers[sp.id] = nil
        if not next(sys.speakers) then
            MySQL.update('DELETE FROM `vr_djbooth_systems` WHERE `id` = ?', { tonumber(sys.id:sub(2)) })
            RemoveSystem(sys)
        else
            PushSystem(sys)
            PushPanel(sys)
        end
    end
    return true
end)

lib.addCommand('djclear', { help = 'Remove every placed speaker, Range Booster and boombox (admin)', restricted = true }, function(source)
    if source <= 0 then return end
    TriggerClientEvent('vr-djbooth:client:clearAll', source)
end)

function CountPlaced(place)
    local c = { speakers = 0, boosters = 0, boomboxes = 0 }
    for _, sp in pairs(Speakers) do
        if sp.ownerCid then
            if place == nil then c.boomboxes = c.boomboxes + 1 end
        elseif place == nil or sp.place == place then
            c.speakers = c.speakers + 1
        end
    end
    for _, b in pairs(Boosters) do
        if place == nil or b.place == place then c.boosters = c.boosters + 1 end
    end
    return c
end

local function deleteIds(tbl, column, ids)
    for i = 1, #ids, 200 do
        local chunk = { table.unpack(ids, i, math.min(i + 199, #ids)) }
        local marks = ('?,'):rep(#chunk):sub(1, -2)
        if not DbAwait('update', ('DELETE FROM `%s` WHERE `%s` IN (%s)'):format(tbl, column, marks), chunk) then return false end
    end
    return true
end

function ClearPlaced(place)
    local done = { speakers = 0, boosters = 0, boomboxes = 0 }

    local speakers, systems, groupIds = {}, {}, {}
    for _, sp in pairs(Speakers) do
        if not sp.ownerCid and sp.dbId and (place == nil or sp.place == place) then speakers[#speakers + 1] = sp end
    end
    for _, sys in pairs(Systems) do
        if sys.kind == 'speakers' and (place == nil or sys.place == place) then
            systems[#systems + 1] = sys
            groupIds[#groupIds + 1] = tonumber(sys.id:sub(2))
        end
    end
    local ids = {}
    for i, sp in ipairs(speakers) do ids[i] = sp.dbId end
    if not deleteIds('vr_djbooth_speakers', 'id', ids) or not deleteIds('vr_djbooth_systems', 'id', groupIds) then
        return done, 'save_failed'
    end
    for _, sp in ipairs(speakers) do
        if Speakers[sp.id] == sp then
            Speakers[sp.id] = nil
            PushSpeakerRemoved(sp.id)
            done.speakers = done.speakers + 1
        end
        local sys = Systems[sp.system]
        if sys then sys.speakers[sp.id] = nil end
    end
    for _, sys in ipairs(systems) do
        for id in pairs(sys.speakers) do
            local sp = Speakers[id]
            if sp then
                Speakers[id] = nil
                PushSpeakerRemoved(id)
                if sp.dbId then MySQL.update('DELETE FROM `vr_djbooth_speakers` WHERE `id` = ?', { sp.dbId }) end
                done.speakers = done.speakers + 1
            end
        end
        sys.speakers = {}
        sys.now = nil
        if Systems[sys.id] == sys then RemoveSystem(sys) end
    end

    local boosters, boosterIds = {}, {}
    for _, b in pairs(Boosters) do
        if place == nil or b.place == place then
            boosters[#boosters + 1] = b
            boosterIds[#boosterIds + 1] = b.dbId
        end
    end
    if not deleteIds('vr_djbooth_boosters', 'id', boosterIds) then return done, 'save_failed' end
    for _, b in ipairs(boosters) do
        if Boosters[b.id] == b then
            Boosters[b.id] = nil
            PushSpeakerRemoved(b.id)
            done.boosters = done.boosters + 1
        end
    end

    if place == nil then
        local cids = {}
        for cid in pairs(Boomboxes) do cids[#cids + 1] = cid end
        if not deleteIds('vr_djbooth_boomboxes', 'citizenid', cids) then return done, 'save_failed' end
        for _, cid in ipairs(cids) do
            if Boomboxes[cid] then
                DropBoombox(cid)
                done.boomboxes = done.boomboxes + 1
            end
        end
    end
    return done
end

local function clearScope(scope)
    if scope == 'all' then return true, nil end
    if type(scope) == 'string' and Zones[scope] then return true, 'biz:' .. scope end
    return false
end

lib.callback.register('vr-djbooth:admin:clearCount', function(src, scope)
    if not IsAdmin(src) then return false, 'not_allowed' end
    local ok, place = clearScope(scope)
    if not ok then return false, 'gone' end
    return true, CountPlaced(place)
end)

lib.callback.register('vr-djbooth:admin:clear', function(src, scope)
    if not IsAdmin(src) then return false, 'not_allowed' end
    if TooFast(src, 'clear', 3000) then return false, 'slow_down' end
    local ok, place = clearScope(scope)
    if not ok then return false, 'gone' end
    local done, err = ClearPlaced(place)
    print(('[vr-djbooth] %s (%d) cleared %s: %d speakers, %d Range Boosters, %d boomboxes%s'):format(
        GetPlayerName(src) or '?', src, place or 'everything', done.speakers, done.boosters, done.boomboxes,
        err and ' (stopped by a database error)' or ''))
    if err then return false, err, done end
    return true, done
end)
