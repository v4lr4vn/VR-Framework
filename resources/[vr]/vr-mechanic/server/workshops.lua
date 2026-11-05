Workshops = { list = {} }

local custom = {}

local function v3(c) return c and vec3((c.x or c[1] or 0) + 0.0, (c.y or c[2] or 0) + 0.0, (c.z or c[3] or 0) + 0.0) or nil end

local function build(id, base, over)
    local w = { id = id }
    for k, v in pairs(base) do w[k] = v end
    for k, v in pairs(over or {}) do w[k] = v end
    w.center = v3(w.center)
    w.counter = v3(w.counter)
    w.radius = (tonumber(w.radius) or 15.0) + 0.0
    w.job = w.job or 'mechanic'
    return w
end

local function plain(w)
    return {
        id = w.id, label = w.label, job = w.job, radius = w.radius,
        center = { x = w.center.x, y = w.center.y, z = w.center.z },
        counter = w.counter and { x = w.counter.x, y = w.counter.y, z = w.counter.z } or nil,
    }
end

function Workshops.publish()
    local out = {}
    for id, w in pairs(Workshops.list) do out[id] = plain(w) end
    GlobalState.vrWorkshops = out
end

function Workshops.rebuild()
    local list = {}
    for id, base in pairs(Config.Workshops) do
        if not (custom[id] and custom[id].deleted) then list[id] = build(id, base, custom[id]) end
    end
    for id, data in pairs(custom) do
        if not Config.Workshops[id] and not data.deleted and data.center then list[id] = build(id, data) end
    end
    Workshops.list = list
    Workshops.publish()
end

function Workshops.load()
    for _, r in ipairs(MySQL.query.await('SELECT id, data FROM vr_mechanic_locations') or {}) do
        local ok, data = pcall(json.decode, r.data)
        if ok and type(data) == 'table' then custom[r.id] = data end
    end
    Workshops.rebuild()
end

function Workshops.get(id)
    return type(id) == 'string' and Workshops.list[id] or nil
end

function Workshops.save(id, w)
    local data = w and plain(w) or { deleted = true }
    custom[id] = data
    MySQL.query.await('INSERT INTO vr_mechanic_locations (id, data, updated) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated = VALUES(updated)', { id, json.encode(data), os.time() })
    Workshops.rebuild()
end

function Workshops.at(pos, jobName)
    if not pos then return nil end
    local best, bestDist
    for _, w in pairs(Workshops.list) do
        if not jobName or w.job == jobName then
            local d = #(pos - w.center)
            if d <= w.radius and (not bestDist or d < bestDist) then best, bestDist = w, d end
        end
    end
    return best
end

function Workshops.atCounter(src, id)
    local w = Workshops.get(id)
    local pos = Core.coords(src)
    if not w or not w.counter or not pos then return nil end
    if #(pos - w.counter) > Config.CounterDistance + 1.0 then return nil end
    return w
end
