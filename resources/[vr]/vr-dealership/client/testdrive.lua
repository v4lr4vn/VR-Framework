local driving

local REASONS = {
    time = 'Test drive over. Hope you liked it!',
    left = 'You left the car, so the test drive ended',
    distance = 'You drove too far, the car was recalled',
    gone = 'The test drive ended',
}

RegisterNetEvent('vr-dealership:client:testDrive', function(netId, d)
    if type(d) ~= 'table' then return end
    local deadline = GetGameTimer() + 8000
    local veh = 0
    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(netId) then
            veh = NetToVeh(netId)
            if veh ~= 0 and DoesEntityExist(veh) then break end
        end
        Wait(50)
    end
    if veh == 0 then return end
    SetVehicleOnGroundProperly(veh)
    Bridge.vehicle.setFuel(veh, 100.0)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)
    Bridge.vehicle.giveKeys(veh, d.plate)
    driving = GetGameTimer() + (tonumber(d.seconds) or 120) * 1000
    local mine = driving
    CreateThread(function()
        while driving == mine do
            local left = math.max(0, math.floor((driving - GetGameTimer()) / 1000))
            lib.showTextUI(('Test drive · %d:%02d left'):format(left // 60, left % 60), { icon = 'fa-solid fa-stopwatch' })
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('vr-dealership:client:testDriveEnd', function(pos, reason)
    driving = nil
    lib.hideTextUI()
    if type(pos) == 'table' and pos.x then
        DoScreenFadeOut(400)
        Wait(450)
        SetEntityCoords(cache.ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
        Wait(200)
        DoScreenFadeIn(400)
    end
    Dealer.notify(REASONS[reason] or REASONS.gone, 'inform')
end)
