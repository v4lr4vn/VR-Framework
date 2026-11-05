Config = {}

-- Money -------------------------------------------------------------------------------------
Config.MoneyType = 'cash'
Config.PricePerUnit = 1.0       -- $ for one percent of a tank at a pump
Config.CanPrice = 100           -- price of a new petrol can
Config.CanRefillPrice = 1.0     -- $ per percent when refilling a can at a pump

-- Items (vr-inventory) ----------------------------------------------------------------------
Config.CanItem = 'WEAPON_PETROLCAN'
Config.SiphonItem = 'fuelsiphon'
Config.AllowSiphoning = true
Config.AllowCanRefuel = true

-- Server checks ------------------------------------------------------------------------------
Config.MaxUnitsPerFill = 100
Config.StationRadius = 50.0     -- pump purchases must happen this close to a station (false to skip)
Config.PurchaseCooldown = 2     -- seconds between two purchases by one player

-- Speed of the three transfers, in percent of a tank per second ----------------------------
Config.Rate = { pump = 1.5, can = 1.0, siphon = 0.5 }

-- Consumption, percent of a tank per second ----------------------------------------------------
-- idle: engine on at rest. full: engine at full revs. In between it grows with the square of the revs.
Config.Usage = { idle = 0.012, full = 0.14 }

-- Multiplier by vehicle class (0 = never uses fuel, e.g. cycles)
Config.Classes = {
    [0] = 1.0, [1] = 1.0, [2] = 1.1, [3] = 1.0, [4] = 1.1, [5] = 1.0, [6] = 1.0, [7] = 1.2, [8] = 0.8,
    [9] = 1.2, [10] = 1.5, [11] = 1.2, [12] = 1.1, [13] = 0.0, [14] = 1.2, [15] = 1.5, [16] = 1.5,
    [17] = 1.3, [18] = 1.0, [19] = 1.3, [20] = 1.4, [21] = 1.2,
}

-- Model names that never use fuel (electric cars and the like)
Config.NoFuel = {}

-- Chance (percent) that a running engine explodes when you start refuelling it. false to turn off.
Config.Explosion = { enabled = true, chance = 25 }

-- Targets --------------------------------------------------------------------------------------
Config.PumpModels = {
    'prop_gas_pump_1d', 'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c',
    'prop_vintage_pump', 'prop_gas_pump_old2', 'prop_gas_pump_old3',
}
Config.CanBones = { 'petrolcap', 'boot', 'wheel_r' }   -- where a can can be used / siphon placed
Config.CanDistance = 2.5

-- Map blips ------------------------------------------------------------------------------------
Config.Blips = { enabled = true, sprite = 361, colour = 26, scale = 0.6, label = 'Fuel Station' }

Config.Stations = {
    vector3(621.05, 269.09, 102.93),   vector3(1181.1, -330.58, 69.51),  vector3(819.14, -1028.9, 26.44),
    vector3(1208.29, -1401.87, 35.23), vector3(174.3, -1561.75, 28.39),  vector3(264.3, -1261.57, 29.77),
    vector3(-70.15, -1762.1, 29.56),   vector3(-524.17, -1210.58, 18.68), vector3(-724.05, -935.7, 19.72),
    vector3(-1436.29, -276.87, 46.09), vector3(-2097.08, -318.81, 13.98), vector3(-1799.9, 802.85, 138.88),
    vector3(2580.94, 361.59, 108.4),   vector3(1207.64, 2660.44, 37.82), vector3(1040.36, 2671.2, 39.71),
    vector3(263.88, 2606.94, 45.01),   vector3(2005.46, 3774.62, 31.98), vector3(1785.16, 3331.04, 41.38),
    vector3(2679.52, 3264.05, 55.14),  vector3(1687.49, 4929.92, 42.42), vector3(1702.49, 6416.16, 32.82),
    vector3(180.2, 6602.7, 31.66),     vector3(-94.6, 6419.65, 31.58),   vector3(-2555.02, 2334.03, 32.92),
    vector3(49.18, 2779.13, 58.1),
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-fuel'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
