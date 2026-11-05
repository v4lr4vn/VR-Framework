Vehicles = { spawned = {} }

local COLS = { mods = true, garage = true, fuel = true, engine = true, body = true, state = true, depotprice = true, drivingdistance = true, status = true,
    fleet = true, nickname = true, impound_reason = true, impound_until = true, impound_by = true, impound_at = true, citizenid = true, license = true }

local function decode(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local ok, v = pcall(json.decode, s)
    return ok and v or nil
end

local function shape(r)
    if not r then return nil end
    r.plate = GU.plate(r.plate) or r.plate
    r.mods = decode(r.mods) or {}
    r.status = decode(r.status)
    r.state = tonumber(r.state) or 1
    r.fuel = tonumber(r.fuel) or 100
    r.engine = tonumber(r.engine) or 1000
    r.body = tonumber(r.body) or 1000
    r.depotprice = tonumber(r.depotprice) or 0
    r.drivingdistance = tonumber(r.drivingdistance) or 0
    r.impound_until = tonumber(r.impound_until) or 0
    r.impound_at = tonumber(r.impound_at) or 0
    r.garage = GU.resolveGarage(r.garage)
    return r
end

function Vehicles.get(plate)
    plate = GU.plate(plate)
    if not plate then return nil end
    return shape(MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }))
end

local function many(sql, params)
    local rows = MySQL.query.await(sql, params) or {}
    for i = 1, #rows do shape(rows[i]) end
    return rows
end

function Vehicles.forOwner(cid)
    return many('SELECT * FROM player_vehicles WHERE citizenid = ? ORDER BY id', { cid })
end

function Vehicles.forGarage(id)
    return many('SELECT * FROM player_vehicles WHERE garage = ? ORDER BY id', { id })
end

function Vehicles.update(plate, fields)
    local sets, params = {}, {}
    for k, v in pairs(fields) do
        if COLS[k] then
            sets[#sets + 1] = ('`%s` = ?'):format(k)
            if (k == 'mods' or k == 'status') and type(v) == 'table' then v = json.encode(v) end
            params[#params + 1] = v
        end
    end
    if #sets == 0 then return false end
    params[#params + 1] = GU.plate(plate)
    return (MySQL.update.await(('UPDATE player_vehicles SET %s WHERE plate = ?'):format(table.concat(sets, ', ')), params) or 0) > 0
end

function Vehicles.tidy()
    local jobIds = {}
    for id, def in pairs(Garages.list) do
        if def.type == 'job' then jobIds[#jobIds + 1] = id end
    end
    local sql = 'SELECT plate, garage, fleet FROM player_vehicles WHERE fleet IS NOT NULL'
    if #jobIds > 0 then sql = sql .. (' OR garage IN (%s)'):format(('?, '):rep(#jobIds):sub(1, -3)) end
    local rows = MySQL.query.await(sql, jobIds) or {}
    for _, r in ipairs(rows) do
        local def = r.garage and Garages.list[GU.resolveGarage(r.garage)]
        local garage = (def and def.type == 'job') and Config.DefaultGarage or r.garage
        MySQL.update.await('UPDATE player_vehicles SET fleet = NULL, garage = ? WHERE plate = ?', { garage, r.plate })
    end
    if #rows > 0 then print(('[vr-garages] moved %d vehicles out of job garages and fleets back to their owners'):format(#rows)) end
    return #rows
end

function Vehicles.exists(plate)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil
end

local LETTERS = 'ABCDEFGHJKLMNPRSTUVWXYZ'

function Vehicles.generatePlate()
    for _ = 1, 60 do
        local out = {}
        for ch in Config.PlateFormat:gmatch('.') do
            if ch == '1' then
                out[#out + 1] = tostring(math.random(0, 9))
            elseif ch == 'A' then
                local i = math.random(1, #LETTERS)
                out[#out + 1] = LETTERS:sub(i, i)
            else
                out[#out + 1] = ch
            end
        end
        local plate = table.concat(out):sub(1, 8)
        if not Vehicles.exists(plate) then return plate end
    end
    return nil
end

function Vehicles.add(cid, license, model, opts)
    opts = opts or {}
    if type(model) ~= 'string' or model == '' then return nil, 'bad_model' end
    local plate = GU.plate(opts.plate) or Vehicles.generatePlate()
    if not plate then return nil, 'no_plate' end
    if Vehicles.exists(plate) then return nil, 'plate_taken' end
    local hash = joaat(model)
    local mods = type(opts.props) == 'table' and opts.props or {}
    mods.model = hash
    mods.plate = plate
    local garage = opts.garage or Config.DefaultGarage
    local state = opts.state or 1
    local id = MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state, fleet) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { license, cid, model, tostring(hash), json.encode(mods), plate, garage, 100, 1000, 1000, state, opts.fleet })
    if not id then return nil, 'failed' end
    TriggerEvent('vr-garages:server:ownerChanged', plate, cid)
    return plate
end

function Vehicles.platesOf(veh)
    local a = GU.plate(GetVehicleNumberPlateText(veh))
    local ok, bag = pcall(function() return Entity(veh).state.vr_plate end)
    local b = ok and GU.plate(bag) or nil
    if b == a then b = nil end
    return a, b
end

function Vehicles.hasPlate(veh, plate)
    if not plate then return false end
    local a, b = Vehicles.platesOf(veh)
    return a == plate or b == plate
end

function Vehicles.entity(plate)
    plate = GU.plate(plate)
    if not plate then return nil end
    local s = Vehicles.spawned[plate]
    if s and DoesEntityExist(s.entity) and Vehicles.hasPlate(s.entity, plate) then return s.entity end
    Vehicles.spawned[plate] = nil
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and Vehicles.hasPlate(veh, plate) then
            Vehicles.spawned[plate] = { entity = veh }
            return veh
        end
    end
    return nil
end

function Vehicles.status(row)
    if Core.bankHeld(row.plate) then return 'held' end
    if row.state == 0 and Vehicles.entity(row.plate) then return 'out' end
    if Core.bankFlagged(row.plate) then return 'held' end
    if row.state == 2 then return 'impounded' end
    if row.state == 0 then return 'lost' end
    return 'stored'
end

function Vehicles.view(row, info, def)
    local status = Vehicles.status(row)
    local category = GU.categoryOfType(Core.vehicleType(row.vehicle))
    local garageDef = row.garage and Garages.get(row.garage)
    local v = {
        plate = row.plate,
        model = row.vehicle,
        label = Core.vehicleLabel(row.vehicle),
        nickname = row.nickname,
        category = category,
        status = status,
        garage = row.garage,
        garageLabel = garageDef and garageDef.label or (row.garage and row.garage:match('^house:') and 'House garage') or row.garage,
        here = def ~= nil and row.garage == def.id,
        fuel = math.floor(row.fuel),
        engine = math.floor(row.engine / 10),
        body = math.floor(row.body / 10),
        mileage = row.drivingdistance,
        mine = info ~= nil and row.citizenid == info.cid,
    }
    if status == 'impounded' or status == 'held' then
        v.impound = {
            reason = row.impound_reason,
            fee = row.depotprice,
            readyAt = row.impound_until,
            by = row.impound_by,
            at = row.impound_at,
        }
        if status == 'held' and not Core.bankHeld(row.plate) then
            v.impound = { reason = 'Flagged for repossession. The bank tracker is on.', by = 'ValRavn Bank' }
        end
    end
    return v
end
