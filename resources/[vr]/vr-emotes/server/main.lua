local ready = false
local pending = {}
local partners = {}
local lastRequest = {}
local lastPtfx = {}
local lastSave = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_emote_prefs` (
            `license` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    ready = true
end)

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

local function citizenId(src)
    if GetResourceState('vr-core') ~= 'started' then return nil end
    local ok, player = pcall(function() return exports['vr-core']:GetPlayer(src) end)
    return ok and player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function near(a, b, dist)
    local pa, pb = coords(a), coords(b)
    return pa and pb and #(pa - pb) <= dist
end

local function readPrefs(id)
    local raw = MySQL.scalar.await('SELECT `data` FROM `vr_emote_prefs` WHERE `license` = ?', { id })
    if not raw then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and type(data) == 'table' and data or {}
end

local function validId(id)
    return type(id) == 'string' and #id <= 120 and Catalog.get(id) ~= nil
end

lib.callback.register('vr-emotes:prefs:load', function(src)
    local id = license(src)
    if not id then return {} end
    local tries = 0
    while not ready and tries < 100 do
        Wait(100)
        tries = tries + 1
    end
    if not ready then return {} end
    local data = readPrefs(id)
    local cid = citizenId(src) or 'default'
    return {
        favs = data.favs,
        slots = data.slots,
        walk = type(data.walks) == 'table' and data.walks[cid] or nil,
        mood = type(data.moods) == 'table' and data.moods[cid] or nil,
    }
end)

RegisterNetEvent('vr-emotes:prefs:save', function(patch)
    local src = source
    local id = license(src)
    if not id or not ready or type(patch) ~= 'table' then return end
    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < 1000 then return end
    lastSave[src] = now
    local data = readPrefs(id)
    if type(patch.favs) == 'table' then
        local favs = {}
        for _, fav in ipairs(patch.favs) do
            if #favs >= 300 then break end
            if validId(fav) then favs[#favs + 1] = fav end
        end
        data.favs = favs
    end
    if type(patch.slots) == 'table' then
        local slots = {}
        for i = 1, Config.QuickSlots do
            local v = patch.slots[i]
            slots[i] = validId(v) and v or false
        end
        data.slots = slots
    end
    local cid = citizenId(src) or 'default'
    if patch.walk ~= nil then
        data.walks = type(data.walks) == 'table' and data.walks or {}
        local valid = false
        if type(patch.walk) == 'string' then
            for _, w in pairs(RP.Walks) do
                if w[1] == patch.walk then valid = true break end
            end
        end
        data.walks[cid] = valid and patch.walk or nil
    end
    if patch.mood ~= nil then
        data.moods = type(data.moods) == 'table' and data.moods or {}
        local valid = false
        if type(patch.mood) == 'string' then
            for _, m in pairs(RP.Expressions) do
                if m[1] == patch.mood then valid = true break end
            end
        end
        data.moods[cid] = valid and patch.mood or nil
    end
    local encoded = json.encode(data)
    if #encoded > 60000 then return end
    MySQL.update.await('INSERT INTO `vr_emote_prefs` (`license`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { id, encoded })
end)

local function sharedEntry(name)
    if type(name) ~= 'string' then return nil end
    if RP.Shared[name] then return RP.Shared[name], 'Shared' end
    if RP.Dances[name] then return RP.Dances[name], 'Dances' end
end

RegisterNetEvent('vr-emotes:shared:request', function(target, name)
    local src = source
    target = tonumber(target)
    if not Config.SharedEmotesEnabled or not target or target == src or not GetPlayerName(target) then return end
    local entry = sharedEntry(name)
    if not entry then return end
    if Config.AdultEmotesDisabled and Catalog.isAdult(entry, name) then return end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 2000 then return end
    lastRequest[src] = now
    if not near(src, target, Config.SharedDistance + 1.0) then return end
    pending[target] = { from = src, name = name, expires = now + Config.SharedRequestSeconds * 1000 }
    TriggerClientEvent('vr-emotes:shared:incoming', target, src, name, GetPlayerName(src))
end)

local function stopPair(src)
    local other = partners[src]
    if other then
        partners[src] = nil
        if partners[other] == src then partners[other] = nil end
        TriggerClientEvent('vr-emotes:shared:stop', other, src)
    end
end

RegisterNetEvent('vr-emotes:shared:accept', function(from)
    local src = source
    local req = pending[src]
    from = tonumber(from)
    if not req or req.from ~= from then return end
    pending[src] = nil
    if GetGameTimer() > req.expires or not GetPlayerName(from) then return end
    if not near(src, from, Config.SharedDistance + 1.0) then return end
    local entry, tbl = sharedEntry(req.name)
    if not entry then return end
    local other = entry[4]
    if type(other) ~= 'string' or not RP[tbl][other] then other = req.name end
    stopPair(src)
    stopPair(from)
    partners[src] = from
    partners[from] = src
    TriggerClientEvent('vr-emotes:shared:play', from, req.name, src, true)
    TriggerClientEvent('vr-emotes:shared:play', src, other, from, false)
end)

RegisterNetEvent('vr-emotes:shared:decline', function(from)
    local src = source
    local req = pending[src]
    if not req or req.from ~= tonumber(from) then return end
    pending[src] = nil
    TriggerClientEvent('vr-emotes:shared:declined', req.from)
end)

RegisterNetEvent('vr-emotes:shared:cancel', function()
    stopPair(source)
end)

RegisterNetEvent('vr-emotes:ptfx:sync', function(id)
    local src = source
    if not validId(id) then return end
    local entry, _, key = Catalog.get(id)
    local o = entry and entry.AnimationOptions
    if not o or type(o.PtfxAsset) ~= 'string' or type(o.PtfxName) ~= 'string' or type(o.PtfxPlacement) ~= 'table' then return end
    if Config.AdultEmotesDisabled and Catalog.isAdult(entry, key) then return end
    local p = o.PtfxPlacement
    local state = Player(src).state
    state:set('ptfxAsset', o.PtfxAsset, true)
    state:set('ptfxName', o.PtfxName, true)
    state:set('ptfxOffset', vector3((p[1] or 0.0) + 0.0, (p[2] or 0.0) + 0.0, (p[3] or 0.0) + 0.0), true)
    state:set('ptfxRot', vector3((p[4] or 0.0) + 0.0, (p[5] or 0.0) + 0.0, (p[6] or 0.0) + 0.0), true)
    state:set('ptfxBone', o.PtfxBone, true)
    state:set('ptfxScale', p[7] or 1.0, true)
    state:set('ptfxColor', o.PtfxColor, true)
    state:set('ptfxPropNet', false, true)
    state:set('ptfx', false, true)
end)

RegisterNetEvent('vr-emotes:ptfx:prop', function(netId)
    local src = source
    netId = tonumber(netId)
    local state = Player(src).state
    if not netId then return state:set('ptfxPropNet', false, true) end
    local tries = 0
    local entity = NetworkGetEntityFromNetworkId(netId)
    while (not entity or entity == 0 or not DoesEntityExist(entity)) and tries < 100 do
        Wait(10)
        tries = tries + 1
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity and entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityOwner(entity) == src then
        state:set('ptfxPropNet', netId, true)
    else
        state:set('ptfxPropNet', false, true)
    end
end)

RegisterNetEvent('vr-emotes:ptfx', function(on)
    local src = source
    local now = GetGameTimer()
    if on and lastPtfx[src] and now - lastPtfx[src] < 250 then return end
    lastPtfx[src] = now
    local state = Player(src).state
    if on and not state.ptfxAsset then return end
    state:set('ptfx', on == true, true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    stopPair(src)
    pending[src] = nil
    lastRequest[src] = nil
    lastPtfx[src] = nil
    lastSave[src] = nil
    for target, req in pairs(pending) do
        if req.from == src then pending[target] = nil end
    end
end)
