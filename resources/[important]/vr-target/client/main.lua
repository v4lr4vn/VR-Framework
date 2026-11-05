local api = TargetApi
local store = TargetStore
local utils = TargetUtils

local active = false
local disabled = false
local nuiFocus = false
local hasTarget = false
local currentMenu
local menuHistory = {}
local menuChanged = false
local current = {}
local groups = {}
local nearbyZones = {}
local shown = {}
local signature = ''
local vec0 = vector3(0.0, 0.0, 0.0)
local mouseButton = TargetConfig.leftClick and 24 or 25

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setFocus(value)
    if value then SetCursorLocation(0.5, 0.5) end
    nuiFocus = value
    SetNuiFocus(value, value)
    SetNuiFocusKeepInput(value)
    send('target:cursor', value)
end

local function setActive(value)
    active = value
    if value then send('target:visible', true) end
end

local function boneMatch(option, entity, endCoords)
    local bone = option.bones
    if type(bone) == 'string' then
        local id = GetEntityBoneIndexByName(entity, bone)
        if id ~= -1 and #(endCoords - GetEntityBonePosition_2(entity, id)) <= 2 then return id end
        return false
    end
    local closest, closestDist
    for i = 1, #bone do
        local id = GetEntityBoneIndexByName(entity, bone[i])
        if id ~= -1 then
            local d = #(endCoords - GetEntityBonePosition_2(entity, id))
            if d <= (closestDist or 1) then
                closest, closestDist = id, d
            end
        end
    end
    return closest or false
end

local function shouldHide(option, distance, endCoords, entity, model)
    if option.menuName ~= currentMenu then return true end
    if distance > (option.distance or TargetConfig.defaultDistance) then return true end
    if option.groups and not utils.hasPlayerGotGroup(option.groups) then return true end
    if option.items and not utils.hasPlayerGotItems(option.items, option.anyItem) then return true end
    local bone
    if model and option.bones then
        bone = boneMatch(option, entity, endCoords)
        if not bone then return true end
    end
    if model and option.offset then
        local offset = option.offset
        if not option.absoluteOffset then
            local min, max = GetModelDimensions(model)
            offset = (max - min) * offset + min
        end
        offset = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
        if #(endCoords - offset) > (option.offsetSize or 1) then return true end
    end
    if option.canInteract then
        local ok, result = pcall(option.canInteract, entity, distance, endCoords, option.name, bone)
        return not ok or not result
    end
    return false
end

local function iconOf(icon)
    if type(icon) == 'table' then return ('%s fa-%s'):format(icon[1] or 'fas', icon[2] or 'circle') end
    return icon
end

local function collect(distance, endCoords, entity, model)
    local items = {}
    local sig = {}
    if currentMenu then
        items[1] = { t = '__back', i = 1, label = locale('go_back'), icon = 'fa-solid fa-circle-chevron-left' }
        sig[1] = '__back'
    end
    local function scan(key, list, dist, ent, mdl, zoneIndex)
        for i = 1, #list do
            local option = list[i]
            if not shouldHide(option, dist, endCoords, ent, mdl) then
                items[#items + 1] = {
                    t = key, i = i, z = zoneIndex,
                    label = tostring(option.label or option.name or ''),
                    icon = iconOf(option.icon),
                    iconColor = option.iconColor,
                }
                sig[#sig + 1] = ('%s:%s:%s:%s'):format(key, i, zoneIndex or 0, option.label or '')
            end
        end
    end
    scan('global', store.global, 0, entity, model)
    for _, key in ipairs({ 'target', 'model', 'entity', 'localEntity' }) do
        if groups[key] then scan(key, groups[key], distance, entity, model) end
    end
    for z = 1, #nearbyZones do
        scan('zone', nearbyZones[z].options or {}, distance, entity, nil, z)
    end
    return items, table.concat(sig, '|')
end

local function resolveGroups(entity, entityType, model)
    groups = {}
    if not entity or entity <= 0 then return end
    if entityType == 1 and IsPedAPlayer(entity) then
        groups.target = store.players
        return
    end
    groups.target = entityType == 1 and store.peds or entityType == 2 and store.vehicles or store.objects
    groups.model = store.models[model]
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)
    groups.entity = netId and store.entities[netId] or nil
    groups.localEntity = store.localEntities[entity]
end

local function entityTypeOf(entity)
    if not entity or entity == 0 then return 0 end
    local ok, t = pcall(GetEntityType, entity)
    return ok and t or 0
end

local function raycast(flag)
    return lib.raycast.fromCamera(flag, 4, 20)
end

local function stopTargeting()
    active = false
end

local function startTargeting()
    if disabled or active or IsNuiFocused() or IsPauseMenuActive() then return end
    setActive(true)
    currentMenu = nil
    menuHistory = {}
    signature = ''
    hasTarget = false

    CreateThread(function()
        local dict = lib.requestStreamedTextureDict('shared')
        local playerId = PlayerId()
        while active do
            utils.drawZoneSprites(dict, 'emptydot_32')
            DisablePlayerFiring(playerId, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            if nuiFocus then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                if not hasTarget or IsDisabledControlJustPressed(0, 25) and mouseButton ~= 25 then
                    setFocus(false)
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, mouseButton) then
                setFocus(true)
            end
            Wait(0)
        end
        SetStreamedTextureDictAsNoLongerNeeded(dict)
    end)

    local flag = 511
    local lastEntity, entityType, entityModel
    while active do
        if not nuiFocus and lib.progressActive() then
            active = false
            break
        end
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local hit, entity, endCoords = raycast(flag)
        endCoords = endCoords or vec0
        local distance = #(playerCoords - endCoords)
        entityType = entity ~= lastEntity and entityTypeOf(entity) or entityType

        if entityType == 0 then
            local altFlag = flag == 511 and 26 or 511
            local altHit, altEntity, altCoords = raycast(altFlag)
            altCoords = altCoords or vec0
            local altDistance = #(playerCoords - altCoords)
            if altDistance < distance then
                flag, hit, entity, endCoords, distance = altFlag, altHit, altEntity, altCoords, altDistance
                entityType = entityTypeOf(entity)
            end
        end

        if entity and entity > 0 and flag ~= 511 and entity ~= lastEntity and not HasEntityClearLosToEntity(entity, ped, 7) then
            entity = 0
            entityType = 0
        end

        local zonesChanged
        nearbyZones, zonesChanged = utils.getNearbyZones(endCoords)

        if entity ~= lastEntity or menuChanged then
            if entity ~= lastEntity then
                currentMenu = nil
                menuHistory = {}
            end
            entityModel = entity and entity > 0 and (select(2, pcall(GetEntityModel, entity))) or nil
            resolveGroups(entity, entityType, entityModel)
            if TargetConfig.debug then
                if lastEntity and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end
                if entity and entity > 0 and entityType ~= 1 then SetEntityDrawOutline(entity, true) end
            end
        end

        lastEntity = entity
        current.entity = entity
        current.coords = endCoords
        current.distance = distance

        local items, sig = collect(distance, endCoords, entity, entityModel)
        if sig ~= signature or zonesChanged or menuChanged then
            signature = sig
            shown = items
            hasTarget = #items > 0
            send('target:set', { items = items, menu = currentMenu ~= nil })
        end
        menuChanged = false

        if not hasTarget then flag = flag == 511 and 26 or 511 end
        Wait(hit and 50 or 100)
    end

    if TargetConfig.debug and lastEntity and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end
    if nuiFocus then setFocus(false) end
    send('target:visible', false)
    current = {}
    groups = {}
    shown = {}
    hasTarget = false
    signature = ''
    nearbyZones = {}
end

local function response(option, server)
    local out = {}
    for k, v in pairs(option) do
        local t = type(v)
        if t ~= 'function' and t ~= 'table' or k == 'args' or k == 'offset' or k == 'bones' then out[k] = v end
    end
    out.icon, out.groups, out.items, out.canInteract, out.onSelect, out.export, out.event, out.serverEvent, out.command = nil, nil, nil, nil, nil, nil, nil, nil, nil
    out.entity = current.entity
    out.zone = current.zone
    out.coords = current.coords
    out.distance = current.distance
    if server then
        local ent = out.entity
        out.entity = ent and ent ~= 0 and NetworkGetEntityIsNetworked(ent) and NetworkGetNetworkIdFromEntity(ent) or 0
    end
    return out
end

local function optionFor(item)
    if item.t == '__back' then return { name = 'builtin:goback', openMenu = true } end
    if item.t == 'zone' then
        local z = nearbyZones[item.z]
        return z and z.options and z.options[item.i], z
    end
    if item.t == 'global' then return store.global[item.i] end
    local list = groups[item.t]
    return list and list[item.i]
end

RegisterNUICallback('select', function(data, cb)
    cb(1)
    if not active or type(data) ~= 'table' then return end
    local index = tonumber(data.index)
    local item = index and shown[index]
    if not item then return end
    local option, zone = optionFor(item)
    if not option then return end

    if option.openMenu then
        if option.name == 'builtin:goback' then
            currentMenu = table.remove(menuHistory)
        else
            menuHistory[#menuHistory + 1] = currentMenu
            currentMenu = option.openMenu ~= 'home' and option.openMenu or nil
        end
        menuChanged = true
        signature = ''
    elseif nuiFocus then
        setFocus(false)
    end

    current.zone = zone and zone.id or nil

    if option.name ~= 'builtin:goback' then
        if option.onSelect then
            local arg = option.qtarget and current.entity or response(option)
            CreateThread(function()
                local ok, err = pcall(option.onSelect, arg)
                if not ok then utils.warn(('onSelect failed: %s'):format(err)) end
            end)
        elseif option.export then
            local res = option.resource or (zone and zone.resource)
            local resp = response(option)
            CreateThread(function()
                local ok, err = pcall(function() return exports[res][option.export](nil, resp) end)
                if not ok then utils.warn(('export %s failed: %s'):format(option.export, err)) end
            end)
        elseif option.event then
            TriggerEvent(option.event, response(option))
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, response(option, true))
        elseif option.command then
            ExecuteCommand(option.command)
        end
    end

    if not option.openMenu then
        active = false
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    if nuiFocus then setFocus(false) end
end)

local keybind = {
    name = 'vr_target',
    defaultKey = TargetConfig.key,
    defaultMapper = 'keyboard',
    description = locale('toggle_targeting'),
}

if TargetConfig.toggle then
    function keybind:onPressed()
        if active then return stopTargeting() end
        return startTargeting()
    end
else
    keybind.onPressed = startTargeting
    function keybind:onReleased()
        stopTargeting()
    end
end

lib.addKeybind(keybind)

function api.disableTargeting(value)
    if value then active = false end
    disabled = value == true
end

function api.isActive()
    return active
end

for name, fn in pairs(api) do
    exports(name, fn)
end
