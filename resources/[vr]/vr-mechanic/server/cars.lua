Cars = { dirty = {} }

local owned = {}

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return nil end
    local ok, r = pcall(json.decode, v)
    return ok and type(r) == 'table' and r or nil
end

function Cars.entity(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

function Cars.plate(veh)
    return MU.plate(Entity(veh).state.vr_plate) or MU.plate(GetVehicleNumberPlateText(veh))
end

function Cars.status(veh)
    return MU.fullStatus(Entity(veh).state.vr_status)
end

function Cars.mileage(veh)
    return tonumber(Entity(veh).state.vr_mileage) or 0
end

function Cars.near(src, veh, dist)
    local pos = Core.coords(src)
    if not pos then return false end
    return #(pos - GetEntityCoords(veh)) <= (dist or Config.WorkDistance) + 1.0
end

function Cars.isOwned(plate)
    if not Db.vehicles or not plate then return false end
    local c = owned[plate]
    if c and os.time() - c.at < 120 then return c.yes end
    local row = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    owned[plate] = { yes = row ~= nil, at = os.time() }
    return row ~= nil
end

function Cars.forget(plate)
    owned[plate] = nil
end

local function round(v) return math.floor(v * 100 + 0.5) / 100 end

function Cars.setStatus(veh, status, extraMiles)
    local full = MU.fullStatus(status)
    for k, v in pairs(full) do full[k] = round(v) end
    local st = Entity(veh).state
    local miles = Cars.mileage(veh)
    if extraMiles and extraMiles > 0 then
        miles = math.floor(miles + extraMiles)
        st:set('vr_mileage', miles, true)
    end
    local old = st.vr_status
    local changed = type(old) ~= 'table'
    if not changed then
        for k, v in pairs(full) do
            if tonumber(old[k]) ~= v then changed = true break end
        end
    end
    if changed then st:set('vr_status', full, true) end
    local plate = Cars.plate(veh)
    if plate then Cars.dirty[plate] = { status = full, mileage = miles } end
    return full
end

function Cars.flush()
    if not Db.vehicles then Cars.dirty = {} return end
    local batch = Cars.dirty
    Cars.dirty = {}
    for plate, d in pairs(batch) do
        if Cars.isOwned(plate) then
            MySQL.update('UPDATE player_vehicles SET status = ?, drivingdistance = GREATEST(COALESCE(drivingdistance, 0), ?) WHERE plate = ?', {
                json.encode(d.status), math.floor(d.mileage or 0), plate,
            })
        end
    end
end

function Cars.saveColumns(plate, fields)
    if not Db.vehicles or not plate or not Cars.isOwned(plate) then return false end
    local sets, params = {}, {}
    for k, v in pairs(fields) do
        if k == 'engine' or k == 'body' then
            sets[#sets + 1] = ('`%s` = ?'):format(k)
            params[#params + 1] = v
        end
    end
    if #sets == 0 then return false end
    params[#params + 1] = plate
    MySQL.update(('UPDATE player_vehicles SET %s WHERE plate = ?'):format(table.concat(sets, ', ')), params)
    return true
end

function Cars.saveMods(plate, changes)
    if not Db.vehicles or not plate or not Cars.isOwned(plate) then return false end
    local row = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ?', { plate })
    if not row then return false end
    local mods = decode(row.mods) or {}
    for k, v in pairs(changes) do mods[k] = v end
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(mods), plate })
    return true
end

function Cars.fix(veh, what, value, fallback)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local owner = NetworkGetEntityOwner(veh)
    local target = (owner and owner > 0) and owner or fallback
    if target then TriggerClientEvent('vr-mechanic:client:fix', target, netId, what, value) end
end

function Cars.label(veh)
    return Core.vehicleLabelByHash(GetEntityModel(veh))
end
