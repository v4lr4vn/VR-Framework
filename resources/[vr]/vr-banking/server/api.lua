Api = {}

local handlers = {}
local last = {}
local atm = {}
local B, AT = Config.Branch, Config.Atm

local function fail(code, extra)
    return { ok = false, error = code, data = extra }
end

local function ok(data)
    return { ok = true, data = data }
end

local function result(success, a, b)
    if success then return ok(a) end
    return fail(a or 'failed', b)
end

local function nearBranch(src)
    local pos = Core.coords(src)
    if not pos then return nil end
    for _, b in ipairs(Config.Branches) do
        if #(pos - b.coords) <= B.useDistance then return b end
    end
    return nil
end

Api.nearBranch = nearBranch

local function reg(name, ctx, fn)
    handlers[name] = { ctx = ctx, fn = fn }
end

local function account(info, id, need)
    local acc = Accounts.byId(id)
    if not acc or acc.closed then return nil, 'no_account' end
    local r = Accounts.rights(acc, info)
    if not r[need or 'view'] then return nil, 'no_access' end
    return acc
end

local function settings()
    local tiers = {}
    for i, t in ipairs(Config.Credit.tiers) do tiers[i] = { min = t.min, label = t.label, key = t.key, maxLoan = t.maxLoan, rate = t.ratePercent } end
    return {
        cardFee = Config.Cards.fee,
        pinLength = Config.Cards.pinLength,
        savings = { rate = Config.Savings.ratePercent, periodHours = Config.Savings.periodHours, maxBalance = Config.Savings.maxInterestBalance, minBalance = Config.Savings.minBalance },
        loans = { enabled = Config.Loans.enabled, terms = Config.Loans.terms, intervalHours = Config.Loans.intervalHours, minAmount = Config.Loans.minAmount, lateFee = Config.Loans.lateFeePercent, defaultAfter = Config.Loans.defaultAfterMissed, collateral = Config.Loans.collateral.enabled and Db.vehicles },
        limits = { maxShared = Config.Accounts.maxShared, maxSavings = Config.Accounts.maxSavings, maxMembers = Config.Accounts.maxSharedMembers, transferLimit = Config.Accounts.transferLimit },
        credit = { min = Config.Credit.min, max = Config.Credit.max, tiers = tiers },
    }
end

function Api.overview(info, branch)
    local accounts = {}
    for _, acc in ipairs(Accounts.listFor(info)) do accounts[#accounts + 1] = Accounts.view(acc, info, true) end
    local cards = {}
    for _, c in ipairs(Cards.listFor(info.cid)) do cards[#cards + 1] = Cards.view(c, info) end
    local loans = {}
    for _, l in ipairs(Loans.forPlayer(info.cid)) do loans[#loans + 1] = Loans.view(l) end
    local score = Credit.get(info.cid)
    local tier = Credit.tier(score)
    return {
        bank = Config.BankName,
        branch = branch and branch.label or nil,
        now = os.time(),
        me = { name = info.name, cid = info.cid, cash = Core.cash(info.src), credit = { score = score, tier = tier.label, key = tier.key } },
        accounts = accounts,
        cards = cards,
        loans = loans,
        debts = Collections.forDebtor(info.cid),
        held = Collections.heldFor(info.cid),
        collector = Collections.isCollector(info) == true,
        settings = settings(),
    }
end

reg('overview', 'branch', function(info, _, branch) return ok(Api.overview(info, branch)) end)

reg('history', 'branch', function(info, d)
    local acc, err = account(info, d.account)
    if not acc then return fail(err) end
    local cards = {}
    if Accounts.rights(acc, info).manage then
        for _, c in ipairs(Cards.listForAccount(acc.id)) do cards[#cards + 1] = Cards.view(c, info) end
    end
    return ok({ account = Accounts.view(acc, info, true), history = Accounts.history(acc), cards = cards })
end)

reg('deposit', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'deposit')
    if not acc then return fail(err) end
    return result(Accounts.deposit(info, acc, d.amount, { reason = 'Cash deposit at branch' }))
end)

reg('withdraw', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'withdraw')
    if not acc then return fail(err) end
    return result(Accounts.withdraw(info, acc, d.amount, { reason = 'Cash withdrawal at branch' }))
end)

reg('transfer', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'transfer')
    if not acc then return fail(err) end
    local success, to = Accounts.transfer(info, acc, d.to, d.amount, d.note)
    if not success then return fail(to) end
    return ok({ to = to.number })
end)

reg('lookup', 'branch', function(_, d)
    local found = Accounts.lookup(d.number)
    if not found then return fail('no_account') end
    return ok(found)
end)

reg('shared.create', 'branch', function(info, d)
    local success, acc = Accounts.createShared(info, d.label)
    if not success then return fail(acc) end
    return ok({ id = acc.id })
end)

reg('savings.open', 'branch', function(info)
    local success, acc = Accounts.openSavings(info)
    if not success then return fail(acc) end
    return ok({ id = acc.id })
end)

reg('account.rename', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'manage')
    if not acc then return fail(err) end
    return result(Accounts.rename(info, acc, d.label))
end)

reg('account.close', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'owner')
    if not acc then return fail(err) end
    local success, moved = Accounts.close(info, acc)
    if not success then return fail(moved) end
    return ok({ moved = moved })
end)

reg('members.add', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'manage')
    if not acc then return fail(err) end
    local success, name = Accounts.addMember(info, acc, d.cid, d.role)
    if not success then return fail(name) end
    return ok({ name = name })
end)

reg('members.remove', 'branch', function(info, d)
    local acc, err = account(info, d.account)
    if not acc then return fail(err) end
    return result(Accounts.removeMember(info, acc, d.cid))
end)

reg('members.role', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'manage')
    if not acc then return fail(err) end
    return result(Accounts.setRole(info, acc, d.cid, d.role))
end)

reg('cards.order', 'branch', function(info, d)
    local acc, err = account(info, d.account, 'withdraw')
    if not acc then return fail(err) end
    local success, card = Cards.issue(info, acc, d.pin)
    if not success then return fail(card) end
    return ok({ last4 = card.id:sub(-4) })
end)

reg('cards.freeze', 'branch', function(info, d)
    local success, err = Cards.setFrozen(info, d.card, d.frozen == true)
    if not success then return fail(err) end
    return ok(true)
end)

reg('cards.cancel', 'branch', function(info, d) return result(Cards.cancel(info, d.card)) end)
reg('cards.pin', 'branch', function(info, d) return result(Cards.changePin(info, d.card, d.pin)) end)
reg('cards.unlock', 'branch', function(info, d) return result(Cards.unlock(info, d.card)) end)

reg('credit', 'branch', function(info) return ok(Credit.report(info.cid)) end)

reg('loans.vehicles', 'branch', function(info) return ok(Loans.vehicles(info.cid)) end)

reg('loans.quote', 'branch', function(info, d)
    return ok(Loans.quote(info, d.amount, d.term, d.plate))
end)

reg('loans.apply', 'branch', function(info, d)
    local success, id, q = Loans.apply(info, d.amount, d.term, d.plate)
    if not success then return fail(id, q) end
    return ok({ id = id, amount = q.amount, installment = q.installment })
end)

reg('loans.pay', 'branch', function(info, d)
    local success, loan = Loans.pay(info, d.loan, d.amount)
    if not success then return fail(loan) end
    return ok({ remaining = loan.remaining, status = loan.status })
end)

reg('debts.pay', 'branch', function(info, d)
    return result(Collections.payAtBranch(info, d.case, d.method, d.amount))
end)

reg('collections.list', 'collector', function(info)
    return ok({ cases = Collections.list(info), me = { name = info.name, cid = info.cid }, settings = { claimMinutes = Config.Collections.claimMinutes, commission = Config.Collections.commissionPercent, repoPay = Config.Collections.collectorRepoPay, repoFee = Config.Collections.repoFee, vehicles = Db.vehicles }, now = os.time() })
end)

reg('collections.claim', 'collector', function(info, d) return result(Collections.claim(info, d.case)) end)
reg('collections.release', 'collector', function(info, d) return result(Collections.release(info, d.case)) end)
reg('collections.note', 'collector', function(info, d) return result(Collections.addNote(info, d.case, d.text)) end)
reg('collections.trace', 'collector', function(info, d) return result(Collections.trace(info, d.case, d.plate)) end)
reg('collections.locate', 'collector', function(info, d) return result(Collections.locate(info, d.case, d.plate)) end)

reg('collections.plates', 'collector', function() return ok(Collections.plates()) end)
reg('collections.repo', 'collector', function(info, d) return result(Collections.repo(info, d.netId, d.plate)) end)
reg('collections.request', 'collector', function(info, d) return result(Collections.request(info, d.target)) end)

local function atmSession(src)
    local s = atm[src]
    if not s then return nil, 'atm_session' end
    if s.expires < os.time() then
        atm[src] = nil
        return nil, 'atm_timeout'
    end
    local pos = Core.coords(src)
    if not pos or #(pos - s.coords) > AT.useDistance then
        atm[src] = nil
        return nil, 'atm_far'
    end
    s.expires = os.time() + AT.sessionSeconds
    return s
end

local function atmAccount(s)
    local card = Cards.get(s.cardId)
    if not card or card.status ~= 'active' then return nil, 'card_invalid' end
    local acc = Accounts.byId(card.accountId)
    if not acc or acc.closed then return nil, 'card_invalid' end
    return acc, card
end

local function atmState(s, acc)
    return {
        account = { number = acc.number, label = acc.label, type = acc.type, balance = Accounts.balance(acc), frozen = acc.frozen },
        holder = Cards.get(s.cardId) and Cards.get(s.cardId).holderName,
        last4 = s.cardId:sub(-4),
        dailyLimit = AT.dailyLimit,
        dailyLeft = math.max(0, AT.dailyLimit - Cards.withdrawnToday(s.cardId)),
        fastCash = AT.fastCash,
        allowDeposit = AT.allowDeposit,
    }
end

reg('atm.cards', 'atm', function(info, d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    local pos = Core.coords(info.src)
    if not (x and y and z) or not pos or #(pos - vec3(x, y, z)) > AT.useDistance then return fail('atm_far') end
    atm[info.src] = { coords = vec3(x, y, z), expires = os.time() + AT.sessionSeconds }
    local list = {}
    for _, item in ipairs(Core.cards(info.src)) do
        local md = item.metadata
        local card = Cards.get(md.cardId)
        list[#list + 1] = { id = md.cardId, last4 = md.last4 or tostring(md.cardId):sub(-4), holder = md.holder, account = md.account, status = card and card.status or 'invalid' }
    end
    return ok({ cards = list, bank = Config.BankName, pinLength = Config.Cards.pinLength })
end)

reg('atm.pin', 'atm', function(info, d)
    local s, err = atmSession(info.src)
    if not s then return fail(err) end
    local cardId = tostring(d.card or '')
    local carried = false
    for _, item in ipairs(Core.cards(info.src)) do
        if item.metadata.cardId == cardId then carried = true break end
    end
    if not carried then return fail('card_missing') end
    local success, card, acc = Cards.verify(cardId, d.pin)
    if not success then
        if card == 'card_retained' then
            for _, item in ipairs(Core.cards(info.src)) do
                if item.metadata.cardId == cardId then Core.takeCard(info.src, item.slot) break end
            end
        end
        return fail(card, acc)
    end
    s.cardId = card.id
    return ok(atmState(s, acc))
end)

reg('atm.state', 'atm', function(info)
    local s, err = atmSession(info.src)
    if not s or not s.cardId then return fail(err or 'atm_session') end
    local acc, e2 = atmAccount(s)
    if not acc then return fail(e2) end
    return ok(atmState(s, acc))
end)

reg('atm.withdraw', 'atm', function(info, d)
    local s, err = atmSession(info.src)
    if not s or not s.cardId then return fail(err or 'atm_session') end
    local acc, card = atmAccount(s)
    if not acc then return fail(card) end
    local amount = Accounts.amount(d.amount)
    if not amount then return fail('bad_amount') end
    if Cards.withdrawnToday(card.id) + amount > AT.dailyLimit then return fail('daily_limit') end
    local success, e2 = Accounts.withdraw(info, acc, amount, { viaCard = true, cardId = card.id, reason = 'ATM withdrawal' })
    if not success then return fail(e2) end
    Cards.addWithdrawn(card.id, amount)
    return ok(atmState(s, acc))
end)

reg('atm.deposit', 'atm', function(info, d)
    if not AT.allowDeposit then return fail('not_allowed') end
    local s, err = atmSession(info.src)
    if not s or not s.cardId then return fail(err or 'atm_session') end
    local acc, card = atmAccount(s)
    if not acc then return fail(card) end
    local amount = Accounts.amount(d.amount)
    if not amount then return fail('bad_amount') end
    if not Core.removeCash(info.src, amount, 'ATM deposit') then return fail('no_cash') end
    if not Accounts.credit(acc, amount, 'ATM deposit') then
        Core.addCash(info.src, amount, 'ATM deposit refund')
        return fail('failed')
    end
    Accounts.log(acc, 'deposit', amount, { reason = 'ATM deposit', actor = info.cid, actorName = info.name, cardId = card.id })
    return ok(atmState(s, acc))
end)

reg('atm.history', 'atm', function(info)
    local s, err = atmSession(info.src)
    if not s or not s.cardId then return fail(err or 'atm_session') end
    local acc, card = atmAccount(s)
    if not acc then return fail(card) end
    local rows = Accounts.history(acc, 8)
    return ok(rows)
end)

reg('atm.end', 'atm', function(info)
    atm[info.src] = nil
    return ok(true)
end)

function Api.handle(src, action, data)
    if type(action) ~= 'string' then return fail('bad_request') end
    local h = handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return fail('not_ready') end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 150 then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return fail('not_loaded') end
    data = type(data) == 'table' and data or {}
    local branch
    if h.ctx == 'branch' then
        branch = nearBranch(src)
        if not branch then return fail('not_at_branch') end
    elseif h.ctx == 'collector' then
        if not Collections.isCollector(info) then return fail('not_collector') end
    end
    local success, res = pcall(h.fn, info, data, branch)
    if not success then
        print(('^1[vr-banking] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end

AddEventHandler('playerDropped', function()
    atm[source] = nil
    last[source] = nil
end)
