local started = {}
local hintShown = false

local function driving()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function hideHint()
    if hintShown then
        hintShown = false
        lib.hideTextUI()
    end
end

local function showHint()
    if hintShown then return end
    hintShown = true
    local key = Keys.hotwireBind and Keys.hotwireBind:getCurrentKey() or ''
    if key == '' then
        lib.showTextUI('No keys. Set a key for Hotwire in /keybinds', { icon = 'fa-solid fa-key' })
    else
        lib.showTextUI(('No keys  ·  [%s] Hotwire'):format(key), { icon = 'fa-solid fa-key' })
    end
end

function Keys.toggleEngine()
    local veh = driving()
    if not veh then return end
    if not Keys.has(veh) then return Keys.notify(Keys.errorText('no_keys'), 'error') end
    local on = GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, not on, false, true)
    Keys.notify(on and 'Engine off' or 'Engine on', 'inform')
end

lib.addKeybind({
    name = 'engine',
    description = 'Start or stop the engine',
    defaultKey = 'G',
    onPressed = function() Keys.toggleEngine() end,
})

RegisterCommand('engine', function() Keys.toggleEngine() end, false)

local cachedVeh, cachedKind, cachedUntil = nil, nil, 0

-- Keys.has reads plates, state bags and groups, so a positive answer is reused for
-- 250 ms instead of being worked out every frame. A "no keys" answer is never cached,
-- so hotwiring still takes effect on the next frame.
local function lookup(veh)
    local now = GetGameTimer()
    if veh == cachedVeh and cachedKind and now < cachedUntil then return cachedKind end
    local kind = Keys.has(veh)
    cachedVeh, cachedKind, cachedUntil = veh, kind, now + 250
    return kind
end

CreateThread(function()
    while true do
        local veh = driving()
        if veh and Config.Engine.requireKeys then
            local kind = lookup(veh)
            if not kind then
                if GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, false, true, true) end
                showHint()
            else
                hideHint()
                if Config.Engine.autoStart and not started[veh] then
                    started[veh] = true
                    if not GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, true, false, true) end
                end
                if Config.Engine.keepRunning and IsControlPressed(0, 75) and GetIsVehicleEngineRunning(veh) then
                    SetVehicleEngineOn(veh, true, true, true)
                end
            end
            Wait((not kind or Config.Engine.keepRunning) and 0 or 100)
        else
            hideHint()
            if next(started) and not veh then started = {} end
            Wait(veh and 250 or 500)
        end
    end
end)
