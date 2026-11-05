Config = {}

Config.Yoga = {
    scenario = 'WORLD_HUMAN_YOGA',
    duration = 30000,
    relief = 25,
    cooldown = 600,
    radius = 1.5,
    blip = { enabled = true, sprite = 1, colour = 3, scale = 0.7, label = 'Yoga spot' },
    spots = {
        { label = 'Del Perro Pier', coords = vec3(-1831.0, -1231.0, 13.0) },
    },
}

Config.Smoking = {
    item = 'cigarette',
    needLighter = true,
    lighter = 'lighter',
    scenario = 'WORLD_HUMAN_SMOKING',
    duration = 12000,
    relief = 8,
    cooldown = 45,
}

Config.CancelKey = 73

Config.Text = {
    yogaTarget = 'Do yoga',
    yogaLabel = 'Doing yoga (X to stop)',
    smokeLabel = 'Smoking (X to stop)',
    relaxed = 'You feel calmer',
    tooSoon = "You're not ready for that again yet",
    noLighter = 'You need a lighter',
    inVehicle = "You can't do that in a vehicle",
    tooFar = 'You are too far away',
    stopped = 'You stopped',
    busy = 'You are already doing something',
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-wellness'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
