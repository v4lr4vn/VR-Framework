-- Licences, closures, hygiene, inspections, and buying a business at City Hall.

local DAY = 86400
local function now() return os.time() end

---------------------------------------------------------------------------
-- Licence and closure state
---------------------------------------------------------------------------

function Rest.licence(b)
    local t = now()
    if b.licenceNumber == '' or b.licenceExpires <= 0 then
        return { status = 'none', valid = false, number = '', expires = 0, left = 0 }
    end
    local left = b.licenceExpires - t
    return {
        status = left > 0 and 'active' or 'expired', valid = left > 0,
        number = b.licenceNumber, expires = b.licenceExpires, left = left,
        renewable = left <= Config.Licence.renewWindowDays * DAY,
    }
end

-- True while the business is shut. Returns the reason code too.
function Rest.isClosed(b)
    if b.status == 'revoked' then return true, 'revoked' end
    if b.status == 'closed' then
        if b.closedUntil == 0 or now() < b.closedUntil then return true, b.closedReason end
    end
    return false
end

function Rest.isOpen(b) return not Rest.isClosed(b) end

local function members(b)
    local out = {}
    if b.owner ~= '' then out[#out + 1] = b.owner end
    for cid in pairs(b.staff) do out[#out + 1] = cid end
    return out
end

local function tell(b, text, kind)
    for _, cid in ipairs(members(b)) do
        local src = Bridge.source(cid)
        if src then Rest.notify(src, text, kind or 'inform') end
    end
end
Rest.tellStaff = tell

local function clockEveryoneOut(b)
    for _, cid in ipairs(members(b)) do
        if Rest.duty[cid] == b.id then Rest.duty[cid] = nil end
    end
end

function Rest.closeBusiness(b, untilAt, reason)
    b.status, b.closedUntil, b.closedReason = 'closed', untilAt or 0, reason or ''
    clockEveryoneOut(b)
    Rest.saveBusiness(b)
    Rest.push()
end

function Rest.reopen(b)
    b.status, b.closedUntil, b.closedReason = 'open', 0, ''
    Rest.saveBusiness(b)
    Rest.push()
end

---------------------------------------------------------------------------
-- Hygiene
---------------------------------------------------------------------------

local function ratingFor(score)
    local list = Config.Hygiene.ratings
    for _, r in ipairs(list) do
        if score >= r.min then return r end
    end
    return list[#list]
end
Rest.ratingFor = ratingFor

local function cleanStations(b)
    local out = {}
    for _, s in pairs(b.stations) do
        if s.kind == 'clean' then out[#out + 1] = s end
    end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end
Rest.cleanStations = cleanStations

-- 100 is spotless. Half the score is the average dirt, half is the worst corner, so one filthy
-- area cannot hide behind clean ones.
function Rest.hygiene(b)
    local list = cleanStations(b)
    if #list == 0 then return math.min(100, Config.Hygiene.noPointCap) end
    local sum, worst = 0, 0
    for _, s in ipairs(list) do
        sum = sum + s.dirt
        if s.dirt > worst then worst = s.dirt end
    end
    return math.max(0, 100 - (sum / #list * 0.5 + worst * 0.5))
end

local dirty = {}

local function onDuty(b)
    local n = 0
    for _, cid in ipairs(members(b)) do
        if Rest.duty[cid] == b.id then n = n + 1 end
    end
    return n
end

function Rest.hygieneTick(seconds)
    local h = Config.Hygiene
    for _, b in pairs(Rest.biz) do
        if b.owner ~= '' and Rest.isOpen(b) then
            local n = onDuty(b)
            if n > 0 then
                local add = h.dirtPerHour * seconds / 3600 * (1 + h.perStaff * (n - 1))
                for _, s in ipairs(cleanStations(b)) do
                    s.dirt = math.min(100.0, s.dirt + add)
                    dirty[s.id] = true
                end
            end
        end
    end
end

-- Kitchen work makes a mess. Spread over the cleaning points.
function Rest.addMess(id, amount)
    local b = Rest.biz[tonumber(id) or -1]
    amount = Rest.num(amount)
    if not b or not amount or amount <= 0 then return false end
    local list = cleanStations(b)
    if #list == 0 then return false end
    for _, s in ipairs(list) do
        s.dirt = math.min(100.0, s.dirt + amount / #list)
        dirty[s.id] = true
    end
    return true
end

function Rest.flushStations()
    for id in pairs(dirty) do
        local s = Rest.stations[id]
        dirty[id] = nil
        if s then MySQL.query('UPDATE vr_rest_stations SET dirt = ? WHERE id = ?', { s.dirt, s.id }) end
    end
end

function Rest.markClean(s)
    s.dirt = 0.0
    dirty[s.id] = true
end

CreateThread(function()
    local since = 0
    while true do
        Wait(Config.Hygiene.tickSeconds * 1000)
        if Rest.loaded then
            pcall(Rest.hygieneTick, Config.Hygiene.tickSeconds)
            since = since + Config.Hygiene.tickSeconds
            if since >= Config.Hygiene.saveSeconds then
                since = 0
                pcall(Rest.flushStations)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Rest.loaded then pcall(Rest.flushStations) end
end)

---------------------------------------------------------------------------
-- Money
---------------------------------------------------------------------------

-- Takes what it can from the business account, up to `amount`, and sends it to the government.
local function charge(b, amount)
    amount = math.floor(amount)
    if amount <= 0 then return 0 end
    local take = math.min(amount, Rest.bank.balance(b))
    if take > 0 and Rest.bank.remove(b, take) then
        Bridge.society.add(Config.Society, take, ('Fine: %s'):format(b.label))
        return take
    end
    return 0
end
Rest.chargeFine = charge

---------------------------------------------------------------------------
-- Inspections
---------------------------------------------------------------------------

local function decayStrikes(b)
    if b.strikes <= 0 then return end
    local span = Config.Inspect.strikeDecayDays * DAY
    local gone = math.floor((now() - b.lastStrike) / span)
    if gone > 0 then
        b.strikes = math.max(0, b.strikes - gone)
        b.lastStrike = b.strikes > 0 and (b.lastStrike + gone * span) or 0
        Rest.saveBusiness(b)
    end
end
Rest.decayStrikes = decayStrikes

local function log(b, entry)
    entry.at = entry.at or now()
    entry.hygiene = math.floor((tonumber(entry.hygiene) or 0) + 0.5)
    entry.fine = math.floor(tonumber(entry.fine) or 0)
    table.insert(b.history, 1, entry)
    while #b.history > Config.Inspect.history do table.remove(b.history) end
    MySQL.query('INSERT INTO vr_rest_inspections (business, at, by_name, hygiene, licence_ok, outcome, fine, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        b.id, entry.at, entry.by or '', entry.hygiene, entry.licence and 1 or 0, entry.outcome or '', entry.fine, (entry.note or ''):sub(1, 200),
    })
end
Rest.logInspection = log

local function banOwner(cid)
    local untilAt = now() + Config.Inspect.permanent.banDays * DAY
    Rest.bans[cid] = untilAt
    MySQL.query('INSERT INTO vr_rest_bans (cid, until_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE until_at = VALUES(until_at)', { cid, untilAt })
end

-- Shut for good: the owner loses the business and the place stays off the market for a while.
function Rest.revoke(b, why)
    local old = b.owner
    clockEveryoneOut(b)
    for cid in pairs(b.staff) do
        Rest.removeStaff(b, cid)
        local src = Bridge.source(cid)
        if src then Rest.notify(src, ('%s was shut down for good. You no longer work there'):format(b.label), 'error') end
    end
    if Config.Inspect.permanent.revokesOwnership and old ~= '' then
        local left = Rest.bank.balance(b)
        if left > 0 and Rest.bank.remove(b, left) then
            local src = Bridge.source(old)
            if not (src and Bridge.addMoney(src, 'bank', left, 'Closed business account')) then
                if Bridge.chars and Bridge.chars.addBank then Bridge.chars.addBank(old, left, 'Closed business account') else Rest.bank.add(b, left) end
            end
        end
        banOwner(old)
        local src = Bridge.source(old)
        if src then Rest.notify(src, ('%s was shut down for good. You cannot buy a business for %d days'):format(b.label, Config.Inspect.permanent.banDays), 'error') end
        b.owner, b.ownerName = '', ''
    end
    b.status, b.closedUntil, b.closedReason = 'revoked', now() + Config.Inspect.permanent.relistDays * DAY, 'revoked'
    b.licenceNumber, b.licenceExpires = '', 0
    Rest.index()
    Rest.saveBusiness(b)
    Rest.push()
end

-- When the time is up a shut-down business goes back on sale, spotless and with a clean record.
local function relist(b)
    b.status, b.closedUntil, b.closedReason, b.strikes, b.lastStrike = 'open', 0, '', 0, 0
    for _, s in pairs(b.stations) do Rest.markClean(s) end
    Rest.saveBusiness(b)
    Rest.push()
end
Rest.relist = relist

-- What an inspector would find right now.
function Rest.assess(b)
    local lic = Rest.licence(b)
    local score = Rest.hygiene(b)
    return { licence = lic, hygiene = score, rating = ratingFor(score), strikes = b.strikes }
end

-- The result of an inspection that decides for itself (the random visit). Returns the outcome name.
function Rest.randomInspection(b)
    local cfg = Config.Inspect
    decayStrikes(b)
    local lic = Rest.licence(b)
    local score = Rest.hygiene(b)
    local offences = {}
    if not lic.valid then offences[#offences + 1] = 'unlicensed' end
    if score < cfg.failBelow then offences[#offences + 1] = 'unhygienic' end
    b.lastInspected = now()

    if #offences == 0 then
        local outcome = score < cfg.warnBelow and 'warning' or 'pass'
        log(b, { by = 'Food Standards', hygiene = score, licence = true, outcome = outcome, note = outcome == 'warning' and 'Clean up before the next visit' or 'No problems found' })
        Rest.saveBusiness(b)
        if outcome == 'warning' then
            tell(b, ('Food Standards visited %s. The place is getting dirty. Clean up before they come back'):format(b.label), 'inform')
        else
            tell(b, ('Food Standards visited %s and found no problems'):format(b.label), 'success')
        end
        return outcome
    end

    b.strikes = b.strikes + 1
    b.lastStrike = now()
    local fine = 0
    for _, o in ipairs(offences) do fine = fine + (cfg.fines[o] or 0) end
    local paid = charge(b, fine)

    if b.strikes >= cfg.maxStrikes then
        log(b, { by = 'Food Standards', hygiene = score, licence = lic.valid, outcome = 'shut_down', fine = paid, note = table.concat(offences, ', ') })
        tell(b, ('Food Standards shut %s down for good after repeated offences'):format(b.label), 'error')
        Rest.revoke(b, 'strikes')
        return 'shut_down'
    end

    local untilAt, reason = 0, 'licence'
    local unlicensed = false
    for _, o in ipairs(offences) do if o == 'unlicensed' then unlicensed = true end end
    if unlicensed then
        untilAt, reason = 0, 'licence'
    else
        untilAt, reason = now() + (cfg.closeHours * b.strikes) * 3600, 'hygiene'
    end
    Rest.closeBusiness(b, untilAt, reason)
    log(b, { by = 'Food Standards', hygiene = score, licence = lic.valid, outcome = 'closed', fine = paid, note = table.concat(offences, ', ') })
    tell(b, ('Food Standards closed %s (%s). Fine: $%d. Strike %d of %d'):format(b.label, table.concat(offences, ', '), paid, b.strikes, cfg.maxStrikes), 'error')
    return 'closed'
end

function Rest.randomInspections()
    local cfg = Config.Inspect
    local t = now()
    local ran = 0
    for _, b in pairs(Rest.biz) do
        if b.status == 'revoked' and b.closedUntil > 0 and t >= b.closedUntil then
            relist(b)
        elseif b.owner ~= '' and Rest.isOpen(b) and onDuty(b) > 0 and t - b.lastInspected >= cfg.cooldownMinutes * 60 then
            local chance = cfg.chance
            if Rest.hygiene(b) < cfg.warnBelow or not Rest.licence(b).valid then chance = chance * cfg.dirtyChanceMultiplier end
            if math.random() < chance then
                Rest.randomInspection(b)
                ran = ran + 1
            end
        end
    end
    return ran
end

CreateThread(function()
    while true do
        Wait(Config.Inspect.randomMinutes * 60 * 1000)
        if Rest.loaded then pcall(Rest.randomInspections) end
    end
end)

---------------------------------------------------------------------------
-- City Hall: buying a business, the licence, handing it back
---------------------------------------------------------------------------

local function nearHall(src)
    local at = Bridge.coords(src)
    if not at then return false end
    for _, d in ipairs(Config.CityHall.desks) do
        local dx, dy, dz = at.x - d.x, at.y - d.y, at.z - d.z
        if dx * dx + dy * dy + dz * dz <= Config.CityHall.range ^ 2 then return true end
    end
    return false
end

local function banned(cid)
    local untilAt = Rest.bans[cid]
    return untilAt ~= nil and untilAt > now()
end

local function forSale(b)
    return b.owner == '' and b.price > 0 and b.status ~= 'revoked'
end

local function hallView(b)
    local score = Rest.hygiene(b)
    local rate = ratingFor(score)
    return { id = b.id, label = b.label, price = b.price, licenceDays = b.licenceDays, stars = rate.stars, rating = rate.label }
end

local function mine(who, b)
    local lic = Rest.licence(b)
    local score = Rest.hygiene(b)
    local rate = ratingFor(score)
    local closed, reason = Rest.isClosed(b)
    decayStrikes(b)
    return {
        id = b.id, label = b.label, price = b.price,
        licence = lic, fee = Config.Licence.fee, days = b.licenceDays,
        stars = rate.stars, rating = rate.label, hygiene = math.floor(score + 0.5),
        closed = closed, reason = reason, closedLeft = b.closedUntil > 0 and math.max(0, b.closedUntil - now()) or 0,
        strikes = b.strikes, maxStrikes = Config.Inspect.maxStrikes,
        refund = math.floor(b.price * Config.Sale.refundPercent / 100),
    }
end

lib.callback.register('vr-restaurant:hall', function(src)
    if not Rest.loaded then return Rest.fail('not_ready') end
    local who = Rest.info(src)
    if not who then return Rest.fail('no_player') end
    if not nearHall(src) then return Rest.fail('too_far') end
    local out = { forSale = {}, mine = nil, bannedLeft = banned(who.cid) and (Rest.bans[who.cid] - now()) or nil, hasJob = false }
    local id = Rest.byCid[who.cid]
    local own = id and Rest.biz[id]
    if own then
        out.hasJob = true
        if own.owner == who.cid then out.mine = mine(who, own) end
    end
    for _, b in pairs(Rest.biz) do
        if forSale(b) then out.forSale[#out.forSale + 1] = hallView(b) end
    end
    table.sort(out.forSale, function(a, c) return a.id < c.id end)
    return { ok = true, data = out }
end)

local HALL = {}

HALL.buy = function(who, id)
    local b = Rest.biz[tonumber(id) or -1]
    if not b or not forSale(b) then return nil, 'not_for_sale' end
    if banned(who.cid) then return nil, 'banned' end
    if Rest.byCid[who.cid] then return nil, 'has_job' end
    local paid = Bridge.pay(who.src, b.price, ('Business: %s'):format(b.label))
    if not paid then return nil, 'no_money' end
    Bridge.society.add(Config.Society, b.price, ('Sale of %s'):format(b.label))
    b.owner, b.ownerName = who.cid, who.name
    b.ownerWage = math.min(b.ownerWage > 0 and b.ownerWage or b.maxWage, b.maxWage)
    b.licenceNumber, b.licenceExpires = '', 0
    b.status, b.closedUntil, b.closedReason = 'open', 0, ''
    b.strikes, b.lastStrike = 0, 0
    Rest.index()
    Rest.saveBusiness(b)
    Rest.push()
    return { id = b.id, label = b.label }
end

HALL.licence = function(who, id)
    local b = Rest.biz[tonumber(id) or -1]
    if not b or b.owner ~= who.cid then return nil, 'not_owner' end
    if b.status == 'revoked' then return nil, 'closed_for_good' end
    local lic = Rest.licence(b)
    if lic.valid and not lic.renewable then return nil, 'not_yet', { left = lic.left } end
    local fee = Config.Licence.fee
    if not Bridge.pay(who.src, fee, ('Food licence: %s'):format(b.label)) then return nil, 'no_money' end
    Bridge.society.add(Config.Society, fee, ('Food licence: %s'):format(b.label))
    local from = math.max(now(), b.licenceExpires)
    b.licenceExpires = from + b.licenceDays * DAY
    if b.licenceNumber == '' then b.licenceNumber = ('%s%06d'):format(Config.Licence.prefix, b.id) end
    -- Being unlicensed was the reason it was shut: buying the licence lets it open again.
    if b.status == 'closed' and b.closedReason == 'licence' then
        b.status, b.closedUntil, b.closedReason = 'open', 0, ''
        Rest.push()
    end
    Rest.saveBusiness(b)
    return { number = b.licenceNumber, expires = b.licenceExpires, days = b.licenceDays }
end

HALL.surrender = function(who, id)
    local b = Rest.biz[tonumber(id) or -1]
    if not b or b.owner ~= who.cid then return nil, 'not_owner' end
    clockEveryoneOut(b)
    for cid in pairs(b.staff) do
        Rest.removeStaff(b, cid)
        local src = Bridge.source(cid)
        if src then Rest.notify(src, ('%s was handed back. You no longer work there'):format(b.label), 'error') end
    end
    local refund = math.floor(b.price * Config.Sale.refundPercent / 100)
    if refund > 0 and Bridge.society.remove(Config.Society, refund, ('Refund: %s'):format(b.label)) then
        Bridge.addMoney(who.src, 'bank', refund, ('Refund: %s'):format(b.label))
    else
        refund = 0
    end
    local left = Rest.bank.balance(b)
    if left > 0 and Rest.bank.remove(b, left) then
        if not Bridge.addMoney(who.src, 'bank', left, 'Business account') then Rest.bank.add(b, left) left = 0 end
    else
        left = 0
    end
    b.owner, b.ownerName = '', ''
    b.licenceNumber, b.licenceExpires = '', 0
    b.status, b.closedUntil, b.closedReason, b.strikes, b.lastStrike = 'open', 0, '', 0, 0
    Rest.index()
    Rest.saveBusiness(b)
    Rest.push()
    return { id = b.id, refund = refund, account = left }
end

lib.callback.register('vr-restaurant:hallAct', function(src, action, id)
    if Rest.throttle(src, 'hall', Config.Business.minGapMs) then return Rest.fail('slow_down') end
    if not Rest.loaded then return Rest.fail('not_ready') end
    local who = Rest.info(src)
    if not who then return Rest.fail('no_player') end
    if not nearHall(src) then return Rest.fail('too_far') end
    local fn = type(action) == 'string' and HALL[action]
    if not fn then return Rest.fail('bad_request') end
    local data, err, extra = fn(who, id)
    if not data then return Rest.fail(err or 'failed', extra) end
    return { ok = true, data = data }
end)

---------------------------------------------------------------------------
-- Food Standards officers
---------------------------------------------------------------------------

local function officer(src)
    local who = Rest.info(src)
    if not who then return nil, 'no_player' end
    local name, grade = Bridge.hasJob(src, { [Config.Inspect.job] = 0 }, true)
    if not name then return nil, 'not_inspector' end
    who.grade = tonumber(grade) or 0
    return who
end

local function nearBusiness(src, b)
    local d = Rest.distance(src, b.x, b.y, b.z)
    if d and d <= 60.0 then return true end
    for _, s in pairs(b.stations) do
        local sd = Rest.distance(src, s.x, s.y, s.z)
        if sd and sd <= 60.0 then return true end
    end
    return false
end

local function report(who, b)
    local a = Rest.assess(b)
    local areas = {}
    for _, s in ipairs(cleanStations(b)) do
        areas[#areas + 1] = { id = s.id, label = s.label ~= '' and s.label or 'Cleaning point', dirt = math.floor(s.dirt + 0.5) }
    end
    local closed, reason = Rest.isClosed(b)
    return {
        id = b.id, label = b.label, owner = b.owner ~= '' and b.ownerName or nil,
        licence = a.licence, hygiene = math.floor(a.hygiene + 0.5), stars = a.rating.stars, rating = a.rating.label,
        areas = areas, noPoints = #areas == 0,
        strikes = b.strikes, maxStrikes = Config.Inspect.maxStrikes,
        closed = closed, reason = reason, closedLeft = b.closedUntil > 0 and math.max(0, b.closedUntil - now()) or 0, status = b.status,
        history = (function() local out = {} for _, h in ipairs(b.history) do out[#out + 1] = { ago = math.max(0, now() - h.at), by = h.by, hygiene = h.hygiene, licence = h.licence, outcome = h.outcome, fine = h.fine, note = h.note } end return out end)(),
        limits = { fine = Config.Inspect.officer.maxFine, hours = Config.Inspect.officer.maxCloseHours, canRevoke = who.grade >= Config.Inspect.officer.revokeGrade },
        onDuty = (function() local n = 0 for _, cid in ipairs(members(b)) do if Rest.duty[cid] == b.id then n = n + 1 end end return n end)(),
    }
end

lib.callback.register('vr-restaurant:inspect', function(src, id)
    if not Rest.loaded then return Rest.fail('not_ready') end
    local who, err = officer(src)
    if not who then return Rest.fail(err) end
    local b = Rest.biz[tonumber(id) or -1]
    if not b then return Rest.fail('not_found') end
    if not nearBusiness(src, b) then return Rest.fail('too_far') end
    return { ok = true, data = report(who, b) }
end)

local OFFICER = {}

local function finish(who, b, outcome, fine, note)
    local a = Rest.assess(b)
    log(b, { by = who.name, hygiene = a.hygiene, licence = a.licence.valid, outcome = outcome, fine = fine or 0, note = note })
    b.lastInspected = now()
    Rest.saveBusiness(b)
end

OFFICER.record = function(who, b)
    finish(who, b, 'visit', 0, 'Checked the premises')
    return { ok = true }
end

OFFICER.warn = function(who, b, note)
    note = Rest.text(note, 2, 200)
    if not note then return nil, 'bad_value' end
    finish(who, b, 'warning', 0, note)
    tell(b, ('Food Standards warning for %s: %s'):format(b.label, note), 'error')
    return { ok = true }
end

OFFICER.fine = function(who, b, amount, note)
    local n = Rest.int(amount, 1, Config.Inspect.officer.maxFine)
    note = Rest.text(note, 2, 200)
    if not n or not note then return nil, 'bad_value' end
    local paid = charge(b, n)
    finish(who, b, 'fine', paid, note)
    tell(b, ('Food Standards fined %s $%d: %s'):format(b.label, paid, note), 'error')
    return { paid = paid, asked = n }
end

OFFICER.close = function(who, b, hours, note)
    local h = Rest.int(hours, 1, Config.Inspect.officer.maxCloseHours)
    note = Rest.text(note, 2, 200)
    if not h or not note then return nil, 'bad_value' end
    if b.owner == '' then return nil, 'no_owner' end
    Rest.closeBusiness(b, now() + h * 3600, 'officer')
    finish(who, b, 'closed', 0, note)
    tell(b, ('Food Standards closed %s for %d hours: %s'):format(b.label, h, note), 'error')
    return { hours = h }
end

OFFICER.reopen = function(who, b)
    if not Rest.isClosed(b) or b.status == 'revoked' then return nil, 'not_closed' end
    Rest.reopen(b)
    finish(who, b, 'reopened', 0, 'Allowed to open again')
    tell(b, ('%s is allowed to open again'):format(b.label), 'success')
    return { ok = true }
end

OFFICER.revoke = function(who, b, note)
    if who.grade < Config.Inspect.officer.revokeGrade then return nil, 'no_permission' end
    note = Rest.text(note, 2, 200)
    if not note then return nil, 'bad_value' end
    if b.owner == '' then return nil, 'no_owner' end
    finish(who, b, 'shut_down', 0, note)
    tell(b, ('Food Standards shut %s down for good: %s'):format(b.label, note), 'error')
    Rest.revoke(b, 'officer')
    return { ok = true }
end

lib.callback.register('vr-restaurant:inspectAct', function(src, id, action, a, c)
    if Rest.throttle(src, 'inspect', Config.Business.minGapMs) then return Rest.fail('slow_down') end
    if not Rest.loaded then return Rest.fail('not_ready') end
    local who, err = officer(src)
    if not who then return Rest.fail(err) end
    local b = Rest.biz[tonumber(id) or -1]
    if not b then return Rest.fail('not_found') end
    if not nearBusiness(src, b) then return Rest.fail('too_far') end
    local fn = type(action) == 'string' and OFFICER[action]
    if not fn then return Rest.fail('bad_request') end
    local data, e, extra = fn(who, b, a, c)
    if not data then return Rest.fail(e or 'failed', extra) end
    data.report = report(who, b)
    return { ok = true, data = data }
end)

---------------------------------------------------------------------------
-- For other scripts
---------------------------------------------------------------------------

exports('IsOpen', function(id)
    local b = Rest.biz[tonumber(id) or -1]
    return b ~= nil and Rest.isOpen(b)
end)
exports('GetHygiene', function(id)
    local b = Rest.biz[tonumber(id) or -1]
    return b and Rest.hygiene(b) or nil
end)
exports('HasLicence', function(id)
    local b = Rest.biz[tonumber(id) or -1]
    return b ~= nil and Rest.licence(b).valid
end)
exports('AddMess', function(id, amount) return Rest.addMess(id, amount) end)

-- A timed closure ends by itself. Tell the clients (map blips) when the open/closed state flips.
do
    local shown = {}
    CreateThread(function()
        while true do
            Wait(30000)
            if Rest.loaded then
                local changed = false
                for id, b in pairs(Rest.biz) do
                    local closed = Rest.isClosed(b) and true or false
                    if shown[id] ~= nil and shown[id] ~= closed then changed = true end
                    shown[id] = closed
                end
                if changed then Rest.push() end
            end
        end
    end)
end
