local MODS = {
    { 'modSpoilers', 0 }, { 'modFrontBumper', 1 }, { 'modRearBumper', 2 }, { 'modSideSkirt', 3 }, { 'modExhaust', 4 },
    { 'modFrame', 5 }, { 'modGrille', 6 }, { 'modHood', 7 }, { 'modFender', 8 }, { 'modRightFender', 9 }, { 'modRoof', 10 },
    { 'modEngine', 11 }, { 'modBrakes', 12 }, { 'modTransmission', 13 }, { 'modHorns', 14 }, { 'modSuspension', 15 },
    { 'modArmor', 16 }, { 'modNitrous', 17 }, { 'modSubwoofer', 19 }, { 'modHydraulics', 21 }, { 'modFrontWheels', 23 },
    { 'modBackWheels', 24 }, { 'modPlateHolder', 25 }, { 'modVanityPlate', 26 }, { 'modTrimA', 27 }, { 'modOrnaments', 28 },
    { 'modDashboard', 29 }, { 'modDial', 30 }, { 'modDoorSpeaker', 31 }, { 'modSeats', 32 }, { 'modSteeringWheel', 33 },
    { 'modShifterLeavers', 34 }, { 'modAPlate', 35 }, { 'modSpeakers', 36 }, { 'modTrunk', 37 }, { 'modHydrolic', 38 },
    { 'modEngineBlock', 39 }, { 'modAirFilter', 40 }, { 'modStruts', 41 }, { 'modArchCover', 42 }, { 'modAerials', 43 },
    { 'modTrimB', 44 }, { 'modTank', 45 }, { 'modWindows', 46 }, { 'modDoorR', 47 }, { 'modLivery', 48 }, { 'modLightbar', 49 },
}

local function round(n, places)
    local m = 10 ^ (places or 1)
    return math.floor(n * m + 0.5) / m
end

return function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local paintType1 = GetVehicleModColor_1(vehicle)
    local paintType2 = GetVehicleModColor_2(vehicle)

    if GetIsVehiclePrimaryColourCustom(vehicle) then
        colorPrimary = { GetVehicleCustomPrimaryColour(vehicle) }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        colorSecondary = { GetVehicleCustomSecondaryColour(vehicle) }
    end

    local extras = {}
    for i = 1, 15 do
        if DoesExtraExist(vehicle, i) then
            extras[i] = IsVehicleExtraTurnedOn(vehicle, i) and 0 or 1
        end
    end

    local damage = { windows = {}, doors = {}, tyres = {} }
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then damage.windows[#damage.windows + 1] = i end
    end
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then damage.doors[#damage.doors + 1] = i end
    end
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            damage.tyres[i] = IsVehicleTyreBurst(vehicle, i, true) and 2 or 1
        end
    end

    local neons = {}
    for i = 0, 3 do neons[i + 1] = IsVehicleNeonLightEnabled(vehicle, i) end

    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = round(GetVehicleBodyHealth(vehicle)),
        engineHealth = round(GetVehicleEngineHealth(vehicle)),
        tankHealth = round(GetVehiclePetrolTankHealth(vehicle)),
        fuelLevel = round(GetVehicleFuelLevel(vehicle)),
        oilLevel = round(GetVehicleOilLevel(vehicle)),
        dirtLevel = round(GetVehicleDirtLevel(vehicle)),
        paintType1 = paintType1,
        paintType2 = paintType2,
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        interiorColor = GetVehicleInteriorColor(vehicle),
        dashboardColor = GetVehicleDashboardColour(vehicle),
        wheelColor = wheelColor,
        wheelWidth = GetVehicleWheelWidth(vehicle),
        wheelSize = GetVehicleWheelSize(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = neons,
        neonColor = { GetVehicleNeonLightsColour(vehicle) },
        extras = extras,
        tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
        modTurbo = IsToggleModOn(vehicle, 18),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modXenon = IsToggleModOn(vehicle, 22),
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        modRoofLivery = GetVehicleRoofLivery(vehicle),
        windows = damage.windows,
        doors = damage.doors,
        tyres = damage.tyres,
        bulletProofTyres = GetVehicleTyresCanBurst(vehicle) == false,
        driftTyres = GetDriftTyresEnabled and GetDriftTyresEnabled(vehicle) or nil,
        livery = GetVehicleLivery(vehicle),
    }

    for i = 1, #MODS do
        local m = MODS[i]
        props[m[1]] = GetVehicleMod(vehicle, m[2])
    end

    return props
end
