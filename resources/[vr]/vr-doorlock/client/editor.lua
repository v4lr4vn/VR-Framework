local open = false
local picking = false
local TEMP_HASH = joaat('vr_doorlock_temp')

local function listItem(door)
    return {
        id = door.id,
        name = door.name,
        zone = door.zone,
        state = door.state,
        double = door.doors ~= nil,
        coords = door.coords and { x = door.coords.x, y = door.coords.y, z = door.coords.z },
        model = door.model,
        heading = door.heading,
        doors = door.doors and {
            { coords = { x = door.doors[1].coords.x, y = door.doors[1].coords.y, z = door.doors[1].coords.z }, model = door.doors[1].model, heading = door.doors[1].heading },
            { coords = { x = door.doors[2].coords.x, y = door.doors[2].coords.y, z = door.doors[2].coords.z }, model = door.doors[2].model, heading = door.doors[2].heading },
        } or nil,
        auto = door.auto,
        autolock = door.autolock,
        lockpick = door.lockpick,
        lockpickDifficulty = door.lockpickDifficulty,
        hideUi = door.hideUi,
        holdOpen = door.holdOpen,
        maxDistance = door.maxDistance,
        doorRate = door.doorRate,
        lockSound = door.lockSound,
        unlockSound = door.unlockSound,
        passcode = door.passcode and true or nil,
        characters = door.characters,
        groups = door.groups,
        items = door.items,
        distance = door.distance and math.floor(door.distance * 10 + 0.5) / 10 or nil,
    }
end

local function allItems()
    local out = {}
    for _, door in pairs(Doors or {}) do out[#out + 1] = listItem(door) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function EditorRefresh(data)
    if not open then return end
    if type(data) == 'table' then
        SendNUIMessage({ action = 'door:update', data = listItem(data) })
    else
        SendNUIMessage({ action = 'door:remove', data = data })
    end
end

local function close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'editor:close' })
end

RegisterNetEvent('vr-doorlock:openEditor', function(closest)
    if source == '' or picking then return end
    open = true
    SendNUIMessage({
        action = 'editor:open',
        data = {
            doors = allItems(),
            sounds = DoorConfig.sounds,
            defaults = { lockSound = DoorConfig.lockSound, unlockSound = DoorConfig.unlockSound },
            selected = closest and ClosestDoor and ClosestDoor.id or nil,
        },
    })
    SetNuiFocus(true, true)
end)

local function outline(entity, state)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityDrawOutlineColor(245, 165, 36, 255)
        SetEntityDrawOutline(entity, state)
    end
end

local function capture(entity)
    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)
    AddDoorToSystem(TEMP_HASH, model, coords.x, coords.y, coords.z, false, false, false)
    DoorSystemSetDoorState(TEMP_HASH, 4, false, false)
    coords = GetEntityCoords(entity)
    RemoveDoorFromSystem(TEMP_HASH)
    return {
        entity = entity,
        model = model,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = math.floor(GetEntityHeading(entity) + 0.5),
    }
end

local function pickDoors(count)
    picking = true
    lib.showTextUI(locale('add_door_textui'), { icon = 'door-closed' })
    local picked = {}
    local last = 0
    local playerId = PlayerId()
    while #picked < count do
        DisablePlayerFiring(playerId, true)
        DisableControlAction(0, 25, true)
        local hit, entity, coords = lib.raycast.fromCamera(1 | 16, 4, 15)
        entity = entity or 0
        if last ~= entity and (not picked[1] or picked[1].entity ~= last) then outline(last, false) end
        last = entity
        if hit and coords then
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12, 245, 165, 36, 160, false, false, 0, true, false, false, false)
        end
        local valid = hit and entity > 0 and GetEntityType(entity) == 3 and (not picked[1] or picked[1].entity ~= entity) and not DoorFromEntity(entity)
        if valid then
            outline(entity, true)
            if IsDisabledControlJustPressed(0, 24) then
                picked[#picked + 1] = capture(entity)
            end
        end
        if IsDisabledControlJustPressed(0, 25) then
            outline(entity, false)
            if not picked[1] then
                lib.hideTextUI()
                picking = false
                return nil
            end
            outline(picked[1].entity, false)
            picked = {}
        end
        Wait(0)
    end
    lib.hideTextUI()
    for i = 1, #picked do
        outline(picked[i].entity, false)
        picked[i].entity = nil
    end
    picking = false
    return picked
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    close()
end)

RegisterNUICallback('save', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    if data.id then
        TriggerServerEvent('vr-doorlock:editDoorlock', data.id, data)
        return
    end
    close()
    CreateThread(function()
        local count = data.double and 2 or 1
        local picked = pickDoors(count)
        if not picked then return end
        if count == 2 then
            data.doors = picked
        else
            data.model = picked[1].model
            data.coords = picked[1].coords
            data.heading = picked[1].heading
        end
        data.double = nil
        TriggerServerEvent('vr-doorlock:editDoorlock', false, data)
        lib.notify({ type = 'success', icon = 'door-closed', description = locale('door_created') })
    end)
end)

RegisterNUICallback('delete', function(data, cb)
    cb(1)
    local id = type(data) == 'table' and tonumber(data.id) or tonumber(data)
    if id then TriggerServerEvent('vr-doorlock:editDoorlock', id) end
end)

RegisterNUICallback('teleport', function(data, cb)
    cb(1)
    local id = type(data) == 'table' and tonumber(data.id) or tonumber(data)
    if not id then return end
    close()
    TriggerServerEvent('vr-doorlock:teleportToDoor', id)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
