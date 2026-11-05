local function accountFor(target)
    if type(target) == 'table' then return target end
    local acc = Accounts.byNumber(target)
    if acc then return acc end
    if type(target) == 'string' then
        return Accounts.find('job', target) or Accounts.find('gang', target) or Accounts.job(target) or Accounts.gang(target)
    end
end

local api = {}

function api.GetAccount(target)
    local acc = accountFor(target)
    if not acc then return nil end
    return { number = acc.number, type = acc.type, owner = acc.owner, label = acc.label, balance = Accounts.balance(acc), frozen = acc.frozen }
end

function api.GetPersonalAccount(cid)
    local acc = Accounts.personal(cid)
    return acc and api.GetAccount(acc) or nil
end

function api.GetAccountBalance(target)
    local acc = accountFor(target)
    return acc and Accounts.balance(acc) or 0
end

function api.AddMoney(target, amount, reason)
    local acc = accountFor(target)
    amount = Accounts.amount(amount)
    if not acc or not amount then return false end
    if not Accounts.credit(acc, amount, reason or 'payment') then return false end
    Accounts.log(acc, 'payment_in', amount, { reason = reason or 'Incoming payment' })
    return true
end

function api.RemoveMoney(target, amount, reason)
    local acc = accountFor(target)
    amount = Accounts.amount(amount)
    if not acc or not amount then return false end
    if not Accounts.debit(acc, amount, reason or 'payment') then return false end
    Accounts.log(acc, 'payment_out', -amount, { reason = reason or 'Payment' })
    return true
end

function api.AddTransaction(target, kind, amount, reason)
    local acc = accountFor(target)
    if not acc then return false end
    Accounts.log(acc, type(kind) == 'string' and kind:sub(1, 16) or 'external', math.floor(tonumber(amount) or 0), { reason = reason })
    return true
end

function api.GetCreditScore(cid)
    local score = Credit.get(cid)
    local tier = Credit.tier(score)
    return score, tier.label
end

function api.AddCreditEvent(cid, delta, reason)
    return Credit.change(cid, delta, reason)
end

function api.IsVehicleHeld(plate)
    return Collections.isHeld(plate)
end

function api.IsVehicleFlagged(plate)
    return Repo.isFlagged(plate)
end

function api.ReleaseVehicle(plate)
    return Collections.releaseVehicle(plate)
end

function api.HasDebt(cid)
    local c = Collections.openFor(cid)
    return c ~= nil, c and c.amount or 0
end

function api.QuoteFinance(src, price, down, term)
    local info = Core.info(src)
    if not info then return nil end
    return Loans.financeQuote(info, price, down, term)
end

function api.CreateFinance(src, price, down, term, plate, model)
    local info = Core.info(src)
    if not info then return false, 'not_loaded' end
    return Loans.createFinance(info, price, down, term, plate, model)
end

function api.CancelFinance(id)
    return Loans.cancelFinance(id)
end

for name, fn in pairs(api) do
    exports(name, fn)
    exports(name:sub(1, 1):lower() .. name:sub(2), fn)
end
