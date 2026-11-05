RegisterNetEvent('vr-adminmenu:client:SetOnFire', function(time)
    time = tonumber(time) or 10
    local timer = time * 1000
    StartEntityFire(cache.ped)
    Wait(timer)
    StopEntityFire(cache.ped)
end)

RegisterNetEvent('vr-adminmenu:client:ExplodePlayer', function(damage)
    local coords = GetEntityCoords(cache.ped)
    if damage == nil then damage = "nodamage" end
    if damage == "nodamage" then
        AddExplosion(coords.x, coords.y, coords.z, 'EXPLOSION_TANKER', 2.0, true, false, 2.0)
    else
        AddExplosion(coords.x, coords.y, coords.z, 2, 0.9, 1, 0, 1065353216, 0)
    end
end)

RegisterNetEvent('vr-adminmenu:client:InitiateDrunkEffect', function()
    local playerPed = cache.ped
    lib.requestAnimSet("MOVE_M@DRUNK@VERYDRUNK")
    Wait(650)
    SetPedMotionBlur(playerPed, true)
    SetPedMovementClipset(playerPed, "MOVE_M@DRUNK@VERYDRUNK", true)
    SetPedIsDrunk(playerPed, true)
    ShakeGameplayCam("DRUNK_SHAKE", 2.0)
    Wait(30000)
    SetPedMoveRateOverride(playerPed, 1.0)
    SetRunSprintMultiplierForPlayer(cache.playerId, 1.0)
    SetPedIsDrunk(playerPed, false)
    SetPedMotionBlur(playerPed, false)
    ResetPedMovementClipset(playerPed)
    ShakeGameplayCam("DRUNK_SHAKE", 0.0)
    SetTimecycleModifierStrength(0.0)
end)
