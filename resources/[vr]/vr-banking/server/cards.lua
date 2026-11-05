Cards = {}

local K = Config.Cards
local byId = {}
local daily = {}
local LIVE = { active = true, frozen = true }

local function fromRow(r)
    return {
        id = r.id,
        accountId = tonumber(r.account_id),
        holder = r.holder,
        holderName = r.holder_name,
        pinHash = r.pin_hash,
        pinSalt = r.pin_salt,
        status = r.status,
        fails = tonumber(r.fails) or 0,
        lockedUntil = tonumber(r.locked_until) or 0,
        created = tonumber(r.created) or 0,
    }
end

function Cards.load()
    local rows = MySQL.query.await("SELECT * FROM vr_bank_cards WHERE status IN ('active', 'frozen')") or {}
    for i = 1, #rows do
        local c = fromRow(rows[i])
        byId[c.id] = c
    end
end

local function salt()
    local t = {}
    for i = 1, 16 do t[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(t)
end

local function hash(pin, s)
    return Sha256(s .. ':' .. pin .. ':' .. GetCurrentResourceName())
end

local function newId()
    for _ = 1, 50 do
        local parts = { '4' }
        for i = 2, 16 do parts[i] = tostring(math.random(0, 9)) end
        local id = table.concat(parts)
        if not byId[id] then
            local taken = MySQL.scalar.await('SELECT 1 FROM vr_bank_cards WHERE id = ?', { id })
            if not taken then return id end
        end
    end
end

function Cards.validPin(pin)
    pin = tostring(pin or '')
    return #pin == K.pinLength and pin:match('^%d+$') ~= nil and pin or nil
end

function Cards.get(id)
    return byId[tostring(id or '')]
end

function Cards.view(card, info)
    local acc = Accounts.byId(card.accountId)
    return {
        id = card.id,
        last4 = card.id:sub(-4),
        holder = card.holderName,
        mine = info and card.holder == info.cid or false,
        status = card.status,
        locked = card.lockedUntil > os.time(),
        account = acc and { number = acc.number, label = acc.label, type = acc.type } or nil,
        created = card.created,
    }
end

function Cards.metadata(card, acc)
    local masked = ('**** %s'):format(card.id:sub(-4))
    return {
        cardId = card.id,
        last4 = card.id:sub(-4),
        holder = card.holderName,
        account = acc.number,
        label = ('%s · %s'):format(Config.BankName, masked),
        description = ('%s\nHolder: %s\nAccount: %s'):format(acc.label, card.holderName, acc.number),
    }
end

local function setStatus(card, status)
    card.status = status
    MySQL.update('UPDATE vr_bank_cards SET status = ? WHERE id = ?', { status, card.id })
    if not LIVE[status] then byId[card.id] = nil end
end

function Cards.listFor(cid)
    local out = {}
    for _, c in pairs(byId) do
        if c.holder == cid then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.created > b.created end)
    return out
end

function Cards.listForAccount(accountId)
    local out = {}
    for _, c in pairs(byId) do
        if c.accountId == accountId then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.created > b.created end)
    return out
end

local function canManage(info, card)
    if card.holder == info.cid then return true end
    local acc = Accounts.byId(card.accountId)
    return acc ~= nil and Accounts.rights(acc, info).manage
end

function Cards.issue(info, acc, pin)
    pin = Cards.validPin(pin)
    if not pin then return false, 'bad_pin' end
    local r = Accounts.rights(acc, info)
    if not r.withdraw then return false, 'no_access' end
    local fee = math.floor(K.fee or 0)
    local personal = Accounts.personal(info.cid)
    local paidBy
    if fee > 0 then
        if personal and Accounts.debit(personal, fee, 'card fee') then
            paidBy = 'bank'
        elseif Core.removeCash(info.src, fee, 'Bank card fee') then
            paidBy = 'cash'
        else
            return false, 'no_funds'
        end
    end
    local id = newId()
    if not id then return false, 'failed' end
    local s = salt()
    local t = os.time()
    local card = { id = id, accountId = acc.id, holder = info.cid, holderName = info.name, pinHash = hash(pin, s), pinSalt = s, status = 'active', fails = 0, lockedUntil = 0, created = t }
    local ok = MySQL.insert.await('INSERT INTO vr_bank_cards (id, account_id, holder, holder_name, pin_hash, pin_salt, status, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { id, acc.id, info.cid, info.name, card.pinHash, s, 'active', t })
    if ok == nil then
        if paidBy == 'bank' then Accounts.credit(personal, fee, 'card fee refund') elseif paidBy == 'cash' then Core.addCash(info.src, fee, 'Bank card fee refund') end
        return false, 'failed'
    end
    if not Core.giveCard(info.src, Cards.metadata(card, acc)) then
        MySQL.update('DELETE FROM vr_bank_cards WHERE id = ?', { id })
        if paidBy == 'bank' then Accounts.credit(personal, fee, 'card fee refund') elseif paidBy == 'cash' then Core.addCash(info.src, fee, 'Bank card fee refund') end
        return false, 'inventory_full'
    end
    for _, old in pairs(byId) do
        if old.holder == info.cid and old.accountId == acc.id then setStatus(old, 'replaced') end
    end
    byId[id] = card
    if paidBy == 'bank' then
        Accounts.log(personal, 'fee', -fee, { reason = ('Card ending %s'):format(id:sub(-4)), actor = info.cid, actorName = info.name })
    end
    return true, card
end

function Cards.setFrozen(info, id, frozen)
    local card = Cards.get(id)
    if not card then return false, 'no_card' end
    if not canManage(info, card) then return false, 'no_access' end
    setStatus(card, frozen and 'frozen' or 'active')
    return true, card
end

function Cards.cancel(info, id)
    local card = Cards.get(id)
    if not card then return false, 'no_card' end
    if not canManage(info, card) then return false, 'no_access' end
    setStatus(card, 'cancelled')
    return true
end

function Cards.changePin(info, id, pin)
    local card = Cards.get(id)
    if not card then return false, 'no_card' end
    if card.holder ~= info.cid then return false, 'no_access' end
    pin = Cards.validPin(pin)
    if not pin then return false, 'bad_pin' end
    card.pinSalt = salt()
    card.pinHash = hash(pin, card.pinSalt)
    card.fails, card.lockedUntil = 0, 0
    MySQL.update('UPDATE vr_bank_cards SET pin_hash = ?, pin_salt = ?, fails = 0, locked_until = 0 WHERE id = ?', { card.pinHash, card.pinSalt, card.id })
    return true
end

function Cards.unlock(info, id)
    local card = Cards.get(id)
    if not card then return false, 'no_card' end
    if not canManage(info, card) then return false, 'no_access' end
    card.fails, card.lockedUntil = 0, 0
    MySQL.update('UPDATE vr_bank_cards SET fails = 0, locked_until = 0 WHERE id = ?', { card.id })
    return true
end

function Cards.verify(id, pin)
    local card = Cards.get(id)
    if not card then return false, 'card_invalid' end
    if card.status == 'frozen' then return false, 'card_frozen' end
    if card.status ~= 'active' then return false, 'card_invalid' end
    local t = os.time()
    if card.lockedUntil > t then return false, 'card_locked', card.lockedUntil - t end
    local acc = Accounts.byId(card.accountId)
    if not acc or acc.closed then return false, 'card_invalid' end
    pin = Cards.validPin(pin)
    if pin and hash(pin, card.pinSalt) == card.pinHash then
        if card.fails > 0 then
            card.fails = 0
            MySQL.update('UPDATE vr_bank_cards SET fails = 0 WHERE id = ?', { card.id })
        end
        return true, card, acc
    end
    card.fails = card.fails + 1
    if card.fails >= K.maxFails then
        card.fails = 0
        card.lockedUntil = t + K.lockMinutes * 60
        MySQL.update('UPDATE vr_bank_cards SET fails = 0, locked_until = ? WHERE id = ?', { card.lockedUntil, card.id })
        if K.retainOnLock then
            setStatus(card, 'retained')
            return false, 'card_retained'
        end
        return false, 'card_locked', K.lockMinutes * 60
    end
    MySQL.update('UPDATE vr_bank_cards SET fails = ? WHERE id = ?', { card.fails, card.id })
    return false, 'bad_pin', K.maxFails - card.fails
end

local function today()
    local t = os.time()
    return t - (t % 86400)
end

function Cards.withdrawnToday(id)
    local d = today()
    local entry = daily[id]
    if entry and entry.day == d then return entry.amount end
    local sum = MySQL.scalar.await("SELECT COALESCE(SUM(-amount), 0) FROM vr_bank_transactions WHERE card_id = ? AND kind = 'withdraw' AND at >= ?", { id, d })
    entry = { day = d, amount = tonumber(sum) or 0 }
    daily[id] = entry
    return entry.amount
end

function Cards.addWithdrawn(id, amount)
    local d = today()
    local entry = daily[id]
    if not entry or entry.day ~= d then entry = { day = d, amount = 0 } daily[id] = entry end
    entry.amount = entry.amount + amount
end

function Cards.cancelForAccount(accountId, status)
    for _, c in pairs(byId) do
        if c.accountId == accountId then setStatus(c, status == 'closed' and 'cancelled' or status) end
    end
end

function Cards.cancelForHolder(accountId, cid)
    for _, c in pairs(byId) do
        if c.accountId == accountId and c.holder == cid then setStatus(c, 'cancelled') end
    end
end

function Cards.cancelForSocietyHolder(kind, name, cid)
    local acc = Accounts.find(kind, name)
    if acc then Cards.cancelForHolder(acc.id, cid) end
end
