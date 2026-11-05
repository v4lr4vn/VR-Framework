Inv = {}
function Inv:AddItem(src, item, count, metadata) return Bridge.inventory.add(src, item, count or 1, metadata) end
function Inv:RemoveItem(src, item, count, metadata, slot) return Bridge.inventory.remove(src, item, count or 1, metadata, slot) end
function Inv:CanCarryItem(src, item, count) return Bridge.inventory.canCarry(src, item, count or 1) end
function Inv:GetSlot(src, slot) return Bridge.inventory.getSlot(src, slot) end
function Inv:Search(src, kind, item, metadata)
    if kind == 'count' then return Bridge.inventory.count(src, item, metadata) end
    return Bridge.inventory.search(src, item, metadata)
end

Speakers = {}
Systems = {}
Viewers = {}

function Debug(...)
    if Config.Debug then print(('[vr-djbooth] ' .. select(1, ...)):format(select(2, ...))) end
end

function GetPlayer(src) return Bridge.player(src) end

function Notify(src, msg, kind) Bridge.notify(src, msg, kind or 'primary') end

function IsAdmin(src)
    return Bridge.isAdmin(src)
end

function PedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local last = {}
function TooFast(src, key, ms)
    local now, k = GetGameTimer(), src .. ':' .. key
    if last[k] and now - last[k] < ms then return true end
    last[k] = now
    return false
end

AddEventHandler('playerDropped', function()
    local src = source
    local prefix = src .. ':'
    for k in pairs(last) do
        if k:sub(1, #prefix) == prefix then last[k] = nil end
    end
    for _, list in pairs(Viewers) do list[src] = nil end
end)

function CountSpeakers(sys)
    local n = 0
    for _ in pairs(sys.speakers) do n = n + 1 end
    return n
end

function SystemRadius(sys)
    if sys.range then return sys.range end
    if sys.kind == 'vehicle' then return Config.CarStereo.radius end
    local r = 0
    for id in pairs(sys.speakers) do
        local sp = Speakers[id]
        local info = sp and DJ.itemInfo(sp.item)
        if info and info.radius > r then r = info.radius end
    end
    return r
end

function SystemPoints(sys)
    local points = {}
    if sys.kind == 'vehicle' then
        local veh = sys.netId and NetworkGetEntityFromNetworkId(sys.netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then points[1] = GetEntityCoords(veh) end
        return points
    end
    for id in pairs(sys.speakers) do
        local sp = Speakers[id]
        if sp then points[#points + 1] = vector3(sp.x, sp.y, sp.z) end
    end
    return points
end

function DistanceTo(src, sys)
    local here = PedCoords(src)
    if not here then return math.huge end
    if (sys.bucket or 0) ~= GetPlayerRoutingBucket(src) then return math.huge end
    local best = math.huge
    for _, p in ipairs(SystemPoints(sys)) do
        local d = #(here - p)
        if d < best then best = d end
    end
    return best
end

function Elapsed(sys)
    local now = sys.now
    if not now then return 0 end
    return math.max(0, ((now.pausedAt or GetGameTimer()) - now.startedAt) / 1000)
end

local function nowPayload(sys)
    local now = sys.now
    if not now then return false end
    local t = now.track
    return {
        trackId = t.id, url = t.url, kind = t.kind, title = t.title,
        duration = t.duration or 0,
        elapsed = Elapsed(sys), paused = now.pausedAt ~= nil,
    }
end

function SpeakerPayload(sp)
    return {
        id = sp.id, item = sp.item, x = sp.x, y = sp.y, z = sp.z, h = sp.h,
        system = sp.system, bucket = sp.bucket or 0, job = PlaceJob(sp.place),
        home = sp.place and sp.place:match('^home:') and true or nil,
        owner = sp.ownerCid, place = sp.place,
    }
end

function SystemPayload(sys)
    return {
        id = sys.id, kind = sys.kind, name = sys.name, volume = sys.volume, bucket = sys.bucket or 0,
        netId = sys.netId, radius = SystemRadius(sys), range = sys.range, now = nowPayload(sys),
    }
end

function PushSpeaker(sp) TriggerClientEvent('vr-djbooth:client:speaker', -1, SpeakerPayload(sp)) end
function PushSpeakerRemoved(id) TriggerClientEvent('vr-djbooth:client:speakerRemoved', -1, id) end
local PUSH_GAP = 250
local pushDue = {}

function PushSystem(sys)
    local now = GetGameTimer()
    if sys.lastPush and now - sys.lastPush < PUSH_GAP then
        pushDue[sys.id] = true
        return
    end
    sys.lastPush = now
    pushDue[sys.id] = nil
    TriggerClientEvent('vr-djbooth:client:system', -1, SystemPayload(sys))
end

CreateThread(function()
    while true do
        Wait(100)
        for id in pairs(pushDue) do
            local sys = Systems[id]
            if not sys then
                pushDue[id] = nil
            elseif GetGameTimer() - (sys.lastPush or 0) >= PUSH_GAP then
                PushSystem(sys)
            end
        end
    end
end)
function PushSystemRemoved(id) TriggerClientEvent('vr-djbooth:client:systemRemoved', -1, id) end

function PanelPayload(sys, src)
    local queue = {}
    for i, t in ipairs(sys.queue) do
        queue[i] = { id = t.id, title = t.title, url = t.url, kind = t.kind, duration = t.duration or 0, by = t.by }
    end
    local speakers, nearby = {}, {}
    if sys.kind == 'speakers' then
        for id in pairs(sys.speakers) do
            local sp = Speakers[id]
            if sp then speakers[#speakers + 1] = { id = id, label = DJ.itemInfo(sp.item).label, x = sp.x, y = sp.y, z = sp.z } end
        end
        for _, sp in pairs(LinkCandidates(sys)) do
            nearby[#nearby + 1] = { id = sp.id, label = DJ.itemInfo(sp.item).label, x = sp.x, y = sp.y, z = sp.z }
        end
    end
    local payload = SystemPayload(sys)
    payload.queue = queue
    payload.loop = sys.loop
    payload.shuffle = sys.shuffle
    payload.speakers = speakers
    payload.nearby = nearby
    payload.place = sys.kind == 'speakers' and PlaceLabel(sys.place) or nil
    payload.linkRange = sys.kind == 'speakers' and LinkRange(sys.place) or nil
    payload.canRename = sys.kind == 'speakers'
    if sys.kind == 'vehicle' then payload.canUninstall = IsDriverOf(src, sys) and CanUninstallStereo(src, sys) end
    payload.maxQueue = Config.Limits.queueLength
    payload.rangeMin, payload.rangeMax, payload.rangeStep = Config.Range.min, Config.Range.max, Config.Range.step
    return payload
end

function PushPanel(sys)
    local list = Viewers[sys.id]
    if not list then return end
    for src in pairs(list) do
        if GetPlayerName(src) and CanControl(src, sys) then
            TriggerClientEvent('vr-djbooth:client:panel', src, PanelPayload(sys, src))
        else
            list[src] = nil
            TriggerClientEvent('vr-djbooth:client:panelClosed', src, sys.id)
        end
    end
end

function RemoveSystem(sys)
    Systems[sys.id] = nil
    pushDue[sys.id] = nil
    local list = Viewers[sys.id]
    if list then
        for src in pairs(list) do TriggerClientEvent('vr-djbooth:client:panelClosed', src, sys.id) end
    end
    Viewers[sys.id] = nil
    PushSystemRemoved(sys.id)
end

function ValidRange(v)
    v = DJ.num(v)
    if not v then return nil end
    return DJ.clamp(math.floor(v + 0.5), Config.Range.min, Config.Range.max)
end

function NewSystem(id, kind, name, place, bucket, volume)
    local sys = {
        id = id, kind = kind, name = name, place = place, bucket = bucket or 0,
        volume = volume or Config.DefaultVolume, speakers = {}, queue = {}, now = nil, loop = 'off', shuffle = false,
    }
    Systems[id] = sys
    return sys
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_systems` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(48) NOT NULL,
            `place` VARCHAR(64) NOT NULL,
            `bucket` INT NOT NULL DEFAULT 0,
            `volume` FLOAT NOT NULL DEFAULT 0.5,
            PRIMARY KEY (`id`),
            KEY `place` (`place`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_speakers` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `item` VARCHAR(32) NOT NULL,
            `system_id` INT UNSIGNED NOT NULL,
            `place` VARCHAR(64) NOT NULL,
            `bucket` INT NOT NULL DEFAULT 0,
            `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
            `owner` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `place` (`place`),
            KEY `system_id` (`system_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_zones` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(48) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            `max_speakers` TINYINT UNSIGNED NOT NULL DEFAULT 10,
            `min_z` DOUBLE NOT NULL,
            `max_z` DOUBLE NOT NULL,
            `points` TEXT NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_boomboxes` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(48) NOT NULL,
            `bucket` INT NOT NULL DEFAULT 0,
            `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
            `volume` FLOAT NOT NULL DEFAULT 0.5,
            `range_m` FLOAT DEFAULT NULL,
            `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_boosters` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `place` VARCHAR(64) NOT NULL,
            `bucket` INT NOT NULL DEFAULT 0,
            `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
            `owner` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `place` (`place`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    local hasRange = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vr_djbooth_systems' AND COLUMN_NAME = 'range_m'
    ]])
    if tonumber(hasRange) == 0 then
        MySQL.query.await('ALTER TABLE `vr_djbooth_systems` ADD COLUMN `range_m` FLOAT DEFAULT NULL')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_djbooth_vehicles` (
            `plate` VARCHAR(16) NOT NULL,
            `installed_by` VARCHAR(50) DEFAULT NULL,
            `installed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

Ready = false

function LoadAll()
    createTables()
    LoadZones()

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `vr_djbooth_systems`') or {}) do
        local sys = NewSystem('g' .. row.id, 'speakers', row.name, row.place, tonumber(row.bucket) or 0, DJ.clamp(tonumber(row.volume) or Config.DefaultVolume, 0, 1))
        sys.range = ValidRange(row.range_m)
    end

    local skipped = 0
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `vr_djbooth_speakers`') or {}) do
        local sys = Systems['g' .. row.system_id]
        if sys and Config.Speakers[row.item] then
            local id = 'p' .. row.id
            Speakers[id] = {
                id = id, dbId = row.id, item = row.item, system = sys.id, place = row.place, bucket = tonumber(row.bucket) or 0,
                x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z), h = tonumber(row.h) or 0.0, owner = row.owner,
            }
            sys.speakers[id] = true
        else
            skipped = skipped + 1
        end
    end
    if skipped > 0 then
        print(('^3[vr-djbooth] %d saved speaker(s) skipped: their item is no longer in Config.Speakers or their group is missing^0'):format(skipped))
    end

    for id, sys in pairs(Systems) do
        if sys.kind == 'speakers' and not next(sys.speakers) then
            Systems[id] = nil
            MySQL.update('DELETE FROM `vr_djbooth_systems` WHERE `id` = ?', { tonumber(id:sub(2)) })
        end
    end

    LoadBoomboxes()
    LoadBoosters()
    LoadVehicles()
    Ready = true
    TriggerClientEvent('vr-djbooth:client:reload', -1)
end

MySQL.ready(function()
    local ok, err = pcall(LoadAll)
    if not ok then print('^1[vr-djbooth] failed to load: ' .. tostring(err) .. '^0') end
end)

lib.callback.register('vr-djbooth:init', function(src)
    if TooFast(src, 'init', 3000) then return nil end
    local deadline = GetGameTimer() + 30000
    while not Ready and GetGameTimer() < deadline do Wait(100) end
    if not Ready then return nil end
    local speakers, systems = {}, {}
    for _, sp in pairs(Speakers) do speakers[#speakers + 1] = SpeakerPayload(sp) end
    for _, b in pairs(Boosters) do speakers[#speakers + 1] = BoosterPayload(b) end
    for _, sys in pairs(Systems) do systems[#systems + 1] = SystemPayload(sys) end
    return { speakers = speakers, systems = systems, zones = ZonesPayload(), isAdmin = IsAdmin(src) }
end)
