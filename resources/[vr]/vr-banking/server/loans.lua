Loans = {}

local L = Config.Loans
local busy = {}

local function num(v) return tonumber(v) or 0 end

local function fromRow(r)
    return {
        id = num(r.id),
        cid = r.citizenid,
        name = r.name,
        principal = num(r.principal),
        interest = num(r.interest),
        total = num(r.total),
        remaining = num(r.remaining),
        installment = num(r.installment),
        arrears = num(r.arrears),
        fees = num(r.fees),
        term = num(r.term),
        paidCount = num(r.paid_count),
        missed = num(r.missed),
        missedTotal = num(r.missed_total),
        intervalH = num(r.interval_h),
        nextDue = num(r.next_due),
        status = r.status,
        rate = num(r.rate),
        plate = r.plate,
        model = r.model,
        kind = r.kind or 'loan',
        created = num(r.created),
        closedAt = r.closed_at and num(r.closed_at) or nil,
    }
end

local function save(loan)
    MySQL.update.await([[UPDATE vr_bank_loans SET remaining = ?, arrears = ?, fees = ?, paid_count = ?, missed = ?, missed_total = ?,
        next_due = ?, status = ?, closed_at = ? WHERE id = ?]],
        { loan.remaining, loan.arrears, loan.fees, loan.paidCount, loan.missed, loan.missedTotal, loan.nextDue, loan.status, loan.closedAt, loan.id })
end

function Loans.get(id)
    local r = MySQL.single.await('SELECT * FROM vr_bank_loans WHERE id = ?', { tonumber(id) })
    return r and fromRow(r) or nil
end

function Loans.forPlayer(cid)
    local rows = MySQL.query.await([[SELECT * FROM vr_bank_loans WHERE citizenid = ?
        AND (status IN ('active', 'collections') OR (closed_at IS NOT NULL AND closed_at > ?)) ORDER BY id DESC LIMIT 12]], { cid, os.time() - 30 * 86400 }) or {}
    local out = {}
    for i = 1, #rows do
        local l = fromRow(rows[i])
        l.vehicle = l.model and Core.vehicleName(l.model) or nil
        out[#out + 1] = l
    end
    return out
end

function Loans.activeCount(cid, kind)
    return num(MySQL.scalar.await("SELECT COUNT(*) FROM vr_bank_loans WHERE citizenid = ? AND kind = ? AND status IN ('active', 'collections')", { cid, kind or 'loan' }))
end

local function plateKey(p)
    return type(p) == 'string' and p:upper():gsub('^%s+', ''):gsub('%s+$', '') or nil
end

Loans.plateKey = plateKey

function Loans.platesOf(veh)
    local a = plateKey(GetVehicleNumberPlateText(veh))
    local ok, bag = pcall(function() return Entity(veh).state.vr_plate end)
    local b = ok and plateKey(bag) or nil
    if a == '' then a = nil end
    if b == '' or b == a then b = nil end
    return a, b
end

function Loans.vehicleHasPlate(veh, plate)
    if not plate or plate == '' then return false end
    local a, b = Loans.platesOf(veh)
    return a == plate or b == plate
end

function Loans.vehicles(cid)
    if not Db.vehicles then return {} end
    local v = Config.Vehicles
    local rows = MySQL.query.await(('SELECT `%s` AS plate, `%s` AS model FROM `%s` WHERE `%s` = ?'):format(v.plate, v.model, v.table, v.owner), { cid }) or {}
    local pledged = {}
    local prow = MySQL.query.await("SELECT plate FROM vr_bank_loans WHERE citizenid = ? AND status IN ('active', 'collections') AND plate IS NOT NULL", { cid }) or {}
    for i = 1, #prow do pledged[plateKey(prow[i].plate)] = true end
    local out = {}
    for i = 1, #rows do
        local plate = plateKey(rows[i].plate)
        if plate then
            local model = tostring(rows[i].model)
            out[#out + 1] = {
                plate = plate,
                model = model,
                name = Core.vehicleName(model),
                value = math.floor(Core.vehiclePrice(model) * (L.collateral.valueShare or 0.6)),
                pledged = pledged[plate] == true,
                held = Collections.isHeld(plate),
            }
        end
    end
    return out
end

local function validTerm(term)
    term = tonumber(term)
    for i = 1, #L.terms do
        if L.terms[i] == term then return term end
    end
    return nil
end

function Loans.quote(info, amount, term, plate)
    local q = { approved = false, reasons = {} }
    if not L.enabled then q.reasons[1] = 'disabled' return q end
    local score = Credit.get(info.cid)
    local tier = Credit.tier(score)
    q.score, q.tier = score, { key = tier.key, label = tier.label }
    q.intervalHours = L.intervalHours
    term = validTerm(term) or L.terms[1]
    q.term = term
    local collateral
    plate = plateKey(plate)
    if plate and plate ~= '' and L.collateral.enabled then
        for _, v in ipairs(Loans.vehicles(info.cid)) do
            if v.plate == plate and not v.pledged and not v.held then collateral = v break end
        end
        if not collateral then q.reasons[#q.reasons + 1] = 'bad_collateral' end
    end
    q.collateral = collateral
    local maxLoan = tier.maxLoan
    local rate = tier.ratePercent
    if collateral then
        maxLoan = math.floor(math.min(tier.maxLoan * (L.collateral.maxMultiplier or 2), tier.maxLoan + collateral.value))
        rate = math.max(1, rate - (L.collateral.rateDiscountPercent or 0))
    end
    q.maxLoan, q.rate = maxLoan, rate
    amount = Accounts.amount(amount) or 0
    q.amount = amount
    q.interest = math.ceil(amount * rate / 100 * term / 12)
    q.total = amount + q.interest
    q.installment = term > 0 and math.ceil(q.total / term) or q.total
    if amount < L.minAmount then q.reasons[#q.reasons + 1] = 'too_small' end
    if amount > maxLoan then q.reasons[#q.reasons + 1] = 'too_large' end
    if score < L.minScore and not collateral then q.reasons[#q.reasons + 1] = 'low_score' end
    if Loans.activeCount(info.cid) >= L.maxActive then q.reasons[#q.reasons + 1] = 'max_loans' end
    if Collections.openFor(info.cid) then q.reasons[#q.reasons + 1] = 'in_collections' end
    q.approved = #q.reasons == 0
    return q
end

function Loans.apply(info, amount, term, plate)
    local q = Loans.quote(info, amount, term, plate)
    if not q.approved then return false, q.reasons[1] or 'denied', q end
    local personal = Accounts.personal(info.cid)
    if not personal then return false, 'failed' end
    local t = os.time()
    local c = q.collateral
    local id = MySQL.insert.await([[INSERT INTO vr_bank_loans (citizenid, name, principal, interest, total, remaining, installment, term, interval_h, next_due, status, rate, plate, model, created)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)]],
        { info.cid, info.name, q.amount, q.interest, q.total, q.total, q.installment, q.term, L.intervalHours, t + L.intervalHours * 3600, q.rate, c and c.plate or nil, c and c.model or nil, t })
    if not id then return false, 'failed' end
    if not Accounts.credit(personal, q.amount, 'loan payout') then
        MySQL.update('DELETE FROM vr_bank_loans WHERE id = ?', { id })
        return false, 'failed'
    end
    Accounts.log(personal, 'loan', q.amount, { reason = ('Loan #%d paid out'):format(id), actor = info.cid, actorName = info.name })
    Credit.event(info.cid, 'opened', ('Loan #%d opened'):format(id))
    return true, id, q
end

function Loans.financeQuote(info, price, down, term)
    local F = L.finance or {}
    local q = { approved = false, reasons = {} }
    if not L.enabled or F.enabled == false then q.reasons[1] = 'disabled' return q end
    price = Accounts.amount(price)
    if not price then q.reasons[1] = 'bad_amount' return q end
    term = validTerm(term) or L.terms[#L.terms]
    local minDown = math.ceil(price * (F.minDownPercent or 0) / 100)
    down = math.floor(tonumber(down) or minDown)
    if down < minDown then down = minDown end
    if down > price then down = price end
    local score = Credit.get(info.cid)
    local tier = Credit.tier(score)
    local value = math.floor(price * (L.collateral.valueShare or 0.6))
    local maxLoan = math.floor(math.min(tier.maxLoan * (L.collateral.maxMultiplier or 2), tier.maxLoan + value))
    local rate = math.max(1, tier.ratePercent - (L.collateral.rateDiscountPercent or 0))
    local financed = price - down
    q.price, q.down, q.minDown, q.financed, q.term, q.rate, q.maxLoan = price, down, minDown, financed, term, rate, maxLoan
    q.score, q.tier = score, { key = tier.key, label = tier.label }
    q.interest = math.ceil(financed * rate / 100 * term / 12)
    q.total = financed + q.interest
    q.installment = term > 0 and math.ceil(q.total / term) or q.total
    q.intervalHours = L.intervalHours
    if financed < 1 then q.reasons[#q.reasons + 1] = 'too_small' end
    if financed > maxLoan then q.reasons[#q.reasons + 1] = 'too_large' end
    if Loans.activeCount(info.cid, 'finance') >= (F.maxActive or 1) then q.reasons[#q.reasons + 1] = 'max_loans' end
    if Collections.openFor(info.cid) then q.reasons[#q.reasons + 1] = 'in_collections' end
    q.approved = #q.reasons == 0
    return q
end

function Loans.createFinance(info, price, down, term, plate, model)
    local q = Loans.financeQuote(info, price, down, term)
    if not q.approved then return false, q.reasons[1] or 'denied', q end
    plate = plateKey(plate)
    if not plate then return false, 'bad_collateral' end
    local t = os.time()
    local id = MySQL.insert.await([[INSERT INTO vr_bank_loans (citizenid, name, principal, interest, total, remaining, installment, term, interval_h, next_due, status, rate, plate, model, created, kind)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, 'finance')]],
        { info.cid, info.name, q.financed, q.interest, q.total, q.total, q.installment, q.term, L.intervalHours, t + L.intervalHours * 3600, q.rate, plate, model, t })
    if not id then return false, 'failed' end
    Credit.event(info.cid, 'opened', ('Car finance #%d opened'):format(id))
    return true, id, q
end

function Loans.cancelFinance(id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await("UPDATE vr_bank_loans SET status = 'closed', closed_at = ? WHERE id = ? AND kind = 'finance' AND paid_count = 0", { os.time(), id }) or 0) > 0
end

local function finish(loan, how)
    loan.status = 'paid'
    loan.closedAt = os.time()
    loan.arrears = 0
    loan.missed = 0
    Credit.event(loan.cid, 'paidOff', ('Loan #%d %s'):format(loan.id, how or 'paid off'))
end

function Loans.pay(info, id, amount)
    id = tonumber(id)
    if not id or busy[id] then return false, 'busy' end
    busy[id] = true
    local ok, a, b = pcall(function()
        local loan = Loans.get(id)
        if not loan or loan.cid ~= info.cid then return false, 'no_loan' end
        if loan.status ~= 'active' then return false, 'not_active' end
        if amount == 'full' then amount = loan.remaining elseif amount == 'due' then amount = math.max(loan.arrears, math.min(loan.installment, loan.remaining)) end
        amount = Accounts.amount(amount)
        if not amount then return false, 'bad_amount' end
        amount = math.min(amount, loan.remaining)
        local personal = Accounts.personal(info.cid)
        if not personal or not Accounts.debit(personal, amount, 'loan repayment') then return false, 'no_funds' end
        Accounts.log(personal, 'repayment', -amount, { reason = ('Loan #%d repayment'):format(loan.id), actor = info.cid, actorName = info.name })
        loan.remaining = loan.remaining - amount
        loan.arrears = math.max(0, loan.arrears - amount)
        if loan.arrears == 0 then loan.missed = 0 end
        if loan.remaining <= 0 then finish(loan, 'paid off early') end
        save(loan)
        return true, loan
    end)
    busy[id] = nil
    if not ok then print(('^1[vr-banking] loan pay: %s^0'):format(tostring(a))) return false, 'failed' end
    return a, b
end

local function miss(loan, src)
    local fee = math.ceil(math.min(loan.installment, loan.remaining) * (L.lateFeePercent or 0) / 100)
    loan.remaining = loan.remaining + fee
    loan.fees = loan.fees + fee
    loan.arrears = math.min(loan.remaining, loan.arrears + math.min(loan.installment, loan.remaining) + fee)
    loan.missed = loan.missed + 1
    loan.missedTotal = loan.missedTotal + 1
    Credit.event(loan.cid, 'missed', ('Loan #%d payment missed'):format(loan.id))
    local case
    if loan.missed >= (L.defaultAfterMissed or 3) then
        loan.status = 'collections'
        Credit.event(loan.cid, 'default', ('Loan #%d defaulted'):format(loan.id))
        case = Collections.open(loan)
        if src then Core.notify(src, ('Loan #%d has defaulted and was sent to collections. Your vehicles can be repossessed.'):format(loan.id), 'error') end
    elseif src then
        Core.notify(src, ('You missed a loan payment. A $%s late fee was added. %d more and the loan defaults.'):format(Fmt.money(fee), (L.defaultAfterMissed or 3) - loan.missed), 'error')
    end
    return fee, case
end

function Loans.charge(loan)
    if busy[loan.id] then return end
    busy[loan.id] = true
    local ok, err = pcall(function()
        local due = math.min(loan.remaining, loan.installment + loan.arrears)
        local personal = Accounts.personal(loan.cid)
        local interval = loan.intervalH * 3600
        local src = Core.sourceOf(loan.cid)
        if personal and due > 0 and Accounts.debit(personal, due, 'loan installment') then
            Accounts.log(personal, 'repayment', -due, { reason = ('Loan #%d installment'):format(loan.id) })
            loan.remaining = loan.remaining - due
            loan.arrears = 0
            loan.missed = 0
            loan.paidCount = loan.paidCount + 1
            Credit.event(loan.cid, 'onTime', ('Loan #%d payment on time'):format(loan.id))
            if loan.remaining <= 0 then
                finish(loan, 'paid in full')
                if src then Core.notify(src, ('Loan #%d is fully paid. Well done.'):format(loan.id), 'success') end
            elseif src then
                Core.notify(src, ('$%s loan payment taken from your account'):format(Fmt.money(due)), 'inform')
            end
        else
            miss(loan, src)
        end
        loan.nextDue = loan.nextDue + interval
        if loan.nextDue <= os.time() then loan.nextDue = os.time() + interval end
        save(loan)
    end)
    busy[loan.id] = nil
    if not ok then print(('^1[vr-banking] loan charge: %s^0'):format(tostring(err))) end
end

local function summary(loan, fee, case)
    return {
        id = loan.id,
        status = loan.status,
        missed = loan.missed,
        defaultAfter = L.defaultAfterMissed or 3,
        fee = fee,
        remaining = loan.remaining,
        arrears = loan.arrears,
        caseId = case and case.id or nil,
        plate = loan.plate,
    }
end

function Loans.forceMiss(id, toDefault)
    id = tonumber(id)
    if not id or busy[id] then return false, 'busy' end
    busy[id] = true
    local ok, a, b = pcall(function()
        local loan = Loans.get(id)
        if not loan then return false, 'no_loan' end
        if loan.status ~= 'active' then return false, 'not_active' end
        if toDefault then loan.missed = math.max(loan.missed, (L.defaultAfterMissed or 3) - 1) end
        local fee, case = miss(loan, Core.sourceOf(loan.cid))
        loan.nextDue = os.time() + loan.intervalH * 3600
        save(loan)
        return true, summary(loan, fee, case)
    end)
    busy[id] = nil
    if not ok then print(('^1[vr-banking] force miss: %s^0'):format(tostring(a))) return false, 'failed' end
    return a, b
end

function Loans.dueNow(id)
    local loan = Loans.get(id)
    if not loan then return false, 'no_loan' end
    if loan.status ~= 'active' then return false, 'not_active' end
    loan.nextDue = os.time()
    MySQL.update.await('UPDATE vr_bank_loans SET next_due = ? WHERE id = ?', { loan.nextDue, loan.id })
    local missedBefore = loan.missed
    Loans.charge(loan)
    local after = Loans.get(id)
    return true, { paid = after.missed == 0 and after.paidCount > loan.paidCount, missed = after.missed > missedBefore, loan = summary(after, 0, after.status == 'collections' and Collections.forLoan(after.id) or nil) }
end

function Loans.latestFor(cid)
    local r = MySQL.single.await("SELECT * FROM vr_bank_loans WHERE citizenid = ? AND status = 'active' ORDER BY id DESC LIMIT 1", { cid })
    return r and fromRow(r) or nil
end

function Loans.process()
    local rows = MySQL.query.await("SELECT * FROM vr_bank_loans WHERE status = 'active' AND next_due <= ? ORDER BY next_due LIMIT 100", { os.time() }) or {}
    for i = 1, #rows do Loans.charge(fromRow(rows[i])) end
    return #rows
end

function Loans.closeFromCase(loanId, how)
    if not loanId then return end
    local loan = Loans.get(loanId)
    if not loan or loan.status == 'paid' then return end
    loan.remaining = 0
    loan.arrears = 0
    loan.missed = 0
    loan.status = 'paid'
    loan.closedAt = os.time()
    save(loan)
end

function Loans.view(l)
    return {
        id = l.id,
        principal = l.principal,
        interest = l.interest,
        total = l.total,
        remaining = l.remaining,
        installment = l.installment,
        arrears = l.arrears,
        fees = l.fees,
        term = l.term,
        paidCount = l.paidCount,
        missed = l.missed,
        nextDue = l.nextDue,
        status = l.status,
        rate = l.rate,
        kind = l.kind,
        plate = l.plate,
        vehicle = l.vehicle,
        created = l.created,
        closedAt = l.closedAt,
        defaultAfter = L.defaultAfterMissed,
    }
end
