lib.callback.register('vr-garages:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

local function returnOutVehicles()
    local inWorld = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local a, b = Vehicles.platesOf(veh)
            if a then inWorld[a] = veh end
            if b then inWorld[b] = veh end
        end
    end
    local rows = MySQL.query.await('SELECT plate, garage FROM player_vehicles WHERE state = 0') or {}
    local back = 0
    for _, r in ipairs(rows) do
        local plate = GU.plate(r.plate)
        if plate and inWorld[plate] then
            Vehicles.spawned[plate] = { entity = inWorld[plate] }
        elseif plate then
            MySQL.update.await('UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?', { r.garage or Config.DefaultGarage, r.plate })
            back = back + 1
        end
    end
    if back > 0 then print(('[vr-garages] returned %d vehicles that were left out'):format(back)) end
end

Db.onReady(function()
    Garages.load()
    local ok, err = pcall(Vehicles.tidy)
    if not ok then print(('^1[vr-garages] tidy vehicles: %s^0'):format(tostring(err))) end
    if Config.ReturnOutVehiclesOnStart then
        local ok, err = pcall(returnOutVehicles)
        if not ok then print(('^1[vr-garages] return vehicles: %s^0'):format(tostring(err))) end
    end
end)

AddEventHandler('vr-banking:server:vehicleSeized', function(plate)
    local row = Vehicles.get(plate)
    if not row then return end
    Api.impound(row.plate, { fee = 0, reason = 'Repossessed by the bank', by = 'ValRavn Bank', hours = 0, silent = true })
end)

AddEventHandler('vr-banking:server:vehicleReleased', function(plate)
    local row = Vehicles.get(plate)
    if not row or row.state ~= 2 then return end
    Vehicles.update(row.plate, { depotprice = 0, impound_until = 0, impound_reason = 'Released by the bank. Collect it at the impound lot.' })
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local plate = GU.plate(GetVehicleNumberPlateText(entity))
    local s = plate and Vehicles.spawned[plate]
    if s and s.entity == entity then Vehicles.spawned[plate] = nil end
end)
