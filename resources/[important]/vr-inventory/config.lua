local function convar(name, default)
    local value = GetConvar('vr-inventory:' .. name, '')
    if value == '' then value = GetConvar('inventory:' .. name, '') end
    if value == '' then return default end
    return value
end

local function convarBool(name, default)
    local value = convar(name, nil)
    if value == nil then return default end
    value = tostring(value):lower()
    return value == 'true' or value == '1' or value == 'yes' or value == 'on'
end

local function convarInt(name, default)
    return tonumber(convar(name, nil)) or default
end

local function convarJson(name, default)
    local value = convar(name, nil)
    if value == nil then return default end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then return decoded end
    return default
end

InvConfig = {
    convar = convar,
    convarBool = convarBool,
    convarInt = convarInt,
    convarJson = convarJson,
}

shared = {
    resource = GetCurrentResourceName(),
    framework = convar('framework', 'auto'),
    playerslots = convarInt('slots', 50),
    playerweight = convarInt('weight', 30000),
    target = convarBool('target', false),
    police = convarJson('police', { 'police', 'sheriff' }),
    networkdumpsters = convarBool('networkdumpsters', false),
    compat = convarBool('compat', true),
}

if shared.framework == 'auto' then shared.framework = Bridge.framework end

shared.dropslots = convarInt('dropslots', shared.playerslots)
shared.dropweight = convarInt('dropweight', shared.playerweight)

do
    local police = shared.police
    if type(police) == 'string' then police = { police } end
    local set = {}
    if type(police) == 'table' then
        for k, v in pairs(police) do
            if type(k) == 'number' then set[v] = 0 else set[k] = tonumber(v) or 0 end
        end
    end
    shared.police = set
end

if IsDuplicityVersion() then
    server = {
        loghookrejection = convarBool('loghookrejection', true),
        bulkstashsave = convarBool('bulkstashsave', true),
        loglevel = convarInt('loglevel', 1),
        randomprices = convarBool('randomprices', false),
        randomloot = convarBool('randomloot', true),
        evidencegrade = convarInt('evidencegrade', 2),
        trimplate = convarBool('trimplate', true),
        cleartime = convarInt('cleartime', 5) * 60,
        clearstashes = convar('clearstashes', '6 MONTH'),
        vehicleloot = convarJson('vehicleloot', {
            { 'sprunk', 1, 1 },
            { 'water', 1, 1 },
            { 'garbage', 1, 2, 50 },
            { 'money', 1, 50 },
            { 'money', 200, 400, 5 },
            { 'bandage', 1, 1 },
        }),
        dumpsterloot = convarJson('dumpsterloot', {
            { 'mustard', 1, 1 },
            { 'garbage', 1, 3 },
            { 'money', 1, 10 },
            { 'burger', 1, 1 },
        }),
        accounts = {},
    }

    local accounts = convarJson('accounts', { 'money' })
    for i = 1, #accounts do server.accounts[accounts[i]] = 0 end
else
    PlayerData = {}

    local function marker(name, fallback)
        local value = convarJson(name, nil)
        if type(value) ~= 'table' or not value.colour or not value.scale then return fallback end
        value.type = tonumber(value.type) or fallback.type
        return value
    end

    local keys = convarJson('keys', nil)
    if type(keys) ~= 'table' or not keys[1] then keys = { 'F2', 'K', 'TAB' } end

    client = {
        autoreload = convarBool('autoreload', false),
        screenblur = convarBool('screenblur', true),
        keys = keys,
        enablekeys = convarJson('enablekeys', { 249 }),
        aimedfiring = convarBool('aimedfiring', false),
        giveplayerlist = convarBool('giveplayerlist', false),
        weaponanims = convarBool('weaponanims', true),
        itemnotify = convarBool('itemnotify', true),
        weaponnotify = convarBool('weaponnotify', true),
        imagepath = convar('imagepath', ('nui://%s/web/images'):format(shared.resource)),
        dropprops = convarBool('dropprops', false),
        dropmodel = joaat(convar('dropmodel', 'prop_med_bag_01b')),
        weaponmismatch = convarBool('weaponmismatch', true),
        ignoreweapons = convarJson('ignoreweapons', {}),
        suppresspickups = convarBool('suppresspickups', true),
        disableweapons = convarBool('disableweapons', false),
        disablesetupnotification = convarBool('disablesetupnotification', false),
        enablestealcommand = convarBool('enablestealcommand', true),
        gloveboxseatrestriction = convarInt('gloveboxseatrestriction', 0) == 1,
        shopmarker = marker('shopmarker', { type = 29, colour = { 245, 165, 36 }, scale = { 0.5, 0.5, 0.5 } }),
        evidencemarker = marker('evidencemarker', { type = 2, colour = { 90, 169, 255 }, scale = { 0.3, 0.2, 0.15 } }),
        craftingmarker = marker('craftingmarker', { type = 2, colour = { 183, 156, 255 }, scale = { 0.3, 0.2, 0.15 } }),
        dropmarker = marker('dropmarker', { type = 2, colour = { 255, 90, 82 }, scale = { 0.3, 0.2, 0.15 } }),
    }

    local ignore = {}
    for i = 1, #client.ignoreweapons do
        local weapon = client.ignoreweapons[i]
        ignore[tonumber(weapon) or joaat(weapon)] = true
    end
    for _, name in ipairs({ 'WEAPON_UNARMED', 'WEAPON_HANDCUFFS', 'WEAPON_GARBAGEBAG', 'OBJECT', 'WEAPON_HOSE' }) do
        ignore[joaat(name)] = true
    end
    client.ignoreweapons = ignore
end
