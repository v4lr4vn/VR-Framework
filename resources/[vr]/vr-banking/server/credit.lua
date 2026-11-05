Credit = {}

local C = Config.Credit
local cache = {}

local function clamp(v)
    return math.max(C.min, math.min(C.max, math.floor(v)))
end

function Credit.get(cid)
    if cache[cid] then return cache[cid] end
    local score = MySQL.scalar.await('SELECT score FROM vr_bank_credit WHERE citizenid = ?', { cid })
    score = tonumber(score) or C.start
    cache[cid] = score
    return score
end

function Credit.tier(score)
    for i = 1, #C.tiers do
        if score >= C.tiers[i].min then return C.tiers[i] end
    end
    return C.tiers[#C.tiers]
end

function Credit.change(cid, delta, reason)
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return Credit.get(cid) end
    local before = Credit.get(cid)
    local after = clamp(before + delta)
    cache[cid] = after
    local t = os.time()
    MySQL.query('INSERT INTO vr_bank_credit (citizenid, score, updated) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE score = VALUES(score), updated = VALUES(updated)', { cid, after, t })
    MySQL.insert('INSERT INTO vr_bank_credit_log (citizenid, delta, score, reason, at) VALUES (?, ?, ?, ?, ?)', { cid, after - before, after, tostring(reason or 'Adjustment'):sub(1, 64), t })
    TriggerEvent('vr-banking:server:creditChanged', cid, after, after - before, reason)
    return after
end

function Credit.event(cid, key, reason)
    return Credit.change(cid, C.events[key] or 0, reason)
end

function Credit.set(cid, score, reason)
    return Credit.change(cid, clamp(score) - Credit.get(cid), reason or 'Set by staff')
end

function Credit.report(cid)
    local score = Credit.get(cid)
    local tier = Credit.tier(score)
    local history = MySQL.query.await('SELECT delta, score, reason, at FROM vr_bank_credit_log WHERE citizenid = ? ORDER BY id DESC LIMIT 25', { cid }) or {}
    for i = 1, #history do
        history[i].delta = tonumber(history[i].delta)
        history[i].score = tonumber(history[i].score)
        history[i].at = tonumber(history[i].at)
    end
    local stats = MySQL.single.await([[SELECT
        COALESCE(SUM(status = 'paid'), 0) AS paid,
        COALESCE(SUM(status = 'active'), 0) AS active,
        COALESCE(SUM(status IN ('default', 'collections')), 0) AS defaults,
        COALESCE(SUM(paid_count), 0) AS payments,
        COALESCE(SUM(missed_total), 0) AS missed
        FROM vr_bank_loans WHERE citizenid = ?]], { cid }) or {}
    local personal = Accounts.personal(cid)
    local nextTier
    for i = #C.tiers, 1, -1 do
        if C.tiers[i].min > score then
            nextTier = { label = C.tiers[i].label, min = C.tiers[i].min }
            break
        end
    end
    return {
        score = score,
        min = C.min,
        max = C.max,
        tier = { key = tier.key, label = tier.label, maxLoan = tier.maxLoan, rate = tier.ratePercent },
        nextTier = nextTier,
        tiers = C.tiers,
        history = history,
        stats = {
            paid = tonumber(stats.paid) or 0,
            active = tonumber(stats.active) or 0,
            defaults = tonumber(stats.defaults) or 0,
            payments = tonumber(stats.payments) or 0,
            missed = tonumber(stats.missed) or 0,
            since = personal and personal.created or os.time(),
        },
    }
end
