VRCore = {}
VRCore.Config = {}

VRCore.Config.Debug           = false
VRCore.Config.QBBridge        = true
VRCore.Config.MaxPlayers      = GetConvarInt('sv_maxclients', 48)
VRCore.Config.DefaultSpawn    = vector4(-1035.71, -2731.87, 12.86, 0.0)
VRCore.Config.UpdateInterval  = 5
VRCore.Config.StatusInterval  = 5000
VRCore.Config.CallbackTimeout = 15000

VRCore.Config.Resources = {
    inventory   = 'vr-inventory',
    banking     = 'vr-banking',
    logs        = 'vr-log',
    vehiclekeys = 'vr-vehiclekeys',
    progressbar = 'progressbar',
}

VRCore.Config.Database = {
    AutoInstall = true,
}

VRCore.Config.CharacterTables = {
    'vr_players',
    'vr_player_contacts',
    'vr_clothing_skins',
    'vr_clothing_outfits',
    { 'vr_inventory_stashes', 'owner' },
}

VRCore.Config.Money = {}
VRCore.Config.Money.MoneyTypes      = { cash = 500, bank = 5000, crypto = 0 }
VRCore.Config.Money.DontAllowMinus  = { 'cash', 'crypto' }
VRCore.Config.Money.MinusLimit      = -5000
VRCore.Config.Money.PayCheckTimeOut = 10
VRCore.Config.Money.PayCheckSociety = false

VRCore.Config.Player = {}
VRCore.Config.Player.HungerRate = 4.2
VRCore.Config.Player.ThirstRate = 3.8
VRCore.Config.Player.Bloodtypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }

VRCore.Config.Player.PlayerDefaults = {
    citizenid = function() return VRCore.Player.CreateCitizenId() end,
    cid = 1,
    money = function()
        local money = {}
        for moneytype, startamount in pairs(VRCore.Config.Money.MoneyTypes) do money[moneytype] = startamount end
        return money
    end,
    optin = true,
    charinfo = {
        firstname = 'Firstname',
        lastname = 'Lastname',
        birthdate = '00-00-0000',
        gender = 0,
        nationality = 'USA',
        phone = function() return VRCore.Functions.CreatePhoneNumber() end,
        account = function() return VRCore.Functions.CreateAccountNumber() end,
    },
    job = {
        name = 'unemployed',
        label = 'Civilian',
        payment = 10,
        type = 'none',
        onduty = false,
        isboss = false,
        grade = { name = 'Freelancer', level = 0 },
    },
    gang = {
        name = 'none',
        label = 'No Gang Affiliation',
        isboss = false,
        grade = { name = 'none', level = 0 },
    },
    metadata = {
        hunger = 100,
        thirst = 100,
        stress = 0,
        isdead = false,
        inlaststand = false,
        armor = 0,
        ishandcuffed = false,
        tracker = false,
        injail = 0,
        jailitems = {},
        status = {},
        phone = {},
        rep = {},
        callsign = 'NO CALLSIGN',
        bloodtype = function() return VRCore.Config.Player.Bloodtypes[math.random(1, #VRCore.Config.Player.Bloodtypes)] end,
        fingerprint = function() return VRCore.Player.CreateFingerId() end,
        walletid = function() return VRCore.Player.CreateWalletId() end,
        criminalrecord = { hasRecord = false },
        licences = { driver = true, business = false, weapon = false },
        inside = { apartment = {} },
        phonedata = {
            SerialNumber = function() return VRCore.Player.CreateSerialNumber() end,
            InstalledApps = {},
        },
    },
    position = VRCore.Config.DefaultSpawn,
    items = {},
}

VRCore.Config.Server = {}
VRCore.Config.Server.Closed                = false
VRCore.Config.Server.ClosedReason          = 'Server Closed'
VRCore.Config.Server.Whitelist             = false
VRCore.Config.Server.WhitelistPermission   = 'admin'
VRCore.Config.Server.PVP                   = true
VRCore.Config.Server.Discord               = ''
VRCore.Config.Server.CheckDuplicateLicense = true
VRCore.Config.Server.Permissions           = { 'god', 'admin', 'mod' }

VRCore.Config.World = {}
VRCore.Config.World.WantedLevel   = false
VRCore.Config.World.AIPolice      = false
VRCore.Config.World.PoliceScanner = false
VRCore.Config.World.DisabledDispatch = { 1, 2, 4, 6, 7, 8, 9, 10, 12, 13, 14 }
VRCore.Config.World.BlockedVehicles = {
    'police', 'police2', 'police3', 'police4', 'police5', 'policeb', 'policet', 'policeold1', 'policeold2',
    'sheriff', 'sheriff2', 'fbi', 'fbi2', 'pranger', 'riot', 'riot2', 'polmav', 'predator', 'pbus',
    'poldominator10', 'poldorado', 'polgauntlet', 'polgreenwood', 'polimpaler5', 'polimpaler6',
    'polcaracara', 'polterminus', 'polcoquette4', 'polfaction2',
}
VRCore.Config.World.BlockedPeds = {
    's_m_y_cop_01', 's_f_y_cop_01', 's_m_y_sheriff_01', 's_f_y_sheriff_01', 's_m_y_hwaycop_01',
    's_m_y_swat_01', 's_m_m_snowcop_01', 's_m_y_ranger_01', 's_f_y_ranger_01', 'csb_cop',
}
VRCore.Config.World.BlockedScenarioTypes = {
    'WORLD_VEHICLE_POLICE_CAR', 'WORLD_VEHICLE_POLICE_BIKE', 'WORLD_VEHICLE_POLICE_NEXT_TO_CAR', 'WORLD_HUMAN_COP_IDLES',
}
VRCore.Config.World.BlockedScenarioGroups = {
    'MP_POLICE', 'MP_POLICE2', 'POLICE_POUND1', 'POLICE_POUND2', 'POLICE_POUND3', 'POLICE_POUND4', 'POLICE_POUND5',
}

VRCore.Config.Commands = {}
VRCore.Config.Commands.OOCColor = { 255, 151, 133 }

VRCore.Config.Notify = {}
VRCore.Config.Notify.NotificationStyling = {
    group = false,
    position = 'right',
    progress = true,
    max = 5,
}

VRCore.Config.Notify.VariantDefinitions = {
    success   = { classes = 'success', icon = 'check_circle' },
    primary   = { classes = 'primary', icon = 'notifications' },
    warning   = { classes = 'warning', icon = 'warning' },
    error     = { classes = 'error', icon = 'error' },
    police    = { classes = 'police', icon = 'local_police' },
    ambulance = { classes = 'ambulance', icon = 'medical_services' },
}
