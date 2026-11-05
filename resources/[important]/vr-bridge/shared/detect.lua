local U = Bridge.util

local function forced(kind)
    local value = GetConvar('vr_bridge:' .. kind, '')
    if value ~= '' and value ~= 'auto' then return value end
    local configured = BridgeConfig[kind]
    if configured and configured ~= 'auto' then return configured end
    return nil
end

local function pick(kind, order)
    local name = forced(kind)
    if name then
        local first
        for _, entry in ipairs(order) do
            if entry[1] == name then return entry[2], entry[1] end
            if entry[2] == name then
                if U.present(entry[1]) then return entry[2], entry[1] end
                first = first or entry
            end
        end
        if first then return first[2], first[1] end
        return name, name
    end
    for _, entry in ipairs(order) do
        if U.present(entry[1]) then return entry[2], entry[1] end
    end
    return 'none'
end

local FRAMEWORKS = {
    { 'vr-core', 'vr' },
    { 'qbx_core', 'qbx' },
    { 'qb-core', 'qb' },
    { 'es_extended', 'esx' },
    { 'ox_core', 'ox' },
}

local INVENTORIES = {
    { 'vr-inventory', 'ox' },
    { 'ox_inventory', 'ox' },
    { 'qs-inventory', 'qs' },
    { 'ps-inventory', 'qb' },
    { 'lj-inventory', 'qb' },
    { 'qb-inventory', 'qb' },
}

local TARGETS = {
    { 'vr-target', 'vr' },
    { 'ox_target', 'ox' },
    { 'qb-target', 'qb' },
}

local framework, coreResource = pick('framework', FRAMEWORKS)
local inventory, inventoryResource = pick('inventory', INVENTORIES)
if inventory == 'none' then
    if framework == 'esx' then inventory = 'esx'
    elseif framework == 'qb' or framework == 'qbx' or framework == 'vr' then inventory = 'core' end
end
local target, targetResource = pick('target', TARGETS)

Bridge.framework = framework
Bridge.coreResource = coreResource or ({ vr = 'vr-core', qb = 'qb-core', qbx = 'qbx_core', esx = 'es_extended', ox = 'ox_core' })[framework]
Bridge.inventoryName = inventory
Bridge.inventoryResource = inventoryResource or ({ ox = 'ox_inventory', qb = 'qb-inventory', qs = 'qs-inventory' })[inventory]
Bridge.targetName = target
Bridge.targetResource = targetResource or ({ vr = 'vr-target', ox = 'ox_target', qb = 'qb-target' })[target]

local OPTIONAL = {
    fuel = { 'vr-fuel', 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel', 'Renewed-Fuel', 'okokGasStation', 'qs-fuelstations', 'BigDaddy-Fuel', 'ti_fuel', 'x-fuel', 'lc_fuel' },
    keys = { 'vr-vehiclekeys', 'qbx_vehiclekeys', 'qb-vehiclekeys', 'Renewed-Vehiclekeys', 'wasabi_carlock', 'MrNewbVehicleKeys', 'qs-vehiclekeys', 'cd_garage', 'okokGarage', 'vehicles_keys', 't1ger_keys' },
    banking = { 'vr-banking', 'Renewed-Banking', 'qb-banking', 'okokBanking', 'qb-management', 'esx_addonaccount', 'fd_banking', 'tgg-banking', 'snipe-banking', 'kartik-banking' },
    voice = { 'vr-voice', 'pma-voice', 'saltychat', 'mumble-voip', 'tokovoip_script' },
    database = { 'vr-mysql', 'oxmysql', 'mysql-async', 'ghmattimysql' },
    phone = { 'vr-phone', 'lb-phone', 'qb-phone', 'qs-smartphone', 'qs-smartphone-pro', 'gksphone', 'npwd', 'yseries', 'okokPhone', 'roadphone', 'high_phone' },
    garage = { 'vr-garages', 'qbx_garages', 'qb-garages', 'jg-advancedgarages', 'cd_garage', 'okokGarage', 'esx_garage', 'loaf_garage' },
}

local found = {}

function Bridge.detect(kind)
    local cached = found[kind]
    if cached and U.started(cached) then return cached end
    local name = forced(kind)
    if name then
        found[kind] = name
        return name
    end
    for _, res in ipairs(OPTIONAL[kind] or {}) do
        if U.started(res) then
            found[kind] = res
            return res
        end
    end
    for _, res in ipairs(OPTIONAL[kind] or {}) do
        if U.present(res) then
            found[kind] = res
            return res
        end
    end
    return nil
end

function Bridge.info()
    return {
        framework = Bridge.framework,
        core = Bridge.coreResource,
        inventory = Bridge.inventoryName,
        inventoryResource = Bridge.inventoryResource,
        target = Bridge.targetName,
        targetResource = Bridge.targetResource,
        fuel = Bridge.detect('fuel'),
        keys = Bridge.detect('keys'),
        banking = Bridge.detect('banking'),
        voice = Bridge.detect('voice'),
        database = Bridge.detect('database'),
        phone = Bridge.detect('phone'),
        garage = Bridge.detect('garage'),
    }
end

return true
