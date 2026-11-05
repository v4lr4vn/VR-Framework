local function resolve(v)
    if type(v) == 'string' then return KU.plate(v), nil end
    if type(v) == 'number' and v ~= 0 and DoesEntityExist(v) then
        local a = Keys.platesOf(v)
        return a, v
    end
    return nil, nil
end

local function give(src, v, minutes)
    local plate = resolve(v)
    local info = Core.info(src)
    if not plate or not info then return false end
    Keys.grantTemp(info.cid, plate, minutes or Config.Keys.tempMinutes)
    Keys.push(tonumber(src))
    return true
end

local function remove(src, v)
    local plate = resolve(v)
    local info = Core.info(src)
    if not plate or not info then return false end
    local done = Keys.revoke(info.cid, plate)
    Keys.push(tonumber(src))
    return done
end

local function has(src, v)
    local plate, veh = resolve(v)
    local info = Core.info(src)
    if not info or not plate then return false end
    if veh then return Keys.forVehicle(info, veh) ~= nil end
    return Keys.kind(info.cid, plate) ~= nil
end

exports('GiveKeys', give)
exports('addKey', give)
exports('RemoveKeys', remove)
exports('removeKey', remove)
exports('HasKeys', has)
exports('hasKey', has)

exports('GiveKeysToCid', function(cid, v, minutes)
    local plate = resolve(v)
    if not plate or type(cid) ~= 'string' then return false end
    Keys.grantTemp(cid, plate, minutes or Config.Keys.tempMinutes)
    Keys.pushCid(cid)
    return true
end)

exports('ClearKeys', function(v)
    local plate = resolve(v)
    if not plate then return 0 end
    local who = Keys.clearPlate(plate)
    Keys.pushAll(who)
    return #who
end)

exports('OwnerChanged', function(plate, cid)
    TriggerEvent('vr-garages:server:ownerChanged', plate, cid)
end)

exports('SetLocked', function(veh, locked)
    if type(veh) ~= 'number' or not DoesEntityExist(veh) then return false end
    Keys.setLocked(veh, locked == true)
    return true
end)

exports('IsLocked', function(veh)
    if type(veh) ~= 'number' or not DoesEntityExist(veh) then return false end
    return Keys.isLocked(veh)
end)

exports('Hotwire', function(veh)
    if type(veh) ~= 'number' or not DoesEntityExist(veh) then return false end
    Entity(veh).state:set('vr_hotwired', true, true)
    return true
end)
