TargetApi = {}
TargetStore = {}

local api = TargetApi
local store = TargetStore
local utils = TargetUtils

store.peds = {}
store.vehicles = {}
store.objects = {}
store.players = {}
store.global = {}
store.models = {}
store.entities = {}
store.localEntities = {}

local function isArray(t)
    if type(t) ~= 'table' then return false end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then return false end
        n = n + 1
    end
    return n == #t
end

local function checkOptions(options)
    if type(options) ~= 'table' then
        error(("expected options to have type 'table' (received %s)"):format(type(options)), 3)
    end
    if options.label then return { options } end
    if not isArray(options) then
        error('expected options to be an array of options', 3)
    end
    return options
end

local function owner()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function removeTarget(list, names, resource, warnReplace)
    if type(names) ~= 'table' then names = { names } end
    for i = #list, 1, -1 do
        local option = list[i]
        if option.resource == resource then
            for j = 1, #names do
                if option.name == names[j] then
                    table.remove(list, i)
                    if warnReplace then utils.warn(("Replacing existing target option '%s'."):format(option.name)) end
                    break
                end
            end
        end
    end
end

local function addTarget(list, options, resource)
    options = checkOptions(options)
    local names = {}
    for i = 1, #options do
        options[i].resource = resource
        if options[i].name then names[#names + 1] = options[i].name end
    end
    if #names > 0 then removeTarget(list, names, resource, true) end
    for i = 1, #options do
        list[#list + 1] = options[i]
    end
end

local function zone(kind, data)
    if type(data) ~= 'table' then error('zone data must be a table', 3) end
    if data.debug then utils.warn(('Creating new %s zone with debug enabled.'):format(kind)) end
    data.resource = owner()
    data.options = checkOptions(data.options)
    local created = lib.zones[kind](data)
    return created.id
end

function api.addPolyZone(data) return zone('poly', data) end
function api.addBoxZone(data) return zone('box', data) end
function api.addSphereZone(data) return zone('sphere', data) end

function api.zoneExists(id)
    local all = lib.zones.getAllZones()
    if type(id) == 'number' then return all[id] ~= nil and all[id].options ~= nil end
    if type(id) == 'string' then
        for _, z in pairs(all) do
            if z.name == id then return true end
        end
    end
    return false
end

function api.removeZone(id, suppressWarning)
    local all = lib.zones.getAllZones()
    if type(id) == 'string' then
        local found = false
        for _, z in pairs(all) do
            if z.name == id then
                found = true
                z:remove()
            end
        end
        if found then return end
    elseif all[id] then
        return all[id]:remove()
    end
    if not suppressWarning then utils.warn(('attempted to remove a zone that does not exist (id: %s)'):format(tostring(id))) end
end

function api.addGlobalPed(options) addTarget(store.peds, options, owner()) end
function api.removeGlobalPed(options) removeTarget(store.peds, options, owner()) end
function api.addGlobalVehicle(options) addTarget(store.vehicles, options, owner()) end
function api.removeGlobalVehicle(options) removeTarget(store.vehicles, options, owner()) end
function api.addGlobalObject(options) addTarget(store.objects, options, owner()) end
function api.removeGlobalObject(options) removeTarget(store.objects, options, owner()) end
function api.addGlobalPlayer(options) addTarget(store.players, options, owner()) end
function api.removeGlobalPlayer(options) removeTarget(store.players, options, owner()) end
function api.addGlobalOption(options) addTarget(store.global, options, owner()) end
function api.removeGlobalOption(options) removeTarget(store.global, options, owner()) end

local function modelHash(m)
    return tonumber(m) or joaat(m)
end

function api.addModel(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = owner()
    for i = 1, #arr do
        local hash = modelHash(arr[i])
        store.models[hash] = store.models[hash] or {}
        addTarget(store.models[hash], options, resource)
    end
end

function api.removeModel(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = owner()
    for i = 1, #arr do
        local hash = modelHash(arr[i])
        local list = store.models[hash]
        if list then
            if options then removeTarget(list, options, resource) end
            if not options or #list == 0 then store.models[hash] = nil end
        end
    end
end

function api.addEntity(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = owner()
    for i = 1, #arr do
        local netId = arr[i]
        if NetworkDoesNetworkIdExist(netId) then
            if not store.entities[netId] then
                store.entities[netId] = {}
                local ent = NetworkGetEntityFromNetworkId(netId)
                if not Entity(ent).state.hasTargetOptions then
                    TriggerServerEvent('vr-target:setEntityHasOptions', netId)
                end
            end
            addTarget(store.entities[netId], options, resource)
        end
    end
end

function api.removeEntity(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = GetInvokingResource() or GetCurrentResourceName()
    for i = 1, #arr do
        local netId = arr[i]
        local list = store.entities[netId]
        if list then
            if options then removeTarget(list, options, resource) end
            if not options or #list == 0 then store.entities[netId] = nil end
        end
    end
end

RegisterNetEvent('vr-target:removeEntity', function(arr)
    if type(arr) ~= 'table' then return end
    for i = 1, #arr do store.entities[arr[i]] = nil end
end)

function api.addLocalEntity(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = owner()
    for i = 1, #arr do
        local ent = arr[i]
        if DoesEntityExist(ent) then
            store.localEntities[ent] = store.localEntities[ent] or {}
            addTarget(store.localEntities[ent], options, resource)
        else
            utils.warn(("No entity with id '%s' exists in %s."):format(tostring(ent), resource))
        end
    end
end

function api.removeLocalEntity(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local resource = owner()
    for i = 1, #arr do
        local ent = arr[i]
        local list = store.localEntities[ent]
        if list then
            if options then removeTarget(list, options, resource) end
            if not options or #list == 0 then store.localEntities[ent] = nil end
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        for ent in pairs(store.localEntities) do
            if not DoesEntityExist(ent) then store.localEntities[ent] = nil end
        end
    end
end)

local function purgeList(list, resource)
    for i = #list, 1, -1 do
        if list[i].resource == resource then table.remove(list, i) end
    end
end

local function purgeMap(map, resource)
    for key, list in pairs(map) do
        purgeList(list, resource)
        if #list == 0 then map[key] = nil end
    end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then return end
    purgeList(store.peds, resource)
    purgeList(store.vehicles, resource)
    purgeList(store.objects, resource)
    purgeList(store.players, resource)
    purgeList(store.global, resource)
    purgeMap(store.models, resource)
    purgeMap(store.entities, resource)
    purgeMap(store.localEntities, resource)
    for _, z in pairs(lib.zones.getAllZones()) do
        if z.resource == resource then z:remove() end
    end
end)

function api.getTargetOptions(entity, entityType, model)
    if not entity then return nil end
    if IsPedAPlayer(entity) then return { global = store.players } end
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)
    return {
        global = entityType == 1 and store.peds or entityType == 2 and store.vehicles or store.objects,
        model = store.models[model],
        entity = netId and store.entities[netId] or nil,
        localEntity = store.localEntities[entity],
    }
end
