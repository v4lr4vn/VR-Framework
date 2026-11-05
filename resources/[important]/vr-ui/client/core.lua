UI = {}

local holders = {}
local looping = false

local function anyKeep()
    for _, h in pairs(holders) do
        if h.keep then return true end
    end
    return false
end

local function controlLoop()
    if looping then return end
    looping = true
    CreateThread(function()
        local playerId = PlayerId()
        while looping do
            for _, h in pairs(holders) do
                if h.keep and h.controls then
                    for i = 1, #h.controls do DisableControlAction(0, h.controls[i], true) end
                end
                if h.keep and h.noFire then DisablePlayerFiring(playerId, true) end
            end
            Wait(0)
        end
    end)
end

function UI.applyFocus()
    local any, cursor, keep = false, false, true
    for _, h in pairs(holders) do
        any = true
        if h.cursor then cursor = true end
        if not h.keep then keep = false end
    end
    if any then
        SetNuiFocus(true, cursor)
        SetNuiFocusKeepInput(keep)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    if any and anyKeep() then controlLoop() else looping = false end
end

function UI.focus(name, cursor, keep, controls, noFire)
    holders[name] = { cursor = cursor == true, keep = keep == true, controls = controls, noFire = noFire }
    UI.applyFocus()
end

function UI.release(name)
    if not holders[name] then return end
    holders[name] = nil
    UI.applyFocus()
end

function UI.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function UI.owner()
    return GetInvokingResource() or GetCurrentResourceName()
end

function UI.call(fn, ...)
    if fn == nil then return end
    local args = table.pack(...)
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then print(('^1[vr-ui] callback error: %s^0'):format(err)) end
    end)
end

function UI.text(value, max)
    if value == nil then return nil end
    local s = tostring(value)
    if s == '' then return nil end
    if max and #s > max then s = s:sub(1, max) end
    return s
end

local stopHandlers = {}

function UI.onOwnerStop(fn)
    stopHandlers[#stopHandlers + 1] = fn
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        return
    end
    for i = 1, #stopHandlers do pcall(stopHandlers[i], resource) end
end)

RegisterNUICallback('config', function(_, cb)
    cb(UIConfig)
end)
