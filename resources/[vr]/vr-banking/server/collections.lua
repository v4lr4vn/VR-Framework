Collections = {}

local K = Config.Collections
local cases = {}
local held = {}
local traced = {}
local requests = {}
local plateCache = {}
local plateCacheAt = 0

local function now() return os.time() end
local function num(v) return tonumber(v) or 0 end

local function fromRow(r)
    local ok, log = pcall(json.decode, r.log or '[]')
    return {
        id = num(r.id),
        loanId = r.loan_id and num(r.loan_id) or nil,
        cid = r.citizenid,
        name = r.name,
        amount = num(r.amount),
        original = num(r.original),
        status = r.status,
        claimedBy = r.claimed_by,
        claimedName = r.claimed_name,
        claimedUntil = num(r.claimed_until),
        log = ok and type(log) == 'table' and log or {},
        created = num(r.created),
        updated = num(r.updated),
        plate = r.loan_plate and Loans.plateKey(r.loan_plate) or nil,
        model = r.loan_model,
    }
end

local function save(c)
    c.updated = now()
    while #c.log > 40 do table.remove(c.log, 1) end
    MySQL.update('UPDATE vr_bank_cases SET amount = ?, status = ?, claimed_by = ?, claimed_name = ?, claimed_until = ?, log = ?, updated = ? WHERE id = ?',
        { c.amount, c.status, c.claimedBy, c.claimedName, c.claimedUntil, json.encode(c.log), c.updated, c.id })
end

local function note(c, text, who)
    c.log[#c.log + 1] = { at = now(), text = text, by = who }
end

function Collections.load()
    local rows = MySQL.query.await("SELECT c.*, l.plate AS loan_plate, l.model AS loan_model FROM vr_bank_cases c LEFT JOIN vr_bank_loans l ON l.id = c.loan_id WHERE c.status = 'open'") or {}
    for i = 1, #rows do
        local c = fromRow(rows[i])
        cases[c.id] = c
    end
    local hrows = MySQL.query.await("SELECT * FROM vr_bank_repos WHERE status = 'held'") or {}
    for i = 1, #hrows do
        local h = hrows[i]
        held[Loans.plateKey(h.plate)] = { id = num(h.id), plate = Loans.plateKey(h.plate), caseId = num(h.case_id), cid = h.citizenid, model = h.model, seizedAt = num(h.seized_at), seizedName = h.seized_name }
    end
end

function Collections.isHeld(plate)
    plate = Loans.plateKey(plate)
    return plate ~= nil and held[plate] ~= nil
end

function Collections.heldFor(cid)
    local out = {}
    for _, h in pairs(held) do
        if h.cid == cid then out[#out + 1] = { plate = h.plate, model = h.model, name = h.model and Core.vehicleName(h.model) or h.plate, caseId = h.caseId, seizedAt = h.seizedAt } end
    end
    return out
end

function Collections.openFor(cid)
    for _, c in pairs(cases) do
        if c.cid == cid and c.status == 'open' then return c end
    end
    return nil
end

local function isCollector(info)
    return info and info.job and info.job.name == Config.CollectorJob and info.job.onduty
end

Collections.isCollector = isCollector

local function claimValid(c)
    return c.claimedBy ~= nil and c.claimedUntil > now()
end

local function collectorInfos()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local info = Core.info(tonumber(id))
        if isCollector(info) then out[#out + 1] = info end
    end
    return out
end

Collections.collectors = collectorInfos

local function collectorSources()
    local out = {}
    for _, info in ipairs(collectorInfos()) do out[#out + 1] = info.src end
    return out
end

Collections.collectorSources = collectorSources

function Collections.collateral()
    local out = {}
    for _, c in pairs(cases) do
        if c.status == 'open' and c.plate and not held[c.plate] then out[c.plate] = c end
    end
    return out
end

function Collections.forLoan(loanId)
    for _, c in pairs(cases) do
        if c.loanId == tonumber(loanId) and c.status == 'open' then return c end
    end
    return nil
end

function Collections.claimedBy(c)
    if c.claimedBy ~= nil and c.claimedUntil > now() then return c.claimedBy end
    return nil
end

function Collections.noteCase(id, text)
    local c = cases[tonumber(id)]
    if not c then return end
    c.log[#c.log + 1] = { at = now(), text = text }
    save(c)
end

local function casePlates(c)
    local list, seen = {}, {}
    local loan = c.loanId and Loans.get(c.loanId) or nil
    if loan and loan.plate then
        local p = Loans.plateKey(loan.plate)
        seen[p] = true
        local tracked = Config.Collections.tracker and Config.Collections.tracker.enabled ~= false
        list[#list + 1] = { plate = p, model = loan.model, name = loan.model and Core.vehicleName(loan.model) or p, collateral = true, held = held[p] ~= nil, tracked = tracked and held[p] == nil, staged = Repo.isStaged(p) }
    end
    if K.repoAnyVehicle then
        for _, v in ipairs(Loans.vehicles(c.cid)) do
            if not seen[v.plate] then
                seen[v.plate] = true
                list[#list + 1] = { plate = v.plate, model = v.model, name = v.name, collateral = false, held = held[v.plate] ~= nil }
            end
        end
    end
    for _, h in pairs(held) do
        if h.caseId == c.id and not seen[h.plate] then
            list[#list + 1] = { plate = h.plate, model = h.model, name = h.model and Core.vehicleName(h.model) or h.plate, collateral = false, held = true }
        end
    end
    return list
end

function Collections.refreshPlates()
    local map = {}
    for _, c in pairs(cases) do
        if c.status == 'open' then
            for _, v in ipairs(casePlates(c)) do
                if not v.held then map[v.plate] = c.id end
            end
        end
    end
    plateCache = map
    plateCacheAt = now()
    for _, src in ipairs(collectorSources()) do
        TriggerClientEvent('vr-banking:client:repoPlates', src, map)
    end
    return map
end

function Collections.plates()
    if now() - plateCacheAt > 300 then return Collections.refreshPlates() end
    return plateCache
end

function Collections.open(loan)
    local t = now()
    local log = { { at = t, text = ('Opened after loan #%d defaulted'):format(loan.id) } }
    local id = MySQL.insert.await('INSERT INTO vr_bank_cases (loan_id, citizenid, name, amount, original, status, log, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { loan.id, loan.cid, loan.name, loan.remaining, loan.remaining, 'open', json.encode(log), t, t })
    if not id then return nil end
    local c = { id = id, loanId = loan.id, cid = loan.cid, name = loan.name, amount = loan.remaining, original = loan.remaining, status = 'open', claimedUntil = 0, log = log, created = t, updated = t, plate = loan.plate and Loans.plateKey(loan.plate) or nil, model = loan.model }
    cases[id] = c
    CreateThread(Collections.refreshPlates)
    if c.plate then CreateThread(function() Repo.onCaseOpened(c) end) end
    for _, src in ipairs(collectorSources()) do
        Core.notify(src, ('New collections case #%d: %s owes $%s'):format(id, c.name, Fmt.money(c.amount)), 'inform', 'Collections')
    end
    TriggerEvent('vr-banking:server:caseOpened', id, c.cid, c.amount)
    return c
end

function Collections.view(c, info, withPlates)
    local v = {
        id = c.id,
        loanId = c.loanId,
        cid = c.cid,
        name = c.name,
        amount = c.amount,
        original = c.original,
        status = c.status,
        claimed = claimValid(c) and { by = c.claimedName, mine = info and c.claimedBy == info.cid or false, expires = c.claimedUntil } or nil,
        online = Core.sourceOf(c.cid) ~= nil,
        created = c.created,
        updated = c.updated,
        log = c.log,
    }
    if withPlates then v.vehicles = casePlates(c) end
    return v
end

function Collections.list(info)
    local out = {}
    for _, c in pairs(cases) do
        if c.status == 'open' then out[#out + 1] = Collections.view(c, info, true) end
    end
    table.sort(out, function(a, b) return a.created > b.created end)
    return out
end

function Collections.forDebtor(cid)
    local out = {}
    for _, c in pairs(cases) do
        if c.cid == cid and c.status == 'open' then out[#out + 1] = Collections.view(c, nil, true) end
    end
    return out
end

local function canAct(info, c)
    if not c or c.status ~= 'open' then return false, 'no_case' end
    if not isCollector(info) then return false, 'not_collector' end
    if claimValid(c) and c.claimedBy ~= info.cid then return false, 'claimed' end
    return true
end

function Collections.claim(info, id)
    local c = cases[tonumber(id)]
    local ok, err = canAct(info, c)
    if not ok then return false, err end
    c.claimedBy, c.claimedName = info.cid, info.name
    c.claimedUntil = now() + K.claimMinutes * 60
    note(c, ('Claimed by %s'):format(info.name), info.name)
    save(c)
    return true, c
end

function Collections.release(info, id)
    local c = cases[tonumber(id)]
    if not c or c.claimedBy ~= info.cid then return false, 'no_case' end
    c.claimedBy, c.claimedName, c.claimedUntil = nil, nil, 0
    note(c, ('Released by %s'):format(info.name), info.name)
    save(c)
    return true, c
end

function Collections.addNote(info, id, text)
    local c = cases[tonumber(id)]
    if not c or c.status ~= 'open' or not isCollector(info) then return false, 'no_case' end
    text = type(text) == 'string' and text:gsub('[%c<>]', ''):sub(1, 140) or ''
    if #text < 2 then return false, 'bad_note' end
    note(c, text, info.name)
    save(c)
    return true, c
end

local function findVehicle(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and Loans.vehicleHasPlate(veh, plate) then return veh end
    end
    return nil
end

function Collections.trace(info, id, plate)
    local c = cases[tonumber(id)]
    local ok, err = canAct(info, c)
    if not ok then return false, err end
    plate = Loans.plateKey(plate)
    local found
    for _, v in ipairs(casePlates(c)) do
        if v.plate == plate and not v.held then found = v break end
    end
    if not found then return false, 'no_vehicle' end
    local key = c.id .. ':' .. plate
    local last = traced[key] or 0
    if now() - last < K.traceCooldownSeconds then return false, 'cooldown', K.traceCooldownSeconds - (now() - last) end
    traced[key] = now()
    local veh = findVehicle(plate)
    if not veh then
        note(c, ('Trace on %s: not out in the city'):format(plate), info.name)
        save(c)
        return true, { found = false }
    end
    local pos = GetEntityCoords(veh)
    local angle = math.random() * math.pi * 2
    local dist = math.random() * K.traceRadius * 0.8
    note(c, ('Trace on %s: signal found'):format(plate), info.name)
    save(c)
    return true, { found = true, x = pos.x + math.cos(angle) * dist, y = pos.y + math.sin(angle) * dist, radius = K.traceRadius }
end

local function pay(cid, amount, reason)
    local acc = Accounts.personal(cid)
    if not acc or amount <= 0 then return false end
    if not Accounts.credit(acc, amount, reason) then return false end
    Accounts.log(acc, 'commission', amount, { reason = reason })
    return true
end

function Collections.repo(info, netId, plate)
    if not isCollector(info) then return false, 'not_collector' end
    plate = Loans.plateKey(plate)
    local caseId = Collections.plates()[plate]
    local c = caseId and cases[caseId]
    local ok, err = canAct(info, c)
    if not ok then return false, err end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'no_vehicle' end
    if not Loans.vehicleHasPlate(veh, plate) then return false, 'no_vehicle' end
    local me = Core.coords(info.src)
    if not me or #(me - GetEntityCoords(veh)) > K.repoDistance then return false, 'too_far' end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return false, 'occupied' end
    local model
    for _, v in ipairs(casePlates(c)) do
        if v.plate == plate then model = v.model break end
    end
    DeleteEntity(veh)
    local t = now()
    local id = MySQL.insert.await('INSERT INTO vr_bank_repos (plate, case_id, citizenid, model, status, seized_by, seized_name, seized_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { plate, c.id, c.cid, model, 'held', info.cid, info.name, t })
    held[plate] = { id = id, plate = plate, caseId = c.id, cid = c.cid, model = model, seizedAt = t, seizedName = info.name }
    Repo.unstage(plate)
    local fee = math.floor(K.repoFee or 0)
    if fee > 0 then c.amount = c.amount + fee end
    note(c, ('%s repossessed %s%s'):format(info.name, plate, fee > 0 and (' · $%s repo fee added'):format(Fmt.money(fee)) or ''), info.name)
    save(c)
    if K.collectorRepoPay and K.collectorRepoPay > 0 then pay(info.cid, math.floor(K.collectorRepoPay), ('Repossession %s (case #%d)'):format(plate, c.id)) end
    Credit.event(c.cid, 'repossessed', ('Vehicle %s repossessed'):format(plate))
    local debtor = Core.sourceOf(c.cid)
    if debtor then Core.notify(debtor, ('Your vehicle %s was repossessed. Clear your debt at any bank branch to get it back.'):format(plate), 'error') end
    TriggerEvent('vr-banking:server:vehicleSeized', plate, c.cid, c.id, model)
    Collections.refreshPlates()
    return true, { plate = plate, caseId = c.id }
end

local function releaseVehicles(c)
    Repo.caseClosed(c)
    local released = {}
    for plate, h in pairs(held) do
        if h.caseId == c.id then
            held[plate] = nil
            released[#released + 1] = plate
            MySQL.update("UPDATE vr_bank_repos SET status = 'released', released_at = ? WHERE id = ?", { now(), h.id })
            TriggerEvent('vr-banking:server:vehicleReleased', plate, h.cid, c.id)
        end
    end
    return released
end

local function settle(c, how)
    c.status = 'settled'
    c.amount = 0
    c.claimedBy, c.claimedName, c.claimedUntil = nil, nil, 0
    note(c, how)
    save(c)
    cases[c.id] = nil
    Loans.closeFromCase(c.loanId)
    Credit.event(c.cid, 'settled', ('Collections case #%d settled'):format(c.id))
    local released = releaseVehicles(c)
    Collections.refreshPlates()
    return released
end

local function receive(c, amount, payerName, collector)
    amount = math.min(amount, c.amount)
    c.amount = c.amount - amount
    note(c, ('$%s paid by %s'):format(Fmt.money(amount), payerName))
    local commissionTo = collector or (claimValid(c) and c.claimedBy) or nil
    if commissionTo and (K.commissionPercent or 0) > 0 then
        local cut = math.floor(amount * K.commissionPercent / 100)
        if cut > 0 then pay(commissionTo, cut, ('Commission case #%d'):format(c.id)) end
    end
    if c.amount <= 0 then return true, settle(c, 'Debt cleared') end
    save(c)
    return false
end

function Collections.payAtBranch(info, id, method, amount)
    local c = cases[tonumber(id)]
    if not c or c.status ~= 'open' or c.cid ~= info.cid then return false, 'no_case' end
    amount = Accounts.amount(amount == 'full' and c.amount or amount)
    if not amount then return false, 'bad_amount' end
    amount = math.min(amount, c.amount)
    if method == 'cash' then
        if not Core.removeCash(info.src, amount, ('Collections case #%d'):format(c.id)) then return false, 'no_cash' end
    else
        local personal = Accounts.personal(info.cid)
        if not personal or not Accounts.debit(personal, amount, 'debt repayment') then return false, 'no_funds' end
        Accounts.log(personal, 'repayment', -amount, { reason = ('Collections case #%d'):format(c.id), actor = info.cid, actorName = info.name })
    end
    local cleared, released = receive(c, amount, info.name)
    return true, { cleared = cleared, released = released or {}, left = c.amount }
end

function Collections.request(info, target)
    if not isCollector(info) then return false, 'not_collector' end
    target = tonumber(target)
    local tinfo = target and Core.info(target)
    if not tinfo then return false, 'no_person' end
    local c = Collections.openFor(tinfo.cid)
    if not c then return false, 'no_debt' end
    if claimValid(c) and c.claimedBy ~= info.cid then return false, 'claimed' end
    local a, b = Core.coords(info.src), Core.coords(target)
    if not a or not b or #(a - b) > K.collectDistance then return false, 'too_far' end
    local token = ('%d-%d-%d'):format(target, c.id, math.random(100000, 999999))
    requests[target] = { token = token, caseId = c.id, collector = info.cid, collectorSrc = info.src, collectorName = info.name, expires = now() + K.requestTimeout }
    TriggerClientEvent('vr-banking:client:debtRequest', target, { token = token, caseId = c.id, amount = c.amount, collector = info.name, timeout = K.requestTimeout })
    return true
end

function Collections.respond(src, token, method)
    local r = requests[src]
    if not r or r.token ~= token then return false, 'no_request' end
    requests[src] = nil
    local function tell(text, kind)
        if GetPlayerName(r.collectorSrc) then Core.notify(r.collectorSrc, text, kind, 'Collections') end
    end
    if r.expires < now() then return false, 'expired' end
    local c = cases[r.caseId]
    if not c or c.status ~= 'open' then return false, 'no_case' end
    local info = Core.info(src)
    if not info then return false, 'no_person' end
    if method ~= 'bank' and method ~= 'cash' then
        tell(('%s refused to pay'):format(info.name), 'error')
        return true, { refused = true }
    end
    local amount = c.amount
    if method == 'cash' then
        if not Core.removeCash(src, amount, ('Collections case #%d'):format(c.id)) then
            tell(('%s does not have enough cash'):format(info.name), 'error')
            return false, 'no_cash'
        end
    else
        local personal = Accounts.personal(info.cid)
        if not personal or not Accounts.debit(personal, amount, 'debt repayment') then
            tell(('%s does not have enough in the bank'):format(info.name), 'error')
            return false, 'no_funds'
        end
        Accounts.log(personal, 'repayment', -amount, { reason = ('Collections case #%d'):format(c.id), actor = info.cid, actorName = info.name })
    end
    local _, released = receive(c, amount, info.name, r.collector)
    tell(('%s paid $%s. Case #%d is closed.'):format(info.name, Fmt.money(amount), c.id), 'success')
    return true, { released = released or {} }
end

function Collections.releaseVehicle(plate)
    plate = Loans.plateKey(plate)
    local h = held[plate]
    if not h then return false end
    held[plate] = nil
    MySQL.update("UPDATE vr_bank_repos SET status = 'released', released_at = ? WHERE id = ?", { now(), h.id })
    TriggerEvent('vr-banking:server:vehicleReleased', plate, h.cid, h.caseId)
    return true
end

function Collections.close(id, reason)
    local c = cases[tonumber(id)]
    if not c then return false end
    c.status = 'closed'
    note(c, reason or 'Closed by staff')
    save(c)
    cases[c.id] = nil
    releaseVehicles(c)
    Collections.refreshPlates()
    return true
end

function Collections.withCollateral()
    local out = {}
    for _, c in pairs(cases) do
        if c.status == 'open' and c.plate then out[#out + 1] = { case = c, plate = c.plate, held = held[c.plate] ~= nil } end
    end
    table.sort(out, function(a, b) return a.case.id < b.case.id end)
    return out
end

function Collections.get(id)
    return cases[tonumber(id)]
end

function Collections.locate(info, id, plate)
    local c = cases[tonumber(id)]
    local ok, err = canAct(info, c)
    if not ok then return false, err end
    plate = Loans.plateKey(plate)
    if not plate or c.plate ~= plate or held[plate] then return false, 'no_vehicle' end
    local veh = findVehicle(plate)
    if not veh then return true, { found = false } end
    local pos = GetEntityCoords(veh)
    note(c, ('Tracker ping on %s'):format(plate), info.name)
    save(c)
    return true, { found = true, x = pos.x, y = pos.y, z = pos.z, radius = 20.0 }
end
