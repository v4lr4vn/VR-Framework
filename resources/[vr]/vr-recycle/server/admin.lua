local G = Gather

local function placeable(kind)
    local cfg = Config.Kinds[kind]
    return cfg ~= nil and not cfg.models
end

local function reachable(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if not at then return nil end
    local x, y, z = G.num(at.x), G.num(at.y), G.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (G.num(at.w) or 0.0) + 0.0 }
end

local function cleanLabel(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if #v < 2 or #v > 48 then return nil end
    return v
end

function G.kindList()
    local out = {}
    for key, cfg in pairs(Config.Kinds) do
        if not cfg.models then out[#out + 1] = { key = key, label = cfg.label, icon = cfg.icon } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

lib.callback.register(G.name('isAdmin'), function(src) return G.admin(src) end)

lib.callback.register(G.name('admin'), function(src, action, d)
    if not G.admin(src) then return G.fail('not_admin') end
    if not G.ready then return G.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return G.fail('bad_request') end
    if action == 'list' then
        return { ok = true, data = { points = G.list(), kinds = G.kindList() } }
    end
    if action == 'add' then
        if G.count() >= 200 then return G.fail('limit') end
        local kind = tostring(d.kind or '')
        if not placeable(kind) then return G.fail('bad_kind') end
        local pos = reachable(src, d)
        if not pos then return G.fail('too_far') end
        local label = cleanLabel(d.label) or Config.Kinds[kind].label
        local pt = G.create(kind, label, pos)
        if not pt then return G.fail('failed') end
        G.push()
        return { ok = true, data = { point = G.view(pt) } }
    end
    local pt = G.points[tonumber(d.id) or -1]
    if not pt then return G.fail('not_found') end
    if action == 'move' then
        local pos = reachable(src, d)
        if not pos then return G.fail('too_far') end
        pt.x, pt.y, pt.z, pt.w = pos.x, pos.y, pos.z, pos.w
        G.save(pt)
        G.push()
        return { ok = true, data = { point = G.view(pt) } }
    elseif action == 'set' then
        local patch = type(d.patch) == 'table' and d.patch or {}
        if patch.label ~= nil then
            local label = cleanLabel(patch.label)
            if not label then return G.fail('bad_value') end
            pt.label = label
        end
        if patch.kind ~= nil then
            if not placeable(tostring(patch.kind)) then return G.fail('bad_kind') end
            pt.kind = tostring(patch.kind)
        end
        G.save(pt)
        G.push()
        return { ok = true, data = { point = G.view(pt) } }
    elseif action == 'remove' then
        G.delete(pt)
        G.push()
        return { ok = true, data = { id = pt.id } }
    end
    return G.fail('bad_request')
end)
