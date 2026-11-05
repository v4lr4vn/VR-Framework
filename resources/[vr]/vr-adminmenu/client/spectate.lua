local oldPos = nil
local spectateInfo = {
    toggled = false,
    target = 0,
    targetPed = 0
}

RegisterNetEvent('vr-adminmenu:requestSpectate', function(targetPed, target, name)
    oldPos = GetEntityCoords(cache.ped)
    spectateInfo = {
        toggled = true,
        target = target,
        targetPed = targetPed
    }
end)

RegisterNetEvent('vr-adminmenu:cancelSpectate', function()
    if NetworkIsInSpectatorMode() then
        NetworkSetInSpectatorMode(false, spectateInfo['targetPed'])
    end
    SetEntityVisible(cache.ped, true, 0)
    spectateInfo = { toggled = false, target = 0, targetPed = 0 }
    if oldPos then
        RequestCollisionAtCoord(oldPos.x, oldPos.y, oldPos.z)
        SetEntityCoords(cache.ped, oldPos.x, oldPos.y, oldPos.z, false, false, false, false)
    end
    oldPos = nil
end)

CreateThread(function()
    while true do
        Wait(0)
        if spectateInfo['toggled'] then
            local targetPed = NetworkGetEntityFromNetworkId(spectateInfo.targetPed)
            if DoesEntityExist(targetPed) then
                SetEntityVisible(cache.ped, false, 0)
                if not NetworkIsInSpectatorMode() then
                    RequestCollisionAtCoord(GetEntityCoords(targetPed))
                    NetworkSetInSpectatorMode(true, targetPed)
                end
            else
                TriggerServerEvent('vr-adminmenu:spectate:teleport', spectateInfo['target'])
                local deadline = GetGameTimer() + 10000
                while spectateInfo['toggled'] and GetGameTimer() < deadline
                    and not DoesEntityExist(NetworkGetEntityFromNetworkId(spectateInfo.targetPed)) do
                    Wait(100)
                end
            end
        else
            Wait(500)
        end
    end
end)
