Doors = nil
ClosestDoor = nil
DoorEntities = {}
PickingLock = false
NearbyDoors = {}

local TXD = 'vr_doorlock_icons'
local iconsReady = false

local function loadIcons()
    if iconsReady or not DoorConfig.icons then return end
    local txd = CreateRuntimeTxd(TXD)
    CreateRuntimeTextureFromImage(txd, 'locked', 'icons/locked.png')
    CreateRuntimeTextureFromImage(txd, 'unlocked', 'icons/unlocked.png')
    iconsReady = true
end

local function zoneName(coords)
    return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
end

local function applyRate(hash, door)
    if door.doorRate or not door.auto then
        DoorSystemSetAutomaticRate(hash, door.doorRate or 10.0, false, false)
    end
end

function RegisterDoor(door)
    door.zone = door.zone or zoneName(door.coords)
    if door.doors then
        for i = 1, 2 do
            local d = door.doors[i]
            AddDoorToSystem(d.hash, d.model, d.coords.x, d.coords.y, d.coords.z, false, false, false)
            DoorSystemSetDoorState(d.hash, 4, false, false)
            DoorSystemSetDoorState(d.hash, door.state, false, false)
            applyRate(d.hash, door)
        end
    else
        AddDoorToSystem(door.hash, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
        DoorSystemSetDoorState(door.hash, 4, false, false)
        DoorSystemSetDoorState(door.hash, door.state, false, false)
        applyRate(door.hash, door)
    end
end

local function releaseDoor(door)
    local hashes = door.doors and { door.doors[1].hash, door.doors[2].hash } or { door.hash }
    for _, hash in ipairs(hashes) do
        DoorSystemSetDoorState(hash, 4, false, false)
        DoorSystemSetDoorState(hash, 0, false, false)
    end
    for entity, id in pairs(DoorEntities) do
        if id == door.id then DoorEntities[entity] = nil end
    end
end

local function locate(door)
    if door.doors then
        for i = 1, 2 do
            local d = door.doors[i]
            if not d.entity and IsModelValid(d.model) then
                local entity = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 1.0, d.model, false, false, false)
                if entity ~= 0 then
                    d.entity = entity
                    DoorEntities[entity] = door.id
                end
            end
        end
    elseif not door.entity and IsModelValid(door.model) then
        local entity = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 1.0, door.model, false, false, false)
        if entity ~= 0 then
            local min, max = GetModelDimensions(door.model)
            local sumX, sumY = 0.0, 0.0
            for _, x in ipairs({ min.x, max.x }) do
                for _, y in ipairs({ min.y, max.y }) do
                    local p = GetOffsetFromEntityInWorldCoords(entity, x, y, min.z)
                    sumX, sumY = sumX + p.x, sumY + p.y
                end
            end
            door.coords = vector3(sumX / 4, sumY / 4, door.coords.z)
            door.entity = entity
            DoorEntities[entity] = door.id
        end
    end
end

local function forget(door)
    if door.doors then
        for i = 1, 2 do
            if door.doors[i].entity then DoorEntities[door.doors[i].entity] = nil end
            door.doors[i].entity = nil
        end
    elseif door.entity then
        DoorEntities[door.entity] = nil
        door.entity = nil
    end
end

local function playSound(door, state)
    if not door.distance or door.distance > 20 then return end
    local volume = (0.01 * GetProfileSetting(300)) / math.max(door.distance / 2, 0.5)
    if volume > 1 then volume = 1 end
    local sound = state == 0 and (door.unlockSound or DoorConfig.unlockSound) or (door.lockSound or DoorConfig.lockSound)
    SendNUIMessage({ action = 'playSound', data = { sound = sound, volume = volume } })
end

CreateThread(function()
    loadIcons()
    local data = lib.callback.await('vr-doorlock:getDoors', false)
    Doors = data or {}
    for _, door in pairs(Doors) do RegisterDoor(door) end
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local nearby = {}
        for _, door in pairs(Doors) do
            door.distance = #(coords - door.coords)
            if door.distance < 80 then
                locate(door)
                if door.distance < 20 then nearby[#nearby + 1] = door end
            else
                forget(door)
            end
        end
        NearbyDoors = nearby
        Wait(500)
    end
end)

RegisterNetEvent('vr-doorlock:setState', function(id, state, by, data)
    if not Doors then return end
    if data then
        Doors[id] = data
        RegisterDoor(data)
        if EditorRefresh then EditorRefresh(data) end
    end
    local door = Doors[id]
    if not door then return end
    door.state = state

    if DoorConfig.notify and by == cache.serverId then
        lib.notify({ type = 'success', icon = state == 0 and 'unlock' or 'lock', description = locale(state == 0 and 'unlocked_door' or 'locked_door') })
    end

    local hashes = door.doors and { door.doors[1].hash, door.doors[2].hash } or { door.hash }
    for _, hash in ipairs(hashes) do
        DoorSystemSetDoorState(hash, state, false, false)
        if door.holdOpen then DoorSystemSetHoldOpen(hash, state == 0) end
    end

    if state == 1 then
        local deadline = GetGameTimer() + 8000
        while door.state == 1 and GetGameTimer() < deadline do
            local closed = true
            for _, hash in ipairs(hashes) do
                if not IsDoorClosed(hash) then closed = false end
            end
            if closed then break end
            Wait(0)
        end
    end

    if door.state == state then playSound(door, state) end
end)

RegisterNetEvent('vr-doorlock:editDoorlock', function(id, data)
    if not Doors then return end
    local door = Doors[id]
    if not door then
        if data then
            Doors[id] = data
            RegisterDoor(data)
        end
        if EditorRefresh then EditorRefresh(data or id) end
        return
    end
    if data then
        data.zone = door.zone
        if door.doors and data.doors and (door.doors[1].hash ~= data.doors[1].hash) then releaseDoor(door) end
        Doors[id] = data
        RegisterDoor(data)
        if data.holdOpen then
            local hashes = data.doors and { data.doors[1].hash, data.doors[2].hash } or { data.hash }
            for _, hash in ipairs(hashes) do DoorSystemSetHoldOpen(hash, data.state == 0) end
        end
    else
        releaseDoor(door)
        Doors[id] = nil
        if ClosestDoor and ClosestDoor.id == id then ClosestDoor = nil end
    end
    if EditorRefresh then EditorRefresh(data or id) end
end)

lib.callback.register('vr-doorlock:passcode', function(id)
    local door = Doors and Doors[id]
    if not door or not door.passcode then return nil end
    local input = lib.inputDialog(locale('door_lock'), {
        { type = 'input', label = locale('passcode'), password = true, icon = 'lock', required = true },
    })
    return input and input[1] or nil
end)

local lastUse = 0

local function useClosestDoor()
    if not ClosestDoor or LocalPlayer.state.vrDoorBlock then return false end
    local now = GetGameTimer()
    if now - lastUse < 500 then return false end
    lastUse = now
    TriggerServerEvent('vr-doorlock:setState', ClosestDoor.id, ClosestDoor.state == 1 and 0 or 1)
    return true
end

CreateThread(function()
    local shown
    while true do
        local list = NearbyDoors
        local count = #list
        local best
        if count > 0 then
            local ratio = GetAspectRatio(true)
            for i = 1, count do
                local door = list[i]
                if door.distance and door.distance < door.maxDistance then
                    if not best or door.distance < best.distance then best = door end
                    if iconsReady and not door.hideUi then
                        local size = DoorConfig.iconSize
                        SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z, 0)
                        DrawSprite(TXD, door.state == 0 and 'unlocked' or 'locked', 0.0, 0.0, size, size * ratio, 0.0, 255, 255, 255, 235)
                        ClearDrawOrigin()
                    end
                end
            end
        end
        ClosestDoor = best

        if best then
            if DoorConfig.textUI and not best.hideUi and best.state ~= shown then
                lib.showTextUI(locale(best.state == 0 and 'lock_door' or 'unlock_door'), { icon = best.state == 0 and 'lock-open' or 'lock' })
                shown = best.state
            end
            if not PickingLock and not LocalPlayer.state.vrDoorBlock and IsDisabledControlJustReleased(0, DoorConfig.interactKey) then
                useClosestDoor()
            end
        elseif shown then
            lib.hideTextUI()
            shown = nil
        end

        Wait(count > 0 and 0 or 500)
    end
end)

local function doorFromEntity(data)
    local entity = type(data) == 'table' and data.entity or data
    if not entity then return nil end
    local id = DoorEntities[entity]
    return id and Doors and Doors[id] or nil
end

DoorFromEntity = doorFromEntity

exports('useClosestDoor', useClosestDoor)
exports('getClosestDoor', function() return ClosestDoor end)
exports('getDoorParts', function(id)
    local door = Doors and Doors[id]
    if not door then return nil end
    locate(door)
    local parts = {}
    if door.doors then
        for i = 1, 2 do
            local d = door.doors[i]
            parts[#parts + 1] = { hash = d.hash, entity = d.entity, model = d.model, coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z } }
        end
    else
        parts[1] = { hash = door.hash, entity = door.entity, model = door.model, coords = { x = door.coords.x, y = door.coords.y, z = door.coords.z } }
    end
    return parts
end)
exports('getClosestDoorId', function() return ClosestDoor and ClosestDoor.id or nil end)
exports('getDoorIdFromEntity', function(entity)
    local door = doorFromEntity(entity)
    return door and door.id or nil
end)

local oxState = GetResourceState('ox_doorlock')
if oxState == 'missing' or oxState == 'stopped' or oxState == 'uninitialized' or oxState == 'unknown' then
    local aliases = {
        useClosestDoor = useClosestDoor,
        getClosestDoor = function() return ClosestDoor end,
        getClosestDoorId = function() return ClosestDoor and ClosestDoor.id or nil end,
        getDoorIdFromEntity = function(entity)
            local door = doorFromEntity(entity)
            return door and door.id or nil
        end,
    }
    for name, fn in pairs(aliases) do
        AddEventHandler(('__cfx_export_ox_doorlock_%s'):format(name), function(setCB) setCB(fn) end)
    end
end
