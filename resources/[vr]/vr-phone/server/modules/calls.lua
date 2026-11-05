-- Phone calls. The server keeps every call in memory while it lasts, and writes the call history when it ends.
--
-- A call goes through these states:
--   ringing    the caller is waiting, the other phone rings
--   active     answered. Both players are on the same voice channel
--   voicemail  nobody picked up (or the phone was out of reach). The caller can leave a typed message
--   ended      gone. Both screens are told why
--
-- Nothing here trusts the screen: who may answer, who may hang up and whether a number can be reached is decided on the server.
local Calls = {}
Phone.Calls = Calls

local Session = Phone.Session
local Status = Phone.Status
local Contacts = Phone.Contacts
local Voicemail = Phone.Voicemail
local Voice = Phone.Voice

local byId = {}  -- call id -> call
local bySrc = {} -- player -> the call they are in
local nextId = 0

local function cfg() return Config.Phone.Calls or {} end

-- The sound file for the ringing phone: the ringtone the player picked, or the server's default ring.
local function ringFile(settings)
    local pick = settings and settings.sound and settings.sound.ringtone
    for _, tone in ipairs(Config.Phone.Ringtones or {}) do
        if tone.id == pick and type(tone.file) == 'string' then return tone.file end
    end
    local default = Config.Phone.Sounds and Config.Phone.Sounds.ring
    return type(default) == 'string' and default or nil
end

local function send(src, data)
    if src then TriggerClientEvent('vr-phone:client:call', src, data) end
end

-- ---------------------------------------------------------------- history

local function log(number, other, outgoing, result, duration, seen)
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_calls` (`number`, `other`, `direction`, `result`, `duration`, `seen`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { number, other, outgoing and 1 or 0, result, duration or 0, seen and 1 or 0, os.time() }
    )
    if id then
        -- Keep the newest 100 for each number.
        local edge = MySQL.scalar.await('SELECT `id` FROM `vr_ph_calls` WHERE `number` = ? ORDER BY `id` DESC LIMIT 1 OFFSET 100', { number })
        if edge then MySQL.update.await('DELETE FROM `vr_ph_calls` WHERE `number` = ? AND `id` <= ?', { number, edge }) end
    end
end

-- The call list for a number, newest first.
function Calls.recent(number)
    local rows = MySQL.query.await(
        'SELECT `id`, `other`, `direction`, `result`, `duration`, `seen`, `created_at` FROM `vr_ph_calls` WHERE `number` = ? ORDER BY `id` DESC LIMIT 60',
        { number }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = { id = r.id, number = r.other, outgoing = r.direction == 1, result = r.result, duration = r.duration, seen = Phone.flag(r.seen), at = r.created_at }
    end
    return out
end

function Calls.markSeen(number)
    MySQL.update.await('UPDATE `vr_ph_calls` SET `seen` = 1 WHERE `number` = ? AND `seen` = 0', { number })
end

function Calls.clear(number)
    MySQL.update.await('DELETE FROM `vr_ph_calls` WHERE `number` = ?', { number })
end

function Calls.unseenMissed(number)
    return tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `vr_ph_calls` WHERE `number` = ? AND `seen` = 0 AND `result` = 'missed'", { number })) or 0
end

-- ---------------------------------------------------------------- helpers

local function party(src, s, name)
    return { src = src, number = s.number, phoneId = s.phoneId, name = name }
end

-- Can this player's phone take a call or message right now? (On, with service, still in their hands.)
local function reachable(src)
    local s = src and Session.get(src)
    if not s then return false end
    Status.ensure(src, s)
    return Status.canReceive(s) and Phone.Identity.holdsPhone(src)
end

local function notify(src, data)
    if src and Session.get(src) then Phone.Notify.push(src, data) end
end

-- Tells the other side's phone about a call that was not picked up.
local function missed(call)
    local c = call.callee
    if call.calleeLogged then return end
    call.calleeLogged = true
    log(c.number, call.caller.number, false, 'missed', 0, false)
    -- A phone with no signal still gets this: it waits and arrives when the phone has service again.
    local rsrc = Session.srcByNumber(c.number)
    if rsrc then
        notify(rsrc, { app = 'phone', id = 'missed-' .. call.id, title = c.callerName or call.caller.number, messageKey = 'call.missed' })
    end
end

local function release(src, call)
    if src and bySrc[src] == call then bySrc[src] = nil end
end

local function setChannel(call, channel)
    Voice.set(call.caller.src, channel)
    Voice.set(call.callee.src, channel)
end

-- ---------------------------------------------------------------- ending

-- Ends a call for good. `reason` is what the screens are told:
--   hangup, declined (callee said no), cancelled (caller gave up while it rang), no_answer, dropped (signal or battery), voicemail_sent
local function finish(call, reason)
    if call.state == 'ended' then return end
    local was = call.state
    call.state = 'ended'
    byId[call.id] = nil

    if was == 'active' then setChannel(call, 0) end
    release(call.caller.src, call)
    release(call.callee.src, call)

    local duration = call.answeredAt and math.max(0, os.time() - call.answeredAt) or 0
    local answered = call.answeredAt ~= nil

    -- Caller's history
    local callerResult = answered and 'answered' or (reason == 'declined' and 'declined' or 'unanswered')
    log(call.caller.number, call.callee.number, true, callerResult, duration, true)

    -- Callee's history (unless it was already written when the call moved to voicemail)
    if not call.calleeLogged then
        if answered then
            call.calleeLogged = true
            log(call.callee.number, call.caller.number, false, 'answered', duration, true)
        elseif reason == 'declined' then
            call.calleeLogged = true
            log(call.callee.number, call.caller.number, false, 'declined', 0, true)
        else
            -- cancelled, or lost while it rang
            missed(call)
        end
    end

    -- Tell both screens. The side that picked up or put down gets the same reason, the screen words it.
    if not call.callerDone then send(call.caller.src, { id = call.id, state = 'ended', reason = reason, duration = duration }) end
    if not call.calleeDone then
        local calleeReason = reason
        if reason == 'cancelled' or reason == 'no_answer' then calleeReason = 'missed' end
        send(call.callee.src, { id = call.id, state = 'ended', reason = calleeReason, duration = duration })
    end
end

-- Nobody picked up, or the other phone could not be reached. The caller may leave a typed voicemail.
local function voicemailOrEnd(call, why)
    -- The other phone stops ringing, and the missed call is written down.
    if call.callee.src and not call.calleeDone then
        send(call.callee.src, { id = call.id, state = 'ended', reason = 'missed' })
        release(call.callee.src, call)
    end
    call.calleeDone = true
    missed(call)

    if not cfg().voicemail then
        finish(call, why)
        return
    end

    call.state = 'voicemail'
    send(call.caller.src, { id = call.id, state = 'voicemail', number = call.callee.number, name = call.callee.name })
    SetTimeout((cfg().voicemailSeconds or 60) * 1000, function()
        if byId[call.id] == call and call.state == 'voicemail' then finish(call, 'no_answer') end
    end)
end

-- ---------------------------------------------------------------- actions

-- Starts a call. Returns { id, state } ('calling' or 'voicemail'), or nil and a reason:
-- invalid_number, self, no_service, in_call, not_in_service, line_busy, unavailable
function Calls.start(src, s, raw)
    local number = Phone.number(raw)
    if not number then return nil, 'invalid_number' end
    if number == s.number then return nil, 'self' end
    if bySrc[src] then return nil, 'in_call' end
    if not reachable(src) then return nil, 'no_service' end

    local owner = Phone.Identity.byNumber(number)
    if not owner then return nil, 'not_in_service' end

    -- A number that blocked this phone sounds the same as one that is switched off.
    if Contacts.isBlocked(owner.phone_id, s.number) then return nil, 'unavailable' end

    local rsrc = Session.srcByNumber(number)
    local live = rsrc and rsrc ~= src and reachable(rsrc)
    if live and bySrc[rsrc] then return nil, 'line_busy' end
    if not live and not cfg().voicemail then return nil, 'unavailable' end

    nextId = nextId + 1
    local call = {
        id = nextId,
        state = 'ringing',
        caller = party(src, s, Contacts.nameFor(s.phoneId, number)),
        callee = { src = live and rsrc or nil, number = number, phoneId = owner.phone_id },
        startedAt = os.time(),
    }
    call.callee.name = call.caller.name
    call.callee.callerName = Contacts.nameFor(owner.phone_id, s.number)
    byId[call.id] = call
    bySrc[src] = call

    send(src, { id = call.id, state = 'calling', number = number, name = call.caller.name })

    if not live then
        voicemailOrEnd(call, 'unavailable')
        return { id = call.id, state = 'voicemail' }
    end

    bySrc[rsrc] = call
    local rs = Session.get(rsrc)
    send(rsrc, {
        id = call.id,
        state = 'incoming',
        number = s.number,
        name = call.callee.callerName,
        silent = rs.settings and rs.settings.quick.silent == true,
        ring = ringFile(rs.settings),
        volume = rs.settings and rs.settings.sound and rs.settings.sound.volume or nil,
    })

    SetTimeout(cfg().ringTimeoutMs or 20000, function()
        if byId[call.id] == call and call.state == 'ringing' then voicemailOrEnd(call, 'no_answer') end
    end)
    return { id = call.id, state = 'calling' }
end

-- The call this player is in, or nil.
function Calls.of(src)
    return bySrc[src]
end

function Calls.answer(src, id)
    local call = bySrc[src]
    if not call or call.id ~= tonumber(id) or call.state ~= 'ringing' or call.callee.src ~= src then return false, 'no_call' end
    if not reachable(src) then return false, 'no_service' end

    call.state = 'active'
    call.answeredAt = os.time()

    -- A channel nobody else is using.
    local base = cfg().channelBase or 50000
    local channel = base + (call.id % 10000)
    for _ = 1, 10000 do
        local clash = false
        for _, other in pairs(byId) do
            if other ~= call and other.channel == channel then clash = true break end
        end
        if not clash then break end
        channel = base + ((channel - base + 1) % 10000)
    end
    call.channel = channel
    setChannel(call, channel)

    send(call.caller.src, { id = call.id, state = 'active', number = call.callee.number, name = call.caller.name, elapsed = 0 })
    send(call.callee.src, { id = call.id, state = 'active', number = call.caller.number, name = call.callee.callerName, elapsed = 0 })
    return true
end

-- Hang up, decline or cancel. Works in every state.
function Calls.hangup(src, id)
    local call = bySrc[src]
    if not call or (id ~= nil and call.id ~= tonumber(id)) then return false, 'no_call' end
    if call.state == 'ringing' then
        finish(call, call.callee.src == src and 'declined' or 'cancelled')
    else
        finish(call, 'hangup')
    end
    return true
end

-- The caller leaves a typed message after nobody answered.
function Calls.leaveVoicemail(src, id, body)
    local call = bySrc[src]
    if not call or call.id ~= tonumber(id) or call.state ~= 'voicemail' or call.caller.src ~= src then return false, 'no_call' end
    local vid, text = Voicemail.add(call.callee.number, call.caller.number, body)
    if not vid then return false, 'empty' end

    local rsrc = Session.srcByNumber(call.callee.number)
    if rsrc then
        notify(rsrc, { app = 'phone', id = 'voicemail-' .. vid, title = call.callee.callerName or call.caller.number, messageKey = 'call.voicemailNew', message = text:sub(1, 80) })
    end
    finish(call, 'voicemail_sent')
    return true
end

-- Drops a call because the phone behind it is gone (put away for good, battery dead, no service, player left).
function Calls.dropFor(src)
    local call = bySrc[src]
    if not call then return end
    if call.state == 'ringing' and call.caller.src ~= src then
        -- The ringing phone vanished: the caller gets the voicemail option.
        call.callee.src = nil
        bySrc[src] = nil
        voicemailOrEnd(call, 'unavailable')
    elseif call.state == 'voicemail' then
        finish(call, 'dropped')
    else
        finish(call, call.state == 'active' and 'dropped' or 'cancelled')
    end
end

-- Checks one player's call against their phone. Called after their settings change (airplane mode) and by the status loop.
function Calls.check(src)
    local call = bySrc[src]
    if not call then return end
    -- The phone is off, has no service, or is no longer in the player's hands.
    if not reachable(src) then return Calls.dropFor(src) end
    local s = Session.get(src)

    -- Weak signal can drop a call that is going on.
    if call.state == 'active' and s.sig and s.sig.level == 'low' and math.random() < (cfg().lowSignalDropChance or 0.1) then
        finish(call, 'dropped')
    end
end

-- Runs with the status loop (every Config.Phone.StatusSeconds).
function Calls.tick()
    local players = {}
    for src in pairs(bySrc) do players[#players + 1] = src end
    for _, src in ipairs(players) do Calls.check(src) end
end

-- A player who leaves takes their call with them.
Session.onStop(function(src) Calls.dropFor(src) end)

-- For other scripts.
function Calls.info(src)
    local call = bySrc[src]
    if not call then return nil end
    local other = call.caller.src == src and call.callee or call.caller
    return { id = call.id, state = call.state, number = other.number, outgoing = call.caller.src == src }
end
