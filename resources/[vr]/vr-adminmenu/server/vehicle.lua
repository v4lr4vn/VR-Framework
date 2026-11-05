local function vehicleTable()
    return ('`%s`'):format(Config.VehicleTable)
end

local function sharedVehicle(model)
    if type(model) == 'string' then return exports['vr-core']:GetShared('Vehicles', model) end
    if type(model) == 'number' then
        return exports['vr-core']:GetShared('VehicleHashes', model)
            or exports['vr-core']:GetShared('VehicleHashes', model < 0 and model + 4294967296 or model - 4294967296)
    end
end

local function currentVehicle(src)
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
end

RegisterNetEvent('vr-adminmenu:server:SaveCar', function(mods)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:Admincar') then return end
    if not VehicleTableReady(src) then return end

    local Player = VRCore.Functions.GetPlayer(src)
    local veh = currentVehicle(src)
    if not Player or not veh then
        return VRCore.Functions.Notify(src, locale("not_in_vehicle"), 'error', 5000)
    end

    local hash = GetEntityModel(veh)
    local vehicleData = sharedVehicle(hash)
    if not vehicleData then
        return VRCore.Functions.Notify(src, locale("cannot_store_veh"), 'error', 5000)
    end

    local plate = Trim(GetVehicleNumberPlateText(veh) or '')
    if plate == '' then
        return VRCore.Functions.Notify(src, locale("plate_invalid"), 'error', 5000)
    end

    if CheckAlreadyPlate(plate) then
        return VRCore.Functions.Notify(src, locale("u_veh_owner"), 'error', 3000)
    end

    mods = type(mods) == 'table' and mods or {}
    mods.model = hash
    mods.plate = plate

    MySQL.insert.await(
        ('INSERT INTO %s (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(vehicleTable()),
        {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            vehicleData.model,
            hash,
            json.encode(mods),
            plate,
            0
        })
    VRCore.Functions.Notify(src, locale("veh_owner"), 'success', 5000)
end)

RegisterNetEvent("vr-adminmenu:server:givecar", function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:givecar', selectedData) then return end
    if not VehicleTableReady(src) then return end

    local vehmodel = Field(selectedData, 'Vehicle')
    local vehicleShared = type(vehmodel) == 'string' and sharedVehicle(vehmodel)
    if not vehicleShared then
        return VRCore.Functions.Notify(src, locale("invalid_vehicle"), "error", 5000)
    end

    local tsrc, Player = GetTargetPlayer(Field(selectedData, 'Player'))
    if not tsrc then
        return VRCore.Functions.Notify(src, locale("not_online"), "error", 5000)
    end

    local vehicleData = lib.callback.await("vr-adminmenu:client:getvehData", src, vehmodel)
    if type(vehicleData) ~= 'table' or not next(vehicleData) then return end

    local plateInput = Field(selectedData, 'Plate (Optional)')
    local plate
    if type(plateInput) == 'string' and Trim(plateInput) ~= '' then
        plate = CleanPlate(plateInput)
        if not plate then
            return VRCore.Functions.Notify(src, locale("plate_max"), "error", 5000)
        end
    else
        plate = CleanPlate(vehicleData.plate)
        if not plate then
            return VRCore.Functions.Notify(src, locale("plate_invalid"), "error", 5000)
        end
    end

    local garage = CleanText(Field(selectedData, 'Garage (Optional)'), 50)
    if not garage or garage == '' then
        garage = Config.DefaultGarage
    end

    if CheckAlreadyPlate(plate) then
        return VRCore.Functions.Notify(src, locale("givecar.plates_alreadyused", plate), "error", 5000)
    end

    vehicleData.plate = plate
    vehicleData.model = joaat(vehmodel)

    MySQL.insert.await(
        ('INSERT INTO %s (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(vehicleTable()),
        {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            vehmodel,
            joaat(vehmodel),
            json.encode(vehicleData),
            plate,
            garage,
            1
        })

    VRCore.Functions.Notify(src,
        locale("givecar.success.source", vehicleShared.name, FullName(Player)), "success", 5000)
    VRCore.Functions.Notify(tsrc, locale("givecar.success.target", plate, garage), "success", 5000)
end)

RegisterNetEvent("vr-adminmenu:server:SetVehicleState", function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SetVehicleState', selectedData) then return end
    if not VehicleTableReady(src) then return end

    local plate = CleanPlate(Field(selectedData, 'Plate'))
    local state = tonumber(Field(selectedData, 'State'))

    if not plate then
        return VRCore.Functions.Notify(src, locale("plate_max"), "error", 5000)
    end
    if state ~= 0 and state ~= 1 then
        return VRCore.Functions.Notify(src, locale("empty_input"), "error", 5000)
    end

    if not CheckAlreadyPlate(plate) then
        return VRCore.Functions.Notify(src, locale("plate_doesnt_exist"), "error", 5000)
    end

    MySQL.update.await(('UPDATE %s SET state = ?, depotprice = ? WHERE plate = ?'):format(vehicleTable()), { state, 0, plate })

    VRCore.Functions.Notify(src, locale("state_changed"), "success", 5000)
end)

lib.callback.register('vr-adminmenu:callback:ChangePlate', function(source, newPlate)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:ChangePlate', { Plate = { value = newPlate } }) then return false end

    local veh = currentVehicle(src)
    if not veh then
        VRCore.Functions.Notify(src, locale("not_in_vehicle"), 'error')
        return false
    end

    newPlate = CleanPlate(newPlate)
    if not newPlate then
        VRCore.Functions.Notify(src, locale("plate_max"), "error", 5000)
        return false
    end

    local currentPlate = Trim(GetVehicleNumberPlateText(veh) or ''):upper()
    if newPlate == currentPlate then return true end

    if CheckAlreadyPlate(newPlate) then
        VRCore.Functions.Notify(src, locale("already_plate"), "error", 5000)
        return false
    end

    if TableExists(Config.VehicleTable) then
        MySQL.update.await(('UPDATE %s SET plate = ? WHERE plate = ?'):format(vehicleTable()), { newPlate, currentPlate })
    end
    exports['vr-inventory']:UpdateVehicle(currentPlate, newPlate)
    SetVehicleNumberPlateText(veh, newPlate)

    return newPlate
end)

lib.callback.register('vr-adminmenu:callback:SpawnPersonalVehicle', function(source, plate)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:SpawnPersonalVehicle', { VehiclePlate = { value = plate } }) then return end
    if not VehicleTableReady(src) then return end

    plate = CleanPlate(plate)
    if not plate then
        VRCore.Functions.Notify(src, locale("plate_invalid"), 'error')
        return
    end

    local row = MySQL.single.await(('SELECT vehicle, mods FROM %s WHERE plate = ? LIMIT 1'):format(vehicleTable()), { plate })
    if not row or type(row.vehicle) ~= 'string' then
        VRCore.Functions.Notify(src, locale("plate_doesnt_exist"), 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local veh = VRCore.Functions.CreateVehicle(src, row.vehicle, nil, vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped)), true)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    SetVehicleNumberPlateText(veh, plate)

    local mods = type(row.mods) == 'string' and json.decode(row.mods) or nil
    return NetworkGetNetworkIdFromEntity(veh), type(mods) == 'table' and mods or nil, plate
end)

RegisterNetEvent('vr-adminmenu:server:FixVehFor', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:FixVehFor', selectedData) then return end

    local playerId, Player = GetTargetPlayer(Field(selectedData, 'Player'))
    if not playerId then
        return VRCore.Functions.Notify(src, locale("not_online"), "error")
    end

    TriggerClientEvent('vr-adminmenu:client:FixVehicle', playerId)
    VRCore.Functions.Notify(src, locale("veh_fixed", FullName(Player)), 'success', 7500)
end)
