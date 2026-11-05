Dealers = { list = {} }

local custom = {}
local display = {}
local POINTS = { kiosk = 3, delivery = 4, testDrive = 4, returnPoint = 3, preview = 4, center = 3 }

local function v3(c) return c and vec3((c.x or c[1] or 0) + 0.0, (c.y or c[2] or 0) + 0.0, (c.z or c[3] or 0) + 0.0) or nil end
local function v4(c) return c and vec4((c.x or c[1] or 0) + 0.0, (c.y or c[2] or 0) + 0.0, (c.z or c[3] or 0) + 0.0, (c.w or c[4] or c.h or 0) + 0.0) or nil end

local function build(id, base, over)
    local d = { id = id }
    for k, v in pairs(base) do d[k] = v end
    for k, v in pairs(over or {}) do d[k] = v end
    for k, n in pairs(POINTS) do d[k] = n == 3 and v3(d[k]) or v4(d[k]) end
    d.radius = (tonumber(d.radius) or 20.0) + 0.0
    local slots = {}
    for i, s in ipairs(d.display or {}) do slots[i] = { coords = v4(s.coords), model = s.model } end
    d.display = slots
    return d
end

local function plain(d)
    local out = { id = d.id, label = d.label, shop = d.shop, radius = d.radius, garage = d.garage, blip = d.blip }
    for k in pairs(POINTS) do
        local p = d[k]
        if p then out[k] = { x = p.x, y = p.y, z = p.z, w = p.w } end
    end
    out.display = {}
    for i, s in ipairs(d.display) do out.display[i] = { coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z, w = s.coords.w }, model = s.model } end
    return out
end

function Dealers.publish()
    local out, disp = {}, {}
    for id, d in pairs(Dealers.list) do
        out[id] = plain(d)
        disp[id] = {}
        for i, s in ipairs(d.display) do disp[id][tostring(i)] = (display[id] and display[id][i]) or s.model end
    end
    GlobalState.vrDealers = out
    GlobalState.vrDealerDisplay = disp
end

function Dealers.rebuild()
    local list = {}
    for id, base in pairs(Config.Dealers) do
        if not (custom[id] and custom[id].deleted) then list[id] = build(id, base, custom[id]) end
    end
    for id, data in pairs(custom) do
        if not Config.Dealers[id] and not data.deleted then list[id] = build(id, data) end
    end
    Dealers.list = list
    Dealers.publish()
end

function Dealers.load()
    for _, r in ipairs(MySQL.query.await('SELECT id, data FROM vr_dealership_locations') or {}) do
        local ok, data = pcall(json.decode, r.data)
        if ok and type(data) == 'table' then custom[r.id] = data end
    end
    for _, r in ipairs(MySQL.query.await('SELECT dealer, slot, model FROM vr_dealership_display') or {}) do
        display[r.dealer] = display[r.dealer] or {}
        display[r.dealer][tonumber(r.slot)] = r.model
    end
    Dealers.rebuild()
end

function Dealers.custom() return custom end

function Dealers.get(id)
    return type(id) == 'string' and Dealers.list[id] or nil
end

function Dealers.save(id, d)
    local data = d and plain(d) or { deleted = true }
    custom[id] = data
    MySQL.query.await('INSERT INTO vr_dealership_locations (id, data, updated) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated = VALUES(updated)', { id, json.encode(data), os.time() })
    Dealers.rebuild()
end

function Dealers.setDisplay(id, slot, model)
    display[id] = display[id] or {}
    display[id][slot] = model
    MySQL.query.await('INSERT INTO vr_dealership_display (dealer, slot, model) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model)', { id, slot, model })
    Dealers.publish()
end

function Dealers.near(d, src, extra)
    local pos = Core.coords(src)
    return pos ~= nil and #(pos - d.center) <= d.radius + (extra or 4.0)
end

function Dealers.sells(d, model)
    local v = Core.vehicle(model)
    return v ~= nil and v.shop == d.shop and (tonumber(v.price) or 0) > 0
end

function Dealers.catalogue(d)
    local out = {}
    for model, v in pairs(Core.vehicles()) do
        if v.shop == d.shop and (tonumber(v.price) or 0) > 0 then
            out[#out + 1] = { model = model, name = v.name or model, brand = v.brand or '', price = math.floor(v.price), category = v.category or 'other' }
        end
    end
    table.sort(out, function(a, b) if a.price ~= b.price then return a.price < b.price end return a.model < b.model end)
    return out
end
