local RES = GetCurrentResourceName()
local notes = {}      -- id -> { x, y, z, entity }
local byEntity = {}   -- entity -> id
local busy = false

local ERRORS = {
    slow_down = 'Slow down a little', no_player = 'Choose a character first', not_writing = 'Use the notepad first',
    no_item = 'You need a notepad for that', bad_text = 'Write something first', too_many_mine = 'You already have enough notes out',
    too_many = 'There are too many notes out already', gone = 'That note is gone', too_far = 'You are too far away',
}

local function notify(text, kind)
    lib.notify({ title = 'Notepad', description = text, type = kind or 'inform' })
end

local function call(name, ...)
    local res = lib.callback.await(RES .. ':' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'slow_down' end
    if res.ok then return true, res.data end
    return false, res.error
end

local function remove(id)
    local n = notes[id]
    if not n then return end
    if n.entity and DoesEntityExist(n.entity) then
        byEntity[n.entity] = nil
        DeleteEntity(n.entity)
    end
    notes[id] = nil
end

RegisterNetEvent(RES .. ':client:add', function(n)
    if type(n) == 'table' and n.id then notes[n.id] = { x = n.x, y = n.y, z = n.z } end
end)

RegisterNetEvent(RES .. ':client:remove', function(id) remove(id) end)

RegisterNetEvent(RES .. ':client:write', function()
    if busy then return end
    busy = true
    local input = lib.inputDialog('Write a note', {
        { type = 'textarea', label = 'Note', description = 'A link to a picture shows up as the picture', required = true, max = Config.MaxLength, autosize = true },
        { type = 'checkbox', label = 'Leave it anonymous', checked = true },
    })
    if not input or not input[1] or tostring(input[1]) == '' then
        busy = false
        return
    end
    local done = lib.progressBar({
        duration = (Config.WriteSeconds or 4) * 1000, label = 'Writing', useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 },
        prop = { model = 'prop_notepad_01', bone = 18905, pos = vec3(0.1, 0.02, 0.05), rot = vec3(10.0, 0.0, 0.0) },
    })
    ClearPedTasks(PlayerPedId())
    if done then
        local ok, err = call('create', tostring(input[1]), input[2] == true)
        if ok then notify('You left a note here', 'success') else notify(ERRORS[err] or 'Something went wrong', 'error') end
    end
    busy = false
end)

local function read(id)
    local ok, data = call('read', id)
    if not ok then return notify(ERRORS[data] or 'Something went wrong', 'error') end
    local content = data.text
    if data.image then content = ('%s\n\n![](%s)'):format(content, data.image) end
    lib.alertDialog({
        header = data.author and ('Note from %s'):format(data.author) or 'A note',
        content = content, centered = true, size = 'md',
    })
end

local function tear(id)
    local ok, err = call('destroy', id)
    if ok then notify('You tore it up', 'inform') else notify(ERRORS[err] or 'Something went wrong', 'error') end
end

local function idOf(data)
    return data and data.entity and byEntity[data.entity] or nil
end

CreateThread(function()
    Wait(2500)
    for _, n in ipairs(lib.callback.await(RES .. ':list', false) or {}) do notes[n.id] = { x = n.x, y = n.y, z = n.z } end
    pcall(Bridge.target.addModel, Config.Prop, {
        { name = RES .. '_read', icon = 'fa-solid fa-note-sticky', label = 'Read the note', distance = 2.0,
          canInteract = function(entity) return byEntity[entity] ~= nil end,
          onSelect = function(data) local id = idOf(data) if id then read(id) end end },
        { name = RES .. '_tear', icon = 'fa-solid fa-trash-can', label = 'Tear it up', distance = 2.0,
          canInteract = function(entity) return byEntity[entity] ~= nil end,
          onSelect = function(data) local id = idOf(data) if id then tear(id) end end },
    })
    local model = joaat(Config.Prop)
    while true do
        Wait(1500)
        local here = GetEntityCoords(PlayerPedId())
        local range = Config.StreamDistance or 60.0
        for id, n in pairs(notes) do
            local far = #(here - vec3(n.x, n.y, n.z)) > range
            if far and n.entity then
                byEntity[n.entity] = nil
                if DoesEntityExist(n.entity) then DeleteEntity(n.entity) end
                n.entity = nil
            elseif not far and not (n.entity and DoesEntityExist(n.entity)) then
                lib.requestModel(model)
                local obj = CreateObject(model, n.x, n.y, n.z, false, false, false)
                if obj and obj ~= 0 then
                    SetEntityCoordsNoOffset(obj, n.x, n.y, n.z - 0.9, false, false, false)
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    SetEntityCollision(obj, false, false)
                    n.entity = obj
                    byEntity[obj] = id
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    for id in pairs(notes) do remove(id) end
end)
