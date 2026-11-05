local VRCore    = VRCore
local Functions = VRCore.Functions
local Round     = VRCore.Shared.Round

function Functions.SpawnVehicle(model, cb, coords, isnetworked, teleportInto)
    local ped = PlayerPedId()
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return end

    local heading
    if type(coords) == 'vector4' then
        heading = coords.w
    elseif type(coords) == 'table' then
        heading = coords.w or coords.h
    end
    coords = (type(coords) == 'table' and vec3(coords.x, coords.y, coords.z)) or (coords and coords.xyz) or GetEntityCoords(ped)
    heading = heading or GetEntityHeading(ped)
    isnetworked = isnetworked == nil or isnetworked

    Functions.LoadModel(hash)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, isnetworked, false)
    if isnetworked then SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true) end
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleFuelLevel(veh, 100.0)
    SetModelAsNoLongerNeeded(hash)
    if teleportInto then TaskWarpPedIntoVehicle(ped, veh, -1) end
    if cb then cb(veh) end
    return veh
end

function Functions.DeleteVehicle(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

function Functions.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return end
    return VRCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
end

function Functions.GetVehicleLabel(vehicle)
    if not vehicle or vehicle == 0 then return end
    return GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
end

local MOD_KEYS = {
    [0] = 'modSpoilers', [1] = 'modFrontBumper', [2] = 'modRearBumper', [3] = 'modSideSkirt',
    [4] = 'modExhaust', [5] = 'modFrame', [6] = 'modGrille', [7] = 'modHood', [8] = 'modFender',
    [9] = 'modRightFender', [10] = 'modRoof', [11] = 'modEngine', [12] = 'modBrakes',
    [13] = 'modTransmission', [14] = 'modHorns', [15] = 'modSuspension', [16] = 'modArmor',
    [17] = 'modKit17', [19] = 'modKit19', [21] = 'modKit21', [23] = 'modFrontWheels',
    [24] = 'modBackWheels', [25] = 'modPlateHolder', [26] = 'modVanityPlate', [27] = 'modTrimA',
    [28] = 'modOrnaments', [29] = 'modDashboard', [30] = 'modDial', [31] = 'modDoorSpeaker',
    [32] = 'modSeats', [33] = 'modSteeringWheel', [34] = 'modShifterLeavers', [35] = 'modAPlate',
    [36] = 'modSpeakers', [37] = 'modTrunk', [38] = 'modHydrolic', [39] = 'modEngineBlock',
    [40] = 'modAirFilter', [41] = 'modStruts', [42] = 'modArchCover', [43] = 'modAerials',
    [44] = 'modTrimB', [45] = 'modTank', [46] = 'modWindows', [47] = 'modKit47', [49] = 'modKit49',
}
local TOGGLE_KEYS = { [18] = 'modTurbo', [20] = 'modSmokeEnabled', [22] = 'modXenon' }

local function bool(v) return v == true or v == 1 end

local function rgb(t)
    return tonumber(t[1] or t['1']) or 0, tonumber(t[2] or t['2']) or 0, tonumber(t[3] or t['3']) or 0
end

function Functions.GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    if GetIsVehiclePrimaryColourCustom(vehicle) then colorPrimary = { GetVehicleCustomPrimaryColour(vehicle) } end
    if GetIsVehicleSecondaryColourCustom(vehicle) then colorSecondary = { GetVehicleCustomSecondaryColour(vehicle) } end

    local extras = {}
    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then extras[tostring(id)] = bool(IsVehicleExtraTurnedOn(vehicle, id)) end
    end

    local modLivery = GetVehicleMod(vehicle, 48)
    if modLivery == -1 and GetVehicleLivery(vehicle) ~= 0 then modLivery = GetVehicleLivery(vehicle) end

    local tireHealth, tireBurstState, tireBurstCompletely, windowStatus, doorStatus = {}, {}, {}, {}, {}
    for i = 0, 3 do tireHealth[i] = GetVehicleWheelHealth(vehicle, i) end
    for i = 0, 5 do
        tireBurstState[i] = IsVehicleTyreBurst(vehicle, i, false)
        tireBurstCompletely[i] = IsVehicleTyreBurst(vehicle, i, true)
        doorStatus[i] = bool(IsVehicleDoorDamaged(vehicle, i))
    end
    for i = 0, 7 do windowStatus[i] = bool(IsVehicleWindowIntact(vehicle, i)) end

    local xenonColor
    local hasCustom, xr, xg, xb = GetVehicleXenonLightsCustomColor(vehicle)
    if hasCustom then xenonColor = { xr, xg, xb } else xenonColor = GetVehicleXenonLightsColor(vehicle) end

    local props = {
        model = GetEntityModel(vehicle),
        plate = Functions.GetPlate(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = Round(GetVehicleBodyHealth(vehicle), 1),
        engineHealth = Round(GetVehicleEngineHealth(vehicle), 1),
        tankHealth = Round(GetVehiclePetrolTankHealth(vehicle), 1),
        fuelLevel = Round(GetVehicleFuelLevel(vehicle), 1),
        dirtLevel = Round(GetVehicleDirtLevel(vehicle), 1),
        oilLevel = Round(GetVehicleOilLevel(vehicle), 1),
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        dashboardColor = GetVehicleDashboardColour(vehicle),
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(vehicle),
        wheelSize = GetVehicleWheelSize(vehicle),
        wheelWidth = GetVehicleWheelWidth(vehicle),
        tireHealth = tireHealth,
        tireBurstState = tireBurstState,
        tireBurstCompletely = tireBurstCompletely,
        windowTint = GetVehicleWindowTint(vehicle),
        windowStatus = windowStatus,
        doorStatus = doorStatus,
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0), IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2), IsVehicleNeonLightEnabled(vehicle, 3),
        },
        neonColor = { GetVehicleNeonLightsColour(vehicle) },
        interiorColor = GetVehicleInteriorColour(vehicle),
        extras = extras,
        tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
        xenonColor = xenonColor,
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        modLivery = modLivery,
        liveryRoof = GetVehicleRoofLivery(vehicle),
    }
    for i = 0, 49 do
        local key = MOD_KEYS[i]
        if key then
            props[key] = GetVehicleMod(vehicle, i)
        elseif TOGGLE_KEYS[i] then
            props[TOGGLE_KEYS[i]] = IsToggleModOn(vehicle, i)
        end
    end
    return props
end

function Functions.SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or type(props) ~= 'table' then return end

    if props.extras then
        for id, enabled in pairs(props.extras) do SetVehicleExtra(vehicle, tonumber(id), not enabled) end
    end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleModKit(vehicle, 0)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end

    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1, colorSecondary)
        else
            SetVehicleCustomPrimaryColour(vehicle, rgb(props.color1))
        end
    end
    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, type(props.color1) == 'number' and props.color1 or colorPrimary, props.color2)
        else
            SetVehicleCustomSecondaryColour(vehicle, rgb(props.color2))
        end
    end
    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end
    if props.interiorColor then SetVehicleInteriorColour(vehicle, props.interiorColor) end
    if props.dashboardColor then SetVehicleDashboardColour(vehicle, props.dashboardColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end

    if props.tireHealth then
        for wheel, health in pairs(props.tireHealth) do SetVehicleWheelHealth(vehicle, tonumber(wheel), health + 0.0) end
    end
    if props.tireBurstState then
        for wheel, burst in pairs(props.tireBurstState) do
            if burst then SetVehicleTyreBurst(vehicle, tonumber(wheel), false, 1000.0) end
        end
    end
    if props.tireBurstCompletely then
        for wheel, burst in pairs(props.tireBurstCompletely) do
            if burst then SetVehicleTyreBurst(vehicle, tonumber(wheel), true, 1000.0) end
        end
    end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
    if props.windowStatus then
        for window, intact in pairs(props.windowStatus) do
            if not intact then SmashVehicleWindow(vehicle, tonumber(window)) end
        end
    end
    if props.doorStatus then
        for door, broken in pairs(props.doorStatus) do
            if broken then SetVehicleDoorBroken(vehicle, tonumber(door), true) end
        end
    end
    if props.neonEnabled then
        for i = 1, 4 do SetVehicleNeonLightEnabled(vehicle, i - 1, bool(props.neonEnabled[i] or props.neonEnabled[tostring(i)])) end
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, rgb(props.neonColor)) end
    if props.wheelSize then SetVehicleWheelSize(vehicle, props.wheelSize) end
    if props.wheelWidth then SetVehicleWheelWidth(vehicle, props.wheelWidth) end
    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, rgb(props.tyreSmokeColor)) end

    for i = 0, 49 do
        local key = MOD_KEYS[i]
        if key then
            if props[key] then SetVehicleMod(vehicle, i, props[key], false) end
            if i == 24 then
                if props.modCustomTiresF then SetVehicleMod(vehicle, 23, props.modFrontWheels or GetVehicleMod(vehicle, 23), true) end
                if props.modCustomTiresR then SetVehicleMod(vehicle, 24, props.modBackWheels or GetVehicleMod(vehicle, 24), true) end
            end
        elseif TOGGLE_KEYS[i] then
            if props[TOGGLE_KEYS[i]] then ToggleVehicleMod(vehicle, i, true) end
            if i == 22 and props.xenonColor then
                if type(props.xenonColor) == 'table' then
                    SetVehicleXenonLightsCustomColor(vehicle, rgb(props.xenonColor))
                else
                    SetVehicleXenonLightsColor(vehicle, props.xenonColor)
                end
            end
        elseif i == 48 and props.modLivery then
            SetVehicleMod(vehicle, 48, props.modLivery, false)
            SetVehicleLivery(vehicle, props.modLivery)
        end
    end

    if props.liveryRoof then SetVehicleRoofLivery(vehicle, props.liveryRoof) end
end
