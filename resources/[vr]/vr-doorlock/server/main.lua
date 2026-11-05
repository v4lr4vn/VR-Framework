local db = Bridge.db
local doors = {}
local isLoaded = false
local hooks = {}
local hookSeq = 0
local lockpickSessions = {}
local lastRequest = {}

local SOUNDS = {}
for _, name in ipairs(DoorConfig.sounds) do SOUNDS[name] = true end

local function vec(c)
    if not c then return nil end
    return vector3((c.x or c[1] or 0.0) + 0.0, (c.y or c[2] or 0.0) + 0.0, (c.z or c[3] or 0.0) + 0.0)
end

local function midpoint(double)
    local a, b = vec(double[1].coords), vec(double[2].coords)
    return a - ((a - b) / 2)
end

local function forClients(door)
    if type(door) ~= 'table' or not door.passcode then return door end
    local copy = {}
    for k, v in pairs(door) do copy[k] = v end
    copy.passcode = true
    return copy
end

local function encode(door)
    local double = door.doors
    return json.encode({
        auto = door.auto,
        autolock = door.autolock,
        coords = door.coords and { x = door.coords.x, y = door.coords.y, z = door.coords.z },
        doors = double and {
            { coords = { x = double[1].coords.x, y = double[1].coords.y, z = double[1].coords.z }, heading = double[1].heading, model = double[1].model },
            { coords = { x = double[2].coords.x, y = double[2].coords.y, z = double[2].coords.z }, heading = double[2].heading, model = double[2].model },
        } or nil,
        characters = door.characters,
        groups = door.groups,
        heading = door.heading,
        items = door.items,
        lockpick = door.lockpick,
        hideUi = door.hideUi,
        holdOpen = door.holdOpen,
        lockSound = door.lockSound,
        maxDistance = door.maxDistance,
        doorRate = door.doorRate,
        model = door.model,
        state = door.state,
        unlockSound = door.unlockSound,
        passcode = door.passcode,
        lockpickDifficulty = door.lockpickDifficulty,
    })
end

local function normalise(id, door, name)
    door.id = id
    door.name = name or door.name or ('door_%s'):format(id)
    if door.doors then
        for i = 1, 2 do
            door.doors[i].hash = joaat(('vr_door_%s_%s'):format(id, i))
            door.doors[i].coords = vec(door.doors[i].coords)
        end
        door.coords = vec(door.coords) or midpoint(door.doors)
    else
        door.hash = joaat(('vr_door_%s'):format(id))
        door.coords = vec(door.coords)
    end
    door.state = door.state == 0 and 0 or 1
    door.maxDistance = tonumber(door.maxDistance) or 2.0
    if door.lockSound and not SOUNDS[door.lockSound] then door.lockSound = nil end
    if door.unlockSound and not SOUNDS[door.unlockSound] then door.unlockSound = nil end
    if type(door.items) == 'table' and type(door.items[1]) == 'string' then
        for i = 1, #door.items do door.items[i] = { name = door.items[i], remove = false } end
    end
    doors[id] = door
    return door
end

local function publicDoor(door)
    door = type(door) == 'table' and door or doors[door]
    if not door then return false end
    return {
        id = door.id,
        name = door.name,
        state = door.state,
        coords = door.coords,
        characters = door.characters,
        groups = door.groups,
        items = door.items,
        maxDistance = door.maxDistance,
    }
end

local function triggerHooks(event, payload)
    local list = hooks[event]
    if not list then return nil end
    local response
    for i = 1, #list do
        local hook = list[i]
        if not hook.nameFilter or (payload.door.name and payload.door.name:match(hook.nameFilter)) then
            local ok, result = pcall(hook.fn, payload)
            if not ok then
                print(('^1[vr-doorlock] hook %s:%s failed: %s^0'):format(hook.resource, event, result))
            elseif result ~= nil then
                response = result
            end
        end
    end
    return response
end

local function hasItem(src, items, removeAll)
    for i = 1, #items do
        local item = items[i]
        local name = type(item) == 'table' and item.name or item
        local metadata = type(item) == 'table' and item.metadata or nil
        if Bridge.inventory.count(src, name, metadata) > 0 then
            if removeAll or (type(item) == 'table' and item.remove) then
                Bridge.inventory.remove(src, name, 1, metadata)
            end
            return name
        end
    end
    return nil
end

local function isAuthorised(src, door, lockpick)
    if DoorConfig.playerAceAuthorised and IsPlayerAceAllowed(src, 'command.doorlock') then return true end
    if IsPlayerAceAllowed(src, ('doorlock.%s'):format(door.name)) then return true end

    local player = Bridge.player(src)
    local authorised = door.passcode and true or false
    local passcodeNeeded = door.passcode ~= nil

    if player then
        if lockpick then
            return hasItem(src, DoorConfig.lockpickItems) ~= nil
        end
        if door.characters then
            for _, cid in ipairs(door.characters) do
                if cid == player.cid then
                    authorised = true
                    passcodeNeeded = false
                    break
                end
            end
        end
        if passcodeNeeded or not authorised then
            if door.groups then
                authorised = Bridge.hasGroup(src, door.groups) and true or nil
            end
            if not authorised and door.items then
                authorised = hasItem(src, door.items) or nil
            end
        end
    end

    if authorised ~= nil and passcodeNeeded and door.passcode then
        local entered = lib.callback.await('vr-doorlock:passcode', src, door.id)
        authorised = entered ~= nil and tostring(entered) == tostring(door.passcode)
    end

    local hook = triggerHooks('doorAuthorization', { source = src, door = door, lockpick = lockpick, authorised = authorised })
    if hook == nil then return authorised end
    return authorised or hook
end

local function broadcastState(door, src)
    TriggerClientEvent('vr-doorlock:setState', -1, door.id, door.state, src)
end

local function setDoorState(id, state, lockpick, src)
    local door = doors[id]
    state = (state == 1 or state == 0) and state or (state and 1 or 0)
    if not door then return false end
    src = tonumber(src)
    if src and src <= 0 then src = nil end

    local authorised = true
    if src then
        authorised = isAuthorised(src, door, lockpick)
    end

    if authorised then
        door.state = state
        broadcastState(door, src)
        if door.autolock and state == 0 then
            local stamp = GetGameTimer()
            door.__unlockedAt = stamp
            SetTimeout(math.floor(tonumber(door.autolock) or 0) * 1000, function()
                if door.state ~= 1 and door.__unlockedAt == stamp and doors[door.id] == door then
                    door.state = 1
                    broadcastState(door)
                    TriggerEvent('vr-doorlock:stateChanged', nil, door.id, true)
                end
            end)
        end
        TriggerEvent('vr-doorlock:stateChanged', src, door.id, state == 1, type(authorised) == 'string' and authorised or nil)
        return true
    end

    if src then
        lib.notify(src, { type = 'error', icon = 'lock', description = locale(state == 0 and 'cannot_unlock' or 'cannot_lock') })
    end
    return false
end

local function near(src, door, extra)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not door.coords then return false end
    return #(GetEntityCoords(ped) - door.coords) <= (door.maxDistance or 2.0) + (extra or DoorConfig.maxStateDistance)
end

RegisterNetEvent('vr-doorlock:setState', function(id, state, lockpick)
    local src = source
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 400 then return end
    lastRequest[src] = now
    local door = type(id) == 'number' and doors[id]
    if not door or not near(src, door) then return end
    if lockpick then
        local session = lockpickSessions[src]
        lockpickSessions[src] = nil
        if not door.lockpick or not session or session.id ~= id or now - session.at < 1500 or now - session.at > 60000 then return end
        if not DoorConfig.canPickUnlockedDoors and door.state == 0 then return end
    end
    setDoorState(id, state, lockpick == true, src)
end)

RegisterNetEvent('vr-doorlock:startLockpick', function(id)
    local src = source
    local door = type(id) == 'number' and doors[id]
    if not door or not door.lockpick or not near(src, door, 2.0) then return end
    lockpickSessions[src] = { id = id, at = GetGameTimer() }
end)

RegisterNetEvent('vr-doorlock:breakLockpick', function()
    local src = source
    hasItem(src, DoorConfig.lockpickItems, true)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
    lockpickSessions[source] = nil
end)

local function isAdmin(src)
    return IsPlayerAceAllowed(src, ('command.%s'):format(DoorConfig.command))
end

local function sanitise(data)
    if type(data) ~= 'table' then return nil end
    local out = {}
    out.name = type(data.name) == 'string' and data.name:sub(1, 50) or nil
    out.state = data.state == 0 and 0 or 1
    out.auto = data.auto == true or nil
    out.autolock = tonumber(data.autolock) and math.max(1, math.floor(tonumber(data.autolock))) or nil
    out.lockpick = data.lockpick == true or nil
    out.hideUi = data.hideUi == true or nil
    out.holdOpen = data.holdOpen == true or nil
    out.maxDistance = tonumber(data.maxDistance) and math.max(0.5, math.min(20.0, tonumber(data.maxDistance) + 0.0)) or 2.0
    out.doorRate = tonumber(data.doorRate) and math.max(0.0, math.min(10.0, tonumber(data.doorRate) + 0.0)) or nil
    out.lockSound = SOUNDS[data.lockSound] and data.lockSound or nil
    out.unlockSound = SOUNDS[data.unlockSound] and data.unlockSound or nil
    if data.passcode ~= nil and data.passcode ~= '' and data.passcode ~= false then out.passcode = data.passcode end
    if type(data.characters) == 'table' and #data.characters > 0 then
        out.characters = {}
        for _, c in ipairs(data.characters) do if type(c) == 'string' and c ~= '' then out.characters[#out.characters + 1] = c end end
        if #out.characters == 0 then out.characters = nil end
    end
    if type(data.groups) == 'table' and next(data.groups) then
        out.groups = {}
        for k, v in pairs(data.groups) do
            if type(k) == 'string' and k ~= '' then out.groups[k] = math.max(0, math.floor(tonumber(v) or 0)) end
        end
        if not next(out.groups) then out.groups = nil end
    end
    if type(data.items) == 'table' and #data.items > 0 then
        out.items = {}
        for _, it in ipairs(data.items) do
            local name = type(it) == 'table' and it.name or it
            if type(name) == 'string' and name ~= '' then
                out.items[#out.items + 1] = { name = name, remove = type(it) == 'table' and it.remove == true or false, metadata = type(it) == 'table' and type(it.metadata) == 'table' and it.metadata or nil }
            end
        end
        if #out.items == 0 then out.items = nil end
    end
    if type(data.lockpickDifficulty) == 'table' and #data.lockpickDifficulty > 0 then
        out.lockpickDifficulty = {}
        for _, d in ipairs(data.lockpickDifficulty) do
            if d == 'easy' or d == 'medium' or d == 'hard' then out.lockpickDifficulty[#out.lockpickDifficulty + 1] = d end
        end
        if #out.lockpickDifficulty == 0 then out.lockpickDifficulty = nil end
    end
    if type(data.doors) == 'table' and data.doors[1] and data.doors[2] then
        out.doors = {}
        for i = 1, 2 do
            local d = data.doors[i]
            local c = vec(d.coords)
            if not c or type(d.model) ~= 'number' then return nil end
            out.doors[i] = { coords = c, heading = tonumber(d.heading) or 0, model = d.model }
        end
    else
        out.coords = vec(data.coords)
        out.model = type(data.model) == 'number' and data.model or nil
        out.heading = tonumber(data.heading) or 0
        if not out.coords or not out.model then return nil end
    end
    return out
end

local function insertDoor(data)
    if not data.coords and data.doors then data.coords = midpoint(data.doors) end
    data.coords = vec(data.coords)
    if not data.name then data.name = ('%.1f, %.1f, %.1f'):format(data.coords.x, data.coords.y, data.coords.z) end
    local id = db.insert('INSERT INTO vr_doorlock (name, data) VALUES (?, ?)', { data.name, encode(data) })
    if not id then return nil end
    local door = normalise(id, data, data.name)
    TriggerClientEvent('vr-doorlock:setState', -1, door.id, door.state, false, forClients(door))
    return door
end

local function removeDoor(id)
    if not doors[id] then return false end
    db.update('DELETE FROM vr_doorlock WHERE id = ?', { id })
    doors[id] = nil
    TriggerClientEvent('vr-doorlock:editDoorlock', -1, id, nil)
    return true
end

RegisterNetEvent('vr-doorlock:editDoorlock', function(id, data)
    local src = source
    if not isAdmin(src) then return end
    if id ~= false and id ~= nil and type(id) ~= 'number' then return end
    if id and not doors[id] then return end
    if data == nil then
        if id then removeDoor(id) end
        return
    end
    local keepPass = data.passcode == true or data.passcode == 'true'
    local clean = sanitise(data)
    if not clean then
        lib.notify(src, { type = 'error', description = locale('invalid_door') })
        return
    end
    if id then
        if keepPass then clean.passcode = doors[id].passcode end
        if not clean.coords and clean.doors then clean.coords = midpoint(clean.doors) end
        if not clean.name then clean.name = doors[id].name end
        db.update('UPDATE vr_doorlock SET name = ?, data = ? WHERE id = ?', { clean.name, encode(clean), id })
        local door = normalise(id, clean, clean.name)
        TriggerClientEvent('vr-doorlock:editDoorlock', -1, id, forClients(door))
    else
        insertDoor(clean)
    end
end)

RegisterNetEvent('vr-doorlock:teleportToDoor', function(id)
    local src = source
    if not isAdmin(src) then return end
    local door = doors[id]
    if not door or not door.coords then return end
    SetEntityCoords(GetPlayerPed(src), door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
end)

lib.callback.register('vr-doorlock:getDoors', function()
    while not isLoaded do Wait(100) end
    local list = {}
    for id, door in pairs(doors) do list[id] = forClients(door) end
    return list
end)

lib.addCommand(DoorConfig.command, {
    help = locale('create_modify_lock'),
    params = { { name = 'closest', help = locale('command_closest'), optional = true } },
    restricted = DoorConfig.commandPrincipal,
}, function(src, args)
    if src <= 0 then return end
    TriggerClientEvent('vr-doorlock:openEditor', src, args.closest ~= nil)
end)

local function migrate()
    db.query([[CREATE TABLE IF NOT EXISTS `vr_doorlock` (
        `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
        `name` varchar(50) NOT NULL,
        `data` longtext NOT NULL,
        PRIMARY KEY (`id`)
    )]])
    local count = tonumber(db.scalar('SELECT COUNT(*) FROM vr_doorlock')) or 0
    if count == 0 and db.tableExists('ox_doorlock') then
        local moved = db.update('INSERT INTO vr_doorlock (id, name, data) SELECT id, name, data FROM ox_doorlock')
        if moved and moved > 0 then
            print(('^2[vr-doorlock] imported %s doors from ox_doorlock^0'):format(moved))
        end
    end
end

CreateThread(function()
    migrate()
    local rows = db.query('SELECT id, name, data FROM vr_doorlock') or {}
    for i = 1, #rows do
        local ok, data = pcall(json.decode, rows[i].data)
        if ok and type(data) == 'table' then
            normalise(rows[i].id, data, rows[i].name)
        end
    end
    isLoaded = true
    TriggerEvent('vr-doorlock:loaded')
end)

local api = {}

api.getDoor = publicDoor

function api.getAllDoors()
    local out = {}
    for _, door in pairs(doors) do out[#out + 1] = publicDoor(door) end
    return out
end

function api.getDoorFromName(name)
    for _, door in pairs(doors) do
        if door.name == name then return publicDoor(door) end
    end
end

function api.editDoor(id, data)
    local door = doors[id]
    if not door or type(data) ~= 'table' then return end
    for k, v in pairs(data) do
        if k ~= 'id' then
            local current = door[k]
            if current ~= nil and v ~= '' and type(current) ~= type(v) then
                error(("Expected '%s' for door.%s, received %s (%s)"):format(type(current), k, type(v), tostring(v)))
            end
            door[k] = v ~= '' and v or nil
        end
    end
    if type(door.characters) == 'table' and #door.characters == 0 then door.characters = nil end
    db.update('UPDATE vr_doorlock SET name = ?, data = ? WHERE id = ?', { door.name, encode(door), id })
    TriggerClientEvent('vr-doorlock:editDoorlock', -1, id, forClients(door))
end

function api.setDoorState(id, state)
    return setDoorState(id, state)
end

function api.registerHook(event, fn, options)
    hooks[event] = hooks[event] or {}
    hookSeq = hookSeq + 1
    local hook = { fn = fn, resource = GetInvokingResource() or 'vr-doorlock', id = hookSeq }
    if type(options) == 'table' then
        hook.nameFilter = options.doorFilter or options.nameFilter
    end
    hooks[event][#hooks[event] + 1] = hook
    return hookSeq
end

function api.removeResourceHook(id)
    local resource = GetInvokingResource() or 'vr-doorlock'
    for event, list in pairs(hooks) do
        for i = #list, 1, -1 do
            if list[i].resource == resource and (not id or list[i].id == id) then table.remove(list, i) end
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    for _, list in pairs(hooks) do
        for i = #list, 1, -1 do
            if list[i].resource == resource then table.remove(list, i) end
        end
    end
end)

function api.vrCreateDoor(data)
    if type(data) ~= 'table' then return nil end
    while not isLoaded do Wait(100) end
    local clean = sanitise(data)
    if not clean then return nil end
    clean.name = data.name and tostring(data.name):sub(1, 50) or clean.name
    if data.passcode then clean.passcode = data.passcode end
    local door = insertDoor(clean)
    return door and door.id or nil
end

api.createDoor = api.vrCreateDoor

function api.vrDeleteDoor(id)
    return removeDoor(id)
end

api.deleteDoor = api.vrDeleteDoor

for name, fn in pairs(api) do
    exports(name, fn)
end

local state = GetResourceState('ox_doorlock')
if state == 'missing' or state == 'stopped' or state == 'uninitialized' or state == 'unknown' then
    for name, fn in pairs(api) do
        AddEventHandler(('__cfx_export_ox_doorlock_%s'):format(name), function(setCB) setCB(fn) end)
    end
end
