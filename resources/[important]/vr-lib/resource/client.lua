local cache = { playerId = PlayerId() }
cache.serverId = GetPlayerServerId(cache.playerId)

local function set(key, value)
    if value ~= cache[key] then
        local old = cache[key]
        cache[key] = value
        TriggerEvent(('vr-lib:cache:%s'):format(key), value, old)
        return true
    end
end

exports('cache', function(key)
    if key == 'coords' then return GetEntityCoords(PlayerPedId()) end
    return cache[key]
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped ~= 0 then
            set('ped', ped)
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle > 0 then
                if vehicle ~= cache.vehicle then set('seat', false) end
                set('vehicle', vehicle)
                if not cache.seat or GetPedInVehicleSeat(vehicle, cache.seat) ~= ped then
                    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
                        if GetPedInVehicleSeat(vehicle, i) == ped then
                            set('seat', i)
                            break
                        end
                    end
                end
            else
                set('vehicle', false)
                set('seat', false)
            end
            local hasWeapon, weapon = GetCurrentPedWeapon(ped, true)
            set('weapon', (hasWeapon and weapon ~= 0) and weapon or false)
        end
        Wait(100)
    end
end)

AddStateBagChangeHandler('vr_lib:vehicleProperties', '', function(bagName, _, value)
    if type(value) ~= 'table' then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local deadline = GetGameTimer() + 5000
    while NetworkGetEntityOwner(entity) ~= cache.playerId do
        if GetGameTimer() > deadline or not DoesEntityExist(entity) then return end
        Wait(50)
    end
    local apply = load(LoadResourceFile(GetCurrentResourceName(), 'imports/setVehicleProperties/client.lua'))
    if apply then
        local fn = apply()
        if fn then fn(entity, value) end
    end
end)
