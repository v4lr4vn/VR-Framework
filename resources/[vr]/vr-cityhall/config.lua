Config = {}

Config.Desks = {
    {
        id = 'cityhall',
        label = 'Los Santos City Hall',
        ped = 'a_m_m_hasjew_01',
        coords = vec4(-265.0, -963.6, 31.2, 206.0),
        blip = { sprite = 419, colour = 3, scale = 0.8, label = 'City Hall' },
    },
}

Config.DeskRange = 6.0

Config.Society = 'government'

Config.Documents = {
    enabled = true,
    refuseIfCarrying = true,
    cooldownMinutes = 5,
    items = {
        { item = 'id_card', label = 'Identity card', description = 'A new card with your details on it', icon = 'fa-id-card', fee = 100 },
        { item = 'driver_license', label = "Driver's licence", description = 'Only if you already passed your test', icon = 'fa-car', fee = 250, licence = 'driver' },
        { item = 'weaponlicense', label = 'Firearms licence', description = 'Only if you already hold the permit', icon = 'fa-gun', fee = 500, licence = 'weapon' },
    },
}

Config.JobCentre = {
    enabled = true,
    maxJobs = 3,
    cooldownSeconds = 20,
    allowQuit = true,
    fallbackJob = 'unemployed',
    jobs = {
        { job = 'garbage', grade = 0, icon = 'fa-trash-can', description = 'Drive the truck round the streets, bag up the rubbish and bring the truck home' },
        { job = 'windowcleaner', grade = 0, icon = 'fa-spray-can-sparkles', description = 'Take the van to a site and clean every window on the frontage' },
        { job = 'trucker', grade = 0, icon = 'fa-truck-front', description = 'Collect a trailer, haul it across the map and bring the cab back' },
        { job = 'taxi', grade = 0, icon = 'fa-taxi', description = 'Take a cab, pick up fares around the city and drive them where they are going' },
        { job = 'busdriver', grade = 0, icon = 'fa-bus', description = 'Run a timetabled route, stop at every bus stop and hand the bus back clean' },
        { job = 'newspaper', grade = 0, icon = 'fa-newspaper', description = 'Take a bike, deliver the morning paper to every mailbox on your round' },
        { job = 'hunter', grade = 0, icon = 'fa-crosshairs', description = 'Track game in the wilderness, skin what you shoot and sell it to the butcher' },
        { job = 'fisherman', grade = 0, icon = 'fa-fish', description = 'Cast a line from the shore, land the catch and sell it at the fish market' },
    },
}

Config.Business = {
    enabled = true,
    maxPerPlayer = 3,
    numberPrefix = 'LS-',
    nameMin = 3,
    nameMax = 32,
    renewWindowDays = 7,
    reprintFee = 50,
    item = 'business_license',
    refundPercent = 0,
    types = {
        { id = 'retail', label = 'Retail shop', icon = 'fa-store', fee = 2500, days = 30, description = 'Sell goods to the public from a premises or a stall' },
        { id = 'food', label = 'Food and drink', icon = 'fa-utensils', fee = 3500, days = 30, description = 'Restaurants, bars, cafes and food trucks' },
        { id = 'trade', label = 'Trades and repairs', icon = 'fa-screwdriver-wrench', fee = 2000, days = 30, description = 'Mechanics, builders, cleaners and other trades' },
        { id = 'vehicles', label = 'Vehicle sales', icon = 'fa-car-side', fee = 6000, days = 30, description = 'Buy and sell cars, bikes and boats' },
        { id = 'entertainment', label = 'Entertainment', icon = 'fa-martini-glass-citrus', fee = 4500, days = 30, description = 'Clubs, venues, events and nightlife' },
        { id = 'services', label = 'Professional services', icon = 'fa-briefcase', fee = 3000, days = 30, description = 'Consultancy, legal, finance and office work' },
    },
}

Config.Admin = {
    command = 'bizlicence',
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-cityhall'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
