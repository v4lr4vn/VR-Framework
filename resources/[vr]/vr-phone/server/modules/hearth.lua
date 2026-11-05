-- Hearth: dating. A profile starts from the character (first name, age from the date of birth, gender); the rest is the player's own.
-- Other people only ever see a profile id, a first name, an age, a bio, tags and photos. Phone numbers and phone ids never leave the server.
local Hearth = {}
Phone.Hearth = Hearth

local function cfg() return Config.Phone.Hearth or {} end
local function now() return os.time() end
local function int(v, d) return math.floor(tonumber(v) or d) end

local PUSH = 'vr-phone:client:social'
local DAY = 86400

-- gender: 0 man, 1 woman (what the framework stores). show_me: 0 men, 1 women, 2 everyone.

-- ---------------------------------------------------------------- the character

-- What the create form starts with. age is nil when the character has no usable date of birth (the player types one then).
function Hearth.suggest(src)
    local p = Bridge.player(src) or {}
    local age
    if cfg().ageFromCharacter ~= false and type(p.dob) == 'string' then
        local y, m, d = p.dob:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
        if y then
            local t = os.date('*t')
            age = t.year - tonumber(y)
            if t.month < tonumber(m) or (t.month == tonumber(m) and t.day < tonumber(d)) then age = age - 1 end
            if age < 0 or age > 120 then age = nil end
        end
    end
    local gender = tonumber(p.gender)
    return {
        name = Phone.text(p.firstname, cfg().nameMax or 20),
        age = age,
        gender = (gender == 0 or gender == 1) and gender or nil,
        minAge = cfg().minAge or 18, maxAge = cfg().maxAge or 99,
        tags = cfg().tags or {},
    }
end

-- ---------------------------------------------------------------- profiles

local function decodeList(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, v = pcall(json.decode, text)
    return ok and type(v) == 'table' and v or {}
end

local function raw(phoneId)
    -- (+ 0 keeps the small number columns numbers: the database layer turns TINYINT(1) into true/false, and show_me can be 2)
    return MySQL.single.await(
        'SELECT `id`, `phone_id`, `name`, `age`, `gender` + 0 AS `gender`, `show_me` + 0 AS `show_me`, `bio`, `tags`, `photos`, `visible` + 0 AS `visible`, `created_at`, `active_at` FROM `vr_ph_hearth_profiles` WHERE `phone_id` = ?',
        { phoneId }
    )
end

local function mine(row)
    return {
        id = row.id, name = row.name, age = row.age, gender = row.gender, showMe = row.show_me, bio = row.bio or '',
        tags = decodeList(row.tags), photos = #decodeList(row.photos), visible = Phone.flag(row.visible),
    }
end

local function card(row)
    return { id = row.id, name = row.name, age = row.age, bio = row.bio or '', tags = decodeList(row.tags), photos = #decodeList(row.photos) }
end

function Hearth.profile(phoneId)
    local row = raw(phoneId)
    return row and mine(row) or nil
end

local function cleanTags(list)
    local allowed = {}
    for _, t in ipairs(cfg().tags or {}) do allowed[t] = true end
    local out, seen = {}, {}
    if type(list) ~= 'table' then return out end
    for _, t in ipairs(list) do
        if type(t) == 'string' and allowed[t] and not seen[t] and #out < (cfg().maxTags or 5) then
            seen[t] = true
            out[#out + 1] = t
        end
    end
    return out
end

-- Photo ids from the Gallery become copies of those pictures. Only photos the phone owns are used.
local function copyPhotos(phoneId, ids)
    local out = {}
    if type(ids) ~= 'table' then return out end
    local seen = {}
    for _, id in ipairs(ids) do
        id = tonumber(id)
        if id and not seen[id] and #out < (cfg().maxPhotos or 3) then
            seen[id] = true
            local m = Phone.Media.get(phoneId, id)
            if m and type(m.image) == 'string' and m.image ~= '' then out[#out + 1] = m.image end
        end
    end
    return out
end

local function ageOk(age)
    return age and age >= (cfg().minAge or 18) and age <= (cfg().maxAge or 99)
end

-- data: { name, age (only when the character has none), gender (same), showMe, bio, tags, photos = { gallery ids } }
function Hearth.create(src, phoneId, data)
    if raw(phoneId) then return nil, 'exists' end
    data = type(data) == 'table' and data or {}
    local base = Hearth.suggest(src)
    local name = Phone.text(data.name, cfg().nameMax or 20) or base.name
    if not name then return nil, 'invalid_name' end
    local age = base.age or int(data.age, 0)
    if not ageOk(age) then return nil, 'invalid_age' end
    local gender = base.gender
    if gender == nil then
        gender = tonumber(data.gender)
        if gender ~= 0 and gender ~= 1 then return nil, 'invalid_gender' end
    end
    local showMe = tonumber(data.showMe)
    if showMe ~= 0 and showMe ~= 1 and showMe ~= 2 then showMe = 2 end
    local bio = Phone.text(data.bio, cfg().bioMax or 240, true) or ''
    local t = now()
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_hearth_profiles` (`phone_id`, `name`, `age`, `gender`, `show_me`, `bio`, `tags`, `photos`, `visible`, `created_at`, `active_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)',
        { phoneId, name, age, gender, showMe, bio, json.encode(cleanTags(data.tags)), json.encode(copyPhotos(phoneId, data.photos)), t, t }
    )
    if not id then return nil, 'exists' end
    return Hearth.profile(phoneId)
end

-- Changes the fields that were sent. Age and gender are the character's and cannot be changed here.
function Hearth.update(phoneId, patch)
    local row = raw(phoneId)
    if not row then return nil, 'no_profile' end
    patch = type(patch) == 'table' and patch or {}
    local sets, args = {}, {}
    local function set(col, value) sets[#sets + 1] = '`' .. col .. '` = ?' args[#args + 1] = value end

    if patch.name ~= nil then
        local name = Phone.text(patch.name, cfg().nameMax or 20)
        if not name then return nil, 'invalid_name' end
        set('name', name)
    end
    if patch.bio ~= nil then set('bio', Phone.text(patch.bio, cfg().bioMax or 240, true) or '') end
    if type(patch.tags) == 'table' then set('tags', json.encode(cleanTags(patch.tags))) end
    if patch.showMe ~= nil then
        local v = tonumber(patch.showMe)
        if v ~= 0 and v ~= 1 and v ~= 2 then return nil, 'invalid' end
        set('show_me', v)
    end
    if patch.visible ~= nil then set('visible', patch.visible == true and 1 or 0) end
    if type(patch.photos) == 'table' then set('photos', json.encode(copyPhotos(phoneId, patch.photos))) end
    if #sets == 0 then return mine(row) end
    args[#args + 1] = phoneId
    MySQL.update.await('UPDATE `vr_ph_hearth_profiles` SET ' .. table.concat(sets, ', ') .. ' WHERE `phone_id` = ?', args)
    return Hearth.profile(phoneId)
end

-- Removes the profile and everything that hangs on it: swipes, matches, chats.
function Hearth.remove(phoneId)
    local row = raw(phoneId)
    if not row then return true end
    local matches = MySQL.query.await('SELECT `id` FROM `vr_ph_hearth_matches` WHERE `a_id` = ? OR `b_id` = ?', { row.id, row.id }) or {}
    for _, m in ipairs(matches) do
        MySQL.update.await('DELETE FROM `vr_ph_hearth_messages` WHERE `match_id` = ?', { m.id })
    end
    MySQL.update.await('DELETE FROM `vr_ph_hearth_matches` WHERE `a_id` = ? OR `b_id` = ?', { row.id, row.id })
    MySQL.update.await('DELETE FROM `vr_ph_hearth_swipes` WHERE `phone_id` = ? OR `target_id` = ?', { phoneId, row.id })
    MySQL.update.await('DELETE FROM `vr_ph_hearth_profiles` WHERE `id` = ?', { row.id })
    return true
end

-- Opening the app keeps the profile "active" (so it stays in other people's decks).
function Hearth.touch(phoneId)
    MySQL.update.await('UPDATE `vr_ph_hearth_profiles` SET `active_at` = ? WHERE `phone_id` = ?', { now(), phoneId })
end

-- One photo of a profile, for the card or the match list. Only for profiles that are shown, or the ones the viewer has matched.
function Hearth.photo(phoneId, profileId, index)
    local me = raw(phoneId)
    profileId = int(profileId, 0)
    index = int(index, 0)
    if profileId == 0 or index < 0 then return nil end
    if me and me.id == profileId then
        return decodeList(me.photos)[index + 1]
    end
    local row = MySQL.single.await('SELECT `photos`, `visible` + 0 AS `visible` FROM `vr_ph_hearth_profiles` WHERE `id` = ?', { profileId })
    if not row then return nil end
    if not Phone.flag(row.visible) then
        if not me then return nil end
        local a, b = math.min(me.id, profileId), math.max(me.id, profileId)
        if not MySQL.scalar.await('SELECT 1 FROM `vr_ph_hearth_matches` WHERE `a_id` = ? AND `b_id` = ?', { a, b }) then return nil end
    end
    return decodeList(row.photos)[index + 1]
end

-- ---------------------------------------------------------------- the deck

local function likesLeft(phoneId)
    local used = MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_hearth_swipes` WHERE `phone_id` = ? AND `liked` = 1 AND `created_at` > ?', { phoneId, now() - DAY }) or 0
    return math.max(0, (cfg().dailyLikes or 40) - used)
end

-- Profiles to look at: shown, not me, not seen before, matching what both sides want, opened recently. Random order.
function Hearth.deck(phoneId)
    local me = raw(phoneId)
    if not me then return nil, 'no_profile' end
    local args = { me.id, phoneId, now() - (cfg().activeDays or 30) * DAY, phoneId, me.gender }
    local where = 'p.`visible` = 1 AND p.`id` <> ? AND p.`phone_id` <> ? AND p.`active_at` > ? '
        .. 'AND NOT EXISTS (SELECT 1 FROM `vr_ph_hearth_swipes` s WHERE s.`phone_id` = ? AND s.`target_id` = p.`id`) '
        .. 'AND (p.`show_me` = 2 OR p.`show_me` = ?)'
    if me.show_me ~= 2 then
        where = where .. ' AND p.`gender` = ?'
        args[#args + 1] = me.show_me
    end
    local rows = MySQL.query.await(
        'SELECT p.`id`, p.`name`, p.`age`, p.`bio`, p.`tags`, p.`photos` FROM `vr_ph_hearth_profiles` p WHERE ' .. where .. ' ORDER BY RAND() LIMIT ' .. (cfg().deckSize or 5),
        args
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = card(r) end
    return out, likesLeft(phoneId)
end

-- ---------------------------------------------------------------- matches

local function tell(phoneId, payload, note)
    local src = Phone.Session.srcByPhoneId(phoneId)
    if not src then return end
    TriggerClientEvent(PUSH, src, payload)
    if note then Phone.Notify.push(src, note) end
end

-- A match, as the viewer sees it: the other person's card, the last message and the unread count.
local function matchShape(m, meId)
    local otherId = m.a_id == meId and m.b_id or m.a_id
    local other = MySQL.single.await('SELECT `id`, `name`, `age`, `bio`, `tags`, `photos` FROM `vr_ph_hearth_profiles` WHERE `id` = ?', { otherId })
    if not other then return nil end
    local read = m.a_id == meId and m.a_read or m.b_read
    local last = MySQL.single.await('SELECT `body`, `from_id`, `created_at` FROM `vr_ph_hearth_messages` WHERE `match_id` = ? ORDER BY `id` DESC LIMIT 1', { m.id })
    local unread = MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_hearth_messages` WHERE `match_id` = ? AND `from_id` <> ? AND `id` > ?', { m.id, meId, read }) or 0
    return {
        id = m.id, with = card(other), at = last and last.created_at or m.created_at,
        last = last and last.body, mine = last and last.from_id == meId or false, unread = unread, new = last == nil,
    }
end

function Hearth.matches(phoneId)
    local me = raw(phoneId)
    if not me then return nil, 'no_profile' end
    local rows = MySQL.query.await('SELECT * FROM `vr_ph_hearth_matches` WHERE `a_id` = ? OR `b_id` = ?', { me.id, me.id }) or {}
    local out = {}
    for _, m in ipairs(rows) do
        local s = matchShape(m, me.id)
        if s then out[#out + 1] = s end
    end
    table.sort(out, function(a, b) return (a.at or 0) > (b.at or 0) end)
    return out
end

local function ownMatch(phoneId, matchId)
    local me = raw(phoneId)
    if not me then return nil end
    matchId = int(matchId, 0)
    local m = MySQL.single.await('SELECT * FROM `vr_ph_hearth_matches` WHERE `id` = ? AND (`a_id` = ? OR `b_id` = ?)', { matchId, me.id, me.id })
    return m, me
end

-- like = true to like, false to pass. Returns { ok, matched, match, left }.
function Hearth.swipe(phoneId, targetId, like)
    local me = raw(phoneId)
    if not me then return nil, 'no_profile' end
    targetId = int(targetId, 0)
    if targetId == 0 or targetId == me.id then return nil, 'not_found' end
    local target = MySQL.single.await('SELECT * FROM `vr_ph_hearth_profiles` WHERE `id` = ? AND `visible` = 1', { targetId })
    if not target then return nil, 'not_found' end
    if MySQL.scalar.await('SELECT 1 FROM `vr_ph_hearth_swipes` WHERE `phone_id` = ? AND `target_id` = ?', { phoneId, targetId }) then return nil, 'seen' end
    like = like == true
    if like and likesLeft(phoneId) <= 0 then return nil, 'no_likes' end
    MySQL.update.await('INSERT IGNORE INTO `vr_ph_hearth_swipes` (`phone_id`, `target_id`, `liked`, `created_at`) VALUES (?, ?, ?, ?)', { phoneId, targetId, like and 1 or 0, now() })

    local matched, match = false, nil
    if like and MySQL.scalar.await('SELECT 1 FROM `vr_ph_hearth_swipes` WHERE `phone_id` = ? AND `target_id` = ? AND `liked` = 1', { target.phone_id, me.id }) then
        local a, b = math.min(me.id, targetId), math.max(me.id, targetId)
        local id = MySQL.insert.await('INSERT IGNORE INTO `vr_ph_hearth_matches` (`a_id`, `b_id`, `created_at`) VALUES (?, ?, ?)', { a, b, now() })
        if id and id > 0 then
            matched = true
            local row = MySQL.single.await('SELECT * FROM `vr_ph_hearth_matches` WHERE `id` = ?', { id })
            match = matchShape(row, me.id)
            -- The other side hears about it at once.
            local theirs = matchShape(row, targetId)
            tell(target.phone_id, { app = 'hearth', kind = 'match', match = theirs },
                { id = ('hearth-match-%d'):format(id), app = 'hearth', titleKey = 'hearth.n.match', messageKey = 'hearth.n.matchText', data = { name = me.name } })
        end
    end
    return { matched = matched, match = match, left = likesLeft(phoneId) }
end

function Hearth.unmatch(phoneId, matchId)
    local m, me = ownMatch(phoneId, matchId)
    if not m then return false, 'not_found' end
    MySQL.update.await('DELETE FROM `vr_ph_hearth_messages` WHERE `match_id` = ?', { m.id })
    MySQL.update.await('DELETE FROM `vr_ph_hearth_matches` WHERE `id` = ?', { m.id })
    local otherId = m.a_id == me.id and m.b_id or m.a_id
    local other = MySQL.scalar.await('SELECT `phone_id` FROM `vr_ph_hearth_profiles` WHERE `id` = ?', { otherId })
    if other then tell(other, { app = 'hearth', kind = 'unmatch', match = m.id }) end
    return true
end

-- ---------------------------------------------------------------- chat

local function shape(row, meId)
    return { id = row.id, mine = row.from_id == meId, body = row.body, at = row.created_at }
end

function Hearth.thread(phoneId, matchId, before)
    local m, me = ownMatch(phoneId, matchId)
    if not m then return nil, 'not_found' end
    local size = cfg().pageSize or 40
    local args = { m.id }
    local where = '`match_id` = ?'
    before = tonumber(before)
    if before then
        where = where .. ' AND `id` < ?'
        args[#args + 1] = before
    end
    local rows = MySQL.query.await('SELECT `id`, `from_id`, `body`, `created_at` FROM `vr_ph_hearth_messages` WHERE ' .. where .. ' ORDER BY `id` DESC LIMIT ' .. (size + 1), args) or {}
    local more = #rows > size
    local out = {}
    for i = math.min(#rows, size), 1, -1 do out[#out + 1] = shape(rows[i], me.id) end
    return out, more
end

function Hearth.read(phoneId, matchId)
    local m, me = ownMatch(phoneId, matchId)
    if not m then return end
    local last = MySQL.scalar.await('SELECT COALESCE(MAX(`id`), 0) FROM `vr_ph_hearth_messages` WHERE `match_id` = ?', { m.id }) or 0
    MySQL.update.await('UPDATE `vr_ph_hearth_matches` SET `' .. (m.a_id == me.id and 'a_read' or 'b_read') .. '` = ? WHERE `id` = ?', { last, m.id })
end

function Hearth.say(phoneId, matchId, body)
    local m, me = ownMatch(phoneId, matchId)
    if not m then return nil, 'not_found' end
    body = Phone.text(body, cfg().maxMessage or 300, false)
    if not body then return nil, 'empty' end
    local at = now()
    local id = MySQL.insert.await('INSERT INTO `vr_ph_hearth_messages` (`match_id`, `from_id`, `body`, `created_at`) VALUES (?, ?, ?, ?)', { m.id, me.id, body, at })
    MySQL.update.await('UPDATE `vr_ph_hearth_matches` SET `' .. (m.a_id == me.id and 'a_read' or 'b_read') .. '` = ? WHERE `id` = ?', { id, m.id })
    local otherId = m.a_id == me.id and m.b_id or m.a_id
    local other = MySQL.scalar.await('SELECT `phone_id` FROM `vr_ph_hearth_profiles` WHERE `id` = ?', { otherId })
    if other then
        tell(other, { app = 'hearth', kind = 'message', match = m.id, msg = { id = id, mine = false, body = body, at = at } },
            { id = ('hearth-msg-%d'):format(m.id), app = 'hearth', title = me.name, message = body })
    end
    return { id = id, mine = true, body = body, at = at }
end

-- ---------------------------------------------------------------- housekeeping

function Hearth.clean()
    local t = now()
    MySQL.update.await('DELETE FROM `vr_ph_hearth_messages` WHERE `created_at` < ?', { t - (cfg().keepMessageDays or 60) * DAY })
    -- A pass is forgotten after a while, so the profile can come round again.
    MySQL.update.await('DELETE FROM `vr_ph_hearth_swipes` WHERE `liked` = 0 AND `created_at` < ?', { t - 30 * DAY })
end

CreateThread(function()
    Phone.DB.waitReady()
    while true do
        Hearth.clean()
        Wait(3600 * 1000)
    end
end)
