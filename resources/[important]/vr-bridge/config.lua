BridgeConfig = {
    framework = 'auto',
    inventory = 'auto',
    target = 'auto',
    notify = 'auto',
    textUI = 'auto',
    fuel = 'auto',
    keys = 'auto',
    banking = 'auto',
    voice = 'auto',
    database = 'auto',

    jobTypes = {
        police = 'leo',
        sheriff = 'leo',
        bcso = 'leo',
        sasp = 'leo',
        statepolice = 'leo',
        ranger = 'leo',
        ambulance = 'ems',
        ems = 'ems',
        doctor = 'ems',
        fire = 'ems',
        judge = 'doj',
        prosecutor = 'doj',
        lawyer = 'doj',
        dispatch = 'dispatch',
    },

    adminGroups = {
        vr = { 'group.admin' },
        qb = { 'qbcore.god', 'qbcore.admin', 'group.admin' },
        qbx = { 'group.admin' },
        esx = { 'group.admin', 'group.superadmin' },
        ox = { 'group.admin' },
        none = { 'group.admin' },
    },

    esx = {
        bossGrades = { boss = true },
        licences = { drive = 'driver', drive_bike = 'driver', drive_truck = 'driver', dmv = 'driver', weapon = 'weapon' },
        society = 'society_%s',
        needs = { hunger = 'hunger', thirst = 'thirst' },
    },

    society = {
        qb = 'auto',
        qbx = 'auto',
    },

    vehicleTables = {
        qb = 'player_vehicles',
        esx = 'owned_vehicles',
        ox = 'vehicles',
    },

    callbackTimeout = 10000,
}
