local api = TargetApi

local function alias(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
        setCB(fn)
    end)
end

local function free(resource)
    local state = GetResourceState(resource)
    if state == 'missing' or state == 'stopped' or state == 'uninitialized' or state == 'unknown' then return true end
    -- the name is a `provide` alias of this very resource
    local mine = GetCurrentResourceName()
    -- GetResourcePath only exists on the server; the client compares manifest names
    if GetResourcePath then return GetResourcePath(resource) == GetResourcePath(mine) end
    return GetResourceMetadata(resource, 'name', 0) == mine
end

if free('ox_target') then
    for name, fn in pairs(api) do
        alias('ox_target', name, fn)
    end
end

local function qbGroups(v)
    local out, any = {}, false
    for _, key in ipairs({ 'job', 'gang' }) do
        local value = v[key]
        if type(value) == 'string' then
            out[value] = 0
            any = true
        elseif type(value) == 'table' then
            if value[1] ~= nil then
                for _, name in ipairs(value) do out[name] = 0 any = true end
            else
                for name, grade in pairs(value) do out[name] = tonumber(grade) or 0 any = true end
            end
        end
    end
    return any and out or nil
end

local function qbConvert(data)
    data = type(data) == 'table' and data or {}
    local distance = data.distance
    local list = {}
    for k, v in pairs(data.options or {}) do
        if type(v) == 'table' then list[#list + 1] = v end
    end
    table.sort(list, function(a, b) return (tonumber(a.num) or 99) < (tonumber(b.num) or 99) end)
    local out = {}
    for _, v in ipairs(list) do
        local o = {
            name = v.name or v.label,
            label = v.label,
            icon = v.icon,
            distance = v.distance or distance or 2.5,
            groups = qbGroups(v),
            items = v.item or v.required_item,
        }
        local check, cid = v.canInteract, v.citizenid
        if check or cid then
            o.canInteract = function(entity, dist)
                if cid then
                    local mine = Bridge.cid()
                    if type(cid) == 'table' then
                        if not mine or not cid[mine] then return false end
                    elseif mine ~= cid then
                        return false
                    end
                end
                if check then return check(entity, dist, v) end
                return true
            end
        end
        local action, kind, event = v.action, v.type, v.event
        o.onSelect = function(res)
            local entity = type(res) == 'table' and res.entity or res
            if action then return action(entity) end
            if not event then return end
            if kind == 'server' then return TriggerServerEvent(event, v) end
            if kind == 'command' then return ExecuteCommand(event) end
            if kind == 'qbcommand' then return TriggerServerEvent('QBCore:CallCommand', event, v) end
            v.entity = entity
            TriggerEvent(event, v)
        end
        out[#out + 1] = o
    end
    return out
end

if free('qb-target') then
    local function qbAlias(name, fn) alias('qb-target', name, fn) end
    qbAlias('AddCircleZone', function(name, center, radius, options, targetoptions)
        options = options or {}
        return api.addSphereZone({ name = name, coords = vec3(center.x, center.y, center.z), radius = radius, debug = options.debugPoly, options = qbConvert(targetoptions) })
    end)
    qbAlias('AddBoxZone', function(name, center, length, width, options, targetoptions)
        options = options or {}
        local minZ, maxZ = options.minZ or (center.z - 2.0), options.maxZ or (center.z + 2.0)
        return api.addBoxZone({
            name = name, coords = vec3(center.x, center.y, (minZ + maxZ) / 2), size = vec3(width, length, math.abs(maxZ - minZ)),
            rotation = options.heading or 0.0, debug = options.debugPoly, options = qbConvert(targetoptions),
        })
    end)
    qbAlias('AddPolyZone', function(name, points, options, targetoptions)
        options = options or {}
        local minZ, maxZ = options.minZ or 0.0, options.maxZ or 100.0
        local list = {}
        for i = 1, #points do list[i] = vec3(points[i].x, points[i].y, (minZ + maxZ) / 2) end
        return api.addPolyZone({ name = name, points = list, thickness = math.abs(maxZ - minZ), debug = options.debugPoly, options = qbConvert(targetoptions) })
    end)
    qbAlias('RemoveZone', function(name) api.removeZone(name, true) end)
    qbAlias('AddTargetModel', function(models, params) api.addModel(models, qbConvert(params)) end)
    qbAlias('RemoveTargetModel', function(models, labels) api.removeModel(models, labels) end)
    qbAlias('AddTargetEntity', function(entities, params)
        if type(entities) ~= 'table' then entities = { entities } end
        local list = qbConvert(params)
        for i = 1, #entities do
            local ent = entities[i]
            if NetworkGetEntityIsNetworked(ent) then api.addEntity(NetworkGetNetworkIdFromEntity(ent), list) else api.addLocalEntity(ent, list) end
        end
    end)
    qbAlias('RemoveTargetEntity', function(entities, labels)
        if type(entities) ~= 'table' then entities = { entities } end
        for i = 1, #entities do
            local ent = entities[i]
            if NetworkGetEntityIsNetworked(ent) then api.removeEntity(NetworkGetNetworkIdFromEntity(ent), labels) else api.removeLocalEntity(ent, labels) end
        end
    end)
    qbAlias('AddTargetBone', function(bones, params)
        if type(bones) ~= 'table' then bones = { bones } end
        local list = qbConvert(params)
        for _, o in ipairs(list) do o.bones = bones end
        api.addGlobalVehicle(list)
    end)
    qbAlias('RemoveTargetBone', function(_, labels) api.removeGlobalVehicle(labels) end)
    qbAlias('AddGlobalPed', function(params) api.addGlobalPed(qbConvert(params)) end)
    qbAlias('RemoveGlobalPed', function(labels) api.removeGlobalPed(labels) end)
    qbAlias('AddGlobalVehicle', function(params) api.addGlobalVehicle(qbConvert(params)) end)
    qbAlias('RemoveGlobalVehicle', function(labels) api.removeGlobalVehicle(labels) end)
    qbAlias('AddGlobalObject', function(params) api.addGlobalObject(qbConvert(params)) end)
    qbAlias('RemoveGlobalObject', function(labels) api.removeGlobalObject(labels) end)
    qbAlias('AddGlobalPlayer', function(params) api.addGlobalPlayer(qbConvert(params)) end)
    qbAlias('RemoveGlobalPlayer', function(labels) api.removeGlobalPlayer(labels) end)
    qbAlias('AllowTargeting', function(state) api.disableTargeting(state == false) end)
    qbAlias('IsTargetActive', function() return api.isActive() end)
end

if not free('qtarget') then return end

local function convert(data)
    local distance = data.distance
    local options = data.options or {}
    local list = {}
    for k, v in pairs(options) do
        if type(k) ~= 'number' then list[#list + 1] = v end
    end
    for i = 1, #options do list[#list + 1] = options[i] end
    for _, v in ipairs(list) do
        v.onSelect = v.action
        v.distance = v.distance or distance
        v.name = v.name or v.label
        v.groups = v.job
        v.items = v.item or v.required_item
        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end
            v.event = nil
            v.type = nil
        end
        v.action, v.job, v.item, v.required_item = nil, nil, nil, nil
        v.qtarget = true
    end
    return list
end

alias('qtarget', 'AddBoxZone', function(name, center, length, width, options, targetoptions)
    options = options or {}
    local minZ = options.minZ or -100
    local maxZ = options.maxZ or 800
    local z = center.z
    if not options.useZ then
        z = z + math.abs(maxZ - minZ) / 2
    end
    return api.addBoxZone({
        name = name,
        coords = vec3(center.x, center.y, z),
        size = vec3(width, length, (options.useZ or not options.maxZ) and center.z or math.abs(maxZ - minZ)),
        debug = options.debugPoly,
        rotation = options.heading,
        options = convert(targetoptions),
    })
end)

alias('qtarget', 'AddPolyZone', function(name, points, options, targetoptions)
    local thickness = math.abs(options.maxZ - options.minZ)
    local list = {}
    for i = 1, #points do
        list[i] = vec3(points[i].x, points[i].y, options.maxZ - thickness / 2)
    end
    return api.addPolyZone({ name = name, points = list, thickness = thickness, debug = options.debugPoly, options = convert(targetoptions) })
end)

alias('qtarget', 'AddCircleZone', function(name, center, radius, options, targetoptions)
    return api.addSphereZone({ name = name, coords = center, radius = radius, debug = options and options.debugPoly, options = convert(targetoptions) })
end)

alias('qtarget', 'RemoveZone', function(id) api.removeZone(id, true) end)

alias('qtarget', 'AddTargetBone', function(bones, options)
    if type(bones) ~= 'table' then bones = { bones } end
    local list = convert(options)
    for _, v in ipairs(list) do v.bones = bones end
    api.addGlobalVehicle(list)
end)

alias('qtarget', 'AddTargetEntity', function(entities, options)
    if type(entities) ~= 'table' then entities = { entities } end
    local list = convert(options)
    for i = 1, #entities do
        local ent = entities[i]
        if NetworkGetEntityIsNetworked(ent) then
            api.addEntity(NetworkGetNetworkIdFromEntity(ent), list)
        else
            api.addLocalEntity(ent, list)
        end
    end
end)

alias('qtarget', 'RemoveTargetEntity', function(entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end
    for i = 1, #entities do
        local ent = entities[i]
        if NetworkGetEntityIsNetworked(ent) then
            api.removeEntity(NetworkGetNetworkIdFromEntity(ent), labels)
        else
            api.removeLocalEntity(ent, labels)
        end
    end
end)

alias('qtarget', 'AddTargetModel', function(models, options) api.addModel(models, convert(options)) end)
alias('qtarget', 'RemoveTargetModel', function(models, labels) api.removeModel(models, labels) end)
alias('qtarget', 'Ped', function(options) api.addGlobalPed(convert(options)) end)
alias('qtarget', 'RemovePed', function(labels) api.removeGlobalPed(labels) end)
alias('qtarget', 'Vehicle', function(options) api.addGlobalVehicle(convert(options)) end)
alias('qtarget', 'RemoveVehicle', function(labels) api.removeGlobalVehicle(labels) end)
alias('qtarget', 'Object', function(options) api.addGlobalObject(convert(options)) end)
alias('qtarget', 'RemoveObject', function(labels) api.removeGlobalObject(labels) end)
alias('qtarget', 'Player', function(options) api.addGlobalPlayer(convert(options)) end)
alias('qtarget', 'RemovePlayer', function(labels) api.removeGlobalPlayer(labels) end)
