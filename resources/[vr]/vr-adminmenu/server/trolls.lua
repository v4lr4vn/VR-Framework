local frozen = {}
RegisterNetEvent('vr-adminmenu:server:FreezePlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:FreezePlayer', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    local label = FullName(Player) .. " | " .. Player.PlayerData.citizenid
    frozen[target] = not frozen[target] or nil
    FreezeEntityPosition(GetPlayerPed(target), frozen[target] == true)
    VRCore.Functions.Notify(src, locale(frozen[target] and "Frozen" or "deFrozen", label), 'success', 7500)
end)

AddEventHandler('playerDropped', function()
    frozen[source] = nil
end)

RegisterNetEvent('vr-adminmenu:server:DrunkPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:DrunkPlayer', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    TriggerClientEvent('vr-adminmenu:client:InitiateDrunkEffect', target)
    VRCore.Functions.Notify(src,
        locale("playerdrunk", FullName(Player) .. " | " .. Player.PlayerData.citizenid), 'success', 7500)
end)
