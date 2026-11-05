Config.Jobs.windowcleaner = {
    label = 'Window Cleaner',
    job = 'windowcleaner',
    icon = 'fa-spray-can-sparkles',
    description = 'Take the van to a site and clean every window on the frontage',
    crew = 3,
    depot = {
        ped = 's_m_y_construct_01',
        coords = vec4(-1243.9, -1240.7, 11.0, 20.0),
        blip = { sprite = 177, colour = 7, scale = 0.8, label = 'Window Cleaning' },
    },
    vehicle = {
        model = 'rumpo',
        coords = vec4(-1238.0, -1236.0, 6.9, 200.0),
        returnRadius = 40.0,
    },
    sites = {
        { label = 'Vespucci shopfronts', center = vec3(-1217.5, -1457.0, 4.3), heading = 125.0, cols = 5, rows = 2, spacing = 1.7, stepZ = 1.5 },
        { label = 'Pillbox office block', center = vec3(266.5, -644.5, 42.0), heading = 70.0, cols = 5, rows = 2, spacing = 1.9, stepZ = 1.6 },
        { label = 'Rockford Plaza arcade', center = vec3(-181.0, -158.0, 43.6), heading = 340.0, cols = 6, rows = 2, spacing = 1.8, stepZ = 1.5 },
    },
    cleanRange = 2.4,
    cleanSeconds = 5,
    pricePerWindow = 38,
    xpPerWindow = 14,
    completionBonus = 120,
    xpCompletion = 200,
    stopRadius = 30.0,
}
