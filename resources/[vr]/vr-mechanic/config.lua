Config = {}

Config.Jobs = { mechanic = true }
Config.CommissionPercent = 20
Config.MaxBill = 250000
Config.BillSeconds = 60
Config.BillDistance = 8.0
Config.WorkDistance = 5.0
Config.CounterDistance = 3.0
Config.Blip = { sprite = 446, colour = 47, scale = 0.7 }

Config.Workshops = {
    burton = { label = 'LS Customs Burton', job = 'mechanic', center = vec3(-337.38, -136.92, 39.01), radius = 18.0, counter = vec3(-345.37, -129.88, 39.01) },
    bennys = { label = "Benny's Original Motorworks", job = 'mechanic', center = vec3(-211.80, -1324.20, 30.89), radius = 20.0, counter = vec3(-200.33, -1314.29, 31.09) },
    lamesa = { label = 'LS Customs La Mesa', job = 'mechanic', center = vec3(731.81, -1088.82, 22.17), radius = 16.0, counter = vec3(736.07, -1085.44, 22.17) },
    harmony = { label = 'LS Customs Route 68', job = 'mechanic', center = vec3(1175.04, 2640.21, 37.75), radius = 14.0, counter = vec3(1182.36, 2635.86, 37.78) },
    paleto = { label = 'Beekers Garage', job = 'mechanic', center = vec3(110.99, 6627.40, 31.79), radius = 14.0, counter = vec3(101.92, 6619.38, 32.44) },
}

Config.Parts = {
    engine = { label = 'Engine', item = 'engine_parts', icon = 'gears', seconds = 14 },
    brakes = { label = 'Brakes', item = 'brake_pads', icon = 'circle-stop', seconds = 10 },
    clutch = { label = 'Clutch & gearbox', item = 'clutch_kit', icon = 'gear', seconds = 12 },
    suspension = { label = 'Suspension', item = 'suspension_parts', icon = 'arrows-up-down', seconds = 12 },
    tyres = { label = 'Tyres', item = 'tyre_set', icon = 'life-ring', seconds = 10 },
    radiator = { label = 'Radiator', item = 'radiator_parts', icon = 'fan', seconds = 10 },
}

Config.Repairs = {
    engineBlock = { label = 'Engine block', item = 'engine_parts', seconds = 15 },
    bodywork = { label = 'Bodywork', item = 'body_panel', seconds = 15 },
    repairKit = { item = 'repair_kit', engineHealth = 650.0, seconds = 15, anyone = true },
}

Config.Orders = {
    item = 'mechanic_order',
    maxOpen = 3,
    expireDays = 7,
    billDistance = 30.0,
}

Config.FitSeconds = {
    engine = 15,
    paint = 20,
    wheel = 12,
    under = 14,
    body = 10,
    glass = 12,
    rear = 6,
    lights = 10,
}

Config.Shop = {
    companyGrade = 2,
    items = {
        { item = 'engine_parts', label = 'Engine parts', price = 600 },
        { item = 'brake_pads', label = 'Brake pads', price = 250 },
        { item = 'clutch_kit', label = 'Clutch kit', price = 400 },
        { item = 'suspension_parts', label = 'Suspension parts', price = 450 },
        { item = 'tyre_set', label = 'Tyre set', price = 350 },
        { item = 'radiator_parts', label = 'Radiator parts', price = 300 },
        { item = 'body_panel', label = 'Body panels', price = 250 },
        { item = 'repair_kit', label = 'Repair kit', price = 400 },
    },
}

Config.Wear = {
    enabled = true,
    intervalSeconds = 2,
    maxSpeed = 110.0,
    reportSeconds = 10,
    persistSeconds = 60,
    perKm = { engine = 0.08, brakes = 0.16, clutch = 0.10, suspension = 0.08, tyres = 0.20, radiator = 0.07 },
    fastSpeed = 38.0,
    fastMultiplier = { engine = 2.0, tyres = 1.6, radiator = 1.8, clutch = 1.3 },
    crash = { per100Body = { suspension = 4.0, radiator = 5.0, engine = 1.5, tyres = 2.0 }, minDrop = 20.0 },
    warnAt = 30,
}

Config.Effects = {
    engine = { below = 40, minPower = 0.55, stallBelow = 12 },
    brakes = { below = 50, minForce = 0.35 },
    clutch = { below = 30, slipChance = 0.05 },
    suspension = { below = 40, minForce = 0.55 },
    tyres = { below = 35, minGrip = 0.70, burstBelow = 8, burstChance = 0.01 },
    radiator = { below = 25, heatPerSecond = 2.5, floor = 280.0 },
}

Config.Tuning = {
    maxChanges = 40,
    performance = {
        { key = 'modEngine', label = 'Engine', levels = { 0, 4000, 9000, 16000, 26000 } },
        { key = 'modBrakes', label = 'Brakes', levels = { 0, 2500, 5000, 9000 } },
        { key = 'modTransmission', label = 'Transmission', levels = { 0, 3500, 7000, 12000 } },
        { key = 'modSuspension', label = 'Suspension', levels = { 0, 2000, 4000, 6500, 9000 } },
        { key = 'modArmor', label = 'Armour', levels = { 0, 5000, 10000, 16000, 24000, 34000 } },
        { key = 'modTurbo', label = 'Turbo', toggle = true, price = 18000 },
    },
    prices = {
        paint = 600, pearl = 400, wheelColor = 300, paintType = 300, wheels = 1500, windowTint = 400, plateIndex = 200,
        neon = 1500, neonColor = 300, xenon = 700, xenonColor = 200, livery = 800, horn = 150, body = 900,
    },
    bodyMods = {
        { key = 'modSpoilers', label = 'Spoiler', id = 0 },
        { key = 'modFrontBumper', label = 'Front bumper', id = 1 },
        { key = 'modRearBumper', label = 'Rear bumper', id = 2 },
        { key = 'modSideSkirt', label = 'Side skirts', id = 3 },
        { key = 'modExhaust', label = 'Exhaust', id = 4 },
        { key = 'modFrame', label = 'Roll cage', id = 5 },
        { key = 'modGrille', label = 'Grille', id = 6 },
        { key = 'modHood', label = 'Hood', id = 7 },
        { key = 'modFender', label = 'Left fender', id = 8 },
        { key = 'modRightFender', label = 'Right fender', id = 9 },
        { key = 'modRoof', label = 'Roof', id = 10 },
        { key = 'modHorns', label = 'Horn', id = 14 },
    },
}

Config.Palette = {
    { id = 0, label = 'Black', hex = '#0D1116' },
    { id = 1, label = 'Graphite black', hex = '#1C1D21' },
    { id = 6, label = 'Graphite', hex = '#4C5157' },
    { id = 4, label = 'Silver', hex = '#9CA1A6' },
    { id = 111, label = 'White', hex = '#F2F2EE' },
    { id = 157, label = 'Ice white', hex = '#E0E3E7' },
    { id = 120, label = 'Chrome', hex = '#C8CDD1' },
    { id = 27, label = 'Red', hex = '#B6111B' },
    { id = 35, label = 'Candy red', hex = '#8F0D14' },
    { id = 38, label = 'Orange', hex = '#F78616' },
    { id = 158, label = 'Gold', hex = '#C2944F' },
    { id = 88, label = 'Yellow', hex = '#F5D21A' },
    { id = 92, label = 'Lime', hex = '#9CC52E' },
    { id = 53, label = 'Green', hex = '#155C2D' },
    { id = 49, label = 'Racing green', hex = '#16362A' },
    { id = 68, label = 'Sky blue', hex = '#3C8FC0' },
    { id = 70, label = 'Ultra blue', hex = '#1B6BD8' },
    { id = 64, label = 'Navy', hex = '#22314F' },
    { id = 145, label = 'Purple', hex = '#62129A' },
    { id = 137, label = 'Pink', hex = '#DF5891' },
    { id = 96, label = 'Brown', hex = '#4E3424' },
    { id = 99, label = 'Bronze', hex = '#9C7C44' },
}

Config.Swatches = {
    { label = 'Black', rgb = { 13, 17, 22 } },
    { label = 'Jet', rgb = { 28, 29, 33 } },
    { label = 'Graphite', rgb = { 76, 81, 87 } },
    { label = 'Silver', rgb = { 156, 161, 166 } },
    { label = 'White', rgb = { 242, 242, 238 } },
    { label = 'Red', rgb = { 182, 17, 27 } },
    { label = 'Crimson', rgb = { 120, 10, 20 } },
    { label = 'Orange', rgb = { 247, 134, 22 } },
    { label = 'Gold', rgb = { 194, 148, 79 } },
    { label = 'Yellow', rgb = { 245, 210, 26 } },
    { label = 'Lime', rgb = { 102, 184, 31 } },
    { label = 'Green', rgb = { 21, 92, 45 } },
    { label = 'Teal', rgb = { 0, 128, 128 } },
    { label = 'Cyan', rgb = { 40, 200, 230 } },
    { label = 'Blue', rgb = { 27, 107, 216 } },
    { label = 'Navy', rgb = { 34, 49, 79 } },
    { label = 'Purple', rgb = { 98, 18, 154 } },
    { label = 'Magenta', rgb = { 200, 30, 150 } },
    { label = 'Pink', rgb = { 223, 88, 145 } },
    { label = 'Brown', rgb = { 78, 52, 36 } },
    { label = 'Sand', rgb = { 196, 170, 120 } },
    { label = 'Olive', rgb = { 85, 90, 50 } },
}

Config.NeonColors = {
    { label = 'White', rgb = { 255, 255, 255 } },
    { label = 'Blue', rgb = { 2, 21, 255 } },
    { label = 'Electric blue', rgb = { 3, 83, 255 } },
    { label = 'Mint', rgb = { 0, 255, 140 } },
    { label = 'Lime', rgb = { 94, 255, 1 } },
    { label = 'Yellow', rgb = { 255, 255, 0 } },
    { label = 'Gold', rgb = { 255, 150, 0 } },
    { label = 'Orange', rgb = { 255, 62, 0 } },
    { label = 'Red', rgb = { 255, 1, 1 } },
    { label = 'Pink', rgb = { 255, 50, 100 } },
    { label = 'Hot pink', rgb = { 255, 5, 190 } },
    { label = 'Purple', rgb = { 35, 1, 255 } },
}

Config.XenonColors = {
    { id = 255, label = 'Stock', hex = '#DCE6FF' },
    { id = 0, label = 'White', hex = '#FFFFFF' },
    { id = 1, label = 'Blue', hex = '#2A5CFF' },
    { id = 2, label = 'Electric blue', hex = '#3B93FF' },
    { id = 3, label = 'Mint', hex = '#3CFFB4' },
    { id = 4, label = 'Lime', hex = '#9DFF3C' },
    { id = 5, label = 'Yellow', hex = '#FFEF3C' },
    { id = 6, label = 'Gold', hex = '#FFC23C' },
    { id = 7, label = 'Orange', hex = '#FF8A3C' },
    { id = 8, label = 'Red', hex = '#FF3C3C' },
    { id = 9, label = 'Pony pink', hex = '#FF7AB8' },
    { id = 10, label = 'Hot pink', hex = '#FF3CC8' },
    { id = 11, label = 'Purple', hex = '#A03CFF' },
    { id = 12, label = 'Blacklight', hex = '#5A3CFF' },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-mechanic'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
