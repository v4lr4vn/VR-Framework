local State = Phone.State
local Prop = Phone.Prop

-- Controls that would fire a weapon, swing a fist or open the pause menu while the phone is out.
local BLOCKED = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 199, 200, 257, 263, 264 }

-- Camera look and the controls that turn it. Disabled while the phone is out so the mouse can use the phone.
local LOOK_LOCK = {
    1, 2, 3, 4, 5, 6,
    106,
    270, 271, 272, 273,
    14, 15, 16, 17, 99, 100,
}

local function loggedIn()
    if Bridge.framework == 'none' then return true end
    return Bridge.playerData() ~= nil
end

-- Focus goes to the phone screen. Movement keys stay with the game unless a text box is being typed in.
function Phone.applyFocus()
    -- With the camera on, the mouse belongs to the game.
    if not State.open or State.camera then return end
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.Phone.KeepInput and not State.typing)
end

local function startLoops()
    CreateThread(function()
        while State.open do
            if Config.Phone.KeepInput then
                for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
                if Config.Phone.LockLook and not State.camera then
                    for i = 1, #LOOK_LOCK do DisableControlAction(0, LOOK_LOCK[i], true) end
                end
            else
                DisableControlAction(0, 199, true)
                DisableControlAction(0, 200, true)
            end
            Wait(0)
        end
    end)

    CreateThread(function()
        local tick = 0
        while State.open do
            local pd = Bridge.framework ~= 'none' and Bridge.playerData() or nil
            local md = pd and pd.metadata or {}
            local down = (Bridge.framework ~= 'none' and not pd) or md.isdead or md.inlaststand or md.ishandcuffed or IsEntityDead(PlayerPedId())
            if down then
                Phone.close()
                break
            end
            if tick % 2 == 0 then
                SendNUIMessage({ action = 'clock', data = Phone.Clock.snapshot() })
            end
            tick = tick + 1
            Wait(500)
        end
    end)
end

function Phone.setFold(fold)
    if not Phone.FoldStates[fold] then return end
    State.fold = fold
end

-- Called by the calls module when a call starts or ends. While a call is active the phone is held to the ear.
-- With the screen closed the phone still goes to the ear, and goes away again when the call ends.
function Phone.setCall(active)
    active = active == true
    if State.call == active then return end
    State.call = active
    if State.open then
        Prop.refresh()
    elseif active then
        Prop.hold()
    else
        Prop.stop(true)
    end
end

-- Takes the phone out. appId (optional) opens that app straight away.
function Phone.open(appId)
    if State.open then return end
    if State.busy or not loggedIn() then return end
    if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end

    State.busy = true
    local payload = lib.callback.await('vr-phone:open', false)
    if type(payload) ~= 'table' or payload.error then
        State.busy = false
        local reason = type(payload) == 'table' and payload.error or 'timeout'
        Bridge.notify(locale('err.' .. reason), 'error')
        return
    end

    State.open = true
    State.typing = false
    State.fold = payload.fold
    payload.openApp = appId

    Prop.start()
    SendNUIMessage({ action = 'open', data = payload })
    -- A call that is going on is shown on the screen straight away.
    local snap = Phone.callSnapshot and Phone.callSnapshot()
    if snap then SendNUIMessage({ action = 'call', data = snap }) end
    Phone.applyFocus()
    startLoops()
    State.busy = false
end

function Phone.openApp(appId)
    if State.open then
        SendNUIMessage({ action = 'openApp', data = appId })
    else
        Phone.open(appId)
    end
end

function Phone.close()
    if not State.open then return end
    if State.camera then Phone.Camera.stop() end
    State.open = false
    State.typing = false
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    -- During a call the phone stays at the ear. It goes away when the call ends.
    if State.call then Prop.refresh() else Prop.stop(true) end
    TriggerServerEvent('vr-phone:server:closed')
end

lib.addKeybind({
    name = 'vr_phone_toggle',
    description = locale('keybind'),
    defaultKey = Config.Phone.OpenKey,
    onPressed = function()
        if State.open then Phone.close() else Phone.open() end
    end,
})

Bridge.on('playerUnloaded', function()
    State.call = false
    if State.open then Phone.close() else Prop.stop(false) end
end)

-- exports['vr-phone']:SetCallActive(true)  while a phone call is active, false when it ends.
-- Only during a call is the phone held to the ear. The phone's own calls already use this, so other scripts rarely need it.
exports('SetCallActive', function(active)
    Phone.setCall(active)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if State.open then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    Prop.stop(false)
end)
