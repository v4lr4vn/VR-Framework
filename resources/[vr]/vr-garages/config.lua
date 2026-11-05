Config = {}

Config.AdminAce = 'command.garagebuilder'
Config.DefaultGarage = 'alta'
Config.DefaultImpound = 'impound'
Config.WarpIntoVehicle = true
Config.ReturnOutVehiclesOnStart = true
Config.TransferFee = 250
Config.ZoneRadius = 18.0
Config.HouseGarageRadius = 8.0
Config.PlateFormat = '11AAA111'
Config.InteractKey = 38
Config.InteractLabel = 'E'

Config.Blips = {
    public = { sprite = 357, colour = 3, scale = 0.65, label = 'Garage' },
    air = { sprite = 360, colour = 3, scale = 0.65, label = 'Hangar' },
    boat = { sprite = 356, colour = 3, scale = 0.65, label = 'Boat house' },
    impound = { sprite = 68, colour = 1, scale = 0.7, label = 'Impound lot' },
    job = { sprite = 357, colour = 38, scale = 0.6, label = 'Fleet garage' },
    gang = { sprite = 357, colour = 1, scale = 0.6, label = 'Garage' },
}

Config.JobVehicles = {
    limit = 1,
    fuel = 100.0,
    removeOnLeave = true,
    returnOtherWhenFull = true,
}

Config.Impound = {
    jobs = { police = 0 },
    requireDuty = true,
    defaultFee = 500,
    maxFee = 25000,
    maxHoldHours = 72,
    recoverFee = 250,
    distance = 4.0,
}

Config.GarageAliases = {
    ['Alta Garage'] = 'alta',
    motelgarage = 'motel',
    sapcounsel = 'alta',
    spanishave = 'spanish',
    caears24 = 'caesars',
    caears242 = 'caesars2',
    lagunapi = 'laguna',
    airportp = 'airport',
    beachp = 'beach',
    themotorhotel = 'motorhotel',
    liqourparking = 'liquor',
    shoreparking = 'shore',
    haanparking = 'paleto',
    pillboxgarage = 'pillbox',
    impoundlot = 'impound',
}

Config.Garages = {
    motel = { label = 'Pink Cage Motel', type = 'public', category = 'car', center = vec3(275.73, -345.72, 45.17), spawns = { vec4(266.03, -332.32, 44.92, 250.5) } },
    alta = { label = 'Alta Street', type = 'public', category = 'car', center = vec3(-330.01, -780.33, 33.96), spawns = { vec4(-341.57, -767.45, 33.56, 92.61) } },
    spanish = { label = 'Spanish Avenue', type = 'public', category = 'car', center = vec3(-1160.86, -741.41, 19.63), spawns = { vec4(-1145.53, -745.89, 19.27, 106.86) } },
    caesars = { label = 'Caesars Parking', type = 'public', category = 'car', center = vec3(69.84, 12.60, 68.96), spawns = { vec4(60.80, 17.54, 68.82, 339.7) } },
    caesars2 = { label = 'Caesars Downtown', type = 'public', category = 'car', center = vec3(-453.70, -786.78, 30.56), spawns = { vec4(-472.39, -787.71, 30.14, 180.52) } },
    laguna = { label = 'Laguna Place', type = 'public', category = 'car', center = vec3(364.37, 297.83, 103.49), spawns = { vec4(377.37, 294.90, 102.86, 161.47) } },
    airport = { label = 'Airport Parking', type = 'public', category = 'car', center = vec3(-773.12, -2033.04, 8.88), spawns = { vec4(-779.77, -2040.18, 8.47, 315.34) } },
    beach = { label = 'Vespucci Beach', type = 'public', category = 'car', center = vec3(-1185.32, -1500.64, 4.38), spawns = { vec4(-1188.14, -1487.95, 3.97, 124.06) } },
    pillbox = { label = 'Pillbox Hill', type = 'public', category = 'car', center = vec3(213.20, -796.05, 30.86), spawns = { vec4(222.02, -804.19, 30.26, 248.19) } },
    liquor = { label = 'Mirror Park', type = 'public', category = 'car', center = vec3(883.96, -3.65, 78.76), spawns = { vec4(881.08, -14.18, 78.34, 237.17) } },
    motorhotel = { label = 'Motor Hotel', type = 'public', category = 'car', center = vec3(1137.77, 2663.54, 37.90), spawns = { vec4(1137.69, 2673.61, 37.90, 359.5) } },
    shore = { label = 'Sandy Shores', type = 'public', category = 'car', center = vec3(1726.21, 3710.07, 34.26), spawns = { vec4(1730.31, 3711.07, 34.20, 20.53) } },
    paleto = { label = 'Paleto Bay', type = 'public', category = 'car', center = vec3(78.34, 6418.74, 31.28), spawns = { vec4(70.71, 6425.16, 30.92, 68.5) } },

    lsia_hangar = { label = 'LSIA Hangar', type = 'public', category = 'air', radius = 30.0, center = vec3(-1025.34, -3017.00, 13.95), spawns = { vec4(-979.20, -2995.51, 13.95, 52.19) } },
    higgins = { label = 'Higgins Helitours', type = 'public', category = 'air', radius = 25.0, center = vec3(-722.12, -1472.74, 5.00), spawns = { vec4(-724.83, -1443.89, 5.00, 135.78) } },
    sandy_hangar = { label = 'Sandy Shores Hangar', type = 'public', category = 'air', radius = 30.0, center = vec3(1757.74, 3296.13, 41.15), spawns = { vec4(1740.88, 3278.99, 41.09, 189.46) } },

    lsymc = { label = 'LSYMC Boat House', type = 'public', category = 'boat', radius = 25.0, center = vec3(-794.64, -1510.89, 1.60), spawns = { vec4(-793.58, -1501.40, 0.12, 111.5) } },
    paleto_boat = { label = 'Paleto Boat House', type = 'public', category = 'boat', radius = 25.0, center = vec3(-277.40, 6637.01, 7.50), spawns = { vec4(-289.20, 6637.96, 1.01, 45.5) } },
    millars = { label = 'Millars Boat House', type = 'public', category = 'boat', radius = 25.0, center = vec3(1299.02, 4216.42, 33.91), spawns = { vec4(1296.78, 4203.76, 30.12, 169.03) } },

    police_fleet = {
        label = 'Mission Row Garage', type = 'job', group = 'police', category = 'car', radius = 14.0, requireDuty = true,
        center = vec3(452.81, -1008.37, 29.31),
        spawns = { vec4(460.55, -1011.82, 29.31, 358.86), vec4(456.82, -1011.55, 29.31, 357.48), vec4(453.14, -1011.03, 29.31, 356.74), vec4(449.67, -1011.48, 29.31, 5.8), vec4(445.93, -1011.58, 29.31, 0.7), vec4(442.25, -1011.27, 29.31, 358.68) },
        ped = { model = 'mp_m_weapexp_01', coords = vec4(465.73, -1010.63, 29.46, 77.06) },
        setupMenu = true,
        vehicles = {
            { model = 'centurionlssd', label = 'Bear Cat', grade = 0, plate = 'LSPD' },
            { model = 'Declasse_killer', label = 'Declass', grade = 2, plate = 'LSPD' },
        },
    },
    ems_fleet = {
        label = 'Pillbox Garage', type = 'job', group = 'ambulance', category = 'car', radius = 12.0, requireDuty = true,
        center = vec3(294.28, -608.32, 43.32),
        spawns = { vec4(294.28, -608.32, 43.32, 69.6) },
        ped = { model = 'mp_m_weapexp_01', coords = vec4(291.2237, -614.9087, 42.4234, 332.9413) },
        setupMenu = true,
        vehicles = {
            { model = 'ambulance', label = 'Ambulance', grade = 0, plate = 'EMS' },
        },
    },

    impound = { label = 'Davis Impound Lot', type = 'impound', category = 'all', radius = 20.0, center = vec3(400.45, -1630.87, 29.29), spawns = { vec4(407.20, -1645.58, 29.31, 228.28) } },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-garages'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
