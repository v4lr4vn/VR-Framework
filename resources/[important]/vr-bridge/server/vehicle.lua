local U = Bridge.util
local V = {}
Bridge.vehicle = V

local SERVER_KEYS = {
    ['vr-vehiclekeys'] = function(src, veh, plate) return exports['vr-vehiclekeys']:GiveKeys(src, plate or veh) end,
    qbx_vehiclekeys = function(src, veh) return exports.qbx_vehiclekeys:GiveKeys(src, veh) end,
    ['Renewed-Vehiclekeys'] = function(src, _, plate) return exports['Renewed-Vehiclekeys']:addKey(src, plate) end,
    wasabi_carlock = function(src, _, plate) return exports.wasabi_carlock:GiveKey(src, plate) end,
    MrNewbVehicleKeys = function(src, veh) return exports.MrNewbVehicleKeys:GiveKeys(src, veh) end,
}

function V.giveKeys(src, veh, plate)
    if not src then return false end
    plate = plate or (veh and veh ~= 0 and GetVehicleNumberPlateText(veh)) or nil
    local res = Bridge.detect('keys')
    local fn = res and SERVER_KEYS[res]
    if fn and U.started(res) then
        local ok = pcall(fn, src, veh, plate)
        if ok then return true end
    end
    TriggerClientEvent('__vrb_keys:' .. Bridge.resource, src, veh and veh ~= 0 and NetworkGetNetworkIdFromEntity(veh) or nil, plate)
    return true
end

function V.setFuel(veh, amount)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    amount = math.max(0.0, math.min(100.0, (tonumber(amount) or 100) + 0.0))
    Entity(veh).state:set('fuel', amount, true)
    return true
end

return V
