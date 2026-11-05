local Session = Phone.Session
local Identity = Phone.Identity
local Security = Phone.Security
local Settings = Phone.Settings
local Apps = Phone.Apps
local Status = Phone.Status
local Battery = Phone.Battery

-- Stops one player from calling the same thing over and over.
local hits = {}

local function tooFast(src, key, ms)
    local id = src .. ':' .. key
    local now = GetGameTimer()
    if hits[id] and now - hits[id] < ms then return true end
    hits[id] = now
    return false
end

local function forget(src)
    local prefix = src .. ':'
    for id in pairs(hits) do
        if id:sub(1, #prefix) == prefix then hits[id] = nil end
    end
end

-- Every call after opening needs a session. Anything that changes the phone also needs it unlocked.
local function guard(src, needUnlocked)
    local s = Session.get(src)
    if not s then return nil, 'no_session' end
    -- The phone must still be in this player's hands (it may have been dropped, sold or stolen since opening).
    local held = Identity.resolve(src, false)
    if not held or held.phone_id ~= s.phoneId or Session.srcByPhoneId(s.phoneId) ~= src then
        Session.stop(src)
        return nil, 'no_phone'
    end
    -- A dead phone does nothing.
    if s.bat and not s.bat.powered then return nil, 'no_power' end
    if needUnlocked and not Session.isUnlocked(src) then return nil, 'locked' end
    return s
end

-- The calls, messages and contacts scripts use the same two checks.
Phone.guard = guard
Phone.tooFast = tooFast

-- The phone is taken out. Finds (or sets up) the player's phone and sends everything the screen needs.
lib.callback.register('vr-phone:open', function(src)
    if not Phone.DB.ready then return { error = 'not_ready' } end
    if tooFast(src, 'open', 500) then return { error = 'busy' } end

    local row, reason = Identity.resolve(src, true)
    if not row then
        Session.stop(src)
        return { error = reason or 'no_phone' }
    end

    local pin = Security.status(row)
    local s = Session.start(src, row, pin.enabled)
    Session.opened(src)

    -- Count the time the phone spent in the pocket, then turn the screen on.
    s.settings = Settings.get(row.phone_id)
    Status.refresh(src, s)
    Status.setScreen(src, s, true, nil)

    return {
        phone = { id = row.phone_id, number = row.number },
        settings = s.settings,
        status = Status.snapshot(s),
        ringtones = Config.Phone.Ringtones,
        layout = Settings.getLayout(row.phone_id),
        apps = Apps.list(),
        installed = Apps.installedIds(row.phone_id),
        contacts = Phone.Contacts.list(row.phone_id),
        badges = Phone.badges(row.number),
        lock = {
            enabled = pin.enabled,
            length = pin.length,
            locked = not Session.isUnlocked(src),
            lockedFor = pin.lockedFor,
        },
        features = {
            fold = Config.Phone.Fold,
            battery = Config.Phone.Battery,
            signal = Config.Phone.Signal,
            pinLengths = Config.Phone.Lock.pinLengths,
            calls = {
                answerKey = Config.Phone.Calls.answerKey,
                hangupKey = Config.Phone.Calls.hangupKey,
                voicemail = Config.Phone.Calls.voicemail == true,
                maxLength = Config.Phone.Messages.maxLength,
            },
            media = {
                maxPhotos = Config.Phone.Media.maxPhotos,
                maxWidth = Config.Phone.Media.maxWidth,
                quality = Config.Phone.Media.quality,
                thumbWidth = Config.Phone.Media.thumbWidth,
                pageSize = Config.Phone.Media.pageSize,
                keepDeletedDays = Config.Phone.Media.keepDeletedDays,
                timerSeconds = Config.Phone.Media.timerSeconds,
            },
            share = {
                range = Config.Phone.Share.range,
                timeoutSeconds = Config.Phone.Share.timeoutSeconds,
                maxItems = Config.Phone.Share.maxItems,
            },
            notes = { max = Config.Phone.Notes.max, titleLength = Config.Phone.Notes.titleLength, bodyLength = Config.Phone.Notes.bodyLength },
            planner = { remindChoices = Config.Phone.Planner.remindChoices },
            wallet = { min = Config.Phone.Wallet.minSend, max = Config.Phone.Wallet.maxSend, note = Config.Phone.Wallet.noteLength },
            maps = { range = Config.Phone.Maps.range, maxPlaces = Config.Phone.Maps.maxPlaces, nameLength = Config.Phone.Maps.nameLength, tiles = Config.Phone.Maps.tiles or nil },
            music = { range = Config.Phone.Music.range, rangeChoices = Config.Phone.Music.rangeChoices, maxLibrary = Config.Phone.Music.maxLibrary, maxQueue = Config.Phone.Music.maxQueue },
            health = { goalRange = Config.Phone.Health.goalRange, reportSeconds = Config.Phone.Health.reportSeconds, restingRate = Config.Phone.Health.restingRate },
            weather = { place = Config.Phone.Weather.place, fahrenheit = Config.Phone.Weather.fahrenheit == true, base = Config.Phone.Weather.base, daySwing = Config.Phone.Weather.daySwing },
            mail = {
                domain = Config.Phone.Mail.domain,
                subjectLength = Config.Phone.Mail.subjectLength,
                bodyLength = Config.Phone.Mail.bodyLength,
                pageSize = Config.Phone.Mail.pageSize,
                keepTrashDays = Config.Phone.Mail.keepTrashDays,
            },
        },
        sounds = Config.Phone.Sounds,
        fold = Config.Phone.DefaultFoldState,
        locale = GetConvar('vr:locale', 'en'),
    }
end)

RegisterNetEvent('vr-phone:server:closed', function()
    local src = source
    local s = Session.get(src)
    if s then Status.setScreen(src, s, false) end
    Session.closed(src)
end)

-- The screen tells the server which app is open (nothing when it is the home screen).
-- The server only uses it to work out battery use, so it must be a known app.
RegisterNetEvent('vr-phone:server:app', function(appId)
    local src = source
    local s = Session.get(src)
    if not s or not s.screen or tooFast(src, 'app', 150) then return end
    if appId ~= nil and (type(appId) ~= 'string' or not Apps.exists(appId)) then return end
    Status.setApp(src, s, appId)
end)

lib.callback.register('vr-phone:unlock', function(src, data)
    local s, reason = guard(src, false)
    if not s then return { ok = false, reason = reason, lockedFor = 0 } end
    if tooFast(src, 'unlock', 300) then return { ok = false, reason = 'busy', lockedFor = 0 } end

    local ok, why, wait = Security.verify(s.phoneId, type(data) == 'table' and data.pin or nil)
    if ok then Session.setUnlocked(src, true) end
    return { ok = ok, reason = why, lockedFor = wait or 0 }
end)

lib.callback.register('vr-phone:lock', function(src)
    if not guard(src, false) then return false end
    Session.setUnlocked(src, false)
    return true
end)

lib.callback.register('vr-phone:setPin', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason, lockedFor = 0 } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid_pin', lockedFor = 0 } end
    if tooFast(src, 'pin', 300) then return { ok = false, reason = 'busy', lockedFor = 0 } end

    local ok, why, wait = Security.setPin(s.phoneId, data.pin, data.old)
    if ok then
        Session.setPin(src, true)
        Session.setUnlocked(src, true)
    end
    return { ok = ok, reason = why, lockedFor = wait or 0, length = ok and #data.pin or nil }
end)

lib.callback.register('vr-phone:removePin', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason, lockedFor = 0 } end
    if tooFast(src, 'pin', 300) then return { ok = false, reason = 'busy', lockedFor = 0 } end

    local ok, why, wait = Security.removePin(s.phoneId, type(data) == 'table' and data.pin or nil)
    if ok then Session.setPin(src, false) end
    return { ok = ok, reason = why, lockedFor = wait or 0 }
end)

-- The quick panel works on the lock screen, like on a real phone. Everything else waits for the unlock.
local function quickOnly(patch)
    if type(patch) ~= 'table' then return false end
    for key, value in pairs(patch) do
        if key == 'quick' then
            if type(value) ~= 'table' then return false end
        elseif key == 'battery' then
            if type(value) ~= 'table' then return false end
            for inner in pairs(value) do
                if inner ~= 'lowPower' then return false end
            end
        else
            return false
        end
    end
    return true
end

lib.callback.register('vr-phone:saveSettings', function(src, patch)
    local s, reason = guard(src, false)
    if not s then return { ok = false, reason = reason } end
    if not Session.isUnlocked(src) and not quickOnly(patch) then return { ok = false, reason = 'locked' } end
    if tooFast(src, 'settings', 120) then return { ok = false, reason = 'busy' } end

    Status.beforeSettingsChange(src, s)
    local saved = Settings.save(s.phoneId, patch)
    Status.afterSettingsChange(src, s, saved, patch)
    -- Airplane mode ends a call that is going on.
    Phone.Calls.check(src)
    return { ok = true, settings = saved }
end)

-- Battery use by app since the player logged in, for the Battery page in Settings.
lib.callback.register('vr-phone:batteryUsage', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, usage = Battery.usageList(s) }
end)

lib.callback.register('vr-phone:saveLayout', function(src, layout)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if tooFast(src, 'layout', 300) then return { ok = false, reason = 'busy' } end

    local clean, why = Settings.saveLayout(s.phoneId, layout)
    if not clean then return { ok = false, reason = why } end
    return { ok = true, layout = clean }
end)

-- Players who already have a phone start receiving notifications as soon as they load in.
-- This only looks for an existing phone. Nothing is created until the phone is opened.
Bridge.on('playerLoaded', function(src)
    CreateThread(function()
        Wait(3000)
        if Session.get(src) then return end
        Phone.DB.waitReady()
        local row = Identity.resolve(src, false)
        if row then Session.start(src, row, Security.status(row).enabled) end
    end)
end)

Bridge.on('playerUnloaded', function(src)
    Session.stop(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Session.stop(src)
    forget(src)
end)

-- Battery, signal and charging for everyone with a phone.
CreateThread(function()
    Phone.DB.waitReady()
    while true do
        Wait((Config.Phone.StatusSeconds or 10) * 1000)
        Status.tick()
        Phone.Calls.tick()
    end
end)
