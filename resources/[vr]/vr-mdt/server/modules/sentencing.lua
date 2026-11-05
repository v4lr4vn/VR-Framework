Sentencing = {}

local SOURCES = { report = true, fine = true, court = true }
local CLASSES = { infraction = true, misdemeanor = true, felony = true }
local READ_PERMS = { 'sentencing.apply', 'records.view', 'reports.view', 'court.view' }

Db.schema('sentences', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_sentences` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `report_id` INT UNSIGNED DEFAULT NULL,
        `cid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `charges` LONGTEXT NOT NULL,
        `fine` INT UNSIGNED NOT NULL DEFAULT 0,
        `paid` INT UNSIGNED NOT NULL DEFAULT 0,
        `months` INT UNSIGNED NOT NULL DEFAULT 0,
        `points` INT UNSIGNED NOT NULL DEFAULT 0,
        `plea` TINYINT(1) NOT NULL DEFAULT 0,
        `jailed` TINYINT(1) NOT NULL DEFAULT 0,
        `officer_cid` VARCHAR(64) DEFAULT NULL,
        `officer_name` VARCHAR(64) DEFAULT NULL,
        `reason` VARCHAR(255) DEFAULT NULL,
        `at` INT UNSIGNED NOT NULL,
        `source` VARCHAR(8) NOT NULL DEFAULT 'report',
        PRIMARY KEY (`id`),
        KEY `cid` (`cid`),
        KEY `report_id` (`report_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function flag(v)
    return v == true or v == 1 or v == '1'
end

local function int(v)
    v = tonumber(v)
    return v and math.tointeger(math.floor(v)) or 0
end

local function dollars(n)
    local s = tostring(int(n))
    while true do
        local k
        s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. s
end

local function marks(n)
    return ('?,'):rep(n):sub(1, -2)
end

function Sentencing.fromRow(r)
    return {
        id = int(r.id),
        reportId = r.report_id and int(r.report_id) or nil,
        cid = r.cid,
        name = r.name,
        charges = U.decode(r.charges, {}),
        fine = int(r.fine),
        paid = int(r.paid),
        months = int(r.months),
        points = int(r.points),
        plea = flag(r.plea),
        jailed = flag(r.jailed),
        officer = r.officer_name,
        officerCid = r.officer_cid,
        reason = r.reason,
        at = int(r.at),
        source = r.source,
    }
end

function Sentencing.byIds(ids)
    local out = {}
    if type(ids) ~= 'table' or #ids == 0 then return out end
    local rows = Db.query(('SELECT * FROM `vr_mdt_sentences` WHERE `id` IN (%s)'):format(marks(#ids)), ids) or {}
    for _, r in ipairs(rows) do
        local s = Sentencing.fromRow(r)
        out[s.id] = s
    end
    return out
end

function Sentencing.forCitizen(cid, limit)
    cid = V.cid(cid)
    if not cid then return {} end
    limit = V.int(limit, 1, 200) or 100
    local rows = Db.query('SELECT * FROM `vr_mdt_sentences` WHERE `cid` = ? ORDER BY `id` DESC LIMIT ?', { cid, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = Sentencing.fromRow(r) end
    return out
end

local function snapshot(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i = 1, math.min(#list, 60) do
        local e = list[i]
        if type(e) == 'table' then
            out[#out + 1] = {
                id = V.id(e.id),
                title = V.str(e.title, 96) or 'Charge',
                class = CLASSES[e.class] and e.class or 'misdemeanor',
                count = V.int(e.count, 1, 99) or 1,
                fine = V.int(e.fine, 0, 100000000) or 0,
                months = V.int(e.months, 0, 100000) or 0,
                points = V.int(e.points, 0, 1000) or 0,
            }
        end
    end
    return out
end

function Sentencing.record(s)
    if type(s) ~= 'table' then return nil, 'bad_request' end
    local cid = V.cid(s.cid)
    if not cid then return nil, 'bad_request' end
    local charges = snapshot(s.charges)
    local fine = V.int(s.fine or 0, 0, 100000000)
    local paid = V.int(s.paid or 0, 0, 100000000)
    local months = V.int(s.months or 0, 0, 100000)
    local points = V.int(s.points or 0, 0, 1000)
    if not fine or not paid or not months or not points or paid > fine then return nil, 'bad_request' end
    local name = V.str(s.name, 64) or Core.nameOf(cid) or 'Unknown'
    local row = {
        reportId = V.id(s.reportId),
        cid = cid,
        name = name,
        charges = charges,
        fine = fine,
        paid = paid,
        months = months,
        points = points,
        plea = s.plea == true,
        jailed = s.jailed == true,
        officerCid = V.cid(s.officerCid),
        officerName = V.str(s.officerName, 64),
        reason = V.str(s.reason, 255),
        at = U.now(),
        source = SOURCES[s.source] and s.source or 'report',
    }
    local id = Db.insert([[INSERT INTO `vr_mdt_sentences` (`report_id`, `cid`, `name`, `charges`, `fine`, `paid`, `months`, `points`, `plea`, `jailed`,
        `officer_cid`, `officer_name`, `reason`, `at`, `source`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        row.reportId, cid, name, json.encode(charges), fine, paid, months, points, row.plea and 1 or 0, row.jailed and 1 or 0,
        row.officerCid, row.officerName, row.reason, row.at, row.source,
    })
    if not id then return nil, 'save_failed' end
    row.id = id
    TriggerEvent('vr-mdt:server:sentenced', U.copy(row))
    return id, row
end

function Sentencing.bounds(totals, plea)
    local rules = Config.Sentencing
    local factor = plea and (1 - rules.pleaReduction) or 1
    local maxFine = int(totals.fine * factor + 0.5)
    local maxMonths = int(totals.months * factor + 0.5)
    return {
        fine = maxFine,
        months = maxMonths,
        minFine = int(math.ceil(maxFine * (1 - rules.maxDiscretion) - 1e-9)),
        minMonths = int(math.ceil(maxMonths * (1 - rules.maxDiscretion) - 1e-9)),
    }
end

local function personFor(data)
    local reportId, personId = V.id(data.reportId), V.id(data.personId)
    if not reportId or not personId then return nil, 'bad_request' end
    local p = Db.single([[SELECT p.*, r.title AS report_title FROM `vr_mdt_report_people` p
        JOIN `vr_mdt_reports` r ON r.id = p.report_id WHERE p.id = ? AND p.report_id = ?]], { personId, reportId })
    if not p then return nil, 'not_found' end
    if p.role ~= 'suspect' then return nil, 'not_suspect' end
    if not V.cid(p.cid) then return nil, 'no_cid' end
    return p
end

local function quote(p, plea)
    local totals = Penal.totals(U.decode(p.charges, {}))
    if #totals.items == 0 then return nil, 'no_charges' end
    local b = Sentencing.bounds(totals, plea)
    return {
        reportId = int(p.report_id),
        personId = int(p.id),
        cid = p.cid,
        name = p.name,
        charges = totals.items,
        total = { fine = totals.fine, months = totals.months, points = totals.points, class = totals.class },
        plea = plea,
        max = { fine = b.fine, months = b.months },
        min = { fine = b.minFine, months = b.minMonths },
        points = totals.points,
        rules = { pleaReduction = Config.Sentencing.pleaReduction, maxDiscretion = Config.Sentencing.maxDiscretion },
        sentenced = flag(p.sentenced),
    }
end
Sentencing.quote = quote

function Sentencing.collect(cid, amount, reason)
    if amount <= 0 then return 0 end
    if not Bridge.chars.removeBank then return 0 end
    return tonumber(Bridge.chars.removeBank(cid, amount, Config.Sentencing.partialPayment == true, reason)) or 0
end

local function addSociety(amount)
    if amount <= 0 then return end
    if not Bridge.addSocietyMoney(Config.Fines.society, amount, 'mdt fine') then
        print('^3[vr-mdt] society payment was not recorded (no banking resource)^0')
    end
end

local function chargeSummary(items)
    local parts = {}
    for _, e in ipairs(items) do
        parts[#parts + 1] = e.count > 1 and ('%s x%d'):format(e.title, e.count) or e.title
    end
    return table.concat(parts, ', ')
end

local function jail(ctx, cid, months, reason, reportId)
    if months <= 0 then return false, nil end
    if not (Prison and Prison.jail) then return false, 'prison_unavailable' end
    local ok, res, err = pcall(Prison.jail, ctx, cid, months, reason, reportId)
    if not ok then
        print(('^1[vr-mdt] Prison.jail failed: %s^0'):format(tostring(res)))
        return false, 'jail_failed'
    end
    if res ~= true then return false, 'jail_failed', err end
    return true, nil
end

local function notifyTarget(cid, fine, paid, months)
    local player = Core.playerByCid(cid)
    if not player then return end
    local parts = {}
    if fine > 0 then parts[#parts + 1] = ('a %s fine'):format(dollars(fine)) end
    if months > 0 then parts[#parts + 1] = months == 1 and '1 month in prison' or ('%d months in prison'):format(months) end
    local msg = ('You have been sentenced to %s.'):format(#parts > 0 and table.concat(parts, ' and ') or 'no penalty')
    if paid < fine then msg = ('%s %s is unpaid.'):format(msg, dollars(fine - paid)) end
    Core.notify(player.source, msg, 'error')
end

local function execute(ctx, p, q, fine, months, plea)
    local cid = p.cid
    local reportId = int(p.report_id)
    local reason = ('Report #%d: %s'):format(reportId, chargeSummary(q.charges)):sub(1, 255)
    local paid = Sentencing.collect(cid, fine, reason)
    addSociety(paid)
    local jailed, warning = jail(ctx, cid, months, reason, reportId)
    local id, row = Sentencing.record({
        reportId = reportId,
        cid = cid,
        name = p.name,
        charges = q.charges,
        fine = fine,
        paid = paid,
        months = months,
        points = q.points,
        plea = plea,
        jailed = jailed,
        officerCid = ctx.cid,
        officerName = ctx.callsign and ('%s %s'):format(ctx.callsign, ctx.name) or ctx.name,
        reason = reason,
        source = 'report',
    })
    if not id then
        print(('^1[vr-mdt] sentence for %s on report %d was applied but could not be recorded^0'):format(cid, reportId))
        return nil, 'save_failed'
    end
    Db.update('UPDATE `vr_mdt_report_people` SET `sentence_id` = ? WHERE `id` = ?', { id, int(p.id) })
    notifyTarget(cid, fine, paid, months)
    local warnings = {}
    if warning then warnings[#warnings + 1] = warning end
    Audit.log(ctx, 'sentencing.apply', cid, {
        report = reportId, person = int(p.id), sentence = id, fine = fine, paid = paid, months = months,
        points = q.points, plea = plea, warnings = #warnings > 0 and warnings or nil,
    })
    return {
        sentence = Sentencing.fromRow({
            id = id, report_id = reportId, cid = cid, name = row.name, charges = json.encode(row.charges), fine = fine, paid = paid,
            months = months, points = q.points, plea = plea, jailed = jailed, officer_cid = row.officerCid, officer_name = row.officerName,
            reason = reason, at = row.at, source = 'report',
        }),
        warnings = warnings,
        unpaid = fine - paid,
    }
end

Api.register('sentencing.preview', 'sentencing.apply', function(src, ctx, data)
    if data.plea ~= nil and V.bool(data.plea) == nil then return false, 'bad_request' end
    local p, err = personFor(data)
    if not p then return false, err end
    local q, qerr = quote(p, data.plea == true)
    if not q then return false, qerr end
    return true, q
end, { rate = 100 })

Api.register('sentencing.apply', 'sentencing.apply', function(src, ctx, data)
    if data.plea ~= nil and V.bool(data.plea) == nil then return false, 'bad_request' end
    local plea = data.plea == true
    local p, err = personFor(data)
    if not p then return false, err end
    if flag(p.sentenced) then return false, 'already_sentenced' end
    local q, qerr = quote(p, plea)
    if not q then return false, qerr end
    local fine = data.fine == nil and q.max.fine or V.int(data.fine, 0, 100000000)
    local months = data.months == nil and q.max.months or V.int(data.months, 0, 100000)
    if not fine or not months then return false, 'bad_request' end
    if fine > q.max.fine or months > q.max.months then return false, 'above_max' end
    if fine < q.min.fine or months < q.min.months then return false, 'below_min' end
    local claimed = Db.update('UPDATE `vr_mdt_report_people` SET `sentenced` = 1 WHERE `id` = ? AND `sentenced` = 0', { int(p.id) })
    if not claimed or claimed < 1 then return false, 'already_sentenced' end
    local ok, result, rerr = pcall(execute, ctx, p, q, fine, months, plea)
    if not ok then
        print(('^1[vr-mdt] sentencing.apply: %s^0'):format(tostring(result)))
        return false, 'server_error'
    end
    if not result then return false, rerr end
    Reports.changed(int(p.report_id))
    return true, result
end, { rate = 1500 })

-- Applies a sentence to a person row that is already on a report (used when an officer books someone at the station).
-- Returns true and the result, or false and an error code.
function Sentencing.applyPerson(ctx, p, plea, fine, months)
    plea = plea == true
    local q, qerr = quote(p, plea)
    if not q then return false, nil, qerr end
    local claimed = Db.update('UPDATE `vr_mdt_report_people` SET `sentenced` = 1 WHERE `id` = ? AND `sentenced` = 0', { int(p.id) })
    if not claimed or claimed < 1 then return false, nil, 'already_sentenced' end
    local ok, result, rerr = pcall(execute, ctx, p, q, fine, months, plea)
    if not ok then
        print(('^1[vr-mdt] booking sentence: %s^0'):format(tostring(result)))
        return false, nil, 'server_error'
    end
    if not result then return false, nil, rerr end
    Reports.changed(int(p.report_id))
    return true, result
end

Api.register('sentencing.list', READ_PERMS, function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    return true, Sentencing.forCitizen(cid, V.int(data.limit, 1, 100) or 50)
end, { rate = 250 })

Core.exportAs('LogFine', function(data)
    if type(data) ~= 'table' then return false end
    local amount = V.int(data.amount, 1, Config.Fines.maxAmount)
    if not amount then return false end
    local officer = Core.player(tonumber(data.officer) or -1)
    local target = Core.player(tonumber(data.target) or -1)
    if not officer or not target then return false end
    if Core.deptOf(officer.job) ~= 'police' then return false end
    local reason = V.str(data.reason, 200) or 'Fine'
    local callsign = Core.callsign(officer.metadata)
    local officerName = officer.name
    local actor = { cid = officer.cid, name = officerName, dept = 'police' }
    local entry = {
        cid = target.cid,
        name = target.name,
        charges = { { title = reason, class = 'infraction', count = 1, fine = amount } },
        fine = amount,
        paid = amount,
        officerCid = officer.cid,
        officerName = callsign and ('%s %s'):format(callsign, officerName) or officerName,
        reason = reason,
        source = 'fine',
    }
    CreateThread(function()
        local id = Sentencing.record(entry)
        Audit.log(actor, 'sentencing.fine', entry.cid, { amount = amount, reason = reason, sentence = id })
    end)
    return true
end)
