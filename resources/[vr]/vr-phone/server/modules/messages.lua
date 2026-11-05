-- Text messages between two phone numbers.
--
-- Every message is stored once (vr_ph_messages). Each number also has one row per conversation (vr_ph_threads)
-- that holds the last message and how many are unread, so the conversation list needs one cheap query.
-- A conversation belongs to the phone number, so it moves with the phone.
local Messages = {}
Phone.Messages = Messages

local cfg = function() return Config.Phone.Messages or {} end

local sent = {} -- number -> { windowStart, count } for the per-minute limit

local function allowed(number)
    local now = os.time()
    local w = sent[number]
    if not w or now - w.start >= 60 then
        w = { start = now, count = 0 }
        sent[number] = w
    end
    if w.count >= (cfg().perMinute or 20) then return false end
    w.count = w.count + 1
    return true
end

-- Who owns a number. Returns the phone row ({ phone_id, number }) or nil when no phone has it.
function Messages.owner(number)
    return Phone.Identity.byNumber(number)
end

local function bump(number, other, id, body, at, mine, unread)
    MySQL.update.await(
        'INSERT INTO `vr_ph_threads` (`number`, `other`, `last_id`, `last_body`, `last_at`, `last_mine`, `unread`) VALUES (?, ?, ?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE `last_id` = VALUES(`last_id`), `last_body` = VALUES(`last_body`), `last_at` = VALUES(`last_at`), `last_mine` = VALUES(`last_mine`), `unread` = `unread` + VALUES(`unread`)',
        { number, other, id, body:sub(1, 120), at, mine and 1 or 0, unread }
    )
end

-- Sends a message from `from` (a number) to `to` (any text that looks like a number).
-- Returns the stored message { id, from, to, body, at, dropped }, or nil and a reason:
-- 'invalid_number', 'invalid_body', 'self', 'no_such_number', 'too_fast'.
function Messages.send(from, to, body)
    local number = Phone.number(to)
    if not number then return nil, 'invalid_number' end
    if number == from then return nil, 'self' end
    body = Phone.text(body, cfg().maxLength or 500, true)
    if not body then return nil, 'invalid_body' end

    local owner = Messages.owner(number)
    if not owner then return nil, 'no_such_number' end
    if not allowed(from) then return nil, 'too_fast' end

    -- A blocked sender still sees their own message, but the receiver never does.
    local dropped = Phone.Contacts.isBlocked(owner.phone_id, from)
    local at = os.time()
    local pair = Phone.pair(from, number)
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_messages` (`pair`, `sender`, `recipient`, `body`, `dropped`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)',
        { pair, from, number, body, dropped and 1 or 0, at }
    )
    if not id then return nil, 'failed' end

    bump(from, number, id, body, at, true, 0)
    if not dropped then bump(number, from, id, body, at, false, 1) end

    -- Old messages in this conversation go. Checked now and then, not every time.
    if id % 20 == 0 then
        local edge = MySQL.scalar.await(
            'SELECT `id` FROM `vr_ph_messages` WHERE `pair` = ? ORDER BY `id` DESC LIMIT 1 OFFSET ' .. math.floor(cfg().keepPerThread or 300),
            { pair }
        )
        if edge then MySQL.update.await('DELETE FROM `vr_ph_messages` WHERE `pair` = ? AND `id` <= ?', { pair, edge }) end
    end

    return { id = id, from = from, to = number, body = body, at = at, dropped = dropped, ownerPhoneId = owner.phone_id }
end

-- Tells the receiving phone about a new message: the open screen gets it at once, and a notification is pushed
-- (it waits when the phone has no service). Nothing happens for a blocked sender or a phone nobody is holding.
function Messages.deliver(m)
    if m.dropped then return end
    local rsrc = Phone.Session.srcByNumber(m.to)
    local rs = rsrc and Phone.Session.get(rsrc)
    if not rs then return end
    Phone.Status.ensure(rsrc, rs)
    if Phone.Status.canReceive(rs) then
        TriggerClientEvent('vr-phone:client:message', rsrc, { id = m.id, from = m.from, body = m.body, at = m.at })
    end
    Phone.Notify.push(rsrc, {
        app = 'messages',
        id = 'msg-' .. m.id,
        title = Phone.Contacts.nameFor(m.ownerPhoneId, m.from) or m.from,
        message = m.body,
    })
end

-- The conversation list for a number, newest first.
function Messages.threads(number)
    local rows = MySQL.query.await(
        'SELECT `other`, `last_id`, `last_body`, `last_at`, `last_mine`, `unread`, `cleared_id` FROM `vr_ph_threads` WHERE `number` = ? ORDER BY `last_id` DESC LIMIT 100',
        { number }
    ) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if r.last_id > r.cleared_id then
            out[#out + 1] = { number = r.other, body = r.last_body, at = r.last_at, mine = Phone.flag(r.last_mine), unread = r.unread, id = r.last_id }
        end
    end
    return out
end

-- One conversation, oldest message first. `before` (a message id) loads the page before it.
function Messages.history(number, other, before)
    other = Phone.number(other)
    if not other then return nil, 'invalid_number' end
    local cleared = MySQL.scalar.await('SELECT `cleared_id` FROM `vr_ph_threads` WHERE `number` = ? AND `other` = ?', { number, other }) or 0
    before = tonumber(before) or 9007199254740991
    local rows = MySQL.query.await(
        'SELECT `id`, `sender`, `body`, `created_at` FROM `vr_ph_messages` WHERE `pair` = ? AND `id` > ? AND `id` < ? AND (`dropped` = 0 OR `sender` = ?) ORDER BY `id` DESC LIMIT 40',
        { Phone.pair(number, other), cleared, before, number }
    ) or {}
    local out = {}
    for i = #rows, 1, -1 do
        local r = rows[i]
        out[#out + 1] = { id = r.id, mine = r.sender == number, body = r.body, at = r.created_at }
    end
    return out, #rows >= 40
end

function Messages.markRead(number, other)
    other = Phone.number(other)
    if not other then return false end
    MySQL.update.await('UPDATE `vr_ph_threads` SET `unread` = 0 WHERE `number` = ? AND `other` = ?', { number, other })
    return true
end

function Messages.unread(number)
    return tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(`unread`), 0) FROM `vr_ph_threads` WHERE `number` = ?', { number })) or 0
end

-- Removes a conversation from this phone only. The other side keeps theirs.
function Messages.deleteThread(number, other)
    other = Phone.number(other)
    if not other then return false end
    MySQL.update.await('UPDATE `vr_ph_threads` SET `cleared_id` = `last_id`, `unread` = 0 WHERE `number` = ? AND `other` = ?', { number, other })
    return true
end
