Dispatcher = {}

local listening = {}
local lastDuty = {}

local function channel(id)
    for _, c in ipairs(Config.Dispatcher.radio.channels or {}) do
        if c.id == id then return c end
    end
end

local function voiceUp()
    return Bridge.voice.resource() ~= nil
end

local function canListen()
    return voiceUp() and Bridge.voice.has('setListenChannels')
end

local function setListen(src, list)
    if not canListen() then return false, {} end
    local ok, now = Bridge.voice.call('setListenChannels', src, list)
    if ok and now and #now > 0 then listening[src] = true else listening[src] = nil end
    return ok, now or {}
end

local function radioDept(ctx)
    if not ctx then return nil end
    if ctx.dept == 'dispatch' then return Core.can(ctx, 'radio.multi') and 'dispatch' or nil end
    if Units.isUnit(ctx) then return ctx.dept end
    return nil
end

local function channelsFor(dept)
    local out = {}
    for _, c in ipairs(Config.Dispatcher.radio.channels or {}) do
        if dept == 'dispatch' or c.dept == dept or c.dept == 'all' then out[#out + 1] = c end
    end
    return out
end

local function allowedFor(dept, id)
    for _, c in ipairs(channelsFor(dept)) do
        if c.id == id then return c end
    end
end

local function nameOf(id)
    local other = Core.context(id)
    if other then return other.callsign or other.name, other.dept end
    local p = Core.player(id)
    return p and p.name or 'Unknown', nil
end

local function membersOf(ch)
    local out = {}
    for member in pairs(Bridge.voice.playersInRadio(ch)) do
        local id = tonumber(member)
        if id then
            local name, dept = nameOf(id)
            out[#out + 1] = { src = id, name = name, dept = dept }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

Api.register('radio.state', nil, function(src, ctx)
    local dept = radioDept(ctx)
    if not dept then return false, 'not_allowed' end
    local up = voiceUp()
    local current = tonumber(Player(src).state.radioChannel) or 0
    local out = {
        mode = dept == 'dispatch' and 'console' or 'unit',
        voice = up,
        channels = channelsFor(dept),
        transmit = current,
        listen = {},
        members = {},
    }
    if dept == 'dispatch' then
        out.listen = canListen() and Bridge.voice.call('getListenChannels', src) or {}
        out.defaults = { listen = Config.Dispatcher.radio.listen, transmit = Config.Dispatcher.radio.transmit }
    elseif up and current > 0 and allowedFor(dept, current) then
        out.members = membersOf(current)
    end
    return true, out
end, { rate = 250 })

Api.register('radio.listen', 'radio.multi', function(src, ctx, data)
    if not canListen() then return false, 'no_voice' end
    local list, seen = {}, {}
    for _, v in ipairs(type(data.channels) == 'table' and data.channels or {}) do
        local id = V.int(v, 1, 5000)
        if id and not seen[id] and channel(id) and #list < 8 then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    local ok, now = setListen(src, list)
    if not ok then return false, 'server_error' end
    return true, { listen = now }
end, { rate = 250 })

Api.register('radio.who', nil, function(src, ctx, data)
    local dept = radioDept(ctx)
    if not dept then return false, 'not_allowed' end
    if not voiceUp() then return false, 'no_voice' end
    local mine = {}
    if dept == 'dispatch' then
        for _, ch in ipairs(canListen() and Bridge.voice.call('getListenChannels', src) or {}) do mine[#mine + 1] = ch end
    end
    local tx = tonumber(Player(src).state.radioChannel) or 0
    if tx > 0 and allowedFor(dept, tx) then mine[#mine + 1] = tx end
    local members = {}
    for _, ch in ipairs(mine) do
        for member in pairs(Bridge.voice.playersInRadio(ch)) do members[tonumber(member)] = true end
    end
    local out = {}
    local ids = type(data.ids) == 'table' and data.ids or {}
    for i = 1, math.min(#ids, 16) do
        local id = V.int(ids[i], 1, 65535)
        if id and members[id] then out[tostring(id)] = (nameOf(id)) end
    end
    return true, out
end, { rate = 100 })

Api.register('radio.move', 'dispatch.manage', function(src, ctx, data)
    if ctx.dept ~= 'dispatch' then return false, 'not_allowed' end
    local cid = V.cid(data.cid)
    local ch = V.int(data.channel, 0, 5000)
    if not cid or not ch then return false, 'bad_request' end
    local p = Core.playerByCid(cid)
    local target = p and Core.context(p.source)
    if not target or not Units.isUnit(target) then return false, 'unit_unavailable' end
    local c = ch > 0 and allowedFor(target.dept, ch) or nil
    if ch > 0 and not c then return false, 'not_allowed' end
    TriggerClientEvent('vr-mdt:client:radioMove', target.src, ch, c and c.label or nil, ctx.callsign or ctx.name)
    Audit.log(ctx, 'radio.move', cid, { channel = ch })
    return true, { cid = cid, channel = ch }
end, { rate = 300 })

Api.register('radio.channels', nil, function(src, ctx)
    local dept = radioDept(ctx)
    if not dept then return false, 'not_allowed' end
    return true, channelsFor(dept)
end, { rate = 500 })

local function isDispatchJob(src)
    local player = Core.player(src)
    local job = player and player.job
    return job and Core.deptOf(job) == 'dispatch', job
end

local dutyEvents = { vr = 'VRCore', qb = 'QBCore', qbx = 'QBCore' }

local dutyFailed = {}

local function setDispatchDuty(src, onduty, why)
    Bridge.setDuty(src, onduty)
    local after = Core.player(src)
    if not after or (after.job and after.job.onduty == true) ~= (onduty == true) then
        if not dutyFailed[src] then
            print(('^1[vr-mdt] could not change dispatch duty for player %s, the framework did not accept it^0'):format(src))
        end
        dutyFailed[src] = GetGameTimer()
        return false
    end
    dutyFailed[src] = nil
    local prefix = dutyEvents[Bridge.framework]
    if prefix then
        TriggerEvent(prefix .. ':Server:SetDuty', src, onduty)
        TriggerClientEvent(prefix .. ':Client:SetDuty', src, onduty)
    end
    if onduty then
        Core.notify(src, why or 'You clocked in at dispatch.', 'success')
    else
        Core.notify(src, why or 'You clocked out of dispatch.', 'inform')
        setListen(src, {})
        TriggerClientEvent('vr-mdt:client:radioReset', src)
    end
    return true
end

RegisterNetEvent('vr-mdt:server:dispatchDuty', function()
    local src = source
    local now = GetGameTimer()
    if lastDuty[src] and now - lastDuty[src] < 3000 then return end
    lastDuty[src] = now
    local ok, job = isDispatchJob(src)
    if not ok then return Core.notify(src, "You don't work in dispatch.", 'error') end
    if Config.Dispatcher.autoDuty then return Core.notify(src, 'Dispatch duty is automatic. Walk into the dispatch centre to clock in.', 'inform') end
    if Core.dispatchSpot(src) ~= 'console' then return Core.notify(src, 'Clock in at a dispatch desk.', 'error') end
    setDispatchDuty(src, not job.onduty)
end)

local wasInside = {}

local function dutyTick()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ok, job = isDispatchJob(src)
        local failedAt = dutyFailed[src]
        if ok and failedAt and GetGameTimer() - failedAt < 30000 then
            ok = false
        end
        if ok then
            local inside = DispatchZones.inZone(Core.pedCoords(src))
            if Config.Dispatcher.autoDuty then
                if inside and not job.onduty then
                    setDispatchDuty(src, true, 'You clocked in at dispatch.')
                elseif not inside and job.onduty then
                    setDispatchDuty(src, false, 'You left the dispatch centre and clocked out.')
                end
            end
            wasInside[src] = inside
        else
            wasInside[src] = nil
        end
    end
end

CreateThread(function()
    while true do
        Wait(1500)
        local ok, err = pcall(dutyTick)
        if not ok then print(('^1[vr-mdt] dispatch duty: %s^0'):format(tostring(err))) end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        for src in pairs(listening) do
            local ok, job = isDispatchJob(src)
            if not ok or not job.onduty or not Core.dispatchSpot(src) then
                setListen(src, {})
                TriggerClientEvent('vr-mdt:client:radioReset', src)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    listening[source] = nil
    lastDuty[source] = nil
    wasInside[source] = nil
    dutyFailed[source] = nil
end)

Db.schema('dispatch_spots', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_dispatch_spots` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(8) NOT NULL,
        `label` VARCHAR(64) NOT NULL,
        `x` DOUBLE NOT NULL,
        `y` DOUBLE NOT NULL,
        `z` DOUBLE NOT NULL,
        `radius` DOUBLE NOT NULL,
        `created_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`id`)
    ) CHARSET utf8mb4
]])

Db.schema('dispatch_zones', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_dispatch_zones` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `label` VARCHAR(64) NOT NULL,
        `points` TEXT NOT NULL,
        `min_z` DOUBLE NOT NULL,
        `max_z` DOUBLE NOT NULL,
        `created_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`id`)
    ) CHARSET utf8mb4
]])

local baseZones = Config.Dispatcher.zones or {}
local baseComputers = Config.Dispatcher.computers or {}
local placed = { zone = {}, desk = {} }
local spotsLoaded = false

local function plainZone(z)
    if type(z.points) == 'table' then
        local pts = {}
        for i, p in ipairs(z.points) do pts[i] = { x = p.x + 0.0, y = p.y + 0.0 } end
        return { id = z.id, label = z.label, points = pts, minZ = z.minZ, maxZ = z.maxZ }
    end
    return { id = z.id, label = z.label, coords = { x = z.coords.x + 0.0, y = z.coords.y + 0.0, z = z.coords.z + 0.0 }, radius = z.radius }
end

local function plain(list)
    local out = {}
    for i, z in ipairs(list) do out[i] = plainZone(z) end
    return out
end

local function applySpots()
    Config.Dispatcher.zones = #placed.zone > 0 and placed.zone or baseZones
    Config.Dispatcher.computers = #placed.desk > 0 and placed.desk or baseComputers
end

local function spotsPayload()
    return { zones = plain(Config.Dispatcher.zones), computers = plain(Config.Dispatcher.computers), autoDuty = Config.Dispatcher.autoDuty == true }
end

local function syncSpots(target)
    TriggerClientEvent('vr-mdt:client:dispatchSpots', target or -1, spotsPayload())
end

local function decodePoints(text)
    local ok, list = pcall(json.decode, text or '')
    if not ok or type(list) ~= 'table' then return nil end
    local out = {}
    for _, p in ipairs(list) do
        local x, y = tonumber(p.x), tonumber(p.y)
        if x and y then out[#out + 1] = vector2(x + 0.0, y + 0.0) end
    end
    return #out >= 3 and out or nil
end

local function loadSpots()
    placed = { zone = {}, desk = {} }
    for _, r in ipairs(Db.query('SELECT * FROM `vr_mdt_dispatch_zones` ORDER BY `id`') or {}) do
        local pts = decodePoints(r.points)
        if pts then
            placed.zone[#placed.zone + 1] = { id = tonumber(r.id), poly = true, label = r.label, points = pts, minZ = tonumber(r.min_z) + 0.0, maxZ = tonumber(r.max_z) + 0.0 }
        end
    end
    for _, r in ipairs(Db.query('SELECT * FROM `vr_mdt_dispatch_spots` ORDER BY `id`') or {}) do
        local list = placed[r.kind]
        if list then
            list[#list + 1] = { id = tonumber(r.id), label = r.label, coords = vector3(tonumber(r.x) + 0.0, tonumber(r.y) + 0.0, tonumber(r.z) + 0.0), radius = tonumber(r.radius) + 0.0 }
        end
    end
    applySpots()
    spotsLoaded = true
end

Db.ready(function()
    loadSpots()
    syncSpots()
end)

local lastSpotAsk = {}
RegisterNetEvent('vr-mdt:server:dispatchSpots', function()
    local src = source
    local now = GetGameTimer()
    if lastSpotAsk[src] and now - lastSpotAsk[src] < 5000 then return end
    lastSpotAsk[src] = now
    if spotsLoaded then syncSpots(src) end
end)

Bridge.on('playerLoaded', function(src)
    if spotsLoaded then syncSpots(src) end
end)

local function reply(src, msg, kind)
    if src == 0 then return print('[vr-mdt] ' .. msg) end
    Core.notify(src, msg, kind)
end

local function nearest(coords, list, maxDist)
    local best, bestDist
    for i, z in ipairs(list) do
        if z.coords then
            local d = #(coords - z.coords)
            if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = i, d end
        end
    end
    return best
end

local function creator(src)
    local p = src > 0 and Core.player(src)
    return p and p.cid or nil
end

local function removeAt(list, index, sql)
    local spot = table.remove(list, index)
    if spot then Db.update(sql, { spot.id }) end
    return spot
end

RegisterCommand('dispatchdesk', function(src, args)
    if not spotsLoaded then return reply(src, 'The MDT database is not ready yet.', 'error') end
    local coords = src > 0 and Core.pedCoords(src)
    if not coords then return reply(src, 'Use this in game.', 'error') end
    if args[1] == 'remove' then
        local i = nearest(coords, placed.desk, 3.0)
        if not i then return reply(src, 'No placed desk within 3 m of you.', 'error') end
        local spot = removeAt(placed.desk, i, 'DELETE FROM `vr_mdt_dispatch_spots` WHERE `id` = ?')
        applySpots()
        syncSpots()
        return reply(src, ('Removed %s.'):format(spot.label), 'success')
    end
    local label = ('Dispatch desk %d'):format(#placed.desk + 1)
    local id = Db.insert('INSERT INTO `vr_mdt_dispatch_spots` (`kind`, `label`, `x`, `y`, `z`, `radius`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { 'desk', label, coords.x, coords.y, coords.z, 1.2, creator(src) })
    if not id then return reply(src, 'Could not save the desk.', 'error') end
    placed.desk[#placed.desk + 1] = { id = tonumber(id), label = label, coords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0), radius = 1.2 }
    applySpots()
    syncSpots()
    local msg = ('%s placed. Dispatchers can open the full screen console here.'):format(label)
    if not DispatchZones.inZone(coords) then msg = msg .. ' It is outside the dispatch zone, draw one with /dispatchzone.' end
    reply(src, msg, 'success')
end, true)

RegisterCommand('dispatchzone', function(src, args)
    if not spotsLoaded then return reply(src, 'The MDT database is not ready yet.', 'error') end
    local coords = src > 0 and Core.pedCoords(src)
    if not coords then return reply(src, 'Use this in game.', 'error') end
    if args[1] == 'remove' then
        for i, z in ipairs(placed.zone) do
            if DispatchZones.inside(coords, z) then
                local sql = z.poly and 'DELETE FROM `vr_mdt_dispatch_zones` WHERE `id` = ?' or 'DELETE FROM `vr_mdt_dispatch_spots` WHERE `id` = ?'
                local spot = removeAt(placed.zone, i, sql)
                applySpots()
                syncSpots()
                return reply(src, ('Removed %s.'):format(spot.label), 'success')
            end
        end
        return reply(src, "You're not inside a placed dispatch zone.", 'error')
    end
    local height = math.max(2.0, math.min(30.0, tonumber(args[1]) or 6.0))
    TriggerClientEvent('vr-mdt:client:zoneTool', src, height)
end, true)

RegisterNetEvent('vr-mdt:server:saveDispatchZone', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, 'command.dispatchzone') then return end
    if not spotsLoaded or type(data) ~= 'table' or type(data.points) ~= 'table' then return end
    local pts, lowest, highest = {}, nil, nil
    for i = 1, math.min(#data.points, 40) do
        local p = data.points[i]
        local x, y, z = type(p) == 'table' and tonumber(p.x), type(p) == 'table' and tonumber(p.y), type(p) == 'table' and tonumber(p.z)
        if not x or not y or not z or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then
            return reply(src, 'That zone has a bad corner, try again.', 'error')
        end
        pts[#pts + 1] = { x = x + 0.0, y = y + 0.0 }
        lowest = lowest and math.min(lowest, z) or z
        highest = highest and math.max(highest, z) or z
    end
    if #pts < 3 then return reply(src, 'A zone needs at least 3 corners.', 'error') end
    local height = math.max(2.0, math.min(30.0, tonumber(data.height) or 6.0))
    local minZ, maxZ = lowest - 1.5, highest + height
    local label = ('Dispatch centre %d'):format(#placed.zone + 1)
    local id = Db.insert('INSERT INTO `vr_mdt_dispatch_zones` (`label`, `points`, `min_z`, `max_z`, `created_by`) VALUES (?, ?, ?, ?, ?)',
        { label, json.encode(pts), minZ, maxZ, creator(src) })
    if not id then return reply(src, 'Could not save the zone.', 'error') end
    local old = 0
    for i = #placed.zone, 1, -1 do
        if not placed.zone[i].poly then
            table.remove(placed.zone, i)
            old = old + 1
        end
    end
    Db.update("DELETE FROM `vr_mdt_dispatch_spots` WHERE `kind` = 'zone'", {})
    local vecs = {}
    for i, p in ipairs(pts) do vecs[i] = vector2(p.x, p.y) end
    placed.zone[#placed.zone + 1] = { id = tonumber(id), poly = true, label = label, points = vecs, minZ = minZ, maxZ = maxZ }
    applySpots()
    syncSpots()
    reply(src, ('%s saved with %d corners.%s'):format(label, #pts, old > 0 and ' The old round zones were removed.' or ''), 'success')
end)

RegisterCommand('dispatchspots', function(src)
    if src == 0 then
        for _, z in ipairs(Config.Dispatcher.zones) do print(('[vr-mdt] zone %s %s'):format(z.label, z.points and (#z.points .. ' corners') or ('round r' .. tostring(z.radius)))) end
        for _, z in ipairs(Config.Dispatcher.computers) do print(('[vr-mdt] desk %s %.1f %.1f %.1f'):format(z.label, z.coords.x, z.coords.y, z.coords.z)) end
        return
    end
    TriggerClientEvent('vr-mdt:client:showDispatchSpots', src, spotsPayload())
    reply(src, ('%d zone(s) and %d desk(s). Showing them for 30 seconds.'):format(#Config.Dispatcher.zones, #Config.Dispatcher.computers), 'inform')
end, true)

Bridge.callback.register('vr-mdt:check', function(src)
    local player = Core.player(src)
    local job = player and player.job or {}
    local coords = Core.pedCoords(src)
    local ctx, why = Core.context(src)
    return {
        job = job.name, type = job.type, onduty = job.onduty == true, dept = Core.deptOf(job),
        coords = coords and { x = coords.x, y = coords.y, z = coords.z } or nil,
        inZone = DispatchZones.inZone(coords), spot = Core.dispatchSpot(src),
        zones = #Config.Dispatcher.zones, desks = #Config.Dispatcher.computers,
        ok = ctx ~= nil, why = why, autoDuty = Config.Dispatcher.autoDuty == true,
    }
end)

AddEventHandler('playerDropped', function()
    lastSpotAsk[source] = nil
end)

local DENY = { 'weapons.', 'cameras.', 'bodycams.', 'evidence.add', 'evidence.remove', 'evidence.update', 'evidence.open', 'evidence.locker' }

function Dispatcher.denied(action)
    for _, prefix in ipairs(DENY) do
        if action:sub(1, #prefix) == prefix then return true end
    end
    return false
end
