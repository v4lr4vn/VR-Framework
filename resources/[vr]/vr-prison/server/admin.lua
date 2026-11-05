local P = Prison

local KINDS = { station = true, canteen = true, cell = true }
local DEFAULT_LABEL = { canteen = 'Canteen', cell = 'Cell' }

local function reachable(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if not at then return nil end
    local x, y, z = P.num(at.x), P.num(at.y), P.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (P.num(at.w) or 0.0) + 0.0 }
end

local function cleanLabel(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if #v < 2 or #v > 48 then return nil end
    return v
end

local function cleanList(list, allowed, minDrawable)
    local out = {}
    for _, c in ipairs(type(list) == 'table' and list or {}) do
        local id, d, t = P.num(c.id), P.num(c.d), P.num(c.t)
        if id and d and t and allowed[id] and d >= minDrawable and d < 3000 and t >= 0 and t < 300 and #out < 20 then
            out[#out + 1] = { id = math.floor(id), d = math.floor(d), t = math.floor(t) }
        end
    end
    return out
end

lib.callback.register('vr-prison:isAdmin', function(src)
    return P.admin(src)
end)

lib.callback.register('vr-prison:admin', function(src, action, d)
    if not P.admin(src) then return P.fail('not_admin') end
    if not P.ready then return P.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return P.fail('bad_request') end

    if action == 'list' then
        return { ok = true, data = { points = P.list(), types = P.typeList(), outfits = { male = P.outfits.male ~= nil, female = P.outfits.female ~= nil } } }
    end

    if action == 'add' then
        if P.count() >= 120 then return P.fail('limit') end
        local kind = d.kind
        if not KINDS[kind] then return P.fail('bad_kind') end
        local typ = ''
        if kind == 'station' then
            typ = tostring(d.type or '')
            if not Config.Stations[typ] then return P.fail('bad_type') end
        end
        local pos = reachable(src, d)
        if not pos then return P.fail('too_far') end
        local label = cleanLabel(d.label) or (kind == 'station' and Config.Stations[typ].label) or DEFAULT_LABEL[kind]
        local pt = P.create(kind, typ, label, pos)
        if not pt then return P.fail('failed') end
        P.push()
        return { ok = true, data = { point = P.view(pt) } }
    end

    if action == 'outfit' then
        local gender = d.gender
        if gender ~= 'male' and gender ~= 'female' then return P.fail('bad_value') end
        local data = { components = cleanList(d.components, P.COMPONENTS, 0), props = cleanList(d.props, P.PROPS, -1) }
        if #data.components == 0 then return P.fail('bad_value') end
        P.outfits[gender] = data
        MySQL.update.await('INSERT INTO `vr_prison_outfits` (`gender`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { gender, json.encode(data) })
        return { ok = true, data = { gender = gender } }
    end

    if action == 'outfitReset' then
        local gender = d.gender
        if gender ~= 'male' and gender ~= 'female' then return P.fail('bad_value') end
        P.outfits[gender] = nil
        MySQL.update.await('DELETE FROM `vr_prison_outfits` WHERE `gender` = ?', { gender })
        return { ok = true, data = { gender = gender } }
    end

    local pt = P.points[tonumber(d.id) or -1]
    if not pt then return P.fail('not_found') end

    if action == 'move' then
        local pos = reachable(src, d)
        if not pos then return P.fail('too_far') end
        pt.x, pt.y, pt.z, pt.w = pos.x, pos.y, pos.z, pos.w
        P.save(pt)
        P.push()
        return { ok = true, data = { point = P.view(pt) } }
    elseif action == 'set' then
        local patch = type(d.patch) == 'table' and d.patch or {}
        if patch.label ~= nil then
            local label = cleanLabel(patch.label)
            if not label then return P.fail('bad_value') end
            pt.label = label
        end
        if patch.type ~= nil then
            if pt.kind ~= 'station' or not Config.Stations[tostring(patch.type)] then return P.fail('bad_type') end
            pt.type = tostring(patch.type)
        end
        P.save(pt)
        P.push()
        return { ok = true, data = { point = P.view(pt) } }
    elseif action == 'remove' then
        P.delete(pt)
        P.push()
        return { ok = true, data = { id = pt.id } }
    end
    return P.fail('bad_request')
end)

function P.typeList()
    local out = {}
    for key, cfg in pairs(Config.Stations) do
        out[#out + 1] = { key = key, label = cfg.label, icon = cfg.icon }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end
