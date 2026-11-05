Fto = {}

local RECOMMENDATIONS = { 'continue', 'extend', 'release', 'signoff' }
local MAX_EVALS = 50

Db.schema('fto_evals', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_fto_evals` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `trainee_cid` VARCHAR(64) NOT NULL,
        `trainee_name` VARCHAR(64) NOT NULL,
        `fto_cid` VARCHAR(64) NOT NULL,
        `fto_name` VARCHAR(64) NOT NULL,
        `at` INT UNSIGNED NOT NULL,
        `phase` TINYINT UNSIGNED NOT NULL,
        `ratings` LONGTEXT NOT NULL,
        `score` DECIMAL(4,2) NOT NULL,
        `notes` TEXT DEFAULT NULL,
        `recommendation` VARCHAR(16) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `trainee_at` (`trainee_cid`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function traineeDivision()
    return Config.Fto.traineeDivision or 'Trainee'
end

local function hasDivision(list, name)
    local want = name:lower()
    for _, d in ipairs(list or {}) do
        if type(d) == 'string' and d:lower() == want then return true end
    end
    return false
end

function Fto.isTrainee(cid, dept)
    local m = Roster.member(cid, dept or 'police')
    return m ~= nil and hasDivision(m.divisions, traineeDivision()), m
end

local function placeholders(n)
    local marks = {}
    for i = 1, n do marks[i] = '?' end
    return table.concat(marks, ',')
end

local function ratingsList(map)
    local out = {}
    for _, cat in ipairs(Config.Fto.categories) do
        local v = type(map) == 'table' and tonumber(map[cat]) or nil
        out[#out + 1] = { category = cat, value = v }
    end
    return out
end

local function shapeEval(r)
    return {
        id = r.id,
        traineeCid = r.trainee_cid,
        traineeName = r.trainee_name,
        ftoCid = r.fto_cid,
        ftoName = r.fto_name,
        at = tonumber(r.at),
        phase = tonumber(r.phase),
        ratings = ratingsList(U.decode(r.ratings, {})),
        score = U.round(tonumber(r.score) or 0, 2),
        notes = r.notes,
        recommendation = r.recommendation,
    }
end

local function cleanRatings(v)
    if type(v) ~= 'table' then return nil end
    local map, sum, n = {}, 0, 0
    for _, cat in ipairs(Config.Fto.categories) do
        local score = V.int(v[cat], 1, 5)
        if not score then return nil end
        map[cat] = score
        sum = sum + score
        n = n + 1
    end
    if n == 0 then return nil end
    return map, sum / n
end

local function traineesOf(dept)
    local like = U.like(('"%s"'):format(traineeDivision()))
    local rows = Db.query([[SELECT `cid` FROM `vr_mdt_roster` WHERE `dept` = ? AND `status` <> 'former' AND LOWER(`divisions`) LIKE LOWER(?) ORDER BY `hired_at` DESC LIMIT 200]], { dept, like })
    if not rows then return nil end
    local out = {}
    for _, r in ipairs(rows) do
        local m = Roster.member(r.cid, dept)
        if m and hasDivision(m.divisions, traineeDivision()) then out[#out + 1] = m end
    end
    return out
end

local function statsFor(cids)
    local stats = {}
    if #cids == 0 then return stats end
    local rows = Db.query(('SELECT `trainee_cid`, COUNT(*) AS `n`, AVG(`score`) AS `avg`, MAX(`id`) AS `last` FROM `vr_mdt_fto_evals` WHERE `trainee_cid` IN (%s) GROUP BY `trainee_cid`'):format(placeholders(#cids)), cids) or {}
    local lastIds = {}
    for _, r in ipairs(rows) do
        stats[r.trainee_cid] = { evals = tonumber(r.n) or 0, average = U.round(tonumber(r.avg) or 0, 2) }
        lastIds[#lastIds + 1] = tonumber(r.last)
    end
    if #lastIds > 0 then
        local last = Db.query(('SELECT * FROM `vr_mdt_fto_evals` WHERE `id` IN (%s)'):format(placeholders(#lastIds)), lastIds) or {}
        for _, r in ipairs(last) do
            local e = shapeEval(r)
            stats[r.trainee_cid].last = { id = e.id, at = e.at, phase = e.phase, recommendation = e.recommendation, ftoName = e.ftoName, score = e.score }
        end
    end
    return stats
end

local function changed(ctx, cid)
    Push.dept(ctx.dept, 'fto:changed', { cid = cid }, function(c) return Core.can(c, 'fto.view') end)
end

Api.register('fto.list', 'fto.view', function(src, ctx)
    local list = traineesOf(ctx.dept)
    if not list then return false, 'server_error' end
    local cids = {}
    for i, m in ipairs(list) do cids[i] = m.cid end
    local stats = statsFor(cids)
    local out = {}
    for _, m in ipairs(list) do
        local s = stats[m.cid] or { evals = 0 }
        out[#out + 1] = {
            cid = m.cid, name = m.name, callsign = m.callsign, gradeName = m.gradeName, grade = m.grade, hiredAt = m.hiredAt,
            online = m.online, onduty = m.onduty, status = m.status,
            phase = s.last and s.last.phase or 1, evals = s.evals, average = s.average, last = s.last,
        }
    end
    table.sort(out, function(a, b) return (a.hiredAt or 0) > (b.hiredAt or 0) or ((a.hiredAt or 0) == (b.hiredAt or 0) and a.name < b.name) end)
    return true, { trainees = out, categories = Config.Fto.categories, phases = Config.Fto.phases or 4, division = traineeDivision() }
end, { rate = 400 })

Api.register('fto.get', 'fto.view', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    local m = Roster.member(cid, ctx.dept)
    if not m then return false, 'not_found' end
    local rows = Db.query('SELECT * FROM `vr_mdt_fto_evals` WHERE `trainee_cid` = ? ORDER BY `id` DESC LIMIT ?', { cid, MAX_EVALS })
    if not rows then return false, 'server_error' end
    local evals, sums, counts, total = {}, {}, {}, 0
    for i, r in ipairs(rows) do
        local e = shapeEval(r)
        evals[i] = e
        total = total + e.score
        for _, rt in ipairs(e.ratings) do
            if rt.value then
                sums[rt.category] = (sums[rt.category] or 0) + rt.value
                counts[rt.category] = (counts[rt.category] or 0) + 1
            end
        end
    end
    local averages = {}
    for _, cat in ipairs(Config.Fto.categories) do
        averages[#averages + 1] = { category = cat, value = counts[cat] and U.round(sums[cat] / counts[cat], 2) or nil }
    end
    return true, {
        trainee = {
            cid = m.cid, name = m.name, callsign = m.callsign, gradeName = m.gradeName, divisions = m.divisions, hiredAt = m.hiredAt,
            online = m.online, onduty = m.onduty, isTrainee = hasDivision(m.divisions, traineeDivision()), isSelf = m.cid == ctx.cid,
        },
        evals = evals,
        averages = averages,
        average = #evals > 0 and U.round(total / #evals, 2) or nil,
        phase = evals[1] and evals[1].phase or 1,
        categories = Config.Fto.categories,
        phases = Config.Fto.phases or 4,
    }
end, { rate = 150 })

Api.register('fto.evaluate', 'fto.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    if cid == ctx.cid then return false, 'cant_self' end
    local isTrainee, m = Fto.isTrainee(cid, ctx.dept)
    if not m then return false, 'not_found' end
    if not isTrainee then return false, 'not_trainee' end
    local phase = V.int(data.phase, 1, Config.Fto.phases or 4)
    local recommendation = V.enum(data.recommendation, RECOMMENDATIONS)
    local ratings, score = cleanRatings(data.ratings)
    if data.notes ~= nil and type(data.notes) ~= 'string' then return false, 'bad_request' end
    local notes = V.text(data.notes, 2000)
    if not phase or not recommendation or not ratings then return false, 'bad_request' end
    local id = Db.insert([[INSERT INTO `vr_mdt_fto_evals` (`trainee_cid`, `trainee_name`, `fto_cid`, `fto_name`, `at`, `phase`, `ratings`, `score`, `notes`, `recommendation`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { m.cid, m.name, ctx.cid, ctx.name, U.now(), phase, json.encode(ratings), U.round(score, 2), notes, recommendation })
    if not id then return false, 'save_failed' end
    Audit.log(ctx, 'fto.evaluate', m.cid, { name = m.name, phase = phase, score = U.round(score, 2), recommendation = recommendation })
    changed(ctx, m.cid)
    local row = Db.single('SELECT * FROM `vr_mdt_fto_evals` WHERE `id` = ?', { id })
    return true, row and shapeEval(row) or { id = id }
end, { rate = 1500 })

Api.register('fto.signoff', 'fto.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    if cid == ctx.cid then return false, 'cant_self' end
    local isTrainee, m = Fto.isTrainee(cid, ctx.dept)
    if not m then return false, 'not_found' end
    if not isTrainee then return false, 'not_trainee' end
    local list = {}
    for _, d in ipairs(m.divisions) do
        if d:lower() ~= traineeDivision():lower() then list[#list + 1] = d end
    end
    local grad = Config.Fto.graduateDivision
    local withGrad = list
    if grad and not hasDivision(list, grad) then
        withGrad = U.copy(list)
        withGrad[#withGrad + 1] = grad
    end
    local clean = Roster.cleanDivisions(ctx.dept, withGrad) or Roster.cleanDivisions(ctx.dept, list) or {}
    if not Roster.setDivisions(ctx, m.cid, clean) then return false, 'save_failed' end
    Audit.log(ctx, 'fto.signoff', m.cid, { name = m.name, from = m.divisions, to = clean })
    local p = Core.playerByCid(m.cid)
    if p then Core.notify(p.source, 'You completed field training.', 'success') end
    changed(ctx, m.cid)
    Roster.changed(ctx, m.cid)
    return true, { cid = m.cid, divisions = clean }
end, { rate = 1000 })
