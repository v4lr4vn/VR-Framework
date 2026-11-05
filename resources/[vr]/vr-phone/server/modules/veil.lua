-- Veil: anonymous chat. Players have an alias; rooms and direct messages show only aliases.
-- A phone's number and the character's name never leave the server in anything this file sends. Messages are stored by phone id
-- (so an alias can change and old messages follow it), and every answer to the screen carries the alias and a `mine` flag only.
local Veil = {}
Phone.Veil = Veil

local function cfg() return Config.Phone.Veil or {} end
local function now() return os.time() end
local function int(v, d) return math.floor(tonumber(v) or d) end

local PUSH = 'vr-phone:client:social'

-- ---------------------------------------------------------------- alias

function Veil.alias(phoneId)
    return MySQL.scalar.await('SELECT `alias` FROM `vr_ph_veil_aliases` WHERE `phone_id` = ?', { phoneId })
end

local function phoneOf(alias)
    if type(alias) ~= 'string' then return nil end
    return MySQL.scalar.await('SELECT `phone_id` FROM `vr_ph_veil_aliases` WHERE `alias` = ?', { alias })
end

-- The alias a player may have: letters, digits and _ only, 3 to 16 long, not a word that sounds official.
local function validAlias(raw)
    if type(raw) ~= 'string' then return nil end
    local c = cfg()
    local a = raw:gsub('^%s+', ''):gsub('%s+$', '')
    if #a < (c.aliasMin or 3) or #a > (c.aliasMax or 16) or not a:match('^[%w_]+$') then return nil end
    for _, word in ipairs(c.reserved or {}) do
        if a:lower() == word then return nil, 'reserved' end
    end
    return a
end

-- Sets or changes the alias. A change has to wait (aliasCooldownHours) so nobody can hop between names to dodge a block.
function Veil.setAlias(phoneId, raw)
    local alias, why = validAlias(raw)
    if not alias then return nil, why or 'invalid_alias' end
    local row = MySQL.single.await('SELECT `alias`, `changed_at` FROM `vr_ph_veil_aliases` WHERE `phone_id` = ?', { phoneId })
    if row and row.alias:lower() == alias:lower() and row.alias == alias then return alias end
    if row then
        local wait = (cfg().aliasCooldownHours or 24) * 3600 - (now() - row.changed_at)
        if wait > 0 then return nil, 'cooldown', wait end
    end
    local taken = MySQL.scalar.await('SELECT `phone_id` FROM `vr_ph_veil_aliases` WHERE `alias` = ?', { alias })
    if taken and taken ~= phoneId then return nil, 'taken' end
    MySQL.update.await(
        'INSERT INTO `vr_ph_veil_aliases` (`phone_id`, `alias`, `changed_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `alias` = VALUES(`alias`), `changed_at` = VALUES(`changed_at`)',
        { phoneId, alias, now() }
    )
    return alias
end

-- ---------------------------------------------------------------- blocks

local function blocked(by, other)
    return MySQL.scalar.await('SELECT 1 FROM `vr_ph_veil_blocks` WHERE `phone_id` = ? AND `blocked_phone` = ?', { by, other }) ~= nil
end

function Veil.block(phoneId, alias)
    local other = phoneOf(alias)
    if not other then return false, 'not_found' end
    if other == phoneId then return false, 'self' end
    MySQL.update.await('INSERT IGNORE INTO `vr_ph_veil_blocks` (`phone_id`, `blocked_phone`) VALUES (?, ?)', { phoneId, other })
    return true
end

function Veil.unblock(phoneId, alias)
    local other = phoneOf(alias)
    if not other then return false, 'not_found' end
    MySQL.update.await('DELETE FROM `vr_ph_veil_blocks` WHERE `phone_id` = ? AND `blocked_phone` = ?', { phoneId, other })
    return true
end

function Veil.blocks(phoneId)
    local rows = MySQL.query.await(
        'SELECT a.`alias` FROM `vr_ph_veil_blocks` b JOIN `vr_ph_veil_aliases` a ON a.`phone_id` = b.`blocked_phone` WHERE b.`phone_id` = ? ORDER BY a.`alias`',
        { phoneId }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.alias end
    return out
end

-- ---------------------------------------------------------------- rooms

local function roomName(raw)
    if type(raw) ~= 'string' then return nil end
    local n = raw:gsub('^#', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #n < 2 or #n > (cfg().roomNameMax or 20) or not n:match('^[%w_%-]+$') then return nil end
    return n:lower()
end

local function salt() return ('%08x%08x'):format(math.random(0, 0x7FFFFFFF), math.random(0, 0x7FFFFFFF)) end

-- The rooms in the config always exist.
function Veil.ensureRooms()
    for _, r in ipairs(cfg().rooms or {}) do
        local name = roomName(r.name)
        if name then
            MySQL.update.await(
                'INSERT INTO `vr_ph_veil_rooms` (`name`, `topic`, `builtin`, `created_at`, `last_at`) VALUES (?, ?, 1, ?, ?) ON DUPLICATE KEY UPDATE `topic` = VALUES(`topic`), `builtin` = 1',
                { name, Phone.text(r.topic, 80), now(), now() }
            )
        end
    end
end

local function isMember(phoneId, roomId)
    return MySQL.scalar.await('SELECT 1 FROM `vr_ph_veil_members` WHERE `room_id` = ? AND `phone_id` = ?', { roomId, phoneId }) ~= nil
end

local function latest(roomId)
    return MySQL.scalar.await('SELECT COALESCE(MAX(`id`), 0) FROM `vr_ph_veil_messages` WHERE `room_id` = ?', { roomId }) or 0
end

-- Rooms the phone is in (with the newest message and how many it has not read), and public rooms it could join.
function Veil.rooms(phoneId)
    local joined = MySQL.query.await(
        'SELECT r.`id`, r.`name`, r.`topic`, r.`builtin`, r.`owner_phone` = ? AS mine, (r.`pass_hash` IS NOT NULL) AS locked, m.`last_read`, '
            .. '(SELECT COUNT(*) FROM `vr_ph_veil_members` x WHERE x.`room_id` = r.`id`) AS members, '
            .. '(SELECT COUNT(*) FROM `vr_ph_veil_messages` g WHERE g.`room_id` = r.`id` AND g.`id` > m.`last_read` AND g.`from_phone` <> ? '
            .. 'AND NOT EXISTS (SELECT 1 FROM `vr_ph_veil_blocks` bl WHERE bl.`phone_id` = ? AND bl.`blocked_phone` = g.`from_phone`)) AS unread, '
            .. '(SELECT g2.`body` FROM `vr_ph_veil_messages` g2 WHERE g2.`room_id` = r.`id` AND NOT EXISTS (SELECT 1 FROM `vr_ph_veil_blocks` b2 WHERE b2.`phone_id` = ? AND b2.`blocked_phone` = g2.`from_phone`) ORDER BY g2.`id` DESC LIMIT 1) AS last_body, '
            .. 'r.`last_at` FROM `vr_ph_veil_members` m JOIN `vr_ph_veil_rooms` r ON r.`id` = m.`room_id` WHERE m.`phone_id` = ? ORDER BY r.`last_at` DESC, r.`name`',
        { phoneId, phoneId, phoneId, phoneId, phoneId }
    ) or {}
    local mine = {}
    local out = {}
    for i, r in ipairs(joined) do
        mine[r.id] = true
        out[i] = {
            id = r.id, name = r.name, topic = r.topic, builtin = Phone.flag(r.builtin), owner = Phone.flag(r.mine), locked = Phone.flag(r.locked),
            members = r.members, unread = r.unread, last = r.last_body, at = r.last_at,
        }
    end
    local open = MySQL.query.await(
        'SELECT r.`id`, r.`name`, r.`topic`, r.`builtin`, (SELECT COUNT(*) FROM `vr_ph_veil_members` x WHERE x.`room_id` = r.`id`) AS members '
            .. 'FROM `vr_ph_veil_rooms` r WHERE r.`pass_hash` IS NULL ORDER BY r.`builtin` DESC, members DESC, r.`name` LIMIT 50',
        {}
    ) or {}
    local discover = {}
    for _, r in ipairs(open) do
        if not mine[r.id] then discover[#discover + 1] = { id = r.id, name = r.name, topic = r.topic, builtin = Phone.flag(r.builtin), members = r.members } end
    end
    return out, discover
end

local function joinedCount(phoneId)
    return MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_veil_members` WHERE `phone_id` = ?', { phoneId }) or 0
end

-- Joins a room by id (public rooms) or by name and password.
function Veil.join(phoneId, ref, pass)
    local room
    if type(ref) == 'number' then
        room = MySQL.single.await('SELECT * FROM `vr_ph_veil_rooms` WHERE `id` = ?', { ref })
    else
        local name = roomName(ref)
        if not name then return nil, 'not_found' end
        room = MySQL.single.await('SELECT * FROM `vr_ph_veil_rooms` WHERE `name` = ?', { name })
    end
    if not room then return nil, 'not_found' end
    if isMember(phoneId, room.id) then return room.id end
    if room.pass_hash then
        -- The same answer for "no such room" and "wrong password", so names cannot be guessed.
        if type(pass) ~= 'string' or pass == '' then return nil, 'not_found' end
        local ok = MySQL.scalar.await('SELECT `pass_hash` = SHA2(CONCAT(`pass_salt`, ?), 256) FROM `vr_ph_veil_rooms` WHERE `id` = ?', { pass, room.id })
        if not (ok == 1 or ok == true) then return nil, 'not_found' end
    end
    if joinedCount(phoneId) >= (cfg().maxJoinedRooms or 15) then return nil, 'too_many_rooms' end
    MySQL.update.await('INSERT IGNORE INTO `vr_ph_veil_members` (`room_id`, `phone_id`, `last_read`) VALUES (?, ?, ?)', { room.id, phoneId, latest(room.id) })
    return room.id
end

function Veil.leave(phoneId, roomId)
    roomId = int(roomId, 0)
    MySQL.update.await('DELETE FROM `vr_ph_veil_members` WHERE `room_id` = ? AND `phone_id` = ?', { roomId, phoneId })
    -- A room nobody is in any more goes away (the ones in the config come back by themselves).
    local left = MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_veil_members` WHERE `room_id` = ?', { roomId }) or 0
    if left == 0 then
        MySQL.update.await('DELETE FROM `vr_ph_veil_rooms` WHERE `id` = ? AND `builtin` = 0', { roomId })
        MySQL.update.await('DELETE FROM `vr_ph_veil_messages` WHERE `room_id` = ? AND NOT EXISTS (SELECT 1 FROM `vr_ph_veil_rooms` r WHERE r.`id` = ?)', { roomId, roomId })
    end
    return true
end

function Veil.create(phoneId, rawName, topic, pass)
    local name = roomName(rawName)
    if not name then return nil, 'invalid_room' end
    if pass ~= nil and pass ~= '' and (type(pass) ~= 'string' or #pass < 3 or #pass > 24) then return nil, 'invalid_pass' end
    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_veil_rooms` WHERE `owner_phone` = ?', { phoneId }) or 0
    if owned >= (cfg().maxOwnedRooms or 2) then return nil, 'too_many_owned' end
    if joinedCount(phoneId) >= (cfg().maxJoinedRooms or 15) then return nil, 'too_many_rooms' end
    if MySQL.scalar.await('SELECT 1 FROM `vr_ph_veil_rooms` WHERE `name` = ?', { name }) then return nil, 'room_exists' end
    local id
    if pass and pass ~= '' then
        local sl = salt()
        id = MySQL.insert.await(
            'INSERT INTO `vr_ph_veil_rooms` (`name`, `topic`, `owner_phone`, `pass_hash`, `pass_salt`, `created_at`, `last_at`) VALUES (?, ?, ?, SHA2(CONCAT(?, ?), 256), ?, ?, ?)',
            { name, Phone.text(topic, 80), phoneId, sl, pass, sl, now(), now() }
        )
    else
        id = MySQL.insert.await(
            'INSERT INTO `vr_ph_veil_rooms` (`name`, `topic`, `owner_phone`, `created_at`, `last_at`) VALUES (?, ?, ?, ?, ?)',
            { name, Phone.text(topic, 80), phoneId, now(), now() }
        )
    end
    if not id then return nil, 'room_exists' end
    MySQL.update.await('INSERT IGNORE INTO `vr_ph_veil_members` (`room_id`, `phone_id`, `last_read`) VALUES (?, ?, 0)', { id, phoneId })
    return id
end

-- ---------------------------------------------------------------- messages

local function shape(row, me)
    return { id = row.id, alias = row.alias or '?', mine = row.from_phone == me, body = row.body, at = row.created_at }
end

-- A page of a room, oldest first. `before` is the id of the oldest message already shown.
function Veil.history(phoneId, roomId, before)
    roomId = int(roomId, 0)
    if not isMember(phoneId, roomId) then return nil, 'not_member' end
    local size = cfg().pageSize or 40
    local args = { roomId, phoneId }
    local where = 'm.`room_id` = ? AND NOT EXISTS (SELECT 1 FROM `vr_ph_veil_blocks` b WHERE b.`phone_id` = ? AND b.`blocked_phone` = m.`from_phone`)'
    before = tonumber(before)
    if before then
        where = where .. ' AND m.`id` < ?'
        args[#args + 1] = before
    end
    local rows = MySQL.query.await(
        'SELECT m.`id`, m.`from_phone`, m.`body`, m.`created_at`, a.`alias` FROM `vr_ph_veil_messages` m LEFT JOIN `vr_ph_veil_aliases` a ON a.`phone_id` = m.`from_phone` '
            .. 'WHERE ' .. where .. ' ORDER BY m.`id` DESC LIMIT ' .. (size + 1),
        args
    ) or {}
    local more = #rows > size
    local out = {}
    for i = math.min(#rows, size), 1, -1 do out[#out + 1] = shape(rows[i], phoneId) end
    return out, more
end

function Veil.readRoom(phoneId, roomId)
    roomId = int(roomId, 0)
    MySQL.update.await('UPDATE `vr_ph_veil_members` SET `last_read` = ? WHERE `room_id` = ? AND `phone_id` = ?', { latest(roomId), roomId, phoneId })
end

local function clean(body)
    return Phone.text(body, cfg().maxMessage or 300, false)
end

local function tell(phoneId, payload, note)
    local src = Phone.Session.srcByPhoneId(phoneId)
    if not src then return end
    TriggerClientEvent(PUSH, src, payload)
    if note then Phone.Notify.push(src, note) end
end

-- Posts in a room and passes it to everyone who is in it and online.
function Veil.say(phoneId, alias, roomId, body)
    roomId = int(roomId, 0)
    if not isMember(phoneId, roomId) then return nil, 'not_member' end
    body = clean(body)
    if not body then return nil, 'empty' end
    local at = now()
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_veil_messages` (`room_id`, `from_phone`, `body`, `created_at`) VALUES (?, ?, ?, ?)', { roomId, phoneId, body, at }
    )
    MySQL.update.await('UPDATE `vr_ph_veil_rooms` SET `last_at` = ? WHERE `id` = ?', { at, roomId })
    MySQL.update.await('UPDATE `vr_ph_veil_members` SET `last_read` = ? WHERE `room_id` = ? AND `phone_id` = ?', { id, roomId, phoneId })

    local members = MySQL.query.await(
        'SELECT m.`phone_id` FROM `vr_ph_veil_members` m WHERE m.`room_id` = ? AND m.`phone_id` <> ? AND NOT EXISTS '
            .. '(SELECT 1 FROM `vr_ph_veil_blocks` b WHERE b.`phone_id` = m.`phone_id` AND b.`blocked_phone` = ?)',
        { roomId, phoneId, phoneId }
    ) or {}
    local room = MySQL.single.await('SELECT `name` FROM `vr_ph_veil_rooms` WHERE `id` = ?', { roomId })
    local lower = body:lower()
    for _, m in ipairs(members) do
        local other = Veil.alias(m.phone_id)
        local note
        -- Only someone who is named gets a banner.
        if other and lower:find('@' .. other:lower(), 1, true) then
            note = { id = ('veil-room-%d'):format(roomId), app = 'veil', title = ('#%s'):format(room and room.name or '?'), message = ('%s: %s'):format(alias, body) }
        end
        tell(m.phone_id, { app = 'veil', kind = 'room', room = roomId, msg = { id = id, alias = alias, mine = false, body = body, at = at } }, note)
    end
    return { id = id, alias = alias, mine = true, body = body, at = at }
end

-- Direct messages ----------------------------------------------------

-- A message to another alias. Someone who blocked you never sees it, and you are not told.
function Veil.dm(phoneId, alias, toAlias, body)
    local to = phoneOf(toAlias)
    if not to then return nil, 'not_found' end
    if to == phoneId then return nil, 'self' end
    if blocked(phoneId, to) then return nil, 'you_blocked' end
    body = clean(body)
    if not body then return nil, 'empty' end
    local at = now()
    if blocked(to, phoneId) then return { id = 0, alias = alias, mine = true, body = body, at = at }, nil, true end

    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_veil_messages` (`from_phone`, `to_phone`, `body`, `created_at`) VALUES (?, ?, ?, ?)', { phoneId, to, body, at }
    )
    MySQL.update.await(
        'INSERT INTO `vr_ph_veil_dmreads` (`phone_id`, `peer_phone`, `last_read`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `last_read` = VALUES(`last_read`)', { phoneId, to, id }
    )
    tell(to, { app = 'veil', kind = 'dm', from = alias, msg = { id = id, alias = alias, mine = false, body = body, at = at } },
        { id = ('veil-dm-%s'):format(alias:lower()), app = 'veil', title = alias, message = body })
    return { id = id, alias = alias, mine = true, body = body, at = at }
end

-- Conversations: the other alias, the last message, and how many are unread. Newest first.
function Veil.dms(phoneId)
    local rows = MySQL.query.await(
        'SELECT CASE WHEN `from_phone` = ? THEN `to_phone` ELSE `from_phone` END AS peer, MAX(`id`) AS last_id FROM `vr_ph_veil_messages` '
            .. 'WHERE `room_id` IS NULL AND (`from_phone` = ? OR `to_phone` = ?) GROUP BY peer ORDER BY last_id DESC LIMIT 50',
        { phoneId, phoneId, phoneId }
    ) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local alias = Veil.alias(r.peer)
        if alias and not blocked(phoneId, r.peer) then
            local last = MySQL.single.await('SELECT `body`, `created_at`, `from_phone` FROM `vr_ph_veil_messages` WHERE `id` = ?', { r.last_id })
            local read = MySQL.scalar.await('SELECT `last_read` FROM `vr_ph_veil_dmreads` WHERE `phone_id` = ? AND `peer_phone` = ?', { phoneId, r.peer }) or 0
            local unread = MySQL.scalar.await(
                'SELECT COUNT(*) FROM `vr_ph_veil_messages` WHERE `room_id` IS NULL AND `from_phone` = ? AND `to_phone` = ? AND `id` > ?', { r.peer, phoneId, read }
            ) or 0
            out[#out + 1] = { alias = alias, last = last and last.body, at = last and last.created_at, mine = last and last.from_phone == phoneId, unread = unread }
        end
    end
    return out
end

function Veil.thread(phoneId, toAlias, before)
    local peer = phoneOf(toAlias)
    if not peer then return nil, 'not_found' end
    if blocked(phoneId, peer) then return nil, 'you_blocked' end
    local size = cfg().pageSize or 40
    local args = { phoneId, peer, peer, phoneId }
    local where = '((m.`from_phone` = ? AND m.`to_phone` = ?) OR (m.`from_phone` = ? AND m.`to_phone` = ?)) AND m.`room_id` IS NULL'
    before = tonumber(before)
    if before then
        where = where .. ' AND m.`id` < ?'
        args[#args + 1] = before
    end
    local rows = MySQL.query.await(
        'SELECT m.`id`, m.`from_phone`, m.`body`, m.`created_at`, a.`alias` FROM `vr_ph_veil_messages` m LEFT JOIN `vr_ph_veil_aliases` a ON a.`phone_id` = m.`from_phone` '
            .. 'WHERE ' .. where .. ' ORDER BY m.`id` DESC LIMIT ' .. (size + 1),
        args
    ) or {}
    local more = #rows > size
    local out = {}
    for i = math.min(#rows, size), 1, -1 do out[#out + 1] = shape(rows[i], phoneId) end
    return out, more
end

function Veil.readDm(phoneId, toAlias)
    local peer = phoneOf(toAlias)
    if not peer then return end
    local last = MySQL.scalar.await(
        'SELECT COALESCE(MAX(`id`), 0) FROM `vr_ph_veil_messages` WHERE `room_id` IS NULL AND `from_phone` = ? AND `to_phone` = ?', { peer, phoneId }
    ) or 0
    MySQL.update.await(
        'INSERT INTO `vr_ph_veil_dmreads` (`phone_id`, `peer_phone`, `last_read`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `last_read` = GREATEST(`last_read`, VALUES(`last_read`))', { phoneId, peer, last }
    )
end

-- ---------------------------------------------------------------- housekeeping

function Veil.clean()
    local c = cfg()
    local t = now()
    MySQL.update.await('DELETE FROM `vr_ph_veil_messages` WHERE `room_id` IS NOT NULL AND `created_at` < ?', { t - (c.keepRoomDays or 7) * 86400 })
    MySQL.update.await('DELETE FROM `vr_ph_veil_messages` WHERE `room_id` IS NULL AND `created_at` < ?', { t - (c.keepDmDays or 30) * 86400 })
    -- Only the newest messages of a busy room are kept.
    local keep = c.keepRoomMessages or 300
    local rooms = MySQL.query.await('SELECT `room_id`, COUNT(*) AS n FROM `vr_ph_veil_messages` WHERE `room_id` IS NOT NULL GROUP BY `room_id` HAVING n > ?', { keep }) or {}
    for _, r in ipairs(rooms) do
        local cut = MySQL.scalar.await('SELECT `id` FROM `vr_ph_veil_messages` WHERE `room_id` = ? ORDER BY `id` DESC LIMIT 1 OFFSET ?', { r.room_id, keep - 1 })
        if cut then MySQL.update.await('DELETE FROM `vr_ph_veil_messages` WHERE `room_id` = ? AND `id` < ?', { r.room_id, cut }) end
    end
    -- Player-made rooms nobody has spoken in for a while.
    local old = MySQL.query.await('SELECT `id` FROM `vr_ph_veil_rooms` WHERE `builtin` = 0 AND `last_at` < ?', { t - (c.roomExpireDays or 14) * 86400 }) or {}
    for _, r in ipairs(old) do
        MySQL.update.await('DELETE FROM `vr_ph_veil_members` WHERE `room_id` = ?', { r.id })
        MySQL.update.await('DELETE FROM `vr_ph_veil_messages` WHERE `room_id` = ?', { r.id })
        MySQL.update.await('DELETE FROM `vr_ph_veil_rooms` WHERE `id` = ?', { r.id })
    end
end

CreateThread(function()
    Phone.DB.waitReady()
    Veil.ensureRooms()
    while true do
        Veil.clean()
        Wait(3600 * 1000)
    end
end)
