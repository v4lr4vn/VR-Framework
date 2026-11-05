JobVehicles = {}

local J = Config.JobVehicles or {}
local owners = {}
local DIGITS = '0123456789'

local function groupOf(info, def)
    return def.type == 'gang' and info.gang or info.job
end

function JobVehicles.tag(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local ok, t = pcall(function() return Entity(veh).state.vr_jobveh end)
    return ok and type(t) == 'table' and t or nil
end

local function mine(cid)
    local out = {}
    for _, veh in ipairs(GetAllVehicles()) do
        local t = JobVehicles.tag(veh)
        if t and t.cid == cid then out[#out + 1] = { veh = veh, at = tonumber(t.at) or 0 } end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

JobVehicles.mine = mine

local function inWorld(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and Vehicles.hasPlate(veh, plate) then return true end
    end
    return false
end

function JobVehicles.plate(prefix)
    prefix = type(prefix) == 'string' and prefix:upper():gsub('[^%w ]', '') or ''
    if #prefix >= 8 then return prefix:sub(1, 8) end
    for _ = 1, 40 do
        local out = { prefix }
        for _ = 1, 8 - #prefix do
            local i = math.random(1, #DIGITS)
            out[#out + 1] = DIGITS:sub(i, i)
        end
        local plate = table.concat(out)
        if not Vehicles.exists(plate) and not inWorld(plate) then return plate end
    end
    return nil
end

function JobVehicles.list(def, info)
    local out = {}
    if not def.vehicles or #def.vehicles == 0 then return out end
    local group = groupOf(info, def)
    local grade = group and tonumber(group.grade) or 0
    for i, v in ipairs(def.vehicles) do
        out[#out + 1] = {
            id = i,
            model = v.model,
            label = v.label or Core.vehicleLabel(v.model),
            name = Core.vehicleLabel(v.model),
            grade = v.grade,
            allowed = grade >= v.grade,
            category = GU.categoryOfType(Core.vehicleType(v.model)),
            plate = v.plate,
        }
    end
    return out
end

local function occupied(veh)
    return Spawn.occupied(veh, true)
end

local function makeRoom(cid)
    local limit = math.floor(tonumber(J.limit) or 1)
    if limit <= 0 then return true end
    local out = mine(cid)
    if #out < limit then return true end
    if J.returnOtherWhenFull == false then return false end
    for _, e in ipairs(out) do
        if not occupied(e.veh) then
            DeleteEntity(e.veh)
            return true, true
        end
    end
    return false
end

local function props(v, plate, hash, fuel)
    local p = {}
    for k, val in pairs(v.mods or {}) do p[k] = val end
    p.plate = plate
    p.model = hash
    p.fuelLevel = fuel
    p.engineHealth = 1000.0
    p.bodyHealth = 1000.0
    if v.colours then
        p.color1 = v.colours[1]
        p.color2 = v.colours[2]
    end
    return p
end

function JobVehicles.take(info, def, index, fallback)
    if def.type ~= 'job' and def.type ~= 'gang' then return false, 'no_access' end
    local v = def.vehicles and def.vehicles[math.floor(tonumber(index) or 0)]
    if not v then return false, 'no_vehicle' end
    local group = groupOf(info, def)
    if not group or (tonumber(group.grade) or 0) < v.grade then return false, 'low_grade' end
    local room, sentBack = makeRoom(info.cid)
    if not room then return false, 'limit' end
    local spot = Spawn.findSpot(def, fallback)
    if not spot then return false, 'no_space' end
    local plate = JobVehicles.plate(v.plate)
    if not plate then return false, 'spawn_failed' end
    local hash = joaat(v.model)
    local veh = CreateVehicleServerSetter(hash, Core.vehicleType(v.model), spot.x, spot.y, spot.z, spot.w)
    local deadline = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(25) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'spawn_failed' end
    SetVehicleNumberPlateText(veh, plate)
    local fuel = (tonumber(v.fuel) or tonumber(J.fuel) or 100.0) + 0.0
    local state = Entity(veh).state
    state:set('vr_lib:vehicleProperties', props(v, plate, hash, fuel), true)
    state:set('vr_plate', plate, true)
    state:set('fuel', fuel, true)
    state:set('vr_jobveh', { group = Garages.groupKey(def), cid = info.cid, garage = def.id, model = v.model, at = os.time() }, true)
    owners[info.src] = info.cid
    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerClientEvent('vr-garages:client:spawned', info.src, netId, {
        plate = plate, fuel = fuel, engine = 1000.0, body = 1000.0, warp = Config.WarpIntoVehicle,
        job = { livery = v.livery, extras = v.extras, maxMods = v.maxMods, menu = def.setupMenu == true, label = v.label or Core.vehicleLabel(v.model) },
    })
    TriggerEvent('vr-garages:server:jobVehicleOut', plate, info.cid, Garages.groupKey(def), v.model, info.src)
    return true, { netId = netId, plate = plate, sentBack = sentBack == true }
end

function JobVehicles.store(info, def, veh, tag)
    if def.type ~= 'job' and def.type ~= 'gang' then return false, 'job_garage' end
    if tag.group ~= Garages.groupKey(def) then return false, 'job_garage' end
    if #(GetEntityCoords(veh) - def.center) > def.radius + 4.0 then return false, 'too_far' end
    if Spawn.occupied(veh, false) then return false, 'passengers' end
    local plate = GU.plate(GetVehicleNumberPlateText(veh)) or GU.plate(Entity(veh).state.vr_plate)
    FreezeEntityPosition(veh, true)
    SetTimeout(1800, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end)
    TriggerEvent('vr-garages:server:jobVehicleReturned', plate, tag.cid, tag.group, info.cid)
    return true, { plate = plate, job = true }
end

AddEventHandler('playerDropped', function()
    local src = source
    local cid = owners[src]
    owners[src] = nil
    if not cid or J.removeOnLeave == false then return end
    for _, e in ipairs(mine(cid)) do
        if not occupied(e.veh) then DeleteEntity(e.veh) end
    end
end)
