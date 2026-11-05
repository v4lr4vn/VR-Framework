local function enabled()
    return Config.Interactions.enable and Config.Interactions.put_out_vehicle
end

RegisterNetEvent('vr-policejob:server:putInVehicle', function(target)
    local src = source
    if not enabled() or not hasJob(src, Config.Interactions.jobs) then return end
    if not Security.cooldown('vehicle', src, 1) then return end

    target = Security.target(src, target, Config.Security.interactDistance)
    if not target then return Security.flag(src, 'putInVehicle on an invalid or far target') end
    if not isCuffed(target) then return end

    releaseDrag(target)
    TriggerClientEvent('vr-policejob:client:putInVehicle', target)
end)

RegisterNetEvent('vr-policejob:server:putOutVehicle', function(target)
    local src = source
    if not enabled() or not hasJob(src, Config.Interactions.jobs) then return end
    if not Security.cooldown('vehicle', src, 1) then return end

    target = Security.target(src, target, Config.Security.interactDistance)
    if not target then return Security.flag(src, 'putOutVehicle on an invalid or far target') end

    local vehicle = GetVehiclePedIsIn(GetPlayerPed(target), false)
    if not vehicle or vehicle == 0 then return end
    if not isCuffed(target) and (GetVehicleDoorLockStatus(vehicle) or 0) > 1 then return end

    TriggerClientEvent('vr-policejob:client:putOutVehicle', target)
end)
