local function reachable(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if not at then return nil end
    local x, y, z = Fence.num(at.x), Fence.num(at.y), Fence.num(at.z)
    local me = Bridge.coords(src)
    if not (x and y and z and me) then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    if dx * dx + dy * dy + dz * dz > 150.0 ^ 2 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (Fence.num(at.w) or 0.0) + 0.0 }
end

local DEFAULT_LABEL = { launder = 'Laundering contact', pawn = 'Pawn shop' }

lib.callback.register('vr-fence:isAdmin', function(src)
    return Fence.admin(src)
end)

lib.callback.register('vr-fence:admin', function(src, action, d)
    if not Fence.admin(src) then return Fence.fail('not_admin') end
    if not Fence.loaded then return Fence.fail('not_ready') end
    if type(action) ~= 'string' or type(d) ~= 'table' then return Fence.fail('bad_request') end
    if action == 'list' then
        return { ok = true, data = { spots = Fence.list() } }
    end
    if action == 'add' then
        if #Fence.list() >= 60 then return Fence.fail('limit') end
        local kind = d.kind
        if kind ~= 'launder' and kind ~= 'pawn' then return Fence.fail('bad_kind') end
        local pos = reachable(src, d)
        if not pos then return Fence.fail('too_far') end
        local label = type(d.label) == 'string' and #d.label >= 2 and d.label or DEFAULT_LABEL[kind]
        local clean, err = Fence.clean(nil, { label = label })
        if not clean then return Fence.fail(err) end
        local spot = Fence.create(kind, clean.label, pos)
        if not spot then return Fence.fail('failed') end
        spot.ped = Config.Ped[kind]
        Fence.save(spot)
        Fence.push()
        return { ok = true, data = { spot = Fence.view(spot) } }
    end
    local spot = Fence.spot(d.id)
    if not spot then return Fence.fail('not_found') end
    if action == 'move' then
        local pos = reachable(src, d)
        if not pos then return Fence.fail('too_far') end
        spot.x, spot.y, spot.z, spot.w = pos.x, pos.y, pos.z, pos.w
        Fence.save(spot)
        Fence.push()
        return { ok = true, data = { spot = Fence.view(spot) } }
    elseif action == 'set' then
        local clean, err = Fence.clean(nil, type(d.patch) == 'table' and d.patch or {})
        if not clean then return Fence.fail(err) end
        if clean.label ~= nil then spot.label = clean.label end
        if clean.ped ~= nil then spot.ped = clean.ped or nil end
        if clean.rate ~= nil then spot.rate = clean.rate or nil end
        Fence.save(spot)
        Fence.push()
        return { ok = true, data = { spot = Fence.view(spot) } }
    elseif action == 'remove' then
        Fence.delete(spot)
        Fence.push()
        return { ok = true, data = { id = spot.id } }
    end
    return Fence.fail('bad_request')
end)
