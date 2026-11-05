local api = {}

function api.AddVehicle(cid, model, opts)
    opts = type(opts) == 'table' and opts or {}
    local license = opts.license or Core.license(cid)
    return Vehicles.add(cid, license, model, opts)
end

function api.GetVehicle(plate)
    local row = Vehicles.get(plate)
    if not row then return nil end
    return {
        plate = row.plate, model = row.vehicle, owner = row.citizenid, garage = row.garage, state = row.state, fleet = row.fleet,
        fuel = row.fuel, engine = row.engine, body = row.body, mileage = row.drivingdistance, status = Vehicles.status(row), mods = row.mods,
    }
end

function api.GetPlayerVehicles(cid)
    local out = {}
    for _, row in ipairs(Vehicles.forOwner(cid)) do
        out[#out + 1] = { plate = row.plate, model = row.vehicle, label = Core.vehicleLabel(row.vehicle), garage = row.garage, state = row.state, fleet = row.fleet }
    end
    return out
end

function api.SetVehicleGarage(plate, garage, state)
    return Vehicles.update(plate, { garage = garage, state = tonumber(state) or 1 })
end

function api.SetVehicleOwner(plate, cid)
    local license = Core.license(cid)
    if not license then return false end
    MySQL.update.await('UPDATE player_vehicles SET citizenid = ?, license = ?, fleet = NULL WHERE plate = ?', { cid, license, GU.plate(plate) })
    TriggerEvent('vr-garages:server:ownerChanged', GU.plate(plate), cid)
    return true
end

function api.ImpoundVehicle(plate, opts)
    return Api.impound(plate, type(opts) == 'table' and opts or {})
end

function api.ReleaseImpound(plate)
    local row = Vehicles.get(plate)
    if not row or row.state ~= 2 then return false end
    return Vehicles.update(row.plate, { depotprice = 0, impound_until = 0 })
end

function api.IsVehicleOut(plate)
    return Vehicles.entity(plate) ~= nil
end

function api.GeneratePlate()
    return Vehicles.generatePlate()
end

function api.SpawnOwnedVehicle(src, plate, coords)
    local row = Vehicles.get(plate)
    if not row then return false, 'no_vehicle' end
    local status = Vehicles.status(row)
    if status ~= 'stored' then return false, status end
    if type(coords) ~= 'table' and type(coords) ~= 'vector4' then return false, 'bad_coords' end
    local spot = vec4((coords.x or 0) + 0.0, (coords.y or 0) + 0.0, (coords.z or 0) + 0.0, (coords.w or coords.h or 0) + 0.0)
    if not Spawn.lock(row.plate) then return false, 'busy' end
    Vehicles.update(row.plate, { state = 0 })
    local ok, veh = pcall(Spawn.create, src, row, spot)
    Spawn.unlock(row.plate)
    if not ok or not veh then
        Vehicles.update(row.plate, { state = 1 })
        return false, 'spawn_failed'
    end
    return true, NetworkGetNetworkIdFromEntity(veh)
end

function api.ParkVehicle(plate, coords)
    local row = Vehicles.get(plate)
    if not row then return false, 'no_vehicle' end
    if Vehicles.entity(row.plate) then return false, 'already_out' end
    if row.state == 2 or Core.bankHeld(row.plate) then return false, 'impounded' end
    if type(coords) ~= 'table' and type(coords) ~= 'vector4' then return false, 'bad_coords' end
    local spot = vec4((coords.x or 0) + 0.0, (coords.y or 0) + 0.0, (coords.z or 0) + 0.0, (coords.w or coords.h or 0) + 0.0)
    if not Spawn.lock(row.plate) then return false, 'busy' end
    local before = { state = row.state, garage = row.garage }
    Vehicles.update(row.plate, { state = 0 })
    local ok, veh = pcall(Spawn.park, row, spot)
    Spawn.unlock(row.plate)
    if not ok or not veh then
        Vehicles.update(row.plate, before)
        return false, 'spawn_failed'
    end
    return true, NetworkGetNetworkIdFromEntity(veh)
end

function api.GetGarages()
    local out = {}
    for id, def in pairs(Garages.list) do out[id] = { label = def.label, type = def.type, category = def.category, group = def.group } end
    return out
end

for name, fn in pairs(api) do
    exports(name, fn)
    exports(name:sub(1, 1):lower() .. name:sub(2), fn)
end
