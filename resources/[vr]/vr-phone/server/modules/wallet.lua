-- Wallet. Shows the player's money, sends money to another phone number and asks for money.
--
-- Money only ever moves on the server, from the sender's bank account to the receiver's. If the second half fails the first is
-- paid back, so a transfer either happens in full or not at all.
local Wallet = {}
Phone.Wallet = Wallet

local function cfg() return Config.Phone.Wallet or {} end

local busy = {} -- phoneId -> true while a transfer for that phone is in progress

local function now() return os.time() end

-- A whole number of dollars within the limits, or nil and a reason.
function Wallet.amount(raw)
    local n = tonumber(raw)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil, 'invalid_amount' end
    n = math.floor(n)
    local c = cfg()
    if n < (c.minSend or 1) then return nil, 'invalid_amount' end
    if n > (c.maxSend or 25000) then return nil, 'too_much' end
    return n
end

-- The phone behind a number, with the player who holds it right now (or the owner when nobody does).
local function target(number)
    local row = MySQL.single.await('SELECT `phone_id`, `number`, `owner_cid` FROM `vr_ph_phones` WHERE `number` = ?', { number })
    if not row then return nil end
    local src = Phone.Session.srcByNumber(row.number)
    return { phoneId = row.phone_id, number = row.number, src = src, cid = row.owner_cid }
end

-- Pays whoever holds the phone. With nobody holding it, the owner is paid through the framework (online or not).
local function credit(t, amount, reason)
    if t.src then return Bridge.addMoney(t.src, 'bank', amount, reason) == true end
    if t.cid and Bridge.chars and Bridge.chars.addBank then
        return Bridge.chars.addBank(t.cid, amount, reason) == true
    end
    return false
end

local function displayName(s)
    local name = s.settings and s.settings.profile and s.settings.profile.name
    if type(name) == 'string' and name ~= '' then return name end
    return s.number
end

local function sentToday(phoneId)
    return tonumber(MySQL.scalar.await(
        "SELECT COALESCE(SUM(`amount`), 0) FROM `vr_ph_wallet_log` WHERE `phone_id` = ? AND `kind` = 'sent' AND `created_at` >= ?",
        { phoneId, now() - 86400 }
    )) or 0
end

local function log(phoneId, kind, amount, other, note)
    MySQL.insert.await(
        'INSERT INTO `vr_ph_wallet_log` (`phone_id`, `kind`, `amount`, `other`, `note`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)',
        { phoneId, kind, amount, other, note, now() }
    )
end

local function tell(number, key, data)
    Phone.Notify.push(number, { app = 'wallet', titleKey = 'wallet.n.' .. key, messageKey = 'wallet.n.' .. key .. 'Text', data = data })
end

-- Moves the money and writes both logs. Returns true, or false and a reason.
local function transfer(src, s, toNumber, amount, note)
    if toNumber == s.number then return false, 'self' end
    if not Phone.Status.canReceive(s) then return false, 'no_service' end
    local c = cfg()
    local t = target(toNumber)
    if not t then return false, 'not_in_service' end
    if t.phoneId == s.phoneId then return false, 'self' end

    if sentToday(s.phoneId) + amount > (c.dailyLimit or 50000) then return false, 'daily_limit' end
    if Bridge.money(src, 'bank') < amount then return false, 'no_funds' end

    local out = ('Wallet: sent to %s'):format(toNumber)
    if not Bridge.removeMoney(src, 'bank', amount, out) then return false, 'no_funds' end
    if not credit(t, amount, ('Wallet: from %s'):format(s.number)) then
        -- The receiver could not be paid, so the sender gets the money back.
        Bridge.addMoney(src, 'bank', amount, 'Wallet: transfer failed')
        return false, 'failed'
    end

    log(s.phoneId, 'sent', amount, toNumber, note)
    log(t.phoneId, 'received', amount, s.number, note)
    tell(toNumber, 'got', { amount = amount, from = displayName(s) })
    return true
end

-- ---------------------------------------------------------------- reading

local function bankNumber(cid)
    if not cid or GetResourceState('vr-banking') ~= 'started' then return nil end
    local ok, acc = pcall(function() return exports['vr-banking']:GetPersonalAccount(cid) end)
    return ok and type(acc) == 'table' and acc.number or nil
end

-- Lines of bank activity from vr-banking (wages, card payments and so on). Quietly nothing when it is not installed.
local function bankLines(number)
    if not number then return nil end
    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT t.`id`, t.`kind`, t.`amount`, t.`balance`, t.`reason`, t.`at` FROM `vr_bank_transactions` t '
                .. 'JOIN `vr_bank_accounts` a ON a.`id` = t.`account_id` WHERE a.`number` = ? ORDER BY t.`id` DESC LIMIT ' .. (cfg().bankHistory or 30),
            { number }
        )
    end)
    if not ok or type(rows) ~= 'table' then return nil end
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = { id = r.id, kind = r.kind, amount = tonumber(r.amount) or 0, balance = tonumber(r.balance), reason = r.reason, at = tonumber(r.at) or 0 }
    end
    return out
end

local function expire(phoneId)
    local hours = cfg().requestHours or 48
    MySQL.update.await(
        "UPDATE `vr_ph_wallet_requests` SET `status` = 'expired', `closed_at` = ? WHERE `status` = 'open' AND `created_at` < ? AND (`to_phone` = ? OR `from_phone` = ?)",
        { now(), now() - hours * 3600, phoneId, phoneId }
    )
end

local function requestsFor(phoneId)
    expire(phoneId)
    local incoming = MySQL.query.await(
        "SELECT `id`, `from_number` AS `number`, `amount`, `note`, `created_at` AS `at` FROM `vr_ph_wallet_requests` WHERE `to_phone` = ? AND `status` = 'open' ORDER BY `id` DESC LIMIT 20",
        { phoneId }
    ) or {}
    local outgoing = MySQL.query.await(
        "SELECT `id`, `to_number` AS `number`, `amount`, `note`, `created_at` AS `at` FROM `vr_ph_wallet_requests` WHERE `from_phone` = ? AND `status` = 'open' ORDER BY `id` DESC LIMIT 20",
        { phoneId }
    ) or {}
    return incoming, outgoing
end

function Wallet.overview(src, s)
    local c = cfg()
    local rows = MySQL.query.await(
        'SELECT `id`, `kind`, `amount`, `other`, `note`, `created_at` AS `at` FROM `vr_ph_wallet_log` WHERE `phone_id` = ? ORDER BY `id` DESC LIMIT ' .. (c.historyLimit or 40),
        { s.phoneId }
    ) or {}
    local transfers = {}
    for i, r in ipairs(rows) do
        transfers[i] = { id = r.id, kind = r.kind, amount = tonumber(r.amount) or 0, number = r.other, note = r.note, at = tonumber(r.at) or 0 }
    end

    local recents, seen = {}, {}
    for _, r in ipairs(transfers) do
        if r.kind == 'sent' and not seen[r.number] and #recents < (c.recents or 6) then
            seen[r.number] = true
            recents[#recents + 1] = r.number
        end
    end

    local incoming, outgoing = requestsFor(s.phoneId)
    local cid = Bridge.cid(src)
    local number = bankNumber(cid)
    local used = sentToday(s.phoneId)
    return {
        cash = Bridge.money(src, 'cash'),
        bank = Bridge.money(src, 'bank'),
        account = number,
        limits = { min = c.minSend or 1, max = c.maxSend or 25000, daily = c.dailyLimit or 50000, left = math.max(0, (c.dailyLimit or 50000) - used), note = c.noteLength or 60 },
        transfers = transfers,
        recents = recents,
        incoming = incoming,
        outgoing = outgoing,
        bankLines = bankLines(number),
    }
end

-- ---------------------------------------------------------------- sending

-- data = { number, amount, note? }. Returns { ok = true, ... } or { ok = false, reason }.
function Wallet.send(src, s, data)
    if busy[s.phoneId] then return { ok = false, reason = 'busy' } end
    busy[s.phoneId] = true
    local ok, result = pcall(function()
        local number = Phone.number(type(data.number) == 'string' and data.number or '')
        if not number then return { ok = false, reason = 'invalid_number' } end
        local amount, why = Wallet.amount(data.amount)
        if not amount then return { ok = false, reason = why } end
        local note = Phone.text(data.note, cfg().noteLength or 60)
        local sent, reason = transfer(src, s, number, amount, note)
        if not sent then return { ok = false, reason = reason } end
        return { ok = true, amount = amount, bank = Bridge.money(src, 'bank') }
    end)
    busy[s.phoneId] = nil
    if not ok then
        print(('^1[vr-phone] wallet send: %s^0'):format(tostring(result)))
        return { ok = false, reason = 'failed' }
    end
    return result
end

-- ---------------------------------------------------------------- requests

-- Asks another number for money.
function Wallet.request(s, data)
    local number = Phone.number(type(data.number) == 'string' and data.number or '')
    if not number then return { ok = false, reason = 'invalid_number' } end
    if number == s.number then return { ok = false, reason = 'self' } end
    local amount, why = Wallet.amount(data.amount)
    if not amount then return { ok = false, reason = why } end
    local t = target(number)
    if not t then return { ok = false, reason = 'not_in_service' } end
    if t.phoneId == s.phoneId then return { ok = false, reason = 'self' } end

    expire(s.phoneId)
    local open = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `vr_ph_wallet_requests` WHERE `from_phone` = ? AND `status` = 'open'", { s.phoneId })) or 0
    if open >= (cfg().maxOpenRequests or 10) then return { ok = false, reason = 'too_many' } end

    local note = Phone.text(data.note, cfg().noteLength or 60)
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_wallet_requests` (`from_phone`, `from_number`, `to_phone`, `to_number`, `amount`, `note`, `status`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { s.phoneId, s.number, t.phoneId, number, amount, note, 'open', now() }
    )
    if not id then return { ok = false, reason = 'failed' } end
    tell(number, 'asked', { amount = amount, from = displayName(s) })
    return { ok = true, id = id }
end

-- The payer answers a request: data = { id, accept }.
function Wallet.respond(src, s, data)
    local id = tonumber(data.id)
    if not id then return { ok = false, reason = 'not_found' } end
    if busy[s.phoneId] then return { ok = false, reason = 'busy' } end
    busy[s.phoneId] = true
    local ok, result = pcall(function()
        expire(s.phoneId)
        local r = MySQL.single.await("SELECT * FROM `vr_ph_wallet_requests` WHERE `id` = ? AND `to_phone` = ? AND `status` = 'open'", { id, s.phoneId })
        if not r then return { ok = false, reason = 'not_found' } end

        if data.accept ~= true then
            MySQL.update.await("UPDATE `vr_ph_wallet_requests` SET `status` = 'declined', `closed_at` = ? WHERE `id` = ? AND `status` = 'open'", { now(), id })
            tell(r.from_number, 'declined', { amount = tonumber(r.amount) or 0, from = displayName(s) })
            return { ok = true }
        end

        -- Close it first, so a second tap cannot pay twice. It opens again if the payment fails.
        local claimed = MySQL.update.await("UPDATE `vr_ph_wallet_requests` SET `status` = 'paid', `closed_at` = ? WHERE `id` = ? AND `status` = 'open'", { now(), id })
        if (claimed or 0) < 1 then return { ok = false, reason = 'not_found' } end
        local sent, reason = transfer(src, s, r.from_number, tonumber(r.amount) or 0, r.note)
        if not sent then
            MySQL.update.await("UPDATE `vr_ph_wallet_requests` SET `status` = 'open', `closed_at` = NULL WHERE `id` = ?", { id })
            return { ok = false, reason = reason }
        end
        return { ok = true, bank = Bridge.money(src, 'bank') }
    end)
    busy[s.phoneId] = nil
    if not ok then
        print(('^1[vr-phone] wallet respond: %s^0'):format(tostring(result)))
        return { ok = false, reason = 'failed' }
    end
    return result
end

-- The player who asked takes the request back.
function Wallet.cancel(s, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await(
        "UPDATE `vr_ph_wallet_requests` SET `status` = 'cancelled', `closed_at` = ? WHERE `id` = ? AND `from_phone` = ? AND `status` = 'open'",
        { now(), id, s.phoneId }
    ) or 0) > 0
end

-- Old log lines go after a while so the table does not grow for ever.
CreateThread(function()
    Phone.DB.waitReady()
    while true do
        MySQL.update.await('DELETE FROM `vr_ph_wallet_log` WHERE `created_at` < ?', { now() - 90 * 86400 })
        MySQL.update.await("DELETE FROM `vr_ph_wallet_requests` WHERE `status` <> 'open' AND `closed_at` < ?", { now() - 30 * 86400 })
        Wait(6 * 3600 * 1000)
    end
end)
