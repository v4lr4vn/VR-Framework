Config = {}

Config.Debug = false

-- Item that toggles the megaphone, and the voice range it gives while held.
Config.MegaphoneItem = 'megaphone'
Config.MegaphoneRange = 50.0

-- Standing in a box lifts your voice range to `range`. spawnProp puts a microphone stand in the middle.
Config.Stands = {
    {
        name = 'vinewood_bowl',
        coords = vector3(683.37, 569.31, 130.46),
        size = vec3(3.6, 3.4, 4.0),   -- width, length, height
        heading = 340.0,
        prop = true,
        range = 50.0,
    },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-microphone'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
