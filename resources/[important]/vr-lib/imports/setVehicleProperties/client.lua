local MODS = {
    modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3, modExhaust = 4, modFrame = 5, modGrille = 6,
    modHood = 7, modFender = 8, modRightFender = 9, modRoof = 10, modEngine = 11, modBrakes = 12, modTransmission = 13,
    modHorns = 14, modSuspension = 15, modArmor = 16, modNitrous = 17, modSubwoofer = 19, modHydraulics = 21,
    modPlateHolder = 25, modVanityPlate = 26, modTrimA = 27, modOrnaments = 28, modDashboard = 29, modDial = 30,
    modDoorSpeaker = 31, modSeats = 32, modSteeringWheel = 33, modShifterLeavers = 34, modAPlate = 35, modSpeakers = 36,
    modTrunk = 37, modHydrolic = 38, modEngineBlock = 39, modAirFilter = 40, modStruts = 41, modArchCover = 42,
    modAerials = 43, modTrimB = 44, modTank = 45, modWindows = 46, modDoorR = 47, modLightbar = 49,
}

local function rgb(v)
    if type(v) == 'table' then return v[1] or v.r or 0, v[2] or v.g or 0, v[3] or v.b or 0 end
    return nil
end

return function(vehicle, props, fixVehicle)
    if not vehicle or not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    SetVehicleModKit(vehicle, 0)
    SetVehicleAutoRepairDisabled(vehicle, true)

    if props.extras then
        for id, disable in pairs(props.extras) do
            id = tonumber(id)
            if id and DoesExtraExist(vehicle, id) then
                SetVehicleExtra(vehicle, id, disable == 1 or disable == true)
            end
        end
    end

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end

    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1, type(props.color2) == 'number' and props.color2 or colorSecondary)
        else
            if props.paintType1 then SetVehicleModColor_1(vehicle, props.paintType1, 0, props.pearlescentColor or 0) end
            SetVehicleCustomPrimaryColour(vehicle, rgb(props.color1))
        end
    end

    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            local primary = (GetVehicleColours(vehicle))
            SetVehicleColours(vehicle, type(props.color1) == 'number' and props.color1 or primary, props.color2)
        else
            if props.paintType2 then SetVehicleModColor_2(vehicle, props.paintType2, 0) end
            SetVehicleCustomSecondaryColour(vehicle, rgb(props.color2))
        end
    end

    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end

    if props.interiorColor then SetVehicleInteriorColor(vehicle, props.interiorColor) end
    if props.dashboardColor then SetVehicleDashboardColor(vehicle, props.dashboardColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if props.neonEnabled then
        for i = 1, 4 do SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i] == true) end
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, rgb(props.neonColor)) end

    if props.windows then
        for _, w in pairs(props.windows) do RemoveVehicleWindow(vehicle, w) end
    end
    if props.doors then
        for _, d in pairs(props.doors) do SetVehicleDoorBroken(vehicle, d, true) end
    end
    if props.tyres then
        for tyre, state in pairs(props.tyres) do
            SetVehicleTyreBurst(vehicle, tonumber(tyre), state == 2, 1000.0)
        end
    end

    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, rgb(props.tyreSmokeColor)) end

    for key, index in pairs(MODS) do
        local value = props[key]
        if value then SetVehicleMod(vehicle, index, value, false) end
    end

    if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF == true) end
    if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR == true) end

    if props.modTurbo ~= nil then ToggleVehicleMod(vehicle, 18, props.modTurbo == true) end
    if props.modSmokeEnabled ~= nil then ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled == true) end
    if props.modXenon ~= nil then ToggleVehicleMod(vehicle, 22, props.modXenon == true) end
    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end

    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end
    if props.livery then SetVehicleLivery(vehicle, props.livery) end
    if props.modRoofLivery then SetVehicleRoofLivery(vehicle, props.modRoofLivery) end

    if props.wheelSize and props.wheelSize ~= GetVehicleWheelSize(vehicle) then SetVehicleWheelSize(vehicle, props.wheelSize + 0.0) end
    if props.wheelWidth and props.wheelWidth ~= GetVehicleWheelWidth(vehicle) then SetVehicleWheelWidth(vehicle, props.wheelWidth + 0.0) end

    if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(vehicle, not props.bulletProofTyres) end
    if props.driftTyres ~= nil and SetDriftTyresEnabled then SetDriftTyresEnabled(vehicle, props.driftTyres == true) end

    if fixVehicle then SetVehicleFixed(vehicle) end

    return true
end
