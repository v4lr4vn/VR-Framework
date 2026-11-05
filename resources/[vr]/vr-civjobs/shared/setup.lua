Setup = { jobs = {}, raw = {} }

local function clone(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = clone(x) end
    return out
end

Setup.clone = clone

local function dig(root, path, create)
    local t = root
    for i = 1, #path - 1 do
        local k = path[i]
        if type(t[k]) ~= 'table' then
            if not create then return nil end
            t[k] = {}
        end
        t = t[k]
    end
    return t, path[#path]
end

function Setup.read(job, path)
    local root = Config.Jobs[job]
    if not root then return nil end
    local t, k = dig(root, path)
    if not t then return nil end
    return t[k]
end

function Setup.write(job, path, value)
    local root = Config.Jobs[job]
    if not root then return false end
    local t, k = dig(root, path, true)
    t[k] = value
    return true
end

local function pathKey(path)
    local parts = {}
    for i, p in ipairs(path) do parts[i] = tostring(p) end
    return table.concat(parts, '.')
end

local DEPOT = { id = 'depot', label = 'Clerk and board', kind = 'vec4', path = { 'depot', 'coords' }, hint = 'Stand where the clerk should stand, facing the way they should face' }

local function add(job, f)
    local list = Setup.jobs[job] or {}
    Setup.jobs[job] = list
    f.job = job
    f.pathKey = pathKey(f.path)
    list[#list + 1] = f
end

local function depot(job) add(job, clone(DEPOT)) end

local function spawn(job, label)
    add(job, { id = 'spawn', label = label or 'Vehicle spawn', kind = 'vec4', path = { 'vehicle', 'coords' }, hint = 'Stand where the work vehicle should appear, facing the way it should point' })
end

local function returnRadius(job)
    add(job, { id = 'returnRadius', label = 'Hand-in radius', kind = 'number', path = { 'vehicle', 'returnRadius' }, min = 10, max = 120, hint = 'How close to the depot the vehicle must be to hand it back' })
end

depot('garbage')
spawn('garbage')
returnRadius('garbage')
add('garbage', { id = 'stopRadius', label = 'Pick-up radius', kind = 'number', path = { 'stopRadius' }, min = 8, max = 80, hint = 'Bags inside this circle count at each stop' })
add('garbage', { id = 'stops', label = 'Stops', kind = 'list', path = { 'stops' }, item = { pos = 'vec3' }, min = 4, max = 60, hint = 'Stand in the middle of a street with bags and add it. Every bin bag within the pick-up radius can be collected' })

depot('lumberjack')
spawn('lumberjack')
returnRadius('lumberjack')
add('lumberjack', { id = 'sawmill', label = 'Sawmill drop-off', kind = 'vec3', path = { 'sawmill' }, hint = 'Where the logs are sold' })
add('lumberjack', { id = 'sawmillRadius', label = 'Sawmill radius', kind = 'number', path = { 'sawmillRadius' }, min = 6, max = 60 })
add('lumberjack', { id = 'forests', label = 'Forests', kind = 'list', path = { 'forests' }, item = { pos = 'area', ckey = 'center', rkey = 'radius', defaultR = 80.0 }, min = 0, max = 20, hint = 'Optional. Add circles to limit felling to those areas. With none, any tree can be felled' })

depot('scrapyard')
add('scrapyard', { id = 'bays', label = 'Wreck bays', kind = 'list', path = { 'bays' }, item = { pos = 'vec4' }, min = 1, max = 12, hint = 'Where a wreck is placed. Stand on the spot facing along the car' })
add('scrapyard', { id = 'bin1', label = 'Metal bin', kind = 'vec3', path = { 'bins', 1, 'coords' } })
add('scrapyard', { id = 'bin2', label = 'Rubber bin', kind = 'vec3', path = { 'bins', 2, 'coords' } })
add('scrapyard', { id = 'crusher', label = 'Crusher', kind = 'vec3', path = { 'crusher' } })
add('scrapyard', { id = 'buyer', label = 'Scrap buyer', kind = 'vec3', path = { 'buyer' } })

depot('windowcleaner')
spawn('windowcleaner')
returnRadius('windowcleaner')
add('windowcleaner', {
    id = 'sites', label = 'Buildings', kind = 'list', path = { 'sites' }, min = 1, max = 20,
    item = {
        pos = 'vec3', ckey = 'center', headingKey = 'heading',
        extra = {
            { key = 'label', label = 'Name', type = 'text', default = 'New building' },
            { key = 'cols', label = 'Windows across', type = 'number', min = 1, max = 10, default = 5 },
            { key = 'rows', label = 'Floors', type = 'number', min = 1, max = 4, default = 2 },
            { key = 'spacing', label = 'Gap between windows', type = 'number', min = 0.8, max = 4, default = 1.8 },
            { key = 'stepZ', label = 'Floor height', type = 'number', min = 0.8, max = 4, default = 1.5 },
        },
    },
    hint = 'Stand in the middle of the front, facing the glass. Windows are spread left and right of you',
})

depot('builder')
add('builder', { id = 'anchor', label = 'Building site', kind = 'vec3', path = { 'sites', 1, 'tasks', 1, 'from' }, custom = 'anchor', hint = 'Move the whole site. Stand where the first pile of materials should be; every task moves with it' })

depot('trucker')
spawn('trucker', 'Cab spawn')
add('trucker', { id = 'returnRadius', label = 'Hand-in radius', kind = 'number', path = { 'vehicle', 'returnRadius' }, min = 10, max = 120 })
do
    local contracts = Config.Jobs.trucker and Config.Jobs.trucker.contracts or {}
    for i, c in ipairs(contracts) do
        add('trucker', { id = 'to' .. i, label = 'Delivery: ' .. c.label, kind = 'vec3', path = { 'contracts', i, 'to' }, hint = 'Stand where the trailer should be dropped' })
    end
end

depot('taxi')
spawn('taxi', 'Cab spawn')
returnRadius('taxi')
add('taxi', { id = 'spots', label = 'Fare spots', kind = 'list', path = { 'spots' }, item = { pos = 'vec3' }, min = 6, max = 60, hint = 'Pavements where passengers wait or ask to be dropped. Stand on the pavement beside a road' })

depot('busdriver')
spawn('busdriver', 'Bus spawn')
returnRadius('busdriver')
do
    local routes = Config.Jobs.busdriver and Config.Jobs.busdriver.routes or {}
    for i, r in ipairs(routes) do
        add('busdriver', {
            id = 'route' .. i, label = 'Route: ' .. r.label, kind = 'list', path = { 'routes', i, 'stops' }, min = 2, max = 20,
            item = { pos = 'vec3', ckey = 'coords', extra = { { key = 'label', label = 'Stop name', type = 'text', default = 'Bus stop' } } },
            hint = 'Stops in order. Stand where the bus should halt, in the road beside the stop',
        })
    end
end

depot('newspaper')
spawn('newspaper', 'Bike spawn')
returnRadius('newspaper')
do
    local routes = Config.Jobs.newspaper and Config.Jobs.newspaper.routes or {}
    for i, r in ipairs(routes) do
        add('newspaper', { id = 'route' .. i, label = 'Route: ' .. r.label, kind = 'list', path = { 'routes', i, 'stops' }, item = { pos = 'vec3' }, min = 3, max = 20, hint = 'Houses in order. Stand by the front gate or mailbox' })
    end
end

depot('hunter')
add('hunter', { id = 'zones', label = 'Hunting grounds', kind = 'list', path = { 'zones' }, min = 1, max = 12, item = { pos = 'area', ckey = 'center', rkey = 'radius', defaultR = 200.0, extra = { { key = 'label', label = 'Name', type = 'text', default = 'Hunting ground' } } }, hint = 'Stand in the woods and add a circle. Animals only appear inside circles, and skinning only works inside them' })

depot('fisherman')
add('fisherman', { id = 'spots', label = 'Fishing spots', kind = 'list', path = { 'spots' }, min = 1, max = 20, item = { pos = 'area', ckey = 'center', rkey = 'radius', defaultR = 60.0, extra = { { key = 'label', label = 'Name', type = 'text', default = 'Fishing spot' }, { key = 'water', label = 'Water', type = 'choice', options = { 'ocean', 'lake', 'river' }, default = 'ocean' } } }, hint = 'Stand on the bank or pier and add a circle covering where players can stand and cast' })

depot('treasurehunter')
add('treasurehunter', { id = 'boat', label = 'Dive boat spawn', kind = 'vec4', path = { 'boat', 'coords' }, hint = 'Stand in shallow water where the boat should appear' })
add('treasurehunter', { id = 'beaches', label = 'Detector zones', kind = 'list', path = { 'detector', 'zones' }, min = 1, max = 12, item = { pos = 'area', ckey = 'center', rkey = 'radius', defaultR = 120.0, extra = { { key = 'label', label = 'Name', type = 'text', default = 'Beach' } } }, hint = 'Stand on sand and add a circle. Buried finds appear inside it' })
add('treasurehunter', { id = 'wrecks', label = 'Dive sites', kind = 'list', path = { 'dive', 'sites' }, min = 1, max = 12, item = { pos = 'area', ckey = 'coords', rkey = 'radius', defaultR = 60.0, extra = { { key = 'label', label = 'Name', type = 'text', default = 'Wreck' } } }, hint = 'Dive down to the sea floor and add a site there. Chests appear around it' })

local function toJsonItem(f, item)
    local spec = f.item
    local out = {}
    if not spec.ckey then
        out.x, out.y, out.z = item.x + 0.0, item.y + 0.0, item.z + 0.0
        if spec.pos == 'vec4' then out.w = (item.w or 0.0) + 0.0 end
        return out
    end
    local c = item[spec.ckey]
    out.x, out.y, out.z = c.x + 0.0, c.y + 0.0, c.z + 0.0
    if spec.pos == 'vec4' then out.w = (c.w or 0.0) + 0.0 end
    if spec.rkey then out.r = (item[spec.rkey] or spec.defaultR or 50.0) + 0.0 end
    if spec.headingKey then out.heading = (item[spec.headingKey] or 0.0) + 0.0 end
    for _, e in ipairs(spec.extra or {}) do out[e.key] = item[e.key] end
    return out
end

local function fromJsonItem(f, j, base)
    local spec = f.item
    if not spec.ckey then
        if spec.pos == 'vec4' then return vec4(j.x + 0.0, j.y + 0.0, j.z + 0.0, (j.w or 0.0) + 0.0) end
        return vec3(j.x + 0.0, j.y + 0.0, j.z + 0.0)
    end
    local item = base and clone(base) or {}
    if spec.pos == 'vec4' then
        item[spec.ckey] = vec4(j.x + 0.0, j.y + 0.0, j.z + 0.0, (j.w or 0.0) + 0.0)
    else
        item[spec.ckey] = vec3(j.x + 0.0, j.y + 0.0, j.z + 0.0)
    end
    if spec.rkey then item[spec.rkey] = (j.r or spec.defaultR or 50.0) + 0.0 end
    if spec.headingKey then item[spec.headingKey] = (j.heading or 0.0) + 0.0 end
    for _, e in ipairs(spec.extra or {}) do
        local v = j[e.key]
        if v == nil then v = item[e.key] end
        if v == nil then v = e.default end
        item[e.key] = v
    end
    return item
end

Setup.itemToJson, Setup.itemFromJson = toJsonItem, fromJsonItem

function Setup.field(job, id)
    for _, f in ipairs(Setup.jobs[job] or {}) do
        if f.id == id then return f end
    end
    return nil
end

local function vecJson(v, four)
    local out = { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 }
    if four then out.w = (v.w or 0.0) + 0.0 end
    return out
end

function Setup.value(f)
    local v = Setup.read(f.job, f.path)
    if v == nil then return nil end
    if f.kind == 'number' then return v + 0.0 end
    if f.kind == 'vec3' then return vecJson(v, false) end
    if f.kind == 'vec4' then return vecJson(v, true) end
    local out = {}
    for i, item in ipairs(v) do out[i] = toJsonItem(f, item) end
    return out
end

local function num(v) return type(v) == 'number' and v == v and v > -20000 and v < 20000 end

function Setup.valid(f, j)
    if f.kind == 'number' then
        return num(j) and j >= (f.min or -20000) and j <= (f.max or 20000)
    elseif f.kind == 'vec3' or f.kind == 'vec4' then
        return type(j) == 'table' and num(j.x) and num(j.y) and num(j.z) and (f.kind == 'vec3' or num(j.w))
    end
    if type(j) ~= 'table' or #j > (f.max or 40) or #j < (f.min or 0) then return false end
    for _, item in ipairs(j) do
        if type(item) ~= 'table' or not num(item.x) or not num(item.y) or not num(item.z) then return false end
        if f.item.pos == 'vec4' and not num(item.w) then return false end
        if f.item.rkey and not (num(item.r) and item.r >= 2.0 and item.r <= 1500.0) then return false end
        if f.item.headingKey and not num(item.heading) then return false end
        for _, e in ipairs(f.item.extra or {}) do
            local v = item[e.key]
            if e.type == 'number' then
                if not num(v) or v < (e.min or -20000) or v > (e.max or 20000) then return false end
            elseif e.type == 'choice' then
                local okc = false
                for _, o in ipairs(e.options) do if o == v then okc = true end end
                if not okc then return false end
            else
                if type(v) ~= 'string' or #v < 1 or #v > 40 then return false end
            end
        end
    end
    return true
end

local function builderShift(f, j)
    local raw = Setup.raw.builder and Setup.raw.builder.anchor
    if not raw then return end
    local first = raw.sites[1].tasks[1].from
    local d = vec3(j.x - first.x, j.y - first.y, j.z - first.z)
    local sites = clone(raw.sites)
    for _, site in ipairs(sites) do
        for _, t in ipairs(site.tasks) do
            for _, k in ipairs({ 'from', 'to', 'at' }) do
                if t[k] then t[k] = vec3(t[k].x + d.x, t[k].y + d.y, t[k].z + d.z) end
            end
        end
    end
    Config.Jobs.builder.sites = sites
end

function Setup.apply(job, id, j)
    local f = Setup.field(job, id)
    if not f or j == nil then return false end
    if f.custom == 'anchor' then
        builderShift(f, j)
        return true
    end
    if f.kind == 'number' then
        Setup.write(job, f.path, j + 0.0)
    elseif f.kind == 'vec3' then
        Setup.write(job, f.path, vec3(j.x + 0.0, j.y + 0.0, j.z + 0.0))
    elseif f.kind == 'vec4' then
        Setup.write(job, f.path, vec4(j.x + 0.0, j.y + 0.0, j.z + 0.0, j.w + 0.0))
    else
        local old = Setup.read(job, f.path) or {}
        local list = {}
        for i, item in ipairs(j) do list[i] = fromJsonItem(f, item, f.item.ckey and old[i] or nil) end
        Setup.write(job, f.path, list)
    end
    return true
end

function Setup.reset(job, id)
    local f = Setup.field(job, id)
    local raw = f and Setup.raw[job] and Setup.raw[job][id]
    if not f or raw == nil then return false end
    if f.custom == 'anchor' then
        Config.Jobs.builder.sites = clone(raw.sites)
        return true
    end
    Setup.write(job, f.path, clone(raw))
    return true
end

function Setup.applyAll(overrides)
    if type(overrides) ~= 'table' then return end
    for job, fields in pairs(overrides) do
        if type(fields) == 'table' then
            for id, j in pairs(fields) do
                local f = Setup.field(job, id)
                if f and Setup.valid(f, j) then Setup.apply(job, id, j) end
            end
        end
    end
end

for job, list in pairs(Setup.jobs) do
    Setup.raw[job] = {}
    for _, f in ipairs(list) do
        if f.custom == 'anchor' then
            Setup.raw[job][f.id] = { sites = clone(Config.Jobs[job].sites) }
        else
            Setup.raw[job][f.id] = clone(Setup.read(job, f.path))
        end
    end
end

function Setup.describe(job)
    local out = {}
    for _, f in ipairs(Setup.jobs[job] or {}) do
        local item
        if f.item then
            local extra = {}
            for _, e in ipairs(f.item.extra or {}) do extra[#extra + 1] = { key = e.key, label = e.label, type = e.type, options = e.options, min = e.min, max = e.max } end
            item = { pos = f.item.pos, radius = f.item.rkey ~= nil, defaultR = f.item.defaultR, heading = f.item.headingKey ~= nil, extra = extra }
        end
        out[#out + 1] = { id = f.id, label = f.label, kind = f.kind, hint = f.hint, min = f.min, max = f.max, item = item }
    end
    return out
end
