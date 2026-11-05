if not TargetConfig.defaults then return end

local api = TargetApi

local seats = {
    [0] = 'dside_f',
    [1] = 'pside_f',
    [2] = 'dside_r',
    [3] = 'pside_r',
}

local function toggleDoor(vehicle, door)
    if GetVehicleDoorLockStatus(vehicle) == 2 then return end
    if GetVehicleDoorAngleRatio(vehicle, door) > 0.0 then
        SetVehicleDoorShut(vehicle, door, false)
    else
        SetVehicleDoorOpen(vehicle, door, false, false)
    end
end

local function usable(vehicle, coords, door, byOffset)
    if not GetIsDoorValid(vehicle, door) or GetVehicleDoorLockStatus(vehicle) > 1 or IsVehicleDoorDamaged(vehicle, door) or cache.vehicle then
        return false
    end
    if byOffset then return true end
    local seat = seats[door]
    if not seat then return false end
    local doorBone = GetEntityBoneIndexByName(vehicle, 'door_' .. seat)
    if doorBone == -1 then return false end
    if #(coords - GetEntityBonePosition_2(vehicle, doorBone)) < 0.5 then return true end
    local seatBone = GetEntityBoneIndexByName(vehicle, 'seat_' .. seat)
    return seatBone ~= -1 and #(coords - GetEntityBonePosition_2(vehicle, seatBone)) < 0.72
end

local function onDoor(data, door)
    local vehicle = data.entity
    if NetworkGetEntityOwner(vehicle) == PlayerId() then
        return toggleDoor(vehicle, door)
    end
    TriggerServerEvent('vr-target:toggleEntityDoor', VehToNet(vehicle), door)
end

RegisterNetEvent('vr-target:toggleEntityDoor', function(netId, door)
    local vehicle = NetToVeh(netId)
    if vehicle and vehicle ~= 0 then toggleDoor(vehicle, door) end
end)

local function doorOption(name, label, icon, door, bones, offset)
    return {
        name = name,
        icon = icon,
        label = locale(label),
        bones = bones,
        offset = offset,
        distance = 2,
        canInteract = function(entity, _, coords)
            return usable(entity, coords, door, offset ~= nil)
        end,
        onSelect = function(data)
            onDoor(data, door)
        end,
    }
end

api.addGlobalVehicle({
    doorOption('vr-target:driverF', 'toggle_front_driver_door', 'fa-solid fa-car-side', 0, { 'door_dside_f', 'seat_dside_f' }),
    doorOption('vr-target:passengerF', 'toggle_front_passenger_door', 'fa-solid fa-car-side', 1, { 'door_pside_f', 'seat_pside_f' }),
    doorOption('vr-target:driverR', 'toggle_rear_driver_door', 'fa-solid fa-car-side', 2, { 'door_dside_r', 'seat_dside_r' }),
    doorOption('vr-target:passengerR', 'toggle_rear_passenger_door', 'fa-solid fa-car-side', 3, { 'door_pside_r', 'seat_pside_r' }),
    doorOption('vr-target:bonnet', 'toggle_hood', 'fa-solid fa-car', 4, nil, vec3(0.5, 1, 0.5)),
    doorOption('vr-target:trunk', 'toggle_trunk', 'fa-solid fa-car-rear', 5, nil, vec3(0.5, 0, 0.5)),
})
