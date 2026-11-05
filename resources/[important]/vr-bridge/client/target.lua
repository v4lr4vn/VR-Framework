local U = Bridge.util
local T = {}
Bridge.target = T

local kind = Bridge.targetName
local RES = Bridge.targetResource

local function list(options)
    if type(options) ~= 'table' then return {} end
    if options.label then return { options } end
    return options
end

local function allowed(o, entity, distance)
    if o.groups and not Bridge.hasGroup(o.groups) then return false end
    if o.items then
        local items = o.items
        if type(items) == 'string' then
            if not Bridge.inventory.has(items) then return false end
        elseif type(items) == 'table' then
            local any = o.anyItem == true
            local hit = false
            for k, v in pairs(items) do
                local name, need = k, v
                if type(k) == 'number' then name, need = v, 1 end
                local has = Bridge.inventory.has(name, tonumber(need) or 1)
                if any and has then hit = true break end
                if not any and not has then return false end
            end
            if any and not hit then return false end
        end
    end
    if o.canInteract then
        local ok, res = pcall(o.canInteract, entity, distance, entity and entity ~= 0 and GetEntityCoords(entity) or GetEntityCoords(PlayerPedId()), o.name)
        if not ok or not res then return false end
    end
    return true
end
T.allowed = allowed

local function fire(o, entity, distance, zone)
    local data = {}
    for k, v in pairs(o) do
        if type(v) ~= 'function' then data[k] = v end
    end
    data.entity = entity or 0
    data.distance = distance
    data.zone = zone
    data.coords = entity and entity ~= 0 and GetEntityCoords(entity) or GetEntityCoords(PlayerPedId())
    if o.onSelect then return o.onSelect(data) end
    if o.export and o.resource then return exports[o.resource][o.export](nil, data) end
    if o.event then return TriggerEvent(o.event, data) end
    if o.serverEvent then
        data.entity = entity and entity ~= 0 and NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
        return TriggerServerEvent(o.serverEvent, data)
    end
    if o.command then return ExecuteCommand(o.command) end
end
T.fire = fire

local function passthrough(fn, ...)
    local args = table.pack(...)
    local ok, res = pcall(function() return exports[RES][fn](nil, table.unpack(args, 1, args.n)) end)
    if not ok then
        print(('^1[vr-bridge] target %s failed: %s^0'):format(fn, tostring(res)))
        return nil
    end
    return res
end

if kind == 'vr' or kind == 'ox' then
    for _, fn in ipairs({
        'addSphereZone', 'addBoxZone', 'addPolyZone', 'removeZone',
        'addModel', 'removeModel', 'addEntity', 'removeEntity', 'addLocalEntity', 'removeLocalEntity',
        'addGlobalVehicle', 'removeGlobalVehicle', 'addGlobalPlayer', 'removeGlobalPlayer',
        'addGlobalPed', 'removeGlobalPed', 'addGlobalObject', 'removeGlobalObject', 'addGlobalOption', 'removeGlobalOption',
        'disableTargeting', 'zoneExists',
    }) do
        T[fn] = function(...) return passthrough(fn, ...) end
    end
    return T
end

local names = {}
local seq = 0

local function nextName(prefix)
    seq = seq + 1
    return ('%s:%s:%d'):format(Bridge.resource, prefix, seq)
end

if kind == 'qb' then
    local function qbOptions(options)
        options = list(options)
        local out, dist = {}, 0
        for i, o in ipairs(options) do
            dist = math.max(dist, tonumber(o.distance) or 2.0)
            local label = o.label or o.name or ('Option %d'):format(i)
            if o.name then names[o.name] = label end
            out[#out + 1] = {
                icon = o.icon,
                label = label,
                num = i,
                canInteract = function(entity, distance) return allowed(o, entity, distance) end,
                action = function(entity) fire(o, entity, nil, nil) end,
            }
        end
        return { options = out, distance = dist > 0 and dist or 2.5 }
    end

    local function labels(list_)
        if type(list_) ~= 'table' then list_ = { list_ } end
        local out = {}
        for _, n in ipairs(list_) do out[#out + 1] = names[n] or n end
        return out
    end

    local function q() return exports[RES] end

    function T.addSphereZone(o)
        local name = o.name or nextName('sphere')
        local c = o.coords
        q():AddCircleZone(name, vector3(c.x, c.y, c.z), o.radius or 1.5, { name = name, debugPoly = o.debug, useZ = true }, qbOptions(o.options))
        return name
    end

    function T.addBoxZone(o)
        local name = o.name or nextName('box')
        local c, size = o.coords, o.size or vec3(2, 2, 2)
        q():AddBoxZone(name, vector3(c.x, c.y, c.z), size.y, size.x, {
            name = name, heading = o.rotation or 0.0, debugPoly = o.debug, minZ = c.z - size.z / 2, maxZ = c.z + size.z / 2,
        }, qbOptions(o.options))
        return name
    end

    function T.addPolyZone(o)
        local name = o.name or nextName('poly')
        local pts, minZ, maxZ = {}, nil, nil
        local half = (o.thickness or 4) / 2
        for i, p in ipairs(o.points or {}) do
            pts[i] = vector2(p.x, p.y)
            minZ = math.min(minZ or p.z, p.z - half)
            maxZ = math.max(maxZ or p.z, p.z + half)
        end
        q():AddPolyZone(name, pts, { name = name, debugPoly = o.debug, minZ = minZ, maxZ = maxZ }, qbOptions(o.options))
        return name
    end

    function T.removeZone(id) pcall(function() q():RemoveZone(id) end) end
    function T.zoneExists() return false end

    function T.addModel(models, options) q():AddTargetModel(models, qbOptions(options)) end
    function T.removeModel(models, n) q():RemoveTargetModel(models, labels(n)) end

    function T.addEntity(netIds, options)
        if type(netIds) ~= 'table' then netIds = { netIds } end
        local ents = {}
        for _, id in ipairs(netIds) do
            local ent = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or 0
            if ent ~= 0 then ents[#ents + 1] = ent end
        end
        if #ents > 0 then q():AddTargetEntity(ents, qbOptions(options)) end
    end

    function T.removeEntity(netIds, n)
        if type(netIds) ~= 'table' then netIds = { netIds } end
        local ents = {}
        for _, id in ipairs(netIds) do
            local ent = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or 0
            if ent ~= 0 then ents[#ents + 1] = ent end
        end
        if #ents > 0 then q():RemoveTargetEntity(ents, n and labels(n) or nil) end
    end

    function T.addLocalEntity(ents, options) q():AddTargetEntity(ents, qbOptions(options)) end
    function T.removeLocalEntity(ents, n) q():RemoveTargetEntity(ents, n and labels(n) or nil) end

    function T.addGlobalVehicle(options) q():AddGlobalVehicle(qbOptions(options)) end
    function T.removeGlobalVehicle(n) q():RemoveGlobalVehicle(labels(n)) end
    function T.addGlobalPlayer(options) q():AddGlobalPlayer(qbOptions(options)) end
    function T.removeGlobalPlayer(n) q():RemoveGlobalPlayer(labels(n)) end
    function T.addGlobalPed(options) q():AddGlobalPed(qbOptions(options)) end
    function T.removeGlobalPed(n) q():RemoveGlobalPed(labels(n)) end
    function T.addGlobalObject(options) q():AddGlobalObject(qbOptions(options)) end
    function T.removeGlobalObject(n) q():RemoveGlobalObject(labels(n)) end
    function T.addGlobalOption() end
    function T.removeGlobalOption() end
    function T.disableTargeting(v) pcall(function() q():AllowTargeting(not v) end) end
    return T
end

local zones, entities, models, globals = {}, {}, {}, { vehicle = {}, player = {}, ped = {}, object = {} }

local function add(store, options)
    for _, o in ipairs(list(options)) do store[#store + 1] = o end
end

local function remove(store, n)
    if type(n) ~= 'table' then n = { n } end
    local drop = {}
    for _, v in ipairs(n) do drop[v] = true end
    for i = #store, 1, -1 do
        if drop[store[i].name] or drop[store[i].label] then table.remove(store, i) end
    end
end

local function addZone(shape, o)
    seq = seq + 1
    local id = seq
    zones[id] = { shape = shape, data = o, options = list(o.options), name = o.name }
    return id
end

function T.addSphereZone(o) return addZone('sphere', o) end
function T.addBoxZone(o) return addZone('box', o) end
function T.addPolyZone(o) return addZone('poly', o) end

function T.removeZone(id)
    if zones[id] then zones[id] = nil return end
    for k, z in pairs(zones) do
        if z.name == id then zones[k] = nil end
    end
end

function T.zoneExists(id) return zones[id] ~= nil end

function T.addModel(m, options)
    if type(m) ~= 'table' then m = { m } end
    for _, model in ipairs(m) do
        local hash = type(model) == 'number' and model or joaat(model)
        models[hash] = models[hash] or {}
        add(models[hash], options)
    end
end

function T.removeModel(m, n)
    if type(m) ~= 'table' then m = { m } end
    for _, model in ipairs(m) do
        local hash = type(model) == 'number' and model or joaat(model)
        if models[hash] then
            if n then remove(models[hash], n) else models[hash] = nil end
        end
    end
end

function T.addLocalEntity(ents, options)
    if type(ents) ~= 'table' then ents = { ents } end
    for _, e in ipairs(ents) do
        entities[e] = entities[e] or {}
        add(entities[e], options)
    end
end

function T.removeLocalEntity(ents, n)
    if type(ents) ~= 'table' then ents = { ents } end
    for _, e in ipairs(ents) do
        if entities[e] then
            if n then remove(entities[e], n) else entities[e] = nil end
        end
    end
end

function T.addEntity(netIds, options)
    if type(netIds) ~= 'table' then netIds = { netIds } end
    for _, id in ipairs(netIds) do
        local ent = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or 0
        if ent ~= 0 then T.addLocalEntity(ent, options) end
    end
end

function T.removeEntity(netIds, n)
    if type(netIds) ~= 'table' then netIds = { netIds } end
    for _, id in ipairs(netIds) do
        local ent = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or 0
        if ent ~= 0 then T.removeLocalEntity(ent, n) end
    end
end

function T.addGlobalVehicle(o) add(globals.vehicle, o) end
function T.removeGlobalVehicle(n) remove(globals.vehicle, n) end
function T.addGlobalPlayer(o) add(globals.player, o) end
function T.removeGlobalPlayer(n) remove(globals.player, n) end
function T.addGlobalPed(o) add(globals.ped, o) end
function T.removeGlobalPed(n) remove(globals.ped, n) end
function T.addGlobalObject(o) add(globals.object, o) end
function T.removeGlobalObject(n) remove(globals.object, n) end
function T.addGlobalOption() end
function T.removeGlobalOption() end

local disabled = false
function T.disableTargeting(v) disabled = v == true end

local function insideZone(z, pos)
    local d = z.data
    local c = d.coords
    if z.shape == 'sphere' then
        return #(pos - vector3(c.x, c.y, c.z)) <= (d.radius or 1.5)
    end
    if z.shape == 'box' then
        local size = d.size or vec3(2, 2, 2)
        local rot = math.rad(-(d.rotation or 0.0))
        local dx, dy = pos.x - c.x, pos.y - c.y
        local lx = dx * math.cos(rot) - dy * math.sin(rot)
        local ly = dx * math.sin(rot) + dy * math.cos(rot)
        return math.abs(lx) <= size.x / 2 and math.abs(ly) <= size.y / 2 and math.abs(pos.z - c.z) <= size.z / 2
    end
    local pts = d.points or {}
    local inside, j = false, #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        if ((a.y > pos.y) ~= (b.y > pos.y)) and (pos.x < (b.x - a.x) * (pos.y - a.y) / (b.y - a.y) + a.x) then inside = not inside end
        j = i
    end
    return inside and math.abs(pos.z - (pts[1] and pts[1].z or pos.z)) <= (d.thickness or 4) / 2
end

local function aimed(maxDist)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    if not cam or not rot then return nil end
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local dest = cam + dir * (maxDist + 4.0)
    local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 30, PlayerPedId(), 4)
    local status, hit, _, _, entity = GetShapeTestResult(ray)
    while status == 1 do
        Wait(0)
        status, hit, _, _, entity = GetShapeTestResult(ray)
    end
    if hit == 1 and entity and entity ~= 0 then return entity end
    return nil
end

local function candidates(pos)
    for id, z in pairs(zones) do
        if insideZone(z, pos) then
            for _, o in ipairs(z.options) do
                if allowed(o, nil, 0.0) then return o, nil, id end
            end
        end
    end
    local entity = aimed(3.0)
    if not entity then return nil end
    local dist = #(pos - GetEntityCoords(entity))
    local pools = { entities[entity], models[GetEntityModel(entity)] }
    local etype = GetEntityType(entity)
    if etype == 2 then pools[#pools + 1] = globals.vehicle
    elseif etype == 1 then pools[#pools + 1] = IsPedAPlayer(entity) and globals.player or globals.ped
    elseif etype == 3 then pools[#pools + 1] = globals.object end
    for _, pool in ipairs(pools) do
        for _, o in ipairs(pool or {}) do
            if dist <= (tonumber(o.distance) or 2.5) and allowed(o, entity, dist) then return o, entity, nil end
        end
    end
    return nil
end

local function anything()
    if next(zones) or next(entities) or next(models) then return true end
    for _, pool in pairs(globals) do if #pool > 0 then return true end end
    return false
end

CreateThread(function()
    local shown, option, entity, zone
    local nextScan = 0
    while true do
        local wait = 500
        if not disabled and anything() and not IsNuiFocused() and not IsPauseMenuActive() then
            local now = GetGameTimer()
            if now >= nextScan then
                option, entity, zone = candidates(GetEntityCoords(PlayerPedId()))
                nextScan = now + 150
            end
            if option then
                wait = 0
                local text = ('[E] %s'):format(option.label or option.name or 'Interact')
                if shown ~= text then
                    Bridge.textUI.show(text)
                    shown = text
                end
                if IsControlJustReleased(0, 38) then
                    local picked, ent, z = option, entity, zone
                    local dist = ent and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ent)) or 0.0
                    nextScan = 0
                    CreateThread(function()
                        local ok, err = pcall(fire, picked, ent, dist, z)
                        if not ok then print(('^1[vr-bridge] target option failed: %s^0'):format(tostring(err))) end
                    end)
                end
            elseif shown then
                Bridge.textUI.hide()
                shown = nil
            end
        else
            option = nil
            if shown then
                Bridge.textUI.hide()
                shown = nil
            end
        end
        Wait(wait)
    end
end)

return T
