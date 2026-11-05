Config = {}

Config.RequireJob = true

Config.FallbackJob = 'unemployed'

Config.Account = 'bank'

Config.Levels = {
    base = 1000,
    growth = 1.1,
    max = 100,
    payPerLevel = 0.02,
}

Config.Crew = {
    range = 20.0,
    inviteSeconds = 30,
    bonusPerExtraMember = 0.15,
    earlyStopPercent = 100,
}

Config.Penalty = {
    vehicleNotReturned = 500,
    crashBelowBodyHealth = 700.0,
    crashPerCent = 0.35,
}

Config.StartCooldownSeconds = 20

Config.Police = {
    enabled = true,
    jobs = { 'police' },
    cooldownSeconds = 60,
}

Config.Admin = {
    command = 'civjobs',
}

Config.Blips = true

-- Jobs that are switched off for now: no depot, no blip, nobody can start a shift. Set one to false (or remove it) to turn it back on.
-- (They are also not offered at the City Hall Job Centre: see Config.JobCentre.jobs in vr-cityhall.)
Config.Disabled = {
    lumberjack = true,
    scrapyard = true,
    builder = true,
    treasurehunter = true,
}

Config.Jobs = {}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-civjobs'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
