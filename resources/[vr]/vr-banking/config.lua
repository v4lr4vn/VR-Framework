Config = {}

Config.BankName = 'ValRavn Bank'
Config.AdminAce = 'command.bankadmin'
Config.CardItem = 'bank_card'
Config.CollectorJob = 'debtcollector'
Config.MaxTransaction = 10000000

Config.Branches = {
    { id = 'legion', label = 'Legion Square', coords = vec3(149.05, -1041.30, 29.37), blip = true },
    { id = 'hawick', label = 'Hawick Avenue', coords = vec3(313.32, -280.03, 54.17), blip = true },
    { id = 'burton', label = 'Burton', coords = vec3(-351.32, -50.39, 49.04), blip = true },
    { id = 'rockford', label = 'Rockford Hills', coords = vec3(-1212.63, -331.17, 37.78), blip = true },
    { id = 'chumash', label = 'Great Ocean Highway', coords = vec3(-2961.98, 482.77, 15.70), blip = true },
    { id = 'harmony', label = 'Route 68', coords = vec3(1175.64, 2707.71, 38.09), blip = true },
    { id = 'pacific', label = 'Pacific Standard', coords = vec3(246.64, 223.20, 106.29), blip = true },
    { id = 'paleto', label = 'Paleto Bay', coords = vec3(-113.01, 6470.24, 31.63), blip = true },
}

Config.Branch = {
    targetRadius = 1.4,
    useDistance = 8.0,
    blip = { sprite = 108, colour = 2, scale = 0.75, label = 'Bank' },
}

Config.Atm = {
    models = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
    useDistance = 4.0,
    dailyLimit = 5000,
    fastCash = { 100, 200, 500, 1000, 2000 },
    allowDeposit = true,
    sessionSeconds = 180,
    blips = false,
}

Config.Cards = {
    fee = 50,
    pinLength = 4,
    maxFails = 3,
    lockMinutes = 15,
    retainOnLock = false,
}

Config.Accounts = {
    numberPrefix = '40',
    maxShared = 3,
    maxSharedMembers = 8,
    maxSavings = 1,
    openFee = 0,
    transferLimit = 1000000,
    historyLimit = 60,
}

Config.Savings = {
    ratePercent = 0.5,
    periodHours = 24,
    maxInterestBalance = 2000000,
    minBalance = 1000,
    catchUpPeriods = 3,
}

Config.Society = {
    defaultBossOnly = true,
    minGrade = {
        police = 3,
        ambulance = 3,
    },
}

Config.Credit = {
    start = 650,
    min = 300,
    max = 850,
    events = {
        onTime = 4,
        missed = -20,
        default = -80,
        paidOff = 15,
        opened = -5,
        settled = 25,
        repossessed = -40,
    },
    tiers = {
        { min = 800, key = 'exceptional', label = 'Exceptional', maxLoan = 150000, ratePercent = 5 },
        { min = 740, key = 'verygood', label = 'Very good', maxLoan = 75000, ratePercent = 8 },
        { min = 670, key = 'good', label = 'Good', maxLoan = 35000, ratePercent = 12 },
        { min = 580, key = 'fair', label = 'Fair', maxLoan = 12000, ratePercent = 18 },
        { min = 0, key = 'poor', label = 'Poor', maxLoan = 3000, ratePercent = 28 },
    },
}

Config.Loans = {
    enabled = true,
    maxActive = 1,
    minAmount = 1000,
    minScore = 500,
    terms = { 4, 8, 12, 24 },
    intervalHours = 24,
    lateFeePercent = 10,
    defaultAfterMissed = 3,
    finance = {
        enabled = true,
        maxActive = 2,
        minDownPercent = 10,
    },
    collateral = {
        enabled = true,
        valueShare = 0.6,
        maxMultiplier = 2.0,
        rateDiscountPercent = 3,
    },
}

Config.Vehicles = {
    table = 'player_vehicles',
    owner = 'citizenid',
    plate = 'plate',
    model = 'vehicle',
}

Config.Collections = {
    claimMinutes = 60,
    traceCooldownSeconds = 120,
    traceRadius = 140.0,
    repoAnyVehicle = true,
    repoSeconds = 12,
    repoDistance = 8.0,
    repoFee = 500,
    collectorRepoPay = 750,
    commissionPercent = 10,
    collectDistance = 3.0,
    requestTimeout = 30,
    stage = {
        enabled = true,
        checkMinutes = 3,
        startDelaySeconds = 45,
        spotClearance = 3.5,
    },
    tracker = {
        enabled = true,
        intervalSeconds = 8,
        blip = { sprite = 225, colour = 1, claimedColour = 47, scale = 0.85 },
    },
}

Config.RepoSpots = {
    vec4(-1145.53, -745.89, 19.27, 106.86),
    vec4(60.80, 17.54, 68.82, 339.7),
    vec4(-472.39, -787.71, 30.14, 180.52),
    vec4(377.37, 294.90, 102.86, 161.47),
    vec4(-779.77, -2040.18, 8.47, 315.34),
    vec4(-1188.14, -1487.95, 3.97, 124.06),
    vec4(881.08, -14.18, 78.34, 237.17),
    vec4(1137.69, 2673.61, 37.90, 359.5),
    vec4(1730.31, 3711.07, 34.20, 20.53),
    vec4(70.71, 6425.16, 30.92, 68.5),
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-banking'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
