Config.Warrants = {
    days = 7,
    selfApproveGrade = 3,
}

Config.Mugshot = {
    distance = 5.0,
    countdown = 3,
    fov = 38.0,
}

Config.VehicleFlags = {
    'Stolen',
    'BOLO',
    'Impounded',
    'Suspended registration',
}

Config.WeaponFlags = {
    'Stolen',
    'Used in crime',
}

Config.Records = {
    searchLimit = 30,
    recentLimit = 12,
    profileListLimit = 50,
}

Config.Prison.tickSeconds = Config.Prison.tickSeconds or 10
Config.Prison.saveSeconds = Config.Prison.saveSeconds or 60
Config.Prison.disableWeapons = Config.Prison.disableWeapons ~= false
Config.Prison.command = Config.Prison.command or 'jailtime'
