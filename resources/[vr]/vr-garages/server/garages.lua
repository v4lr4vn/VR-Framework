Garages = { list = {} }

local TYPES = { public = true, job = true, gang = true, impound = true }
local CATEGORIES = { car = true, air = true, boat = true, all = true }
local custom = {}
local houseCache = {}

local function v3(c)
    if not c then return nil end
    return vec3((c.x or c[1] or 0) + 0.0, (c.y or c[2] or 0) + 0.0, (c.z or c[3] or 0) + 0.0)
end

local function v4(c)
    if not c then return nil end
    return vec4((c.x or c[1] or 0) + 0.0, (c.y or c[2] or 0) + 0.0, (c.z or c[3] or 0) + 0.0, (c.w or c[4] or c.h or 0) + 0.0)
end

local function extrasList(e)
    if type(e) ~= 'table' then return nil end
    local out = {}
    for k, on in pairs(e) do
        local id, state
        if type(on) == 'table' then
            id, state = tonumber(on.id), on.on == true
        else
            id, state = tonumber(k), on == true
        end
        if id and id >= 0 and id <= 20 then out[#out + 1] = { id = math.floor(id), on = state } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return #out > 0 and out or nil
end

local function colours(c)
    if type(c) ~= 'table' then return nil end
    local a, b = tonumber(c[1] or c.primary), tonumber(c[2] or c.secondary)
    if not a then return nil end
    return { math.floor(a), math.floor(b or a) }
end

local function vehicleList(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, v in ipairs(list) do
        if type(v) == 'table' and type(v.model) == 'string' and v.model ~= '' then
            out[#out + 1] = {
                model = v.model,
                label = type(v.label) == 'string' and v.label ~= '' and v.label or nil,
                grade = math.max(0, math.floor(tonumber(v.grade or v.minGrade) or 0)),
                plate = type(v.plate) == 'string' and v.plate or nil,
                livery = tonumber(v.livery) and math.floor(tonumber(v.livery)) or nil,
                extras = extrasList(v.extras),
                colours = colours(v.colours or v.colors),
                mods = type(v.mods) == 'table' and v.mods or nil,
                maxMods = v.maxMods == true,
                fuel = tonumber(v.fuel),
            }
        end
    end
    return out
end

local function pedOf(p)
    if type(p) ~= 'table' or type(p.model) ~= 'string' then return nil end
    local c = p.coords or p
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not x or not y or not z then return nil end
    return { model = p.model, x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (tonumber(c.w or c[4] or c.h or p.heading) or 0) + 0.0 }
end

local function normalise(id, g)
    if type(g) ~= 'table' or not g.center then return nil end
    local spawns = {}
    for i, s in ipairs(g.spawns or {}) do spawns[i] = v4(s) end
    local kind = TYPES[g.type] and g.type or 'public'
    return {
        id = id,
        label = tostring(g.label or id),
        type = kind,
        category = CATEGORIES[g.category] and g.category or 'car',
        group = (kind == 'job' or kind == 'gang') and g.group or nil,
        requireDuty = g.requireDuty == true,
        center = v3(g.center),
        radius = (tonumber(g.radius) or Config.ZoneRadius) + 0.0,
        spawns = spawns,
        blip = g.blip ~= false,
        custom = g.custom == true,
        vehicles = (kind == 'job' or kind == 'gang') and vehicleList(g.vehicles) or {},
        ped = pedOf(g.ped),
        setupMenu = g.setupMenu == true,
    }
end

local function plain(def)
    local spawns = {}
    for i, s in ipairs(def.spawns) do spawns[i] = { x = s.x, y = s.y, z = s.z, w = s.w } end
    return {
        id = def.id, label = def.label, type = def.type, category = def.category, group = def.group, requireDuty = def.requireDuty,
        center = { x = def.center.x, y = def.center.y, z = def.center.z }, radius = def.radius, spawns = spawns, blip = def.blip,
        ped = def.ped, setupMenu = def.setupMenu, jobVehicles = #(def.vehicles or {}),
    }
end

function Garages.publish()
    local out = {}
    for id, def in pairs(Garages.list) do out[id] = plain(def) end
    GlobalState.vrGarages = out
end

local fromConfig = {}

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then
        if type(a) == 'number' then return math.abs(a - b) < 0.0001 end
        return a == b
    end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function Garages.rebuild()
    local list = {}
    fromConfig = {}
    for id, g in pairs(Config.Garages) do
        local def = normalise(id, g)
        if def then
            list[id] = def
            fromConfig[id] = def
        end
    end
    for id, data in pairs(custom) do
        if data.deleted then
            list[id] = nil
        else
            local def = normalise(id, data)
            if def then
                def.custom = true
                local base = list[id]
                if base then
                    if data.vehicles == nil and (def.type == 'job' or def.type == 'gang') then def.vehicles = base.vehicles end
                    if data.ped == nil then def.ped = base.ped end
                    if data.setupMenu == nil then def.setupMenu = base.setupMenu end
                end
                list[id] = def
            end
        end
    end
    Garages.list = list
    Garages.publish()
end

function Garages.load()
    local rows = MySQL.query.await('SELECT id, data FROM vr_garage_locations') or {}
    for i = 1, #rows do
        local ok, data = pcall(json.decode, rows[i].data)
        if ok and type(data) == 'table' then custom[rows[i].id] = data end
    end
    Garages.rebuild()
end

function Garages.store(id, def)
    local data = def and plain(def) or { deleted = true }
    if def then
        data.custom = true
        data.jobVehicles = nil
        data.vehicles = def.vehicles or {}
        data.ped = def.ped or false
        data.setupMenu = def.setupMenu == true
        local base = fromConfig[id]
        if base then
            if same(data.vehicles, base.vehicles or {}) then data.vehicles = nil end
            if same(def.ped, base.ped) then data.ped = nil end
            if data.setupMenu == (base.setupMenu == true) then data.setupMenu = nil end
        end
    end
    custom[id] = data
    MySQL.query.await('INSERT INTO vr_garage_locations (id, data, updated) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated = VALUES(updated)', { id, json.encode(data), os.time() })
    Garages.rebuild()
end

function Garages.reset(id)
    if not fromConfig[id] and not (custom[id] and custom[id].deleted) then return false end
    custom[id] = nil
    MySQL.query.await('DELETE FROM vr_garage_locations WHERE id = ?', { id })
    Garages.rebuild()
    return true
end

function Garages.source(id)
    if fromConfig[id] and custom[id] then return 'edited' end
    if fromConfig[id] then return 'config' end
    return 'built'
end

function Garages.removedConfig()
    local out = {}
    for id, data in pairs(custom) do
        if data.deleted then
            local g = Config.Garages[id]
            if g then out[#out + 1] = normalise(id, g) end
        end
    end
    return out
end

function Garages.serialise(def)
    local spawns = {}
    for i, sp in ipairs(def.spawns) do spawns[i] = { x = sp.x, y = sp.y, z = sp.z, w = sp.w } end
    local vehicles = {}
    for i, v in ipairs(def.vehicles or {}) do
        vehicles[i] = {
            model = v.model, label = v.label, grade = v.grade, plate = v.plate, livery = v.livery, extras = v.extras,
            colours = v.colours, mods = v.mods, maxMods = v.maxMods, fuel = v.fuel,
        }
    end
    return {
        id = def.id, label = def.label, type = def.type, category = def.category, group = def.group, requireDuty = def.requireDuty,
        center = { x = def.center.x, y = def.center.y, z = def.center.z }, radius = def.radius, spawns = spawns, blip = def.blip,
        ped = def.ped, setupMenu = def.setupMenu, vehicles = vehicles,
    }
end

local function text(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:sub(1, max)
end

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if lo and v < lo then return nil end
    if hi and v > hi then return nil end
    return v
end

local function point(c, heading)
    if type(c) ~= 'table' then return nil end
    local x, y, z = num(c.x, -10000, 10000), num(c.y, -10000, 10000), num(c.z, -500, 3000)
    if not x or not y or not z then return nil end
    local out = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
    if heading then out.w = ((num(c.w, -720, 720) or 0) % 360) + 0.0 end
    return out
end

function Garages.fromInput(id, d)
    if type(d) ~= 'table' then return nil, 'bad_data' end
    if type(id) ~= 'string' or not id:match('^[%w_]+$') or #id < 2 or #id > 40 or id:match('^house') then return nil, 'bad_id' end
    local kind = TYPES[d.type] and d.type or nil
    if not kind then return nil, 'bad_type' end
    local group
    if kind == 'job' or kind == 'gang' then
        group = text(d.group, 50)
        if not group or not group:match('^[%w_%-]+$') then return nil, 'need_group' end
        local list = kind == 'gang' and Bridge.gangs() or Bridge.jobs()
        if next(list) and not list[group] then return nil, 'unknown_group' end
    end
    local center = point(d.center, false)
    if not center then return nil, 'need_center' end
    local spawns = {}
    for _, sp in ipairs(type(d.spawns) == 'table' and d.spawns or {}) do
        local p = point(sp, true)
        if p and #spawns < 24 then spawns[#spawns + 1] = p end
    end
    local ped
    if type(d.ped) == 'table' then
        local model = text(d.ped.model, 40)
        local p = point(d.ped, true)
        if model and model:match('^[%w_]+$') and p then
            p.model = model
            ped = p
        end
    end
    local vehicles = {}
    if kind == 'job' or kind == 'gang' then
        for _, v in ipairs(type(d.vehicles) == 'table' and d.vehicles or {}) do
            local model = type(v) == 'table' and text(v.model, 40)
            if model and model:match('^[%w_]+$') and #vehicles < 60 then
                local plate = text(v.plate, 8)
                plate = plate and plate:upper():gsub('[^%w ]', '') or nil
                local c1, c2 = type(v.colours) == 'table' and num(v.colours[1], 0, 255), type(v.colours) == 'table' and num(v.colours[2], 0, 255)
                vehicles[#vehicles + 1] = {
                    model = model:lower(),
                    label = text(v.label, 40),
                    grade = math.floor(num(v.grade, 0, 100) or 0),
                    plate = plate ~= '' and plate or nil,
                    livery = num(v.livery, 0, 100) and math.floor(num(v.livery, 0, 100)) or nil,
                    extras = v.extras,
                    colours = c1 and { math.floor(c1), math.floor(c2 or c1) } or nil,
                    mods = type(v.mods) == 'table' and v.mods or nil,
                    maxMods = v.maxMods == true,
                    fuel = num(v.fuel, 0, 100),
                }
            end
        end
    end
    local def = normalise(id, {
        label = text(d.label, 40) or id,
        type = kind,
        category = CATEGORIES[d.category] and d.category or (kind == 'impound' and 'all' or 'car'),
        group = group,
        requireDuty = kind == 'job' and d.requireDuty == true,
        center = center,
        radius = math.max(3, math.min(80, num(d.radius) or Config.ZoneRadius)),
        spawns = spawns,
        blip = d.blip ~= false,
        vehicles = vehicles,
        ped = ped,
        setupMenu = (kind == 'job' or kind == 'gang') and d.setupMenu == true,
    })
    if not def then return nil, 'bad_data' end
    return def
end

function Garages.raw(id)
    return Garages.list[id]
end

local function houseRow(propertyId)
    local cached = houseCache[propertyId]
    if cached and cached.at > GetGameTimer() - 30000 then return cached.row end
    local row
    if Db.properties then
        row = MySQL.single.await('SELECT property_id, owner_citizenid, has_access, garage_data, street FROM properties WHERE property_id = ?', { tonumber(propertyId) })
    end
    houseCache[propertyId] = { at = GetGameTimer(), row = row }
    return row
end

function Garages.forgetHouse(propertyId)
    houseCache[tostring(propertyId)] = nil
end

local function decode(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local ok, v = pcall(json.decode, s)
    return ok and v or nil
end

function Garages.get(id)
    if type(id) ~= 'string' then return nil end
    local houseId = id:match('^house:(%d+)$')
    if not houseId then return Garages.list[GU.resolveGarage(id)] end
    local row = houseRow(houseId)
    local g = row and decode(row.garage_data)
    if type(g) ~= 'table' or not g.x then return nil end
    local access = {}
    if row.owner_citizenid then access[row.owner_citizenid] = true end
    for _, cid in ipairs(decode(row.has_access) or {}) do access[cid] = true end
    return {
        id = id,
        label = ('%s %s garage'):format(row.street or 'House', houseId),
        type = 'house',
        category = 'car',
        center = vec3(g.x + 0.0, g.y + 0.0, g.z + 0.0),
        radius = Config.HouseGarageRadius,
        spawns = { vec4(g.x + 0.0, g.y + 0.0, g.z + 0.0, (g.h or g.w or 0) + 0.0) },
        access = access,
    }
end

function Garages.groupKey(def)
    if def.type == 'job' or def.type == 'gang' then return def.type .. ':' .. def.group end
    return nil
end

function Garages.member(info, kind, name)
    local group = kind == 'gang' and info.gang or info.job
    return group ~= nil and group.name == name
end

function Garages.access(def, info)
    if not def or not info then return false end
    if def.type == 'public' or def.type == 'impound' then return true end
    if def.type == 'house' then return def.access[info.cid] == true end
    if def.type == 'job' then
        if not Garages.member(info, 'job', def.group) then return false end
        return not def.requireDuty or info.job.onduty
    end
    if def.type == 'gang' then return Garages.member(info, 'gang', def.group) end
    return false
end

function Garages.near(def, src, extra)
    local pos = Core.coords(src)
    return pos ~= nil and #(pos - def.center) <= def.radius + (extra or 6.0)
end

function Garages.categoryOk(def, category)
    return def.category == 'all' or def.category == category
end

function Garages.groupLabel(def)
    if def.type == 'job' or def.type == 'gang' then return Core.groupLabel(def.type, def.group) end
    return nil
end
