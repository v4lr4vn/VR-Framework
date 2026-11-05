RegisterNetEvent('vr-adminmenu:server:TeleportToPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:TeleportToPlayer', selectedData) then return end

    local player = GetTargetId(Field(selectedData, "Player"))
    if not player then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    local coords = GetEntityCoords(GetPlayerPed(player))

    CheckRoutingbucket(src, player)
    TriggerClientEvent('vr-adminmenu:client:TeleportToPlayer', src, coords)
end)

RegisterNetEvent('vr-adminmenu:server:BringPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:BringPlayer', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    local coords = GetEntityCoords(GetPlayerPed(src))

    CheckRoutingbucket(target, src)
    SetEntityCoords(GetPlayerPed(target), coords.x, coords.y, coords.z, false, false, false, false)
end)
