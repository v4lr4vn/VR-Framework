local U = Bridge.util
local V = {}
Bridge.vehicle = V

local STATE_FUEL = { ox_fuel = true, ['Renewed-Fuel'] = true, lc_fuel = true }

function V.getFuel(veh)
    if not veh or veh == 0 then return 0.0 end
    local res = Bridge.detect('fuel')
    if res and U.started(res) then
        if STATE_FUEL[res] then
            local v = Entity(veh).state.fuel
            if tonumber(v) then return tonumber(v) + 0.0 end
        else
            local ok, v = pcall(function() return exports[res]:GetFuel(veh) end)
            if ok and tonumber(v) then return tonumber(v) + 0.0 end
        end
    end
    return GetVehicleFuelLevel(veh) + 0.0
end

function V.setFuel(veh, amount)
    if not veh or veh == 0 then return false end
    amount = math.max(0.0, math.min(100.0, (tonumber(amount) or 100) + 0.0))
    local res = Bridge.detect('fuel')
    if res and U.started(res) then
        if STATE_FUEL[res] then
            Entity(veh).state:set('fuel', amount, true)
        else
            local ok = pcall(function() exports[res]:SetFuel(veh, amount) end)
            if ok then return true end
        end
    end
    SetVehicleFuelLevel(veh, amount)
    return true
end

local KEYS = {
    ['vr-vehiclekeys'] = function(_, plate) TriggerEvent('vehiclekeys:client:SetOwner', plate) end,
    ['qb-vehiclekeys'] = function(_, plate) TriggerEvent('vehiclekeys:client:SetOwner', plate) end,
    qbx_vehiclekeys = function(_, plate) TriggerEvent('vehiclekeys:client:SetOwner', plate) end,
    ['Renewed-Vehiclekeys'] = function(_, plate) exports['Renewed-Vehiclekeys']:addKey(plate) end,
    wasabi_carlock = function(_, plate) exports.wasabi_carlock:GiveKey(plate) end,
    MrNewbVehicleKeys = function(veh) exports.MrNewbVehicleKeys:GiveKeys(veh) end,
    ['qs-vehiclekeys'] = function(veh, plate) exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(veh)), true) end,
    cd_garage = function(_, plate) TriggerEvent('cd_garage:AddKeys', plate) end,
    okokGarage = function(_, plate) TriggerServerEvent('okokGarage:GiveKeys', plate) end,
    vehicles_keys = function(_, plate) TriggerServerEvent('vehicles_keys:selfGiveVehicleKeys', plate) end,
    t1ger_keys = function(_, plate) exports.t1ger_keys:GiveTemporaryKeys(plate) end,
}

function V.giveKeys(veh, plate)
    plate = plate or (veh and veh ~= 0 and GetVehicleNumberPlateText(veh)) or nil
    if not plate then return false end
    plate = U.trim(plate)
    local res = Bridge.detect('keys')
    local fn = res and KEYS[res]
    if fn and U.started(res) then
        local ok = pcall(fn, veh, plate)
        if ok then return true end
    end
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    return true
end

RegisterNetEvent('__vrb_keys:' .. Bridge.resource, function(netId, plate)
    local veh = netId and NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or nil
    V.giveKeys(veh, plate)
end)

function V.plate(veh)
    if not veh or veh == 0 then return nil end
    return U.trim(GetVehicleNumberPlateText(veh))
end

function V.getProps(veh)
    if type(lib) == 'table' and lib.getVehicleProperties then return lib.getVehicleProperties(veh) end
    local ok, res = pcall(function() return exports['vr-lib']:getVehicleProperties(veh) end)
    if ok and res then return res end
    return { model = GetEntityModel(veh), plate = V.plate(veh), fuelLevel = V.getFuel(veh), bodyHealth = GetVehicleBodyHealth(veh), engineHealth = GetVehicleEngineHealth(veh) }
end

function V.setProps(veh, props)
    if type(lib) == 'table' and lib.setVehicleProperties then return lib.setVehicleProperties(veh, props) end
    local ok = pcall(function() exports['vr-lib']:setVehicleProperties(veh, props) end)
    return ok
end

return V
