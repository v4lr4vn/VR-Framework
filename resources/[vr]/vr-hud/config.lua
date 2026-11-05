Config = {}

Config.OpenMenu = 'I'
Config.Command = 'hud'

Config.UseRealTime = false
Config.CompassFollowsCamera = true
Config.VoiceModes = 3

Config.GearsUnlocked = false

Config.FuelScript = 'vr-fuel'
Config.HarnessItem = 'harness'
Config.FuelBlacklist = {
    'surge', 'iwagen', 'voltic', 'voltic2', 'raiden', 'cyclone', 'tezeract', 'neon', 'omnisegt', 'imorgon', 'dilettante',
    'khamelion', 'caddy', 'caddy2', 'caddy3', 'airtug', 'rcbandito', 'virtue', 'powersurge',
}

Config.Defaults = {
    stats = {
        health  = { mode = 'always', at = 100 },
        armor   = { mode = 'auto',   at = 1 },
        hunger  = { mode = 'auto',   at = 50 },
        thirst  = { mode = 'auto',   at = 50 },
        stamina = { mode = 'auto',   at = 95 },
        oxygen  = { mode = 'auto',   at = 95 },
        stress  = { mode = 'auto',   at = 30 },
    },
    mapOnFoot = false,
    compassOnFoot = false,
    postal = true,
    unit = 'mph',
    gears = true,
}

Config.Notify = {
    cash = 'Cash: $%s',
    bank = 'Bank: $%s',
    stressUp = 'You feel more stressed',
    stressDown = 'You feel more relaxed',
}

Config.Postal = {
    interval = 300,
    blip = { sprite = 8, color = 3, clearDistance = 100.0 },
    text = {
        routing = 'Drawing a route to postal %s',
        cleared = 'Postal route removed',
        arrived = 'You have reached your postal destination',
        missing = "That postal doesn't exist",
    },
}

Config.Minimap = {
    zoom = 1100,
    fix  = { dx = 0.005, dy = 0.055, sx = 0.77, sy = 1.1 },
    ultrawideFix = true,
    map  = { sx = 1.28, sy = 0.915, dx = 0.0,   dy = -0.047 },
    blur = { sx = 2.047, sy = 1.5,  dx = -0.01, dy = 0.025 },
}

Config.Stress = {
    enabled = true,
    chance = 0.1,
    minimum = 50,
    speedUnbuckled = 50,
    speedAny = 100,
    levels = {
        { 50, 60, 1500, 50, 60 }, { 60, 70, 2000, 40, 50 }, { 70, 80, 2500, 30, 40 },
        { 80, 90, 2700, 20, 30 }, { 90, 101, 3000, 15, 20 },
    },
    noStressWeapons = { `weapon_petrolcan`, `weapon_hazardcan`, `weapon_fireextinguisher` },
    policeImmune = true,
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-hud'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
