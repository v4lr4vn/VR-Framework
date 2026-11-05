local VRCore    = VRCore
local Functions = VRCore.Functions
local Shared    = VRCore.Shared
local resourceName = GetCurrentResourceName()

function Functions.SetMethod(methodName, handler)
    if type(methodName) ~= 'string' then return false, 'invalid_method_name' end
    if Functions[methodName] ~= nil then return false, 'method_exists' end
    Functions[methodName] = handler
    CoreEmit('Server:UpdateObject')
    return true, 'success'
end

function Functions.SetField(fieldName, data)
    if type(fieldName) ~= 'string' then return false, 'invalid_field_name' end
    if VRCore[fieldName] ~= nil then return false, 'field_exists' end
    VRCore[fieldName] = data
    CoreEmit('Server:UpdateObject')
    return true, 'success'
end

local delta = {}

local function remember(ns, key, value)
    delta[ns] = delta[ns] or {}
    if value == nil then value = false end
    delta[ns][key] = value
end

local function broadcast(ns, key, value)
    remember(ns, key, value)
    TriggerClientEvent('VRCore:Client:OnSharedUpdate', -1, ns, key, value)
    CoreEmit('Server:UpdateObject')
end

local function defineSharedApi(ns, singular, plural)
    local lower = singular:lower()

    Functions['Add' .. singular] = function(name, data)
        if type(name) ~= 'string' then return false, 'invalid_' .. lower .. '_name' end
        if Shared[ns][name] then return false, lower .. '_exists' end
        Shared[ns][name] = data
        broadcast(ns, name, data)
        return true, 'success'
    end

    Functions['Add' .. plural] = function(list)
        for name, data in pairs(list) do
            if type(name) ~= 'string' then return false, 'invalid_' .. lower .. '_name', data end
            if Shared[ns][name] then return false, lower .. '_exists', data end
        end
        for name, data in pairs(list) do
            Shared[ns][name] = data
            remember(ns, name, data)
        end
        TriggerClientEvent('VRCore:Client:OnSharedUpdateMultiple', -1, ns, list)
        CoreEmit('Server:UpdateObject')
        return true, 'success', nil
    end

    Functions['Update' .. singular] = function(name, data)
        if type(name) ~= 'string' then return false, 'invalid_' .. lower .. '_name' end
        if not Shared[ns][name] then return false, lower .. '_not_exists' end
        Shared[ns][name] = data
        broadcast(ns, name, data)
        return true, 'success'
    end

    Functions['Remove' .. singular] = function(name)
        if type(name) ~= 'string' then return false, 'invalid_' .. lower .. '_name' end
        if not Shared[ns][name] then return false, lower .. '_not_exists' end
        Shared[ns][name] = nil
        broadcast(ns, name, nil)
        return true, 'success'
    end
end

defineSharedApi('Jobs', 'Job', 'Jobs')
defineSharedApi('Items', 'Item', 'Items')
defineSharedApi('Gangs', 'Gang', 'Gangs')

local synced = {}
RegisterNetEvent('VRCore:Server:RequestSharedSync', function()
    local src = source
    if synced[src] then return end
    synced[src] = true
    if next(delta) then TriggerClientEvent('VRCore:Client:SharedSync', src, delta) end
end)
AddEventHandler('playerDropped', function() synced[source] = nil end)

function Functions.GetCoreVersion()
    return GetResourceMetadata(resourceName, 'version', 0)
end

function Functions.ExploitBan(playerId, origin)
    local name = GetPlayerName(playerId) or 'unknown'
    MySQL.insert('INSERT INTO vr_bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name,
        Functions.GetIdentifier(playerId, 'license'),
        Functions.GetIdentifier(playerId, 'discord') or '',
        Functions.GetIdentifier(playerId, 'ip') or '',
        origin,
        2147483647,
        'Anti Cheat',
    })
    DropPlayer(playerId, Lang:t('info.exploit_banned', { discord = VRCore.Config.Server.Discord }))
    CoreLog('anticheat', 'Anti-Cheat', 'red', true, '%s has been banned for exploiting %s', name, origin)
end

for name, fn in pairs(Functions) do
    if type(fn) == 'function' and not ExportedNames[name] then
        CoreExport(name, fn)
    end
end
