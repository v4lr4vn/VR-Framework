Config = {}

Config.Command = 'mdt'
Config.Keys = {
    open = 'F5',
    respond = 'Y',
}

Config.RequireDuty = true

Config.Departments = {
    police = { label = 'Los Santos Police Department', short = 'LSPD', type = 'leo', color = '#5AA9FF' },
    ems = { label = 'Los Santos Medical Services', short = 'LSMS', type = 'ems', color = '#FF6F91' },
    doj = { label = 'San Andreas Department of Justice', short = 'DOJ', type = 'doj', color = '#B79CFF', separateJobs = true },
    dispatch = { label = 'San Andreas Emergency Dispatch', short = 'DISPATCH', type = 'dispatch', color = '#3DD68C' },
}

Config.Tablet = {
    prop = 'prop_cs_tablet',
    animDict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    anim = 'base',
}

Config.Dispatch = {
    maxCalls = 40,
    keepClosed = 30,
    alertSeconds = 8,
    blipSeconds = 300,
    unitRefresh = 3000,
    emergencyCooldown = 60,
    clientAlertLimit = { count = 5, seconds = 30 },
    maxAlertDistance = 150.0,
    phoneItems = {},
    emergency = {
        ['911'] = { 'leo' },
        ['311'] = { 'ems' },
    },
}

Config.AutoAlerts = {
    shooting = true,
    autotheft = true,
    melee = false,
    speeding = false,
    explosion = false,
    cooldown = 20,
    ignoreJobs = { 'leo' },
    silencedChance = 0.0,
}

Config.UnitStatuses = {
    { id = 'available', label = 'Available', code = '10-8', color = 'ok' },
    { id = 'enroute', label = 'En route', code = '10-76', color = 'accent' },
    { id = 'onscene', label = 'On scene', code = '10-97', color = 'info' },
    { id = 'busy', label = 'Busy', code = '10-6', color = 'muted' },
    { id = 'transport', label = 'Transporting', code = '10-15', color = 'info' },
    { id = 'break', label = 'On break', code = '10-7', color = 'muted' },
}

Config.Fines = {
    society = 'police',
    maxAmount = 250000,
}

Config.Prison = {
    secondsPerMonth = 60,
    maxMonths = 300,
    inside = vector4(1691.6, 2565.9, 45.56, 180.0),
    release = vector4(1847.9, 2585.9, 45.67, 270.0),
    centre = vector3(1690.0, 2580.0, 45.6),
    radius = 190.0,
    keepItems = { 'phone' },
}

Config.Images = {
    maxBytes = 600000,
    quality = 0.6,
    cameraResource = 'vr-camera',
}

Config.Map = {
    image = 'images/map.jpg',
    size = 8192,
    originX = 3753.6,
    originY = 5529.6,
    scaleX = 0.66304,
    scaleY = -0.656,
}

Config.CitizenFlags = {
    'Armed and dangerous',
    'Gang affiliated',
    'Known to flee',
    'Mental health concern',
    'Violent towards officers',
    'Parolee',
}

Config.Licences = {
    driver = 'Driver licence',
    weapon = 'Weapon licence',
    business = 'Business licence',
    pilot = 'Pilot licence',
    hunting = 'Hunting licence',
    fishing = 'Fishing licence',
}

Config.CallSounds = {
    ['10-99'] = { file = 'sounds/panic.mp3', volume = 0.8 },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-mdt'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
