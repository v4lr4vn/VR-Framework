local function GetVehicleName(hash)
    local byHash = VRCore.Shared.VehicleHashes and VRCore.Shared.VehicleHashes[hash]
    if byHash then return byHash.model end
    for _, v in pairs(VRCore.Shared.Vehicles or {}) do
        if hash == v.hash then
            return v.model
        end
    end
end

local function FixVehicle(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    if ResourceUp('mechanic') then
        TriggerEvent('vehiclemod:client:fixEverything')
    end
end

RegisterNetEvent('vr-adminmenu:client:Admincar', function(data)
    if not cache.vehicle then return Notify(locale("not_in_vehicle"), 'error') end

    local props = lib.getVehicleProperties(cache.vehicle)
    local name = GetVehicleName(props.model)

    if name then
        TriggerServerEvent('vr-adminmenu:server:SaveCar', props)
    else
        Notify(locale("cannot_store_veh"), 'error')
    end
end)

RegisterNetEvent('vr-adminmenu:client:SpawnVehicle', function(data, selectedData)
    local selectedVehicle = type(selectedData) == 'table' and selectedData["Vehicle"] and selectedData["Vehicle"].value
    if type(selectedVehicle) ~= 'string' then return end
    local hash = GetHashKey(selectedVehicle)

    if not IsModelValid(hash) or not IsModelAVehicle(hash) then return end

    lib.requestModel(hash)

    if cache.vehicle then
        DeleteVehicle(cache.vehicle)
    end

    local vehicle = CreateVehicle(hash, GetEntityCoords(cache.ped), GetEntityHeading(cache.ped), true, false)
    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    SetModelAsNoLongerNeeded(hash)

    Wait(100)

    SetFuel(vehicle, 100.0)
    GiveKeys(VRCore.Functions.GetPlate(vehicle))
end)

RegisterNetEvent('vr-adminmenu:client:RefuelVehicle', function(data)
    if cache.vehicle then
        SetFuel(cache.vehicle, 100.0)
        Notify(locale("refueled_vehicle"), 'success')
    else
        Notify(locale("not_in_vehicle"), 'error')
    end
end)

RegisterNetEvent('vr-adminmenu:client:FixVehicle', function()
    local vehicle = cache.vehicle or GetVehiclePedIsIn(cache.ped, false)
    if not vehicle or vehicle == 0 then
        return Notify(locale("not_in_vehicle"), 'error')
    end
    FixVehicle(vehicle)
end)

RegisterNetEvent('vr-adminmenu:client:ChangePlate', function(data, selectedData)
    local plate = type(selectedData) == 'table' and selectedData["Plate"] and selectedData["Plate"].value
    if type(plate) ~= 'string' or plate == '' then
        return Notify(locale("plate_invalid"), "error", 5000)
    end

    if string.len(plate) > 8 then
        return Notify(locale("plate_max"), "error", 5000)
    end

    if not cache.vehicle then
        return Notify(locale("not_in_vehicle"), 'error')
    end

    local newPlate = lib.callback.await('vr-adminmenu:callback:ChangePlate', false, plate)
    if not newPlate then return end

    if type(newPlate) == 'string' then
        SetVehicleNumberPlateText(cache.vehicle, newPlate)
    end
    Wait(100)
    if ResourceUp('vehiclekeys') then
        TriggerServerEvent(Config.Resources.vehiclekeys .. ':server:AcquireVehicleKeys', VRCore.Functions.GetPlate(cache.vehicle))
    end
end)

local VEHICLE_DEV_MODE = false
local function UpdateVehicleMenu()
    while VEHICLE_DEV_MODE do
        Wait(1000)

        if not cache.vehicle then
            VEHICLE_DEV_MODE = false
            SendNUIMessage({ action = "showVehicleMenu", data = { show = false } })
            break
        end

        local vehicle = lib.getVehicleProperties(cache.vehicle)
        local name = GetVehicleName(vehicle.model)
        local netID = VehToNet(cache.vehicle)

        SendNUIMessage({
            action = "showVehicleMenu",
            data = {
                show = VEHICLE_DEV_MODE,
                name = name,
                model = vehicle.model,
                netID = netID,
                engine_health = vehicle.engineHealth,
                body_health = vehicle.bodyHealth,
                plate = vehicle.plate,
                fuel = vehicle.fuelLevel,
            }
        })
    end
end

RegisterNetEvent('vr-adminmenu:client:ToggleVehDevMenu', function(data)
    if not cache.vehicle then return end

    VEHICLE_DEV_MODE = not VEHICLE_DEV_MODE

    if VEHICLE_DEV_MODE then
        CreateThread(UpdateVehicleMenu)
    end
end)

local PERFORMANCE_MOD_INDICES = { 11, 12, 13, 15, 16 }
local function UpgradePerformance(vehicle)
    SetVehicleModKit(vehicle, 0)
    ToggleVehicleMod(vehicle, 18, true)
    SetVehicleFixed(vehicle)

    for _, modType in ipairs(PERFORMANCE_MOD_INDICES) do
        local maxMod = GetNumVehicleMods(vehicle, modType) - 1
        SetVehicleMod(vehicle, modType, maxMod, false)
    end

    Notify(locale("vehicle_max_modded"), 'success', 7500)
end

RegisterNetEvent('vr-adminmenu:client:maxmodVehicle', function(data)
    if cache.vehicle then
        UpgradePerformance(cache.vehicle)
    else
        Notify(locale("vehicle_not_driver"), 'error', 7500)
    end
end)

RegisterNetEvent("vr-adminmenu:client:SpawnPersonalVehicle", function(data, selectedData)
    local plate = type(selectedData) == 'table' and selectedData['VehiclePlate'] and selectedData['VehiclePlate'].value
    if type(plate) ~= 'string' then return end

    local netId, mods, savedPlate = lib.callback.await('vr-adminmenu:callback:SpawnPersonalVehicle', false, plate)
    if not netId then return end

    local timeout = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < timeout do Wait(10) end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local veh = NetToVeh(netId)
    local ped = cache.ped
    if GetVehiclePedIsIn(ped, false) ~= veh then
        TaskWarpPedIntoVehicle(ped, veh, -1)
    end
    SetVehicleModKit(veh, 0)
    Wait(100)
    if mods then
        VRCore.Functions.SetVehicleProperties(veh, mods)
    end
    SetVehicleNumberPlateText(veh, savedPlate or plate)

    SetFuel(veh, 100.0)
    GiveKeys(savedPlate or plate)
    FixVehicle(veh)
end)

lib.callback.register("vr-adminmenu:client:getvehData", function(vehicle)
    if type(vehicle) ~= 'string' or not IsModelInCdimage(joaat(vehicle)) then return {} end
    lib.requestModel(vehicle)

    local coords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5), GetEntityHeading(cache.ped) + 90)
    local veh = CreateVehicle(vehicle, coords, false, false)

    local prop = {}
    if DoesEntityExist(veh) then
        SetEntityCollision(veh, false, false)
        FreezeEntityPosition(veh, true)
        prop = VRCore.Functions.GetVehicleProperties(veh)
        Wait(500)
        DeleteVehicle(veh)
    end

    return prop
end)
