Config = {}

Config.Lock = {
    range = 30.0,
    shareRange = 4.0,
    cooldown = 700,
    flashes = 2,
    horn = true,
    animation = true,
}

Config.NoKeyClasses = { [13] = true }

Config.Engine = {
    requireKeys = true,
    autoStart = true,
    keepRunning = true,
}

Config.Group = {
    jobVehicles = true,
    requireDuty = false,
}

Config.Keys = {
    maxShared = 6,
    lendMinutes = 60,
    tempMinutes = 240,
}

Config.Claims = {
    enabled = true,
    range = 15.0,
    perMinute = 10,
}

Config.NpcVehicles = {
    lockedChance = 55,
}

Config.Lockpick = {
    items = { 'lockpick' },
    skill = { 'easy', 'easy', 'medium' },
    breakChance = { success = 3, fail = 30 },
    alarmChance = 45,
    cooldown = 3,
}

Config.Hotwire = {
    items = { 'lockpick' },
    skill = { 'easy', 'medium', 'medium' },
    breakChance = { success = 2, fail = 25 },
    alarmChance = 20,
    cooldown = 20,
}

Config.Carjack = {
    enabled = true,
    aimTime = 1500,
    distance = 12.0,
}

Config.Alert = {
    enabled = true,
    jobs = { 'police' },
    cooldown = 45,
    chance = { lockpick = 30, hotwire = 40, carjack = 85 },
}

Config.Locksmith = {
    fee = 750,
    blip = { sprite = 446, colour = 5, scale = 0.7, label = 'Locksmith' },
    locations = {
        { label = 'Legion Locksmith', ped = 's_m_m_autoshop_01', coords = vec4(214.74, -810.07, 30.73, 160.0) },
    },
}

-- Quick key handing: /givekeys, /lendkeys and the radial menu entry
Config.Quick = {
    radial = true,
    label = 'Vehicle keys',
    icon = 'key',
    vehicleRange = 8.0, -- how close a car you own must be when you are on foot
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-vehiclekeys'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
