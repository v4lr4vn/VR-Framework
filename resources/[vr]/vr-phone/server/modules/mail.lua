-- Mail on ravenmail.io. Each account has its own copy of every message (inbox, sent, trash).
--
-- An account belongs to a name and a password, not to a phone: a phone signs in to one account and can sign out again,
-- and the same account can be signed in on another phone. The password and the recovery code are kept as salted SHA-256
-- (the database does the comparing, like the PIN) and wrong guesses lock the account for a while.
local Mail = {}
Phone.Mail = Mail

local function cfg() return Config.Phone.Mail or {} end
local function domain() return cfg().domain or 'ravenmail.io' end

math.randomseed(os.time() + GetGameTimer())

local function randomSalt()
    local out = {}
    for i = 1, 16 do out[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(out)
end

-- No 0/O/1/I/L: easy to copy by eye.
local ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
local function newRecoveryCode()
    local out = {}
    for i = 1, 12 do
        local n = math.random(1, #ALPHABET)
        out[i] = ALPHABET:sub(n, n)
    end
    return table.concat(out, '', 1, 4) .. '-' .. table.concat(out, '', 5, 8) .. '-' .. table.concat(out, '', 9, 12)
end

local function cleanCode(code)
    if type(code) ~= 'string' then return nil end
    local c = code:upper():gsub('[%s%-]', '')
    if #c ~= 12 or c:find('[^' .. ALPHABET .. ']') then return nil end
    return c
end

-- ---------------------------------------------------------------- addresses

-- 'Name@RavenMail.io' -> 'name'. Returns the part before the @ (lower case) or nil.
function Mail.localPart(value)
    if type(value) ~= 'string' then return nil end
    local s = value:lower():gsub('^%s+', ''):gsub('%s+$', '')
    local name, host = s:match('^([^@]+)@([^@]+)$')
    if host then
        if host ~= domain() then return nil end
        s = name
    end
    if #s < 3 or #s > 20 then return nil end
    if not s:match('^[a-z0-9][a-z0-9._]*[a-z0-9]$') or s:find('%.%.') or s:find('%._') or s:find('_%.') then return nil end
    return s
end

local function addressOf(name) return name .. '@' .. domain() end

local function isReserved(name)
    for _, r in ipairs(cfg().reserved or {}) do
        if r == name then return true end
    end
    return false
end

-- ---------------------------------------------------------------- accounts

local function toAccount(row) return { id = row.id, address = row.address, name = row.name } end

function Mail.account(phoneId)
    local row = MySQL.single.await(
        'SELECT a.`id`, a.`address`, a.`name` FROM `vr_ph_mail_links` l JOIN `vr_ph_mail_accounts` a ON a.`id` = l.`account_id` WHERE l.`phone_id` = ?',
        { phoneId }
    )
    return row and toAccount(row) or nil
end

local function link(phoneId, accountId)
    MySQL.update.await('DELETE FROM `vr_ph_mail_links` WHERE `phone_id` = ?', { phoneId })
    MySQL.insert.await('INSERT INTO `vr_ph_mail_links` (`phone_id`, `account_id`) VALUES (?, ?)', { phoneId, accountId })
end

-- Makes an account and signs the phone in. name is the display name (optional).
-- Returns account, recoveryCode  or  nil, reason ('invalid_address', 'reserved', 'taken', 'weak_password', 'has_account', 'failed').
function Mail.create(phoneId, address, password, name)
    if Mail.account(phoneId) then return nil, 'has_account' end
    local part = Mail.localPart(address)
    if not part then return nil, 'invalid_address' end
    if isReserved(part) then return nil, 'reserved' end
    if type(password) ~= 'string' or #password < 6 or #password > 40 then return nil, 'weak_password' end
    local full = addressOf(part)
    if MySQL.scalar.await('SELECT `id` FROM `vr_ph_mail_accounts` WHERE `address` = ?', { full }) then return nil, 'taken' end

    local code = newRecoveryCode()
    local salt, rsalt = randomSalt(), randomSalt()
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_mail_accounts` (`address`, `name`, `pass_hash`, `pass_salt`, `recovery_hash`, `recovery_salt`, `created_at`) '
            .. 'VALUES (?, ?, SHA2(CONCAT(?, ?), 256), ?, SHA2(CONCAT(?, ?), 256), ?, ?)',
        { full, Phone.text(name, 60), salt, password, salt, rsalt, cleanCode(code), rsalt, os.time() }
    )
    -- Two phones can pick the same name at the same moment: the unique key lets only one win.
    if not id then return nil, 'taken' end
    link(phoneId, id)
    return { id = id, address = full, name = Phone.text(name, 60) }, code
end

-- Wrong guesses lock the account: 5 wrong in a row = 1 minute, then 5 minutes, 30 minutes.
local function lockSeconds(fails)
    if fails >= 15 then return 1800 end
    if fails >= 10 then return 300 end
    if fails >= 5 then return 60 end
    return 0
end

-- Checks a secret (password or recovery code). field is 'pass' or 'recovery'.
-- Returns the account row, or nil and 'wrong' | 'locked' | 'no_account', plus the seconds left on a lock.
local function check(address, secret, field)
    local part = Mail.localPart(address)
    if not part or type(secret) ~= 'string' then return nil, 'wrong', 0 end
    local row = MySQL.single.await('SELECT `id`, `address`, `name`, `fail_count`, `locked_until` FROM `vr_ph_mail_accounts` WHERE `address` = ?', { addressOf(part) })
    -- Same answer for a name that does not exist and a wrong password, so nobody can look names up this way.
    if not row then return nil, 'wrong', 0 end
    local now = os.time()
    if row.locked_until > now then return nil, 'locked', row.locked_until - now end

    local col = field == 'pass' and 'pass' or 'recovery'
    local result = MySQL.scalar.await(
        ('SELECT `%s_hash` = SHA2(CONCAT(`%s_salt`, ?), 256) FROM `vr_ph_mail_accounts` WHERE `id` = ?'):format(col, col),
        { secret, row.id }
    )
    if result == 1 or result == true then
        MySQL.update.await('UPDATE `vr_ph_mail_accounts` SET `fail_count` = 0, `locked_until` = 0 WHERE `id` = ?', { row.id })
        return row
    end
    local fails = row.fail_count + 1
    local secs = lockSeconds(fails)
    MySQL.update.await('UPDATE `vr_ph_mail_accounts` SET `fail_count` = ?, `locked_until` = ? WHERE `id` = ?', { fails, secs > 0 and (now + secs) or 0, row.id })
    return nil, secs > 0 and 'locked' or 'wrong', secs
end

-- Returns account, or nil, 'wrong' | 'locked', secondsLeft.
function Mail.login(phoneId, address, password)
    local row, why, secs = check(address, password, 'pass')
    if not row then return nil, why, secs end
    link(phoneId, row.id)
    return toAccount(row)
end

function Mail.logout(phoneId)
    MySQL.update.await('DELETE FROM `vr_ph_mail_links` WHERE `phone_id` = ?', { phoneId })
    return true
end

-- Sets a new password with the recovery code, signs the phone in and gives out a new recovery code (the old one stops working).
-- Returns account, newCode  or  nil, reason.
function Mail.reset(phoneId, address, code, newPassword)
    if type(newPassword) ~= 'string' or #newPassword < 6 or #newPassword > 40 then return nil, 'weak_password' end
    local clean = cleanCode(code)
    if not clean then
        -- Count it as a wrong guess anyway.
        check(address, 'x', 'recovery')
        return nil, 'wrong'
    end
    local row, why, secs = check(address, clean, 'recovery')
    if not row then return nil, why, secs end
    local salt, rsalt, fresh = randomSalt(), randomSalt(), newRecoveryCode()
    MySQL.update.await(
        'UPDATE `vr_ph_mail_accounts` SET `pass_salt` = ?, `pass_hash` = SHA2(CONCAT(?, ?), 256), `recovery_salt` = ?, `recovery_hash` = SHA2(CONCAT(?, ?), 256) WHERE `id` = ?',
        { salt, salt, newPassword, rsalt, rsalt, cleanCode(fresh), row.id }
    )
    link(phoneId, row.id)
    return toAccount(row), fresh
end

function Mail.changePassword(accountId, address, old, new)
    if type(new) ~= 'string' or #new < 6 or #new > 40 then return false, 'weak_password' end
    local row, why, secs = check(address, old, 'pass')
    if not row or row.id ~= accountId then return false, why or 'wrong', secs end
    local salt = randomSalt()
    MySQL.update.await('UPDATE `vr_ph_mail_accounts` SET `pass_salt` = ?, `pass_hash` = SHA2(CONCAT(?, ?), 256) WHERE `id` = ?', { salt, salt, new, accountId })
    return true
end

-- ---------------------------------------------------------------- reading

local FOLDERS = { inbox = true, sent = true, trash = true }

local function toHeader(r)
    local body = (r.body or ''):gsub('%s+', ' ')
    return {
        id = r.id, from = r.from_addr, fromName = r.from_name, to = r.to_addr, subject = r.subject,
        preview = body:sub(1, 90), read = r.is_read == 1 or r.is_read == true,
        starred = r.starred == 1 or r.starred == true, at = r.created_at, was = r.was,
    }
end

-- folder: 'inbox' | 'sent' | 'trash' | 'starred'. before: the id of the last message already shown. Returns messages, more.
function Mail.list(accountId, folder, before)
    local size = cfg().pageSize or 30
    local where, args = '`account_id` = ?', { accountId }
    if folder == 'starred' then
        where = where .. " AND `starred` = 1 AND `folder` <> 'trash'"
    elseif FOLDERS[folder] then
        where = where .. ' AND `folder` = ?'
        args[#args + 1] = folder
    else
        return nil, 'invalid'
    end
    before = tonumber(before)
    if before then
        where = where .. ' AND `id` < ?'
        args[#args + 1] = before
    end
    local rows = MySQL.query.await(
        'SELECT `id`, `from_addr`, `from_name`, `to_addr`, `subject`, LEFT(`body`, 120) AS `body`, `is_read`, `starred`, `created_at`, `was` FROM `vr_ph_mail` '
            .. 'WHERE ' .. where .. ' ORDER BY `id` DESC LIMIT ' .. (size + 1),
        args
    ) or {}
    local more = #rows > size
    local out = {}
    for i = 1, math.min(#rows, size) do out[i] = toHeader(rows[i]) end
    return out, more
end

-- One message in full. Reading an inbox message marks it as read.
function Mail.get(accountId, id)
    id = tonumber(id)
    if not id then return nil end
    local r = MySQL.single.await('SELECT * FROM `vr_ph_mail` WHERE `account_id` = ? AND `id` = ?', { accountId, id })
    if not r then return nil end
    if r.folder == 'inbox' and r.is_read == 0 then
        MySQL.update.await('UPDATE `vr_ph_mail` SET `is_read` = 1 WHERE `id` = ?', { id })
        r.is_read = 1
    end
    local m = toHeader(r)
    m.body = r.body or ''
    m.folder = r.folder
    return m
end

function Mail.counts(accountId)
    local rows = MySQL.query.await("SELECT `folder`, COUNT(*) AS `n`, COUNT(CASE WHEN `is_read` = 0 THEN 1 END) AS `unread` FROM `vr_ph_mail` WHERE `account_id` = ? GROUP BY `folder`", { accountId }) or {}
    local out = { inbox = 0, unread = 0, sent = 0, trash = 0 }
    for _, r in ipairs(rows) do
        out[r.folder] = tonumber(r.n) or 0
        if r.folder == 'inbox' then out.unread = tonumber(r.unread) or 0 end
    end
    return out
end

-- The number on the Mail icon, for the phone with this number.
function Mail.unreadByNumber(number)
    return tonumber(MySQL.scalar.await(
        "SELECT COUNT(*) FROM `vr_ph_mail` m JOIN `vr_ph_mail_links` l ON l.`account_id` = m.`account_id` JOIN `vr_ph_phones` p ON p.`phone_id` = l.`phone_id` "
            .. "WHERE p.`number` = ? AND m.`folder` = 'inbox' AND m.`is_read` = 0",
        { number }
    )) or 0
end

-- ---------------------------------------------------------------- writing

-- Keeps a folder from growing without end: the oldest go.
local function trim(accountId, folder)
    local max = cfg().maxPerFolder or 300
    local keep = MySQL.query.await('SELECT `id` FROM `vr_ph_mail` WHERE `account_id` = ? AND `folder` = ? ORDER BY `id` DESC LIMIT 1 OFFSET ' .. (max - 1), { accountId, folder })
    if keep and keep[1] then
        MySQL.update.await('DELETE FROM `vr_ph_mail` WHERE `account_id` = ? AND `folder` = ? AND `id` < ?', { accountId, folder, keep[1].id })
    end
end

local function deliver(toAccount, rec)
    MySQL.insert.await(
        'INSERT INTO `vr_ph_mail` (`account_id`, `folder`, `from_addr`, `from_name`, `to_addr`, `subject`, `body`, `is_read`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)',
        { toAccount, 'inbox', rec.from, rec.fromName, rec.to, rec.subject, rec.body, os.time() }
    )
    trim(toAccount, 'inbox')
    -- Every phone signed in to the account hears about it.
    local numbers = MySQL.query.await(
        'SELECT p.`number` FROM `vr_ph_mail_links` l JOIN `vr_ph_phones` p ON p.`phone_id` = l.`phone_id` WHERE l.`account_id` = ?',
        { toAccount }
    ) or {}
    for _, row in ipairs(numbers) do
        Phone.Notify.push(row.number, { app = 'mail', title = rec.fromName or rec.from, message = rec.subject })
    end
end

local function clean(subject, body)
    local c = cfg()
    local s = Phone.text(subject, c.subjectLength or 100)
    local b = Phone.text(body, c.bodyLength or 4000, true)
    return s, b
end

-- A player writes a message. from = the signed-in account ({ id, address, name }).
-- Returns true, or false and a reason ('invalid_address', 'no_such_account', 'empty').
function Mail.send(from, to, subject, body)
    local part = Mail.localPart(to)
    if not part then return false, 'invalid_address' end
    local s, b = clean(subject, body)
    if not s and not b then return false, 'empty' end
    s = s or '(no subject)'

    local rcpt = MySQL.single.await('SELECT `id`, `address` FROM `vr_ph_mail_accounts` WHERE `address` = ?', { addressOf(part) })
    if not rcpt then return false, 'no_such_account' end

    MySQL.insert.await(
        'INSERT INTO `vr_ph_mail` (`account_id`, `folder`, `from_addr`, `from_name`, `to_addr`, `subject`, `body`, `is_read`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)',
        { from.id, 'sent', from.address, from.name, rcpt.address, s, b, os.time() }
    )
    trim(from.id, 'sent')
    deliver(rcpt.id, { from = from.address, fromName = from.name, to = rcpt.address, subject = s, body = b })
    return true
end

-- A message from a script (a shop, the courier, a job): it has no account of its own.
-- rec = { from = 'courier@ravenmail.io' (optional), fromName = 'Courier', subject, body }. Returns true, or false and a reason.
function Mail.system(to, rec)
    if type(rec) ~= 'table' then return false, 'invalid' end
    local part = Mail.localPart(to)
    if not part then return false, 'invalid_address' end
    local s, b = clean(rec.subject, rec.body)
    if not s and not b then return false, 'empty' end
    local rcpt = MySQL.single.await('SELECT `id`, `address` FROM `vr_ph_mail_accounts` WHERE `address` = ?', { addressOf(part) })
    if not rcpt then return false, 'no_such_account' end
    local fromPart = Mail.localPart(rec.from or '') or 'noreply'
    deliver(rcpt.id, { from = addressOf(fromPart), fromName = Phone.text(rec.fromName, 60), to = rcpt.address, subject = s or '(no subject)', body = b })
    return true
end

-- ---------------------------------------------------------------- organising

local function idList(ids)
    local out, seen = {}, {}
    if type(ids) ~= 'table' then return out end
    for _, v in ipairs(ids) do
        local n = tonumber(v)
        if n and not seen[n] and #out < 100 then seen[n] = true out[#out + 1] = math.floor(n) end
    end
    return out
end

local function marks(list) return string.rep('?,', #list):sub(1, -2) end

function Mail.mark(accountId, ids, patch)
    local list = idList(ids)
    if #list == 0 or type(patch) ~= 'table' then return 0 end
    local sets, args = {}, {}
    if patch.read ~= nil then sets[#sets + 1] = '`is_read` = ?' args[#args + 1] = patch.read == true and 1 or 0 end
    if patch.starred ~= nil then sets[#sets + 1] = '`starred` = ?' args[#args + 1] = patch.starred == true and 1 or 0 end
    if #sets == 0 then return 0 end
    args[#args + 1] = accountId
    for _, id in ipairs(list) do args[#args + 1] = id end
    return MySQL.update.await('UPDATE `vr_ph_mail` SET ' .. table.concat(sets, ', ') .. ' WHERE `account_id` = ? AND `id` IN (' .. marks(list) .. ')', args) or 0
end

function Mail.trash(accountId, ids)
    local list = idList(ids)
    if #list == 0 then return 0 end
    local args = { os.time(), accountId }
    for _, id in ipairs(list) do args[#args + 1] = id end
    return MySQL.update.await(
        "UPDATE `vr_ph_mail` SET `was` = `folder`, `folder` = 'trash', `trashed_at` = ? WHERE `account_id` = ? AND `folder` <> 'trash' AND `id` IN (" .. marks(list) .. ')',
        args
    ) or 0
end

function Mail.restore(accountId, ids)
    local list = idList(ids)
    if #list == 0 then return 0 end
    local args = { accountId }
    for _, id in ipairs(list) do args[#args + 1] = id end
    return MySQL.update.await(
        "UPDATE `vr_ph_mail` SET `folder` = COALESCE(`was`, 'inbox'), `was` = NULL, `trashed_at` = 0 WHERE `account_id` = ? AND `folder` = 'trash' AND `id` IN (" .. marks(list) .. ')',
        args
    ) or 0
end

function Mail.erase(accountId, ids)
    local list = idList(ids)
    if #list == 0 then return 0 end
    local args = { accountId }
    for _, id in ipairs(list) do args[#args + 1] = id end
    return MySQL.update.await("DELETE FROM `vr_ph_mail` WHERE `account_id` = ? AND `folder` = 'trash' AND `id` IN (" .. marks(list) .. ')', args) or 0
end

function Mail.emptyTrash(accountId)
    return MySQL.update.await("DELETE FROM `vr_ph_mail` WHERE `account_id` = ? AND `folder` = 'trash'", { accountId }) or 0
end

function Mail.purgeOld()
    local days = cfg().keepTrashDays or 30
    MySQL.update.await("DELETE FROM `vr_ph_mail` WHERE `folder` = 'trash' AND `trashed_at` > 0 AND `trashed_at` < ?", { os.time() - days * 86400 })
end

CreateThread(function()
    Phone.DB.waitReady()
    while true do
        Mail.purgeOld()
        Wait(3600 * 1000)
    end
end)
