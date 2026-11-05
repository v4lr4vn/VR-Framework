Config = {}

Config.Debug = false

Config.Speakers = {
    speaker_wall    = { label = 'Wall Speaker',    model = 'sf_prop_sf_speaker_wall_01a',       mount = 'wall',    radius = 20.0, yaw = 0.0 },
    speaker_ceiling = { label = 'Ceiling Speaker', model = 'v_serv_metro_ceilingspeaker',        mount = 'ceiling', radius = 18.0, yaw = 0.0 },
    speaker_floor   = { label = 'Floor Speaker',   model = 'ba_prop_battle_club_speaker_small',  mount = 'floor',   radius = 25.0, yaw = 0.0 },
    speaker_large   = { label = 'Large Speaker',   model = 'ba_prop_battle_club_speaker_large',  mount = 'floor',   radius = 35.0, yaw = 0.0 },
}

Config.Boombox = {
    item = 'boombox',
    label = 'Boombox',
    model = 'prop_boombox_01',
    mount = 'floor',
    radius = 15.0,
    yaw = 0.0,
    anyoneCanControl = false,
}

Config.Booster = {
    item = 'range_booster',
    label = 'Range Booster',
    model = 'prop_satdish_s_03',
    mount = 'wall',
    yaw = 0.0,
    linkRange = 100.0,
    perPlace = 1,
}

Config.CarStereo = {
    item = 'car_stereo',
    label = 'Car Sound System',
    radius = 18.0,
    seats = { -1, 0 },
    command = 'stereo',
    key = '',
    installTime = 4000,
}

Config.Limits = {
    perBusiness = 50,
    maxPerZone = 100,
    perHome = 35,
    linkRange = 40.0,
    queueLength = 50,
    placeDistance = 8.0,
    controlDistance = 40.0,
}

Config.Range = { min = 5, max = 100, step = 5 }

Config.Businesses = {}

Config.AudioHosts = {}

Config.AdminPermission = 'admin'

Config.MasterVolume = 0.6
Config.DefaultVolume = 0.5
Config.StreamDistance = 120.0

Config.Occlusion = {
    room    = { cutoff = 2600, gain = 0.85, ytGain = 0.75 },
    outside = { cutoff = 650,  gain = 0.75, ytGain = 0.35 },
    vehicle = { cutoff = 900,  gain = 0.8,  ytGain = 0.45 },
}

Config.SystemName = { home = 'Home Speakers', boombox = 'Boombox', vehicle = 'Car Stereo' }

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-djbooth'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
