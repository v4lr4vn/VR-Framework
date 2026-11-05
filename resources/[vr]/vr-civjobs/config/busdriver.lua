Config.Jobs.busdriver = {
    label = 'Bus Driver',
    job = 'busdriver',
    icon = 'fa-bus',
    description = 'Run a timetabled route, stop at every bus stop and hand the bus back clean',
    depot = {
        ped = 's_m_m_gentransport',
        coords = vec4(453.1, -600.3, 28.6, 265.0),
        blip = { sprite = 513, colour = 3, scale = 0.8, label = 'Bus Depot' },
    },
    vehicle = {
        model = 'bus',
        coords = vec4(462.2, -607.0, 28.5, 270.0),
        returnRadius = 40.0,
    },
    stopRange = 14.0,
    stopSpeed = 3.0,
    stopWaitSeconds = 9,
    passengers = { 1, 5 },
    -- Most people the bus carries at once. Seats are used one by one, then nobody else gets on.
    capacity = 14,
    -- Who stands at the stops.
    passengerModels = {
        'a_m_y_business_01', 'a_f_y_business_01', 'a_m_m_tourist_01', 'a_f_y_tourist_01', 'a_m_y_hipster_01', 'a_f_y_hipster_01',
        'a_m_m_skater_01', 'a_f_m_bevhills_01', 'a_m_y_vinewood_01', 'a_f_y_vinewood_01', 'a_m_m_business_01', 'a_f_m_downtown_01',
    },
    farePerPassenger = 4,
    routes = {
        {
            id = 'cityline', label = 'Cityline', level = 1, pay = 450, xp = 300,
            stops = {
                { label = 'Mission Row', coords = vec3(437.8, -633.5, 28.7) },
                { label = 'Legion Square', coords = vec3(199.5, -809.0, 30.8) },
                { label = 'Pillbox Hill', coords = vec3(-215.9, -787.0, 30.7) },
                { label = 'Little Seoul', coords = vec3(-573.0, -1013.8, 22.2) },
                { label = 'Strawberry', coords = vec3(95.0, -1283.5, 29.3) },
            },
        },
        {
            id = 'beachline', label = 'Beachline', level = 3, pay = 800, xp = 520,
            stops = {
                { label = 'Del Perro', coords = vec3(-1330.0, -388.0, 36.6) },
                { label = 'Vespucci Canals', coords = vec3(-1138.8, -1370.8, 5.0) },
                { label = 'Vespucci Beach', coords = vec3(-1302.0, -1514.0, 4.6) },
                { label = 'Rockford Hills', coords = vec3(-707.0, -142.0, 37.4) },
                { label = 'Hawick', coords = vec3(316.0, -161.0, 57.7) },
                { label = 'Textile City', coords = vec3(410.0, -970.0, 29.4) },
            },
        },
        {
            id = 'daily', label = 'Daily express', level = 1, pay = 1200, xp = 1100, daily = true,
            stops = {
                { label = 'Airport', coords = vec3(-1044.0, -2749.0, 21.4) },
                { label = 'Port', coords = vec3(125.0, -2755.0, 6.0) },
                { label = 'Strawberry', coords = vec3(95.0, -1283.5, 29.3) },
                { label = 'Vinewood', coords = vec3(298.0, 175.0, 104.3) },
                { label = 'Mirror Park', coords = vec3(1043.0, -526.0, 62.5) },
                { label = 'Mission Row', coords = vec3(437.8, -633.5, 28.7) },
            },
        },
    },
}
