Config = {}

-- model: the road sign prop in the world. item: the inventory item you get. label: shown to players.
Config.Signs = {
    { model = 'prop_sign_road_01a',            item = 'stopsign',                  label = 'Stop Sign' },
    { model = 'prop_sign_road_05a',            item = 'walkingmansign',            label = 'Pedestrian Sign' },
    { model = 'prop_sign_road_03e',            item = 'dontblockintersectionsign', label = 'Intersection Sign' },
    { model = 'prop_sign_road_03m',            item = 'uturnsign',                 label = 'U Turn Sign' },
    { model = 'prop_sign_road_04a',            item = 'noparkingsign',             label = 'No Parking Sign' },
    { model = 'prop_sign_road_05e',            item = 'leftturnsign',              label = 'Left Turn Sign' },
    { model = 'prop_sign_road_05f',            item = 'rightturnsign',             label = 'Right Turn Sign' },
    { model = 'prop_sign_road_restriction_10', item = 'notrespassingsign',         label = 'No Trespassing Sign' },
    { model = 'prop_sign_road_02a',            item = 'yieldsign',                 label = 'Yield Sign' },
}

Config.Steal = {
    time = { 5000, 7000 },                    -- ms, picked at random
    skillCheck = { 'easy', 'easy', 'medium' },-- false to skip
    distance = 4.0,
    cooldown = 10,                            -- seconds between two thefts by one player
    maxPerHour = 30,
}

-- Where signs turn into materials. The player must stand within `distance` of `coords`.
Config.Scrap = {
    coords = vector3(2332.43, 3026.89, 48.15),
    radius = 2.5,
    distance = 3.0,
    items = { 'metalscrap', 'copper', 'iron', 'aluminum', 'steel' },
    rolls = { 3, 5 },      -- how many times a material is drawn per sign
    amount = { 1, 3 },     -- how many of it each time
}

-- Chance (0-1) that a theft sends an alert to the police (needs vr-mdt).
Config.Dispatch = { enabled = true, chance = 0.35 }

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-signrobbery'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
