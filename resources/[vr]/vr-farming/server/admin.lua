local function reachable(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if not at then return nil end
    local x, y, z = Farm.num(at.x), Farm.num(at.y), Farm.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (Farm.num(at.w) or 0.0) + 0.0 }
end

-- The corners an admin walked: they must be close to where the admin is standing now.
local function outline(src, d)
    local shape, err = Farm.shape(d.points)
    if not shape then return nil, err end
    local me = Bridge.coords(src)
    if not me then return nil, 'too_far' end
    local dx, dy = shape.x - me.x, shape.y - me.y
    if dx * dx + dy * dy > (shape.radius + 150.0) ^ 2 then return nil, 'too_far' end
    return shape
end

local DEFAULT_LABEL = { field = 'Farm field', store = 'Farm store', well = 'Water well' }

lib.callback.register('vr-farming:isAdmin', function(src)
    return Farm.admin(src)
end)

lib.callback.register('vr-farming:admin', function(src, action, d)
    if not Farm.admin(src) then return Farm.fail('not_admin') end
    if not Farm.loaded then return Farm.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return Farm.fail('bad_request') end
    if action == 'list' then
        return { ok = true, data = { spots = Farm.list() } }
    end
    if action == 'add' then
        if #Farm.list() >= 80 then return Farm.fail('limit') end
        local kind = d.kind
        if kind ~= 'field' and kind ~= 'store' and kind ~= 'well' then return Farm.fail('bad_kind') end
        local shape, pos
        if kind == 'field' and d.points ~= nil then
            local err
            shape, err = outline(src, d)
            if not shape then return Farm.fail(err) end
            pos = { x = shape.x, y = shape.y, z = shape.z, w = 0.0 }
        else
            pos = reachable(src, d)
            if not pos then return Farm.fail('too_far') end
        end
        local label = type(d.label) == 'string' and #d.label >= 2 and d.label or DEFAULT_LABEL[kind]
        local clean, err = Farm.clean({ label = label, radius = kind == 'field' and (d.radius or Config.DefaultFieldRadius) or nil, crops = kind == 'field' and d.crops or nil, irrigated = kind == 'field' and d.irrigated or nil })
        if not clean then return Farm.fail(err) end
        local spot = Farm.create(kind, clean.label, pos, clean.radius or Config.DefaultFieldRadius, shape)
        if not spot then return Farm.fail('failed') end
        if clean.crops then spot.crops = clean.crops end
        if clean.irrigated then spot.irrigated = true end
        spot.ped = Config.Ped[kind]
        Farm.save(spot)
        Farm.push()
        return { ok = true, data = { spot = Farm.view(spot) } }
    end
    local spot = Farm.spot(d.id)
    if not spot then return Farm.fail('not_found') end
    if action == 'shape' then
        if spot.kind ~= 'field' then return Farm.fail('bad_request') end
        local shape, err = outline(src, d)
        if not shape then return Farm.fail(err) end
        spot.points, spot.minZ, spot.maxZ = shape.points, shape.minZ, shape.maxZ
        spot.x, spot.y, spot.z, spot.radius = shape.x, shape.y, shape.z, shape.radius
        -- Plants that are no longer inside the new outline are removed.
        local gone = {}
        for _, p in pairs(Farm.plants) do
            if p.field == spot.id and not Farm.inField(spot, p.x, p.y, p.z) then gone[#gone + 1] = p end
        end
        for _, p in ipairs(gone) do Farm.dropPlant(p) end
        Farm.save(spot)
        Farm.push()
        return { ok = true, data = { spot = Farm.view(spot), removed = #gone } }
    elseif action == 'move' then
        if spot.kind == 'field' and spot.points then return Farm.fail('bad_request') end
        local pos = reachable(src, d)
        if not pos then return Farm.fail('too_far') end
        spot.x, spot.y, spot.z, spot.w = pos.x, pos.y, pos.z, pos.w
        Farm.save(spot)
        Farm.push()
        return { ok = true, data = { spot = Farm.view(spot) } }
    elseif action == 'set' then
        local clean, err = Farm.clean(type(d.patch) == 'table' and d.patch or {})
        if not clean then return Farm.fail(err) end
        if clean.label ~= nil then spot.label = clean.label end
        if clean.ped ~= nil then spot.ped = clean.ped or nil end
        if clean.rate ~= nil then spot.rate = clean.rate or nil end
        if clean.radius ~= nil and spot.kind == 'field' and not spot.points then spot.radius = clean.radius end
        if clean.crops ~= nil and spot.kind == 'field' then spot.crops = clean.crops or nil end
        if clean.irrigated ~= nil and spot.kind == 'field' and (clean.irrigated == true) ~= (spot.irrigated == true) then
            -- Bring every plant up to date under the old rule first, then switch.
            Farm.settle(spot.id)
            spot.irrigated = clean.irrigated or nil
            Farm.refresh(spot.id)
        end
        Farm.save(spot)
        Farm.push()
        return { ok = true, data = { spot = Farm.view(spot) } }
    elseif action == 'remove' then
        if spot.kind == 'field' then
            local gone = {}
            for _, p in pairs(Farm.plants) do
                if p.field == spot.id then gone[#gone + 1] = p end
            end
            for _, p in ipairs(gone) do Farm.dropPlant(p) end
        end
        Farm.delete(spot)
        Farm.push()
        return { ok = true, data = { id = spot.id } }
    end
    return Farm.fail('bad_request')
end)
