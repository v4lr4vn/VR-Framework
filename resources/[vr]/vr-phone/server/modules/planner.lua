-- Reminders and calendar events, and the alerts that come from them.
--
-- The game clock is the only clock these use, and only the player's game knows it. So the server never watches a clock:
-- the player's game asks for the list of alerts that are waiting (Planner.pending), compares them with the game clock, and
-- tells the server when one is due (Planner.fire). The server then sends the notification through the normal notification door.
local Planner = {}
Phone.Planner = Planner

local function cfg() return Config.Phone.Planner or {} end

local function flag(v) return v == 1 or v == true end

-- A minute of the day, or nil.
local function minuteOf(v)
    if v == nil then return nil end
    local n = Phone.clamp(v, 0, 1439)
    return n and math.floor(n) or nil
end

-- ---------------------------------------------------------------- reminders

local function toReminder(r)
    return { id = r.id, title = r.title, note = r.note, date = r.date, minute = r.minute, done = flag(r.done) }
end

function Planner.reminders(phoneId)
    local rows = MySQL.query.await(
        'SELECT `id`, `title`, `note`, `date`, `minute`, `done` FROM `vr_ph_reminders` WHERE `phone_id` = ? '
            .. 'ORDER BY `done`, (`date` IS NULL), `date`, `minute`, `id` LIMIT ' .. (cfg().maxReminders or 200),
        { phoneId }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = toReminder(r) end
    return out
end

-- r = { id?, title, note?, date?, minute? }. A date gives the reminder an alert (at `minute`, or 09:00 when there is no time).
function Planner.saveReminder(phoneId, r)
    local title = Phone.text(r.title, 120)
    if not title then return nil, 'empty' end
    local note = Phone.text(r.note, 300, true)
    local date, minute, alert = nil, nil, nil
    if r.date ~= nil and r.date ~= '' then
        if not Phone.parseDate(r.date) then return nil, 'invalid_date' end
        date = r.date
        minute = minuteOf(r.minute)
        alert = Phone.stamp(date, minute or cfg().defaultAlertMinute or 540)
    end

    if r.id ~= nil then
        local id = tonumber(r.id)
        if not id then return nil, 'not_found' end
        -- Changing a reminder re-arms its alert.
        MySQL.update.await(
            'UPDATE `vr_ph_reminders` SET `title` = ?, `note` = ?, `date` = ?, `minute` = ?, `alert_at` = ?, `fired` = 0 WHERE `phone_id` = ? AND `id` = ?',
            { title, note, date, minute, alert, phoneId, id }
        )
        local row = MySQL.single.await('SELECT `id`, `title`, `note`, `date`, `minute`, `done` FROM `vr_ph_reminders` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
        if not row then return nil, 'not_found' end
        return toReminder(row)
    end

    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_reminders` WHERE `phone_id` = ?', { phoneId })) or 0
    if count >= (cfg().maxReminders or 200) then return nil, 'full' end
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_reminders` (`phone_id`, `title`, `note`, `date`, `minute`, `alert_at`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { phoneId, title, note, date, minute, alert, os.time() }
    )
    if not id then return nil, 'failed' end
    return { id = id, title = title, note = note, date = date, minute = minute, done = false }
end

function Planner.setDone(phoneId, id, done)
    id = tonumber(id)
    if not id then return false end
    MySQL.update.await('UPDATE `vr_ph_reminders` SET `done` = ? WHERE `phone_id` = ? AND `id` = ?', { done and 1 or 0, phoneId, id })
    return MySQL.scalar.await('SELECT `id` FROM `vr_ph_reminders` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) ~= nil
end

function Planner.removeReminder(phoneId, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_reminders` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) or 0) > 0
end

function Planner.clearDone(phoneId)
    return MySQL.update.await('DELETE FROM `vr_ph_reminders` WHERE `phone_id` = ? AND `done` = 1', { phoneId }) or 0
end

-- ---------------------------------------------------------------- events

local function toEvent(r)
    return { id = r.id, title = r.title, place = r.place, note = r.note, date = r.date, minute = r.minute, length = r.length, colour = r.colour, remind = r.remind }
end

-- Events from one date to another (both included), at most 400 days apart.
function Planner.events(phoneId, from, to)
    local y1, m1, d1 = Phone.parseDate(from)
    local y2, m2, d2 = Phone.parseDate(to)
    if not y1 or not y2 then return nil, 'invalid_date' end
    if Phone.dayNumber(y2, m2, d2) - Phone.dayNumber(y1, m1, d1) > 400 then return nil, 'invalid_date' end
    local rows = MySQL.query.await(
        'SELECT `id`, `title`, `place`, `note`, `date`, `minute`, `length`, `colour`, `remind` FROM `vr_ph_events` '
            .. 'WHERE `phone_id` = ? AND `date` >= ? AND `date` <= ? ORDER BY `date`, (`minute` IS NULL) DESC, `minute`, `id` LIMIT 500',
        { phoneId, from, to }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = toEvent(r) end
    return out
end

-- e = { id?, title, place?, note?, date, minute? (nil = all day), length?, colour?, remind? (minutes before) }
function Planner.saveEvent(phoneId, e)
    local title = Phone.text(e.title, 120)
    if not title then return nil, 'empty' end
    if not Phone.parseDate(e.date) then return nil, 'invalid_date' end
    local minute = minuteOf(e.minute)
    local length = minute and Phone.clamp(e.length, 5, 1440) or nil
    length = length and math.floor(length) or nil
    local colour = math.floor(Phone.clamp(e.colour, 0, 7) or 0)

    local remind = nil
    if e.remind ~= nil then
        remind = Phone.clamp(e.remind, 0, 10080)
        if not remind then return nil, 'invalid' end
        remind = math.floor(remind)
        local ok = false
        for _, choice in ipairs(cfg().remindChoices or {}) do if choice == remind then ok = true end end
        if not ok then return nil, 'invalid' end
    end
    local alert = nil
    if remind then alert = Phone.stamp(e.date, minute or (cfg().defaultAlertMinute or 540)) - remind end

    local place = Phone.text(e.place, 120)
    local note = Phone.text(e.note, 500, true)

    if e.id ~= nil then
        local id = tonumber(e.id)
        if not id then return nil, 'not_found' end
        MySQL.update.await(
            'UPDATE `vr_ph_events` SET `title` = ?, `place` = ?, `note` = ?, `date` = ?, `minute` = ?, `length` = ?, `colour` = ?, `remind` = ?, `alert_at` = ?, `fired` = 0 '
                .. 'WHERE `phone_id` = ? AND `id` = ?',
            { title, place, note, e.date, minute, length, colour, remind, alert, phoneId, id }
        )
        local row = MySQL.single.await('SELECT `id`, `title`, `place`, `note`, `date`, `minute`, `length`, `colour`, `remind` FROM `vr_ph_events` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
        if not row then return nil, 'not_found' end
        return toEvent(row)
    end

    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_events` WHERE `phone_id` = ?', { phoneId })) or 0
    if count >= (cfg().maxEvents or 300) then return nil, 'full' end
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_events` (`phone_id`, `title`, `place`, `note`, `date`, `minute`, `length`, `colour`, `remind`, `alert_at`, `created_at`) '
            .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { phoneId, title, place, note, e.date, minute, length, colour, remind, alert, os.time() }
    )
    if not id then return nil, 'failed' end
    return { id = id, title = title, place = place, note = note, date = e.date, minute = minute, length = length, colour = colour, remind = remind }
end

function Planner.removeEvent(phoneId, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_events` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) or 0) > 0
end

-- ---------------------------------------------------------------- alerts

-- The alerts still waiting, soonest first: { { kind = 'reminder' | 'event', id, at = stamp }, ... }. Up to 60.
function Planner.pending(phoneId)
    local out = {}
    local reminders = MySQL.query.await(
        'SELECT `id`, `alert_at` FROM `vr_ph_reminders` WHERE `phone_id` = ? AND `alert_at` IS NOT NULL AND `fired` = 0 AND `done` = 0 ORDER BY `alert_at` LIMIT 60',
        { phoneId }
    ) or {}
    for _, r in ipairs(reminders) do out[#out + 1] = { kind = 'reminder', id = r.id, at = tonumber(r.alert_at) } end
    local events = MySQL.query.await(
        'SELECT `id`, `alert_at` FROM `vr_ph_events` WHERE `phone_id` = ? AND `alert_at` IS NOT NULL AND `fired` = 0 ORDER BY `alert_at` LIMIT 60',
        { phoneId }
    ) or {}
    for _, r in ipairs(events) do out[#out + 1] = { kind = 'event', id = r.id, at = tonumber(r.alert_at) } end
    table.sort(out, function(a, b) return a.at < b.at end)
    while #out > 60 do out[#out] = nil end
    return out
end

-- The game says an alert is due. Returns what to show ({ app, title, message }), or nil when there is nothing to send
-- (already sent, done, deleted). The alert is marked sent first, so it can only go out once.
function Planner.fire(phoneId, kind, id)
    id = tonumber(id)
    if not id then return nil end
    if kind == 'reminder' then
        local changed = MySQL.update.await('UPDATE `vr_ph_reminders` SET `fired` = 1 WHERE `phone_id` = ? AND `id` = ? AND `fired` = 0 AND `done` = 0 AND `alert_at` IS NOT NULL', { phoneId, id })
        if (changed or 0) < 1 then return nil end
        local r = MySQL.single.await('SELECT `title`, `note` FROM `vr_ph_reminders` WHERE `id` = ?', { id })
        if not r then return nil end
        return { app = 'reminders', id = 'rem' .. id, title = r.title, message = r.note }
    elseif kind == 'event' then
        local changed = MySQL.update.await('UPDATE `vr_ph_events` SET `fired` = 1 WHERE `phone_id` = ? AND `id` = ? AND `fired` = 0 AND `alert_at` IS NOT NULL', { phoneId, id })
        if (changed or 0) < 1 then return nil end
        local e = MySQL.single.await('SELECT `title`, `place`, `minute` FROM `vr_ph_events` WHERE `id` = ?', { id })
        if not e then return nil end
        local when = e.minute and ('%02d:%02d'):format(e.minute // 60, e.minute % 60) or nil
        local parts = {}
        if when then parts[#parts + 1] = when end
        if e.place then parts[#parts + 1] = e.place end
        return { app = 'calendar', id = 'ev' .. id, title = e.title, message = #parts > 0 and table.concat(parts, ' · ') or nil }
    end
    return nil
end
