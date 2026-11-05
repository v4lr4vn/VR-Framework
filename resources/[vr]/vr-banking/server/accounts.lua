Accounts = {}

local byId, byNumber, single = {}, {}, {}
local members, memberOf, savingsOf = {}, {}, {}
local pending = {}
local muteKeys = {}
local A = Config.Accounts

local function now() return os.time() end

local function index(acc)
    byId[acc.id] = acc
    byNumber[acc.number] = acc
    if acc.closed then return end
    if acc.type == 'personal' or acc.type == 'job' or acc.type == 'gang' then
        single[acc.type .. ':' .. acc.owner] = acc
    elseif acc.type == 'savings' then
        savingsOf[acc.owner] = savingsOf[acc.owner] or {}
        savingsOf[acc.owner][acc.id] = true
    end
end

local function unindex(acc)
    if acc.type == 'savings' and savingsOf[acc.owner] then savingsOf[acc.owner][acc.id] = nil end
    if acc.type == 'shared' and members[acc.id] then
        for cid in pairs(members[acc.id]) do
            if memberOf[cid] then memberOf[cid][acc.id] = nil end
        end
        members[acc.id] = nil
    end
    single[acc.type .. ':' .. acc.owner] = nil
end

local function addMemberIndex(accountId, cid, name, role, added)
    members[accountId] = members[accountId] or {}
    members[accountId][cid] = { name = name, role = role, added = added }
    memberOf[cid] = memberOf[cid] or {}
    memberOf[cid][accountId] = true
end

local function fromRow(r)
    return {
        id = tonumber(r.id),
        number = r.number,
        type = r.type,
        owner = r.owner,
        label = r.label,
        balance = tonumber(r.balance) or 0,
        frozen = r.frozen == 1 or r.frozen == true,
        closed = r.closed == 1 or r.closed == true,
        interestAt = tonumber(r.interest_at) or 0,
        created = tonumber(r.created) or 0,
    }
end

function Accounts.load()
    local rows = MySQL.query.await('SELECT * FROM vr_bank_accounts') or {}
    for i = 1, #rows do index(fromRow(rows[i])) end
    local mrows = MySQL.query.await('SELECT * FROM vr_bank_members') or {}
    for i = 1, #mrows do
        local m = mrows[i]
        local acc = byId[tonumber(m.account_id)]
        if acc and not acc.closed then addMemberIndex(acc.id, m.citizenid, m.name, m.role, tonumber(m.added) or 0) end
    end
end

local function newNumber()
    local prefix = tostring(A.numberPrefix or '40')
    for _ = 1, 50 do
        local n = prefix .. tostring(math.random(10000000, 99999999))
        if not byNumber[n] then return n end
    end
    return prefix .. tostring(os.time()):sub(-8)
end

local function create(kind, owner, label, balance)
    local number = newNumber()
    byNumber[number] = true
    local t = now()
    local id = MySQL.insert.await('INSERT INTO vr_bank_accounts (number, type, owner, label, balance, interest_at, created) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { number, kind, owner, label, balance or 0, t, t })
    if not id then
        byNumber[number] = nil
        return nil
    end
    local acc = { id = id, number = number, type = kind, owner = owner, label = label, balance = balance or 0, frozen = false, closed = false, interestAt = t, created = t }
    index(acc)
    return acc
end

function Accounts.ensure(kind, owner, label)
    local key = kind .. ':' .. owner
    if single[key] then return single[key] end
    if pending[key] then
        local guard = 0
        while pending[key] and guard < 500 do
            guard = guard + 1
            Wait(10)
        end
        return single[key]
    end
    pending[key] = true
    local ok, acc = pcall(create, kind, owner, label)
    pending[key] = nil
    if not ok then print(('^1[vr-banking] create account: %s^0'):format(tostring(acc))) return nil end
    return acc
end

function Accounts.personal(cid)
    if type(cid) ~= 'string' or cid == '' then return nil end
    return Accounts.ensure('personal', cid, 'Personal account')
end

function Accounts.job(name)
    if not Core.isJob(name) or name == 'unemployed' then return nil end
    return Accounts.ensure('job', name, Core.jobLabel(name))
end

function Accounts.gang(name)
    if not Core.isGang(name) or name == 'none' then return nil end
    return Accounts.ensure('gang', name, Core.gangLabel(name))
end

function Accounts.byId(id) return byId[tonumber(id)] end

function Accounts.byNumber(number)
    if type(number) ~= 'string' then number = tostring(number or '') end
    number = number:gsub('[%s%-]', '')
    local acc = byNumber[number]
    if type(acc) ~= 'table' or acc.closed then return nil end
    return acc
end

function Accounts.find(ownerType, owner)
    return single[ownerType .. ':' .. owner]
end

function Accounts.members(acc)
    return members[acc.id] or {}
end

function Accounts.memberAccounts(cid)
    local out = {}
    for id in pairs(memberOf[cid] or {}) do
        local acc = byId[id]
        if acc and not acc.closed then out[#out + 1] = acc end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Accounts.savings(cid)
    local out = {}
    for id in pairs(savingsOf[cid] or {}) do
        local acc = byId[id]
        if acc and not acc.closed then out[#out + 1] = acc end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Accounts.allSavings()
    local out = {}
    for _, set in pairs(savingsOf) do
        for id in pairs(set) do
            local acc = byId[id]
            if acc and not acc.closed then out[#out + 1] = acc end
        end
    end
    return out
end

function Accounts.isMuted(key)
    return key ~= nil and (muteKeys[key] or 0) > 0
end

local function muted(key, fn, ...)
    muteKeys[key] = (muteKeys[key] or 0) + 1
    local r = table.pack(pcall(fn, ...))
    muteKeys[key] = muteKeys[key] - 1
    if muteKeys[key] <= 0 then muteKeys[key] = nil end
    if not r[1] then
        print(('^1[vr-banking] %s^0'):format(tostring(r[2])))
        return false
    end
    return r[2]
end

function Accounts.balance(acc)
    if acc.type == 'personal' then return Core.bank(acc.owner) end
    if acc.type == 'job' or acc.type == 'gang' then return Core.societyBalance(acc.owner) end
    return acc.balance
end

local function reasonText(reason)
    return ('Bank: %s'):format(reason or 'transaction')
end

function Accounts.credit(acc, amount, reason)
    if amount <= 0 or acc.closed then return false end
    if acc.type == 'personal' then return muted(acc.owner, Core.addBank, acc.owner, amount, reasonText(reason)) == true end
    if acc.type == 'job' or acc.type == 'gang' then return muted(acc.owner, Core.addSociety, acc.owner, amount, reasonText(reason)) == true end
    acc.balance = acc.balance + amount
    MySQL.update('UPDATE vr_bank_accounts SET balance = balance + ? WHERE id = ?', { amount, acc.id })
    return true
end

function Accounts.debit(acc, amount, reason)
    if amount <= 0 or acc.closed or acc.frozen then return false end
    if acc.type == 'personal' then return muted(acc.owner, Core.removeBank, acc.owner, amount, reasonText(reason)) == true end
    if acc.type == 'job' or acc.type == 'gang' then return muted(acc.owner, Core.removeSociety, acc.owner, amount, reasonText(reason)) == true end
    if acc.balance < amount then return false end
    acc.balance = acc.balance - amount
    MySQL.update('UPDATE vr_bank_accounts SET balance = balance - ? WHERE id = ?', { amount, acc.id })
    return true
end

function Accounts.log(acc, kind, amount, opts)
    opts = opts or {}
    local balance = opts.balance
    if balance == nil then
        local ok, b = pcall(Accounts.balance, acc)
        balance = ok and b or nil
    end
    MySQL.insert('INSERT INTO vr_bank_transactions (account_id, kind, amount, balance, other, reason, actor, actor_name, card_id, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        acc.id, kind, math.floor(amount), balance, opts.other, opts.reason and tostring(opts.reason):sub(1, 128) or nil,
        opts.actor, opts.actorName, opts.cardId, opts.at or now(),
    })
    TriggerEvent('vr-banking:server:transaction', acc.number, kind, amount, opts.reason)
end

function Accounts.history(acc, limit)
    limit = math.min(math.max(tonumber(limit) or A.historyLimit or 60, 1), 200)
    local rows = MySQL.query.await(('SELECT id, kind, amount, balance, other, reason, actor_name, card_id, at FROM vr_bank_transactions WHERE account_id = ? ORDER BY id DESC LIMIT %d'):format(limit), { acc.id }) or {}
    for i = 1, #rows do
        rows[i].amount = tonumber(rows[i].amount)
        rows[i].balance = tonumber(rows[i].balance)
        rows[i].at = tonumber(rows[i].at)
        rows[i].card = rows[i].card_id and rows[i].card_id:sub(-4) or nil
        rows[i].card_id = nil
    end
    return rows
end

local function societyAccess(info, kind, name)
    local group = kind == 'job' and info.job or info.gang
    if not group or group.name ~= name then return false end
    if group.isboss then return true end
    local min = Config.Society.minGrade[name]
    if min then return group.grade >= min end
    return Config.Society.defaultBossOnly == false
end

function Accounts.rights(acc, info)
    local r = { view = false, deposit = false, withdraw = false, transfer = false, manage = false, owner = false }
    if not acc or acc.closed or not info then return r end
    if acc.type == 'personal' or acc.type == 'savings' then
        if acc.owner == info.cid then
            r.view, r.deposit, r.withdraw, r.transfer, r.manage, r.owner = true, true, true, true, true, true
        end
    elseif acc.type == 'shared' then
        local m = members[acc.id] and members[acc.id][info.cid]
        if m then
            r.view, r.deposit = true, true
            if m.role == 'owner' or m.role == 'manager' then r.withdraw, r.transfer = true, true end
            if m.role == 'owner' then r.manage, r.owner = true, true end
        end
    elseif acc.type == 'job' or acc.type == 'gang' then
        if societyAccess(info, acc.type, acc.owner) then
            r.view, r.deposit, r.withdraw, r.transfer, r.manage = true, true, true, true, true
        end
    end
    return r
end

function Accounts.ownerName(acc)
    if acc.type == 'job' then return Core.jobLabel(acc.owner) end
    if acc.type == 'gang' then return Core.gangLabel(acc.owner) end
    if acc.type == 'shared' then return acc.label end
    return Core.nameByCid(acc.owner) or 'Account holder'
end

function Accounts.view(acc, info, withMembers)
    local r = Accounts.rights(acc, info)
    local v = {
        id = acc.id,
        number = acc.number,
        type = acc.type,
        label = acc.label,
        balance = Accounts.balance(acc),
        frozen = acc.frozen,
        rights = r,
        created = acc.created,
    }
    if acc.type == 'savings' then
        v.rate = Config.Savings.ratePercent
        v.nextInterest = acc.interestAt + Config.Savings.periodHours * 3600
    end
    if acc.type == 'shared' and withMembers then
        local list = {}
        for cid, m in pairs(members[acc.id] or {}) do
            list[#list + 1] = { cid = cid, name = m.name, role = m.role, added = m.added, me = cid == info.cid }
        end
        table.sort(list, function(a, b)
            local order = { owner = 1, manager = 2, member = 3 }
            if order[a.role] ~= order[b.role] then return order[a.role] < order[b.role] end
            return a.name < b.name
        end)
        v.members = list
        v.myRole = members[acc.id] and members[acc.id][info.cid] and members[acc.id][info.cid].role or nil
    end
    return v
end

function Accounts.listFor(info)
    local out = {}
    local personal = Accounts.personal(info.cid)
    if personal then out[#out + 1] = personal end
    for _, acc in ipairs(Accounts.savings(info.cid)) do out[#out + 1] = acc end
    for _, acc in ipairs(Accounts.memberAccounts(info.cid)) do out[#out + 1] = acc end
    if info.job and info.job.name and societyAccess(info, 'job', info.job.name) then
        local acc = Accounts.job(info.job.name)
        if acc then out[#out + 1] = acc end
    end
    if info.gang and info.gang.name and societyAccess(info, 'gang', info.gang.name) then
        local acc = Accounts.gang(info.gang.name)
        if acc then out[#out + 1] = acc end
    end
    return out
end

local function amountOk(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge then return nil end
    amount = math.floor(amount)
    if amount <= 0 or amount > (Config.MaxTransaction or 10000000) then return nil end
    return amount
end

Accounts.amount = amountOk

function Accounts.deposit(info, acc, amount, opts)
    opts = opts or {}
    amount = amountOk(amount)
    if not amount then return false, 'bad_amount' end
    if not Accounts.rights(acc, info).deposit then return false, 'no_access' end
    if not Core.removeCash(info.src, amount, 'Bank deposit') then return false, 'no_cash' end
    if not Accounts.credit(acc, amount, 'cash deposit') then
        Core.addCash(info.src, amount, 'Bank deposit refund')
        return false, 'failed'
    end
    Accounts.log(acc, 'deposit', amount, { reason = opts.reason or 'Cash deposit', actor = info.cid, actorName = info.name, cardId = opts.cardId })
    return true
end

function Accounts.withdraw(info, acc, amount, opts)
    opts = opts or {}
    amount = amountOk(amount)
    if not amount then return false, 'bad_amount' end
    if not opts.viaCard and not Accounts.rights(acc, info).withdraw then return false, 'no_access' end
    if acc.frozen then return false, 'frozen' end
    if not Accounts.debit(acc, amount, 'cash withdrawal') then return false, 'no_funds' end
    if not Core.addCash(info.src, amount, 'Bank withdrawal') then
        Accounts.credit(acc, amount, 'withdrawal refund')
        return false, 'failed'
    end
    Accounts.log(acc, 'withdraw', -amount, { reason = opts.reason or 'Cash withdrawal', actor = info.cid, actorName = info.name, cardId = opts.cardId })
    return true
end

function Accounts.transfer(info, from, toNumber, amount, note, opts)
    opts = opts or {}
    amount = amountOk(amount)
    if not amount then return false, 'bad_amount' end
    if amount > (A.transferLimit or math.huge) then return false, 'over_limit' end
    if not opts.viaCard and not Accounts.rights(from, info).transfer then return false, 'no_access' end
    local to = Accounts.byNumber(toNumber)
    if not to then return false, 'no_account' end
    if to.id == from.id then return false, 'same_account' end
    if from.frozen then return false, 'frozen' end
    note = type(note) == 'string' and note:gsub('[%c<>]', ''):sub(1, 64) or nil
    if note == '' then note = nil end
    if not Accounts.debit(from, amount, ('transfer to %s'):format(to.number)) then return false, 'no_funds' end
    if not Accounts.credit(to, amount, ('transfer from %s'):format(from.number)) then
        Accounts.credit(from, amount, 'transfer refund')
        return false, 'failed'
    end
    Accounts.log(from, 'transfer_out', -amount, { other = to.number, reason = note or ('To %s'):format(to.type == 'personal' and 'account ' .. to.number or to.label), actor = info.cid, actorName = info.name, cardId = opts.cardId })
    Accounts.log(to, 'transfer_in', amount, { other = from.number, reason = note or ('From %s'):format(from.type == 'personal' and info.name or from.label), actor = info.cid, actorName = info.name })
    if to.type == 'personal' then
        local target = Core.sourceOf(to.owner)
        if target then Core.notify(target, ('You received $%s from %s'):format(Fmt.money(amount), from.type == 'personal' and info.name or from.label), 'success') end
    end
    return true, to
end

function Accounts.createShared(info, label)
    label = type(label) == 'string' and label:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32) or ''
    if #label < 2 then return false, 'bad_label' end
    local count = 0
    for _, acc in ipairs(Accounts.memberAccounts(info.cid)) do
        if members[acc.id][info.cid].role == 'owner' then count = count + 1 end
    end
    if count >= (A.maxShared or 3) then return false, 'limit' end
    local acc = create('shared', info.cid, label, 0)
    if not acc then return false, 'failed' end
    local t = now()
    MySQL.insert.await('INSERT INTO vr_bank_members (account_id, citizenid, name, role, added) VALUES (?, ?, ?, ?, ?)', { acc.id, info.cid, info.name, 'owner', t })
    addMemberIndex(acc.id, info.cid, info.name, 'owner', t)
    Accounts.log(acc, 'opened', 0, { reason = 'Shared account opened', actor = info.cid, actorName = info.name, balance = 0 })
    return true, acc
end

function Accounts.openSavings(info)
    if #Accounts.savings(info.cid) >= (A.maxSavings or 1) then return false, 'limit' end
    local acc = create('savings', info.cid, 'Savings', 0)
    if not acc then return false, 'failed' end
    Accounts.log(acc, 'opened', 0, { reason = 'Savings account opened', actor = info.cid, actorName = info.name, balance = 0 })
    return true, acc
end

function Accounts.rename(info, acc, label)
    if acc.type ~= 'shared' and acc.type ~= 'savings' then return false, 'not_allowed' end
    if not Accounts.rights(acc, info).manage then return false, 'no_access' end
    label = type(label) == 'string' and label:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32) or ''
    if #label < 2 then return false, 'bad_label' end
    acc.label = label
    MySQL.update('UPDATE vr_bank_accounts SET label = ? WHERE id = ?', { label, acc.id })
    return true
end

function Accounts.close(info, acc)
    if acc.type ~= 'shared' and acc.type ~= 'savings' then return false, 'not_allowed' end
    if not Accounts.rights(acc, info).owner then return false, 'no_access' end
    local left = acc.balance
    local personal = Accounts.personal(info.cid)
    if left > 0 then
        if not personal then return false, 'failed' end
        acc.balance = 0
        MySQL.update('UPDATE vr_bank_accounts SET balance = 0 WHERE id = ?', { acc.id })
        Accounts.log(acc, 'transfer_out', -left, { other = personal.number, reason = 'Account closed', actor = info.cid, actorName = info.name, balance = 0 })
        Accounts.credit(personal, left, 'closed account balance')
        Accounts.log(personal, 'transfer_in', left, { other = acc.number, reason = ('%s closed'):format(acc.label), actor = info.cid, actorName = info.name })
    end
    acc.closed = true
    unindex(acc)
    MySQL.update('UPDATE vr_bank_accounts SET closed = 1 WHERE id = ?', { acc.id })
    MySQL.update('DELETE FROM vr_bank_members WHERE account_id = ?', { acc.id })
    Cards.cancelForAccount(acc.id, 'closed')
    return true, left
end

function Accounts.addMember(info, acc, cid, role)
    if acc.type ~= 'shared' then return false, 'not_allowed' end
    if not Accounts.rights(acc, info).manage then return false, 'no_access' end
    if type(cid) ~= 'string' or cid == '' then return false, 'no_person' end
    cid = cid:upper():gsub('%s', '')
    role = role == 'manager' and 'manager' or 'member'
    local list = members[acc.id] or {}
    if list[cid] then return false, 'already_member' end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    if count >= (A.maxSharedMembers or 8) then return false, 'limit' end
    if not Core.exists(cid) then return false, 'no_person' end
    local name = Core.nameByCid(cid) or cid
    local t = now()
    MySQL.insert.await('INSERT INTO vr_bank_members (account_id, citizenid, name, role, added) VALUES (?, ?, ?, ?, ?)', { acc.id, cid, name, role, t })
    addMemberIndex(acc.id, cid, name, role, t)
    local target = Core.sourceOf(cid)
    if target then Core.notify(target, ('%s added you to the shared account %s'):format(info.name, acc.label), 'inform') end
    return true, name
end

function Accounts.removeMember(info, acc, cid)
    if acc.type ~= 'shared' then return false, 'not_allowed' end
    local list = members[acc.id] or {}
    local m = list[cid]
    if not m then return false, 'no_person' end
    local self = cid == info.cid
    if m.role == 'owner' then return false, 'owner' end
    if not self and not Accounts.rights(acc, info).manage then return false, 'no_access' end
    list[cid] = nil
    if memberOf[cid] then memberOf[cid][acc.id] = nil end
    MySQL.update('DELETE FROM vr_bank_members WHERE account_id = ? AND citizenid = ?', { acc.id, cid })
    Cards.cancelForHolder(acc.id, cid, 'removed')
    return true
end

function Accounts.setRole(info, acc, cid, role)
    if acc.type ~= 'shared' then return false, 'not_allowed' end
    if not Accounts.rights(acc, info).manage then return false, 'no_access' end
    if role ~= 'manager' and role ~= 'member' then return false, 'bad_role' end
    local m = members[acc.id] and members[acc.id][cid]
    if not m or m.role == 'owner' then return false, 'no_person' end
    m.role = role
    MySQL.update('UPDATE vr_bank_members SET role = ? WHERE account_id = ? AND citizenid = ?', { role, acc.id, cid })
    return true
end

function Accounts.setFrozen(acc, frozen)
    acc.frozen = frozen == true
    MySQL.update('UPDATE vr_bank_accounts SET frozen = ? WHERE id = ?', { acc.frozen and 1 or 0, acc.id })
end

function Accounts.lookup(number)
    local acc = Accounts.byNumber(number)
    if not acc then return nil end
    local kindLabel = ({ personal = 'Personal', savings = 'Savings', shared = 'Shared', job = 'Business', gang = 'Organisation' })[acc.type]
    local name = Accounts.ownerName(acc)
    if acc.type == 'personal' or acc.type == 'savings' then
        local first, last = name:match('^(%S+)%s*(.*)$')
        if first and last and last ~= '' then name = ('%s %s.'):format(first, last:sub(1, 1)) end
    end
    return { number = acc.number, type = acc.type, kind = kindLabel, name = name }
end

function Accounts.setInterestAt(acc, t)
    acc.interestAt = t
    MySQL.update('UPDATE vr_bank_accounts SET interest_at = ? WHERE id = ?', { t, acc.id })
end
