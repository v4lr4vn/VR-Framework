-- Phone calls and texts as the player's game sees them.
-- The server runs the call. This side shows it, listens for the answer and hang up keys, and puts the phone to the ear while the call is active.
-- All of it works with the phone put away: the screen's call pill shows the call, and the keys answer and end it.
local State = Phone.State

local call = nil     -- the call as last heard from the server: { id, state, number, name }
local activeAt = 0   -- when it went active (game timer), for the clock on the screen
local watching = false

local function dead()
    local pd = Bridge.framework ~= 'none' and Bridge.playerData() or nil
    local md = pd and pd.metadata or {}
    return md.isdead == true or md.inlaststand == true or IsEntityDead(PlayerPedId())
end

-- A copy of the call for the screen. Used when the screen is opened in the middle of a call.
function Phone.callSnapshot()
    if not call then return nil end
    local out = { id = call.id, state = call.state, number = call.number, name = call.name, silent = call.silent }
    out.keys = { answer = Config.Phone.Calls.answerKey, hangup = Config.Phone.Calls.hangupKey }
    if call.state == 'active' then out.elapsed = math.floor((GetGameTimer() - activeAt) / 1000) end
    return out
end

-- Somebody who is dead cannot hold a phone call.
local function watch()
    if watching or not call then return end
    watching = true
    CreateThread(function()
        while call do
            if dead() then
                lib.callback.await('vr-phone:call:end', false, call.id)
                Wait(1500)
            end
            Wait(500)
        end
        watching = false
    end)
end

RegisterNetEvent('vr-phone:client:call', function(c)
    if type(c) ~= 'table' or type(c.state) ~= 'string' then return end

    if c.state == 'ended' then
        if call and call.id ~= c.id then return end -- an old call's last message
        call = nil
        Phone.setCall(false)
    else
        if not call or call.id ~= c.id then call = { id = c.id } end
        call.state = c.state
        if c.number then call.number = c.number end
        if c.name ~= nil or c.state == 'incoming' or c.state == 'calling' then call.name = c.name end
        call.silent = c.silent
        if c.state == 'active' then
            activeAt = GetGameTimer() - (tonumber(c.elapsed) or 0) * 1000
            Phone.setCall(true)
        else
            Phone.setCall(false)
        end
        watch()
    end
    c.keys = { answer = Config.Phone.Calls.answerKey, hangup = Config.Phone.Calls.hangupKey }
    SendNUIMessage({ action = 'call', data = c })
end)

-- A new text. The screen adds it to the open conversation, or counts it.
RegisterNetEvent('vr-phone:client:message', function(m)
    if type(m) ~= 'table' then return end
    SendNUIMessage({ action = 'message', data = m })
end)

local function fail(res)
    if type(res) == 'table' and res.ok == false and res.reason then
        local text = locale('err.' .. res.reason)
        if text and text ~= ('err.' .. res.reason) then Bridge.notify(text, 'error') end
    end
end

-- Answer: only when it is ringing for this player.
lib.addKeybind({
    name = 'vr_phone_answer',
    description = locale('keybindAnswer'),
    defaultKey = Config.Phone.Calls.answerKey,
    onPressed = function()
        if State.typing or not call or call.state ~= 'incoming' then return end
        fail(lib.callback.await('vr-phone:call:answer', false, call.id))
    end,
})

-- Hang up, decline, or cancel: whatever fits the call right now.
lib.addKeybind({
    name = 'vr_phone_hangup',
    description = locale('keybindHangup'),
    defaultKey = Config.Phone.Calls.hangupKey,
    onPressed = function()
        if State.typing or not call then return end
        fail(lib.callback.await('vr-phone:call:end', false, call.id))
    end,
})

Bridge.on('playerUnloaded', function()
    call = nil
    SendNUIMessage({ action = 'call', data = { state = 'ended', reason = 'hangup' } })
end)
