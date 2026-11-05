local cuffed = {}
local adminGrants = {}

local ADMIN_GRANT_MS = 15000

local function syncState(src, value)
    local p = getPlayer(src)
    if p then p.Functions.SetMetaData('ishandcuffed', value) end
    pcall(function() Player(src).state:set('isHandcuffed', value, true) end)
end

function isCuffed(src)
    src = tonumber(src)
    return src ~= nil and cuffed[src] ~= nil
end

function cuffPlayer(target, status, by)
    cuffed[target] = { status = status, by = by, time = GetGameTimer() }
    syncState(target, true)
    TriggerClientEvent('vr-policejob:client:handcuff', target, status)
end

function uncuffPlayer(target)
    if not cuffed[target] then return false end
    cuffed[target] = nil
    syncState(target, false)
    releaseDrag(target)
    TriggerClientEvent('vr-policejob:client:uncuff', target)
    return true
end

function clearCuffs(src)
    adminGrants[src] = nil
    if not cuffed[src] then return end
    cuffed[src] = nil
    syncState(src, false)
end

local function cuffsEnabled()
    return Config.Interactions.enable and Config.Interactions.handcuffs
end

RegisterNetEvent('vr-policejob:server:handcuff', function(data)
    local src = source
    if not cuffsEnabled() or type(data) ~= 'table' then return end
    if not hasJob(src, Config.Interactions.jobs) then return end
    if not Security.cooldown('cuff', src, 1.5) then return end

    local target = Security.target(src, data.targetServerId, Config.Security.interactDistance)
    if not target then return Security.flag(src, 'handcuff on an invalid or far target') end
    if cuffed[target] then return end

    if (tonumber(exports['vr-inventory']:Search(src, 'count', Config.ItemCuffs)) or 0) < 1 then
        return notify(src, locale('no_handcuffs'), 'error')
    end
    if not exports['vr-inventory']:RemoveItem(src, Config.ItemCuffs, 1) then return end

    cuffPlayer(target, data.handcuffStatus == 1 and 1 or 0, src)
end)

RegisterNetEvent('vr-policejob:server:uncuff', function(data)
    local src = source
    if not cuffsEnabled() or type(data) ~= 'table' then return end
    if not hasJob(src, Config.Interactions.jobs) then return end
    if not Security.cooldown('cuff', src, 1.5) then return end

    local target = Security.target(src, data.targetServerId, Config.Security.interactDistance)
    if not target then return Security.flag(src, 'uncuff on an invalid or far target') end
    if not cuffed[target] then return end

    uncuffPlayer(target)
end)

RegisterNetEvent('vr-policejob:server:breakCuffs', function(success)
    local src = source
    if not Config.CanBreakCuffs or not cuffed[src] then return end
    if not Security.cooldown('breakcuffs', src, 5) then return end
    if (tonumber(exports['vr-inventory']:Search(src, 'count', Config.BreakCuffsItem)) or 0) < 1 then return end
    if not exports['vr-inventory']:RemoveItem(src, Config.BreakCuffsItem, 1) then return end
    if success == true then uncuffPlayer(src) end
end)

RegisterNetEvent('vr-adminmenu:server:CuffPlayer', function(_, selectedData)
    local src = source
    if VRCore.Functions.HasPermission(src, Config.AdminCuffPermissions) ~= true then return end
    local field = type(selectedData) == 'table' and selectedData.Player or nil
    local target = Security.int(tonumber(type(field) == 'table' and field.value or nil), 1)
    if not target or not GetPlayerName(target) then return end
    adminGrants[target] = GetGameTimer() + ADMIN_GRANT_MS
end)

RegisterNetEvent('vr-policejob:server:adminToggleCuffs', function()
    local src = source
    local expires = adminGrants[src]
    adminGrants[src] = nil
    if not expires or GetGameTimer() > expires then
        return Security.flag(src, 'cuff toggle without a staff request')
    end
    if not getPlayer(src) then return end

    if cuffed[src] then
        uncuffPlayer(src)
    else
        cuffPlayer(src, 0, nil)
    end
end)

exports('IsHandcuffed', function(src)
    return isCuffed(src)
end)

AddEventHandler('VRCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and tonumber(player.PlayerData.source)
    if not src or cuffed[src] then return end
    local p = getPlayer(src)
    if p and p.PlayerData.metadata and p.PlayerData.metadata.ishandcuffed then
        syncState(src, false)
    end
end)

CreateThread(function()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local p = src and getPlayer(src)
        if p and p.PlayerData.metadata and p.PlayerData.metadata.ishandcuffed and not cuffed[src] then
            syncState(src, false)
        end
    end
end)
