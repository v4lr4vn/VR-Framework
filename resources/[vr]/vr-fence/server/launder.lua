local sessions = {}
local ledger = {}

local function rateFor(spot)
    return spot.rate or Config.Launder.rate
end

local function used(cid)
    local cfg = Config.Launder
    local now = os.time()
    local cutoff = now - cfg.windowMinutes * 60
    local list = ledger[cid] or {}
    local keep, total = {}, 0
    for _, e in ipairs(list) do
        if e.t > cutoff then
            keep[#keep + 1] = e
            total = total + e.amount
        end
    end
    ledger[cid] = keep
    return total
end

local function allowance(cid)
    return math.max(0, Config.Launder.maxPerWindow - used(cid))
end

local function waitSeconds(amount)
    local cfg = Config.Launder
    return math.floor(math.min(cfg.minutesMax, cfg.minutesBase + (amount / 1000) * cfg.minutesPer1000) * 60)
end

local function access(src, spotId)
    local who = Fence.info(src)
    if not who then return nil, nil, 'no_player' end
    local spot = Fence.spot(spotId)
    if not spot or spot.kind ~= 'launder' then return nil, nil, 'bad_request' end
    if not Fence.near(src, spot) then return nil, nil, 'too_far' end
    return who, spot
end

local function jobsOf(cid)
    return MySQL.query.await('SELECT id, amount, paid, ready FROM vr_fence_jobs WHERE cid = ? ORDER BY id', { cid }) or {}
end

local function jobView(rows)
    local now = os.time()
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, amount = r.amount, paid = r.paid, wait = math.max(0, r.ready - now) }
    end
    return out
end

lib.callback.register('vr-fence:launder:info', function(src, spotId)
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    local cfg = Config.Launder
    local jobs = jobView(jobsOf(who.cid))
    return {
        ok = true,
        data = {
            dirty = Fence.count(src, Config.DirtyItem),
            rate = rateFor(spot),
            min = cfg.min,
            maxDeal = cfg.maxPerDeal,
            left = allowance(who.cid),
            jobs = jobs,
            maxOpen = cfg.maxOpen,
        },
    }
end)

lib.callback.register('vr-fence:launder:begin', function(src, spotId, amount)
    if Fence.throttle(src, 'lbegin', 800) then return Fence.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    amount = Fence.num(amount)
    if not amount then return Fence.fail('bad_request') end
    amount = math.floor(amount)
    local cfg = Config.Launder
    if amount < cfg.min then return Fence.fail('too_small') end
    if amount > cfg.maxPerDeal then return Fence.fail('too_big') end
    if amount > allowance(who.cid) then return Fence.fail('limit') end
    if Fence.count(src, Config.DirtyItem) < amount then return Fence.fail('not_enough') end
    local open = MySQL.scalar.await('SELECT COUNT(*) FROM vr_fence_jobs WHERE cid = ?', { who.cid }) or 0
    if open >= cfg.maxOpen then return Fence.fail('too_many') end
    sessions[src] = { spot = spot.id, amount = amount, at = GetGameTimer(), seconds = cfg.handoverSeconds }
    return { ok = true, data = { seconds = cfg.handoverSeconds } }
end)

local function tellWhenReady(cid, wait, label)
    SetTimeout(math.min(wait, 3600) * 1000, function()
        for _, id in ipairs(GetPlayers()) do
            local who = Fence.info(tonumber(id))
            if who and who.cid == cid then
                Fence.notify(who.src, ('Your clean money from %s is ready. Go and collect it.'):format(label or 'the contact'), 'success')
                return
            end
        end
    end)
end

lib.callback.register('vr-fence:launder:finish', function(src, spotId)
    if Fence.throttle(src, 'lfinish', 800) then return Fence.fail('slow_down') end
    local s = sessions[src]
    if not s or s.spot ~= (tonumber(spotId) or -1) then return Fence.fail('bad_request') end
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    if GetGameTimer() - s.at < s.seconds * 1000 * Config.Launder.minFraction then return Fence.fail('too_fast') end
    if GetGameTimer() - s.at > 10 * 60 * 1000 then
        sessions[src] = nil
        return Fence.fail('bad_request')
    end
    sessions[src] = nil
    if s.amount > allowance(who.cid) then return Fence.fail('limit') end
    if Fence.count(src, Config.DirtyItem) < s.amount then return Fence.fail('not_enough') end
    local open = MySQL.scalar.await('SELECT COUNT(*) FROM vr_fence_jobs WHERE cid = ?', { who.cid }) or 0
    if open >= Config.Launder.maxOpen then return Fence.fail('too_many') end
    local paid = math.floor(s.amount * rateFor(spot))
    if not Fence.take(src, Config.DirtyItem, s.amount) then return Fence.fail('not_enough') end
    local wait = waitSeconds(s.amount)
    local now = os.time()
    local id = MySQL.insert.await('INSERT INTO vr_fence_jobs (cid, spot, amount, paid, created, ready) VALUES (?, ?, ?, ?, ?, ?)', { who.cid, spot.id, s.amount, paid, now, now + wait })
    if not id then
        Fence.give(src, Config.DirtyItem, s.amount)
        return Fence.fail('failed')
    end
    ledger[who.cid] = ledger[who.cid] or {}
    table.insert(ledger[who.cid], { t = now, amount = s.amount })
    tellWhenReady(who.cid, wait, spot.label)
    TriggerEvent('vr-fence:handedOver', src, who.cid, s.amount, paid, spot.id)
    return { ok = true, data = { dirty = s.amount, paid = paid, fee = s.amount - paid, wait = wait, left = allowance(who.cid), job = id } }
end)

lib.callback.register('vr-fence:launder:collect', function(src, spotId, jobId)
    if Fence.throttle(src, 'lcollect', 800) then return Fence.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    jobId = Fence.num(jobId)
    if not jobId then return Fence.fail('bad_request') end
    local job = MySQL.single.await('SELECT id, cid, amount, paid, ready FROM vr_fence_jobs WHERE id = ?', { math.floor(jobId) })
    if not job or job.cid ~= who.cid then return Fence.fail('bad_request') end
    if job.ready > os.time() then return Fence.fail('not_done', { wait = job.ready - os.time() }) end
    -- Delete first: only the call that removes the row gets paid, so a double click can not pay twice.
    local removed = MySQL.update.await('DELETE FROM vr_fence_jobs WHERE id = ? AND cid = ?', { job.id, who.cid })
    if (removed or 0) < 1 then return Fence.fail('bad_request') end
    if not Fence.pay(src, job.paid) then
        MySQL.insert.await('INSERT INTO vr_fence_jobs (cid, spot, amount, paid, created, ready) VALUES (?, ?, ?, ?, ?, ?)', { who.cid, spot.id, job.amount, job.paid, os.time(), os.time() })
        return Fence.fail('failed')
    end
    TriggerEvent('vr-fence:laundered', src, who.cid, job.amount, job.paid, spot.id)
    return { ok = true, data = { dirty = job.amount, paid = job.paid, fee = job.amount - job.paid } }
end)

lib.callback.register('vr-fence:launder:cancel', function(src)
    sessions[src] = nil
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
