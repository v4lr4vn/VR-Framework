Config = {}

-- ---------------------------------------------------------------------------
-- Character select (the apartment the preview ped stands in)
-- ---------------------------------------------------------------------------
Config.Interior     = vector3(-763.2816, 330.0418, 199.4865)
Config.PedCoords    = vector4(-763.2816, 330.0418, 199.4865, 177.7942)
Config.HiddenCoords = vector4(-779.0154, 326.1801, 196.0860, 91.0454)
Config.CamCoords    = vector4(-763.1219, 326.8112, 200, 357.0954)

Config.InteriorIpl = 'apa_v_mp_h_06_b'
Config.InteriorIplVariants = {
    'apa_v_mp_h_01_b', 'apa_v_mp_h_02_b', 'apa_v_mp_h_03_b', 'apa_v_mp_h_04_b',
    'apa_v_mp_h_05_b', 'apa_v_mp_h_06_b', 'apa_v_mp_h_07_b', 'apa_v_mp_h_08_b',
}

-- Quiet idle pose for the preview ped. Set to nil to leave the ped standing still.
Config.IdleAnim = { dict = 'anim@heists@heist_corona@single_team', name = 'single_team_loop_boss' }

Config.EnableDeleteButton = true
Config.customNationality  = false
Config.MinAge             = 18          -- youngest allowed character; 0 turns the check off
Config.Tagline            = 'The city never sleeps.'

Config.DefaultNumberOfCharacters = 5
Config.PlayersNumberOfCharacters = {
}

-- ---------------------------------------------------------------------------
-- Spawning (this used to be the separate vr-spawn resource)
-- ---------------------------------------------------------------------------
-- A brand new character always starts here; the clothing creator opens on arrival.
Config.FirstSpawn = vector4(-1035.71, -2731.87, 12.86, 330.0)

-- true: returning characters always get the map. false: only when they own a house.
Config.ShowSpawnMenu = true

-- Only for housing that uses the qb-houses tables. vr-housing brings its own.
Config.HouseEnterEvent = nil

Config.CameraHeight = 400.0

-- Spawn at the character's workplace. Keyed by job name; only shown to people with that job.
Config.JobSpawns = {
    police    = { label = 'Mission Row PD', coords = vector4(441.0, -982.0, 30.69, 90.0) },
    ambulance = { label = 'Pillbox Medical', coords = vector4(298.0, -584.0, 43.26, 70.0) },
}

-- Open to everyone. Empty the list to remove "The City" from the menu.
-- Check each one in game after changing: the ground height is snapped automatically,
-- but a position inside a building will put people inside it.
Config.PublicSpawns = {
    { label = 'Legion Square',  coords = vector4(195.17, -933.77, 30.69, 144.0) },
    { label = 'Del Perro Pier', coords = vector4(-1850.0, -1231.0, 13.02, 320.0) },
    { label = 'LS Airport',     coords = vector4(-1035.71, -2731.87, 12.86, 330.0) },
    { label = 'Sandy Shores',   coords = vector4(1851.0, 3686.0, 34.27, 210.0) },
    { label = 'Paleto Bay',     coords = vector4(-448.0, 6008.0, 31.7, 225.0) },
}

-- The map behind the spawn menu is vr-mdt's dispatch map (web/map.jpg), so the numbers
-- below must match vr-mdt's Config.Map.
Config.Map = {
    size = 8192,
    originX = 3753.6,
    originY = 5529.6,
    scaleX = 0.66304,
    scaleY = -0.656,
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-multicharacter'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
