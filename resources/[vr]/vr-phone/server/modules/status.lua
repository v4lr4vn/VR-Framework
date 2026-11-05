-- Keeps battery, signal and charging up to date for every player with a phone, and tells their screen when something changes.
-- One loop (Config.Phone.StatusSeconds) does it all. Nothing is sent unless something changed.
local Status = {}
Phone.Status = Status

local Session = Phone.Session
local Battery = Phone.Battery
local Signal = Phone.Signal
local cfg = Config.Phone.Battery

-- Loads what the phone needs (its settings and its battery) the first time it is used.
function Status.ensure(src, s)
    if not s.settings then s.settings = Phone.Settings.get(s.phoneId) end
    Battery.load(s)
    s.sig = s.sig or { level = 'full' }
    return s
end

-- Where the player is decides their signal, and whether anything is charging the phone.
local function sampleWorld(src, s)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if not coords then return end

    s.sig.level = Signal.levelAt(coords)

    local charge = cfg.charge or {}
    local vehicleRate
    if (charge.vehicle or 0) > 0 then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle and vehicle ~= 0 and GetIsVehicleEngineRunning(vehicle) then vehicleRate = charge.vehicle end
    end
    Battery.setSource(s, 'vehicle', vehicleRate)

    local pointRate
    for _, point in ipairs(charge.points or {}) do
        local dx, dy, dz = coords.x - point.coords.x, coords.y - point.coords.y, coords.z - point.coords.z
        local r = point.radius or 2.0
        if dx * dx + dy * dy + dz * dz <= r * r and (not pointRate or point.rate > pointRate) then pointRate = point.rate end
    end
    Battery.setSource(s, 'point', pointRate)

    -- Inside a building. Only the game knows what an interior is, so the player's own game tells us (and keeps telling us:
    -- the report runs out after 30 seconds). A fake report can only ever give the slow "wall socket" rate.
    local indoorsRate
    if (charge.indoors or 0) > 0 and s.indoors and GetGameTimer() - s.indoors < 30000 then indoorsRate = charge.indoors end
    Battery.setSource(s, 'indoors', indoorsRate)

    -- Inside one of the player's properties (vr-housing keeps this in the character's data).
    local homeRate
    if (charge.home or 0) > 0 then
        local ok, inside = pcall(Bridge.getMeta, src, 'inside')
        if ok and type(inside) == 'table' and inside.property_id then homeRate = charge.home end
    end
    Battery.setSource(s, 'home', homeRate)
end

function Status.airplane(s)
    return s.settings and s.settings.quick.airplane == true
end

-- True when the phone is on and has service. Notifications, messages and calls need this.
function Status.canReceive(s)
    if not s.bat or not s.settings then return false end
    return s.bat.powered and Signal.hasService(s.sig and s.sig.level or 'full', Status.airplane(s))
end

-- What the screen shows in the status bar and what apps check.
function Status.snapshot(s)
    local level = s.sig and s.sig.level or 'full'
    local airplane = Status.airplane(s)
    local b = s.bat
    return {
        battery = b and math.floor(b.level + 0.5) or 100,
        charging = Battery.chargeRate(s) > 0,
        powered = b == nil or b.powered,
        lowPower = s.settings ~= nil and s.settings.battery.lowPower == true,
        signal = {
            level = airplane and 'none' or level,
            bars = Signal.bars(level, airplane),
            service = Signal.hasService(level, airplane),
            airplane = airplane,
            carrier = Signal.carrier(),
        },
    }
end

local function key(snap)
    return ('%d|%s|%s|%s|%d|%s|%s'):format(snap.battery, tostring(snap.charging), tostring(snap.powered), tostring(snap.lowPower), snap.signal.bars, snap.signal.level, tostring(snap.signal.airplane))
end

-- Changes a battery setting from the server side (Low Power Mode switching itself on or off) and tells the screen.
local function setLowPower(src, s, on)
    local saved = Phone.Settings.save(s.phoneId, { battery = { lowPower = on } })
    s.settings = saved
    TriggerClientEvent('vr-phone:client:settings', src, { battery = { lowPower = on } })
end

-- Works out everything for one player. Call it before changing anything the battery depends on
-- (screen on or off, the open app, a setting), so the time up to now is counted the old way.
function Status.refresh(src, s, force)
    Status.ensure(src, s)
    sampleWorld(src, s)

    local quick, battery = s.settings.quick, s.settings.battery
    local before, after = Battery.update(s, {
        screen = s.screen == true,
        app = s.app,
        signal = s.sig.level,
        airplane = quick.airplane,
        bluetooth = quick.bluetooth,
        lowPower = battery.lowPower,
    })

    local b = s.bat
    -- A phone that dies starts on the lock screen when it comes back.
    if not b.powered then Phone.Session.setUnlocked(src, false) end
    local threshold = cfg.lowPowerThreshold or 20
    local charging = Battery.chargeRate(s) > 0
    local needNote

    if b.powered then
        if before > threshold and after <= threshold and not charging then
            if battery.autoLowPower ~= false and not battery.lowPower then
                b.autoLowPower = true
                setLowPower(src, s, true)
                needNote = { title = 'battery.low', message = 'battery.lowOn', level = after }
            else
                needNote = { title = 'battery.low', message = 'battery.lowOnly', level = after }
            end
        elseif before > 10 and after <= 10 and not charging then
            needNote = { title = 'battery.critical', message = 'battery.criticalText', level = after }
        end
        -- Low Power Mode that the battery switched on goes off again once the phone is mostly charged.
        if b.autoLowPower and s.settings.battery.lowPower and charging and after >= 80 then
            b.autoLowPower = false
            setLowPower(src, s, false)
        end
    end

    local snap = Status.snapshot(s)
    local k = key(snap)
    if force or k ~= s.statusKey then
        s.statusKey = k
        TriggerClientEvent('vr-phone:client:status', src, snap)
    end

    if needNote then
        -- These carry text keys, not words. The screen has the words (its language files).
        Phone.Notify.push(src, {
            app = 'system',
            id = 'battery-' .. needNote.title,
            titleKey = needNote.title,
            messageKey = needNote.message,
            data = { level = math.floor(needNote.level + 0.5) },
        }, { system = true })
    end

    if Status.canReceive(s) then Phone.Notify.flush(src, s) end

    -- Save the level now and then, not on every change.
    if b.dirty and os.time() - b.saved >= 300 then Battery.save(s) end
    return snap
end

-- Settings were changed by the player. Count the time up to now the old way, then switch.
function Status.beforeSettingsChange(src, s)
    if s.bat then Status.refresh(src, s) end
end

function Status.afterSettingsChange(src, s, saved, patch)
    s.settings = saved
    -- The player took control of Low Power Mode, so the battery stops managing it.
    if type(patch) == 'table' and type(patch.battery) == 'table' and patch.battery.lowPower ~= nil and s.bat then
        s.bat.autoLowPower = false
    end
    Status.refresh(src, s, true)
end

function Status.setScreen(src, s, on, app)
    if s.bat then Status.refresh(src, s) end
    s.screen = on == true
    s.app = on and app or nil
end

function Status.setApp(src, s, app)
    if s.bat then Status.refresh(src, s) end
    s.app = app
end

function Status.tick()
    Session.each(function(src, s)
        local ok, err = pcall(Status.refresh, src, s)
        if not ok then print(('^1[vr-phone] status update failed for %s: %s^0'):format(tostring(src), tostring(err))) end
    end)
end

-- Save the battery when a player leaves, and when the resource stops.
Session.onStop(function(_, s)
    if s.bat and s.bat.dirty then Battery.save(s) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Session.each(function(_, s)
        if s.bat and s.bat.dirty then pcall(Battery.save, s) end
    end)
end)
