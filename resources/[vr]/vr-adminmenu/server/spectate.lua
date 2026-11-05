local spectating = {}

local function stopSpectate(src)
    spectating[src] = nil
    TriggerClientEvent('vr-adminmenu:cancelSpectate', src)
    FreezeEntityPosition(GetPlayerPed(src), false)
    TriggerClientEvent('vr-adminmenu:client:toggleNames', src)
end

local function startSpectate(src, target)
    local tPed = GetPlayerPed(target)
    if not DoesEntityExist(tPed) then return false end
    spectating[src] = target
    TriggerClientEvent('vr-adminmenu:requestSpectate', src, NetworkGetNetworkIdFromEntity(tPed), target, GetPlayerName(target))
    TriggerClientEvent('vr-adminmenu:client:toggleNames', src)
    return true
end

RegisterNetEvent('vr-adminmenu:server:SpectateTarget', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SpectateTarget', selectedData) then return end

    if spectating[src] then return stopSpectate(src) end

    local player = GetTargetId(Field(selectedData, "Player"))
    if not player then return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500) end
    if player == src then return VRCore.Functions.Notify(src, locale("cant_spectate_yourself"), 'error', 7500) end

    if startSpectate(src, player) then
        CheckRoutingbucket(src, player)
    end
end)

RegisterNetEvent('vr-adminmenu:spectate:teleport', function(target)
    local src = source
    target = tonumber(target)
    if not target or spectating[src] ~= target then return end
    if not Authorize(src, 'vr-adminmenu:server:SpectateTarget', nil, true) then
        spectating[src] = nil
        return
    end

    local ped = GetPlayerPed(target)
    if DoesEntityExist(ped) then
        local targetCoords = GetEntityCoords(ped)
        SetEntityCoords(GetPlayerPed(src), targetCoords.x, targetCoords.y, targetCoords.z - 10)
        FreezeEntityPosition(GetPlayerPed(src), true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    spectating[src] = nil
    for admin, target in pairs(spectating) do
        if target == src then stopSpectate(admin) end
    end
end)
