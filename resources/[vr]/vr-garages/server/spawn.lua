Spawn = {}

local busy = {}

local function clear(spot, radius)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - vec3(spot.x, spot.y, spot.z)) < radius then return false end
    end
    return true
end

function Spawn.findSpot(def, fallback)
    for _, s in ipairs(def.spawns) do
        if clear(s, 3.0) then return s end
    end
    if type(fallback) == 'table' and tonumber(fallback.x) and tonumber(fallback.y) and tonumber(fallback.z) then
        local f = vec4(fallback.x + 0.0, fallback.y + 0.0, fallback.z + 0.0, (tonumber(fallback.w) or 0) + 0.0)
        if #(vec3(f.x, f.y, f.z) - def.center) <= def.radius + 40.0 and clear(f, 3.0) then return f end
    end
    return nil
end

function Spawn.lock(plate)
    if busy[plate] then return false end
    busy[plate] = true
    return true
end

function Spawn.unlock(plate)
    busy[plate] = nil
end

function Spawn.create(src, row, spot)
    local hash = joaat(row.vehicle)
    local veh = CreateVehicleServerSetter(hash, Core.vehicleType(row.vehicle), spot.x, spot.y, spot.z, spot.w)
    local deadline = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(25) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    SetVehicleNumberPlateText(veh, row.plate)
    local props = type(row.mods) == 'table' and row.mods or {}
    props.plate = row.plate
    props.model = hash
    props.fuelLevel = row.fuel + 0.0
    props.engineHealth = row.engine + 0.0
    props.bodyHealth = row.body + 0.0
    local state = Entity(veh).state
    state:set('vr_lib:vehicleProperties', props, true)
    state:set('vr_plate', row.plate, true)
    state:set('vr_owner', row.citizenid, true)
    state:set('vr_mileage', row.drivingdistance or 0, true)
    if type(row.status) == 'table' then state:set('vr_status', row.status, true) end
    Vehicles.spawned[row.plate] = { entity = veh, src = src, at = os.time() }
    TriggerClientEvent('vr-garages:client:spawned', src, NetworkGetNetworkIdFromEntity(veh), {
        plate = row.plate, fuel = row.fuel, engine = row.engine, body = row.body, warp = Config.WarpIntoVehicle,
    })
    TriggerEvent('vr-garages:server:vehicleOut', row.plate, row.citizenid, src)
    return veh
end

local function colourOf(v)
    if type(v) == 'number' then return math.floor(v) end
    return nil
end

function Spawn.park(row, spot)
    local hash = joaat(row.vehicle)
    local veh = CreateVehicleServerSetter(hash, Core.vehicleType(row.vehicle), spot.x, spot.y, spot.z, spot.w)
    local deadline = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(25) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    SetVehicleNumberPlateText(veh, row.plate)
    SetEntityOrphanMode(veh, 2)
    SetVehicleDoorsLocked(veh, 2)
    local props = type(row.mods) == 'table' and row.mods or {}
    props.plate = row.plate
    props.model = hash
    props.fuelLevel = row.fuel + 0.0
    props.engineHealth = row.engine + 0.0
    props.bodyHealth = row.body + 0.0
    local c1, c2 = colourOf(props.color1), colourOf(props.color2)
    if c1 and c2 then SetVehicleColours(veh, c1, c2) end
    local state = Entity(veh).state
    state:set('vr_lib:vehicleProperties', props, true)
    state:set('vr_plate', row.plate, true)
    state:set('vr_owner', row.citizenid, true)
    state:set('vr_mileage', row.drivingdistance or 0, true)
    state:set('fuel', row.fuel + 0.0, true)
    if type(row.status) == 'table' then state:set('vr_status', row.status, true) end
    Vehicles.spawned[row.plate] = { entity = veh, at = os.time() }
    TriggerEvent('vr-garages:server:vehicleOut', row.plate, row.citizenid, nil)
    return veh
end

function Spawn.release(src, row, def, fallback, extra)
    local spot = Spawn.findSpot(def, fallback)
    if not spot then return false, 'no_space' end
    local fields = { state = 0 }
    for k, v in pairs(extra or {}) do fields[k] = v end
    Vehicles.update(row.plate, fields)
    local veh = Spawn.create(src, row, spot)
    if not veh then
        Vehicles.update(row.plate, { state = row.state, garage = row.garage })
        return false, 'spawn_failed'
    end
    return true, NetworkGetNetworkIdFromEntity(veh)
end

local function clamp(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end

function Spawn.readCondition(veh, row, data)
    local fields = {}
    local props = type(data.props) == 'table' and data.props or nil
    if props and GU.plate(props.plate) == row.plate and tonumber(props.model) == joaat(row.vehicle) then
        local ok, encoded = pcall(json.encode, props)
        if ok and #encoded < 60000 then fields.mods = props end
    end
    fields.fuel = math.floor(clamp(data.fuel, 0, 100, row.fuel))
    fields.engine = clamp(data.engine, 0, 1000, row.engine)
    fields.body = clamp(data.body, 0, 1000, row.body)
    if veh then
        local st = Entity(veh).state
        local miles = tonumber(st.vr_mileage)
        if miles and miles >= row.drivingdistance then fields.drivingdistance = math.floor(miles) end
        if type(st.vr_status) == 'table' then fields.status = st.vr_status end
    end
    return fields
end

function Spawn.occupied(veh, includeDriver)
    for seat = includeDriver and -1 or 0, 14 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 then return true end
    end
    return false
end
