Court = {}

local STATUSES = { 'filed', 'scheduled', 'in_session', 'verdict', 'closed', 'dismissed' }
local EDIT_STATUSES = { 'filed', 'scheduled', 'in_session', 'closed', 'dismissed' }
local LIST_FILTERS = { 'all', 'open', 'filed', 'scheduled', 'in_session', 'verdict', 'closed', 'dismissed' }
local VERDICTS = { 'guilty', 'not_guilty', 'dismissed', 'plea' }
local STATUS_LABEL = { filed = 'Filed', scheduled = 'Scheduled', in_session = 'In session', verdict = 'Verdict', closed = 'Closed', dismissed = 'Dismissed' }
local VERDICT_LABEL = { guilty = 'Guilty', not_guilty = 'Not guilty', dismissed = 'Dismissed', plea = 'Plea agreement' }
local PAGE = 50
local MAX_EVENTS = 200
local LIST_COLUMNS = '`id`, `number`, `title`, `status`, `defendant_cid`, `defendant_name`, `prosecutor_name`, `defense_name`, `judge_name`, `hearing_at`, `courtroom`, `charges`, `verdict`, `updated_at`'

local sequence = {}

Db.schema('court_cases', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_court_cases` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `number` VARCHAR(24) NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'filed',
        `defendant_cid` VARCHAR(64) DEFAULT NULL,
        `defendant_name` VARCHAR(64) NOT NULL,
        `prosecutor_cid` VARCHAR(64) DEFAULT NULL,
        `prosecutor_name` VARCHAR(64) DEFAULT NULL,
        `defense_cid` VARCHAR(64) DEFAULT NULL,
        `defense_name` VARCHAR(64) DEFAULT NULL,
        `judge_cid` VARCHAR(64) DEFAULT NULL,
        `judge_name` VARCHAR(64) DEFAULT NULL,
        `hearing_at` INT UNSIGNED DEFAULT NULL,
        `courtroom` VARCHAR(48) DEFAULT NULL,
        `charges` LONGTEXT DEFAULT NULL,
        `report_id` INT UNSIGNED DEFAULT NULL,
        `case_id` INT UNSIGNED DEFAULT NULL,
        `verdict` VARCHAR(16) DEFAULT NULL,
        `sentence` LONGTEXT DEFAULT NULL,
        `summary` MEDIUMTEXT DEFAULT NULL,
        `created_by_cid` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `number` (`number`),
        KEY `status` (`status`),
        KEY `hearing_at` (`hearing_at`),
        KEY `defendant_cid` (`defendant_cid`),
        KEY `updated_at` (`updated_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('court_events', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_court_events` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `case_id` INT UNSIGNED NOT NULL,
        `at` INT UNSIGNED NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `author_cid` VARCHAR(64) DEFAULT NULL,
        `author_name` VARCHAR(64) DEFAULT NULL,
        `text` TEXT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `case_at` (`case_id`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function inList(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

local function flag(v)
    if v == nil then return false end
    return V.bool(v)
end

local function optional(value, fn, ...)
    if value == nil or value == '' then return true, nil end
    local v = fn(value, ...)
    if v == nil then return false end
    return true, v
end

local function party(cid, name)
    if not cid and not name then return nil end
    return { cid = cid, name = name }
end

local function isFinal(row)
    return row.verdict ~= nil or row.status == 'closed' or row.status == 'dismissed'
end

local function isLocked(row)
    return row.status == 'closed' or row.status == 'dismissed'
end

local function roleIn(row, cid)
    if not cid then return nil end
    if row.judge_cid == cid then return 'judge' end
    if row.prosecutor_cid == cid then return 'prosecutor' end
    if row.defense_cid == cid then return 'defense' end
    return nil
end

local function canVerdict(ctx, row)
    if not Core.can(ctx, 'court.manage') or not inList(Config.Court.judgeJobs, ctx.job) then return false end
    if row.judge_cid and row.judge_cid == ctx.cid then return true end
    return ctx.isboss == true
end

local function canNote(ctx, row)
    return Core.can(ctx, 'court.manage') or roleIn(row, ctx.cid) ~= nil
end

local function toCase(r)
    return {
        id = r.id,
        number = r.number,
        title = r.title,
        status = r.status,
        defendant = party(r.defendant_cid, r.defendant_name),
        prosecutor = party(r.prosecutor_cid, r.prosecutor_name),
        defense = party(r.defense_cid, r.defense_name),
        judge = party(r.judge_cid, r.judge_name),
        hearingAt = r.hearing_at,
        courtroom = r.courtroom,
        charges = U.decode(r.charges, {}),
        reportId = r.report_id,
        caseId = r.case_id,
        verdict = r.verdict,
        sentence = U.decode(r.sentence, nil),
        summary = r.summary,
        createdBy = r.created_by_cid,
        createdAt = r.created_at,
        updatedAt = r.updated_at,
    }
end

local function toRow(r, cid)
    local charges = U.decode(r.charges, {})
    return {
        id = r.id,
        number = r.number,
        title = r.title,
        status = r.status,
        defendant = r.defendant_name,
        prosecutor = r.prosecutor_name,
        defense = r.defense_name,
        judge = r.judge_name,
        hearingAt = r.hearing_at,
        courtroom = r.courtroom,
        verdict = r.verdict,
        chargeCount = type(charges) == 'table' and #charges or 0,
        updatedAt = r.updated_at,
        mine = cid ~= nil and roleIn(r, cid) ~= nil or nil,
    }
end

local function loadRow(id)
    return Db.single('SELECT * FROM `vr_mdt_court_cases` WHERE `id` = ? LIMIT 1', { id })
end

local function addEvent(caseId, ctx, kind, text)
    return Db.insert('INSERT INTO `vr_mdt_court_events` (`case_id`, `at`, `kind`, `author_cid`, `author_name`, `text`) VALUES (?, ?, ?, ?, ?, ?)', {
        caseId, U.now(), kind, ctx and ctx.cid or nil, ctx and ctx.name or 'System', text,
    })
end

local function events(caseId)
    local rows = Db.query(('SELECT `id`, `at`, `kind`, `author_cid`, `author_name`, `text` FROM `vr_mdt_court_events` WHERE `case_id` = ? ORDER BY `at` DESC, `id` DESC LIMIT %d'):format(MAX_EVENTS), { caseId }) or {}
    local out = {}
    for i = #rows, 1, -1 do
        local e = rows[i]
        out[#out + 1] = { id = e.id, at = e.at, kind = e.kind, authorCid = e.author_cid, author = e.author_name, text = e.text }
    end
    return out
end

local function viewOf(ctx, row)
    local c = toCase(row)
    c.events = events(row.id)
    c.role = roleIn(row, ctx.cid)
    c.can = {
        edit = Core.can(ctx, 'court.manage') and not isLocked(row),
        schedule = Core.can(ctx, 'court.manage') and not isFinal(row),
        verdict = canVerdict(ctx, row) and not isFinal(row),
        note = canNote(ctx, row),
    }
    return c
end

local function push(row)
    Push.dept('doj', 'court:changed', { id = row.id, number = row.number, status = row.status }, function(c)
        return Core.can(c, 'court.view')
    end)
    TriggerEvent('vr-mdt:server:courtChanged', row.id, row.status)
end

local function prefixFor(year)
    return ('%s-%d-'):format(Config.Court.numberPrefix, year)
end

local function highestNumber(prefix)
    local like = prefix:gsub('[%%_\\]', '\\%0') .. '%'
    return tonumber(Db.scalar('SELECT MAX(CAST(SUBSTRING(`number`, ?) AS UNSIGNED)) FROM `vr_mdt_court_cases` WHERE `number` LIKE ?', { #prefix + 1, like })) or 0
end

local function nextNumber()
    local year = tonumber(os.date('%Y', U.now()))
    local prefix = prefixFor(year)
    if not sequence[year] then
        local top = highestNumber(prefix)
        sequence[year] = math.max(sequence[year] or 0, top)
    end
    sequence[year] = sequence[year] + 1
    return ('%s%04d'):format(prefix, sequence[year]), year
end

function Court.nextNumber()
    return nextNumber()
end

local function penalTitle(id)
    if not (Penal and Penal.get) then return nil end
    local ok, row = pcall(Penal.get, id)
    if not ok or type(row) ~= 'table' then return nil end
    return V.str(row.title or row.label or row.name, 96)
end

local function cleanCharges(list)
    if list == nil then return {} end
    if type(list) ~= 'table' then return nil end
    local out = {}
    for i = 1, math.min(#list, Config.Court.maxCharges) do
        local c = list[i]
        if type(c) == 'table' then
            local count = c.count == nil and 1 or V.int(c.count, 1, 99)
            local id = V.id(c.id)
            local title = id and penalTitle(id) or nil
            if not title then
                id = nil
                title = V.str(c.title, 96, 2)
            end
            if title and count then out[#out + 1] = { id = id, title = title, count = count } end
        end
    end
    return out
end

local function staffParty(cid, jobs)
    if cid == nil or cid == '' then return true, nil end
    cid = V.cid(cid)
    if not cid then return false, 'bad_request' end
    local p = People.get(cid)
    if not p then return false, 'unknown_person' end
    if not inList(jobs, p.job) then return false, 'wrong_role' end
    return true, { cid = cid, name = p.name }
end

local function defendantOf(data)
    if data.defendantCid ~= nil and data.defendantCid ~= '' then
        local cid = V.cid(data.defendantCid)
        if not cid then return false, 'bad_request' end
        local p = People.get(cid)
        if not p then return false, 'unknown_person' end
        return true, { cid = cid, name = p.name }
    end
    local name = V.str(data.defendantName, 64, 2)
    if not name then return false, 'bad_request' end
    return true, { name = name }
end

local function readFields(data)
    local title = V.str(data.title, 96, 3)
    if not title then return nil, 'bad_request' end
    local ok, defendant = defendantOf(data)
    if not ok then return nil, defendant end
    local okP, prosecutor = staffParty(data.prosecutorCid, Config.Court.prosecutorJobs)
    if not okP then return nil, prosecutor end
    local okD, defense = staffParty(data.defenseCid, Config.Court.defenseJobs)
    if not okD then return nil, defense end
    local okJ, judge = staffParty(data.judgeCid, Config.Court.judgeJobs)
    if not okJ then return nil, judge end
    local charges = cleanCharges(data.charges)
    if not charges then return nil, 'bad_request' end
    local okR, reportId = optional(data.reportId, V.id)
    local okC, caseId = optional(data.caseId, V.id)
    if not okR or not okC then return nil, 'bad_request' end
    local okS, summary = optional(data.summary, V.text, 6000)
    if not okS then return nil, 'bad_request' end
    return {
        title = title,
        defendant = defendant,
        prosecutor = prosecutor or {},
        defense = defense or {},
        judge = judge or {},
        charges = charges,
        reportId = reportId,
        caseId = caseId,
        summary = summary,
    }
end

local function insertCase(ctx, f)
    local now = U.now()
    for _ = 1, 3 do
        local number, year = nextNumber()
        local id = Db.insert([[INSERT INTO `vr_mdt_court_cases` (`number`, `title`, `status`, `defendant_cid`, `defendant_name`, `prosecutor_cid`, `prosecutor_name`,
            `defense_cid`, `defense_name`, `judge_cid`, `judge_name`, `charges`, `report_id`, `case_id`, `summary`, `created_by_cid`, `created_at`, `updated_at`)
            VALUES (?, ?, 'filed', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            number, f.title, f.defendant.cid, f.defendant.name, f.prosecutor.cid, f.prosecutor.name, f.defense.cid, f.defense.name,
            f.judge.cid, f.judge.name, json.encode(f.charges), f.reportId, f.caseId, f.summary, ctx.cid, now, now,
        })
        if id then return id, number end
        sequence[year] = nil
    end
    return nil
end

local function saveFinal(ctx, row, data)
    local status = row.status
    if data.status ~= nil and data.status ~= row.status then
        if data.status ~= 'closed' then return false, 'locked' end
        status = 'closed'
    end
    local summary = row.summary
    if data.summary ~= nil then
        local ok, s = optional(data.summary, V.text, 6000)
        if not ok then return false, 'bad_request' end
        summary = s
    end
    local done = Db.update('UPDATE `vr_mdt_court_cases` SET `status` = ?, `summary` = ?, `updated_at` = ? WHERE `id` = ?', { status, summary, U.now(), row.id })
    if done == nil then return false, 'save_failed' end
    if status ~= row.status then
        addEvent(row.id, ctx, 'status', ('Status changed from %s to %s'):format(STATUS_LABEL[row.status], STATUS_LABEL[status]))
    end
    Audit.log(ctx, 'court.edit', row.number, { status = status })
    local fresh = loadRow(row.id)
    push(fresh)
    return true, viewOf(ctx, fresh)
end

local function create(ctx, f)
    local id, number = insertCase(ctx, f)
    if not id then return false, 'save_failed' end
    addEvent(id, ctx, 'filed', ('Case filed by %s'):format(ctx.name))
    Audit.log(ctx, 'court.create', number, { title = f.title, defendant = f.defendant.name })
    local row = loadRow(id)
    push(row)
    return true, viewOf(ctx, row)
end

local function update(ctx, row, f, data)
    local status = row.status
    if data.status ~= nil and data.status ~= row.status then
        status = V.enum(data.status, EDIT_STATUSES)
        if not status then return false, 'bad_request' end
        if status == 'scheduled' and not row.hearing_at then return false, 'no_hearing' end
    end
    local done = Db.update([[UPDATE `vr_mdt_court_cases` SET `title` = ?, `status` = ?, `defendant_cid` = ?, `defendant_name` = ?, `prosecutor_cid` = ?, `prosecutor_name` = ?,
        `defense_cid` = ?, `defense_name` = ?, `judge_cid` = ?, `judge_name` = ?, `charges` = ?, `report_id` = ?, `case_id` = ?, `summary` = ?, `updated_at` = ? WHERE `id` = ?]], {
        f.title, status, f.defendant.cid, f.defendant.name, f.prosecutor.cid, f.prosecutor.name, f.defense.cid, f.defense.name,
        f.judge.cid, f.judge.name, json.encode(f.charges), f.reportId, f.caseId, f.summary, U.now(), row.id,
    })
    if done == nil then return false, 'save_failed' end
    if status ~= row.status then
        addEvent(row.id, ctx, 'status', ('Status changed from %s to %s'):format(STATUS_LABEL[row.status], STATUS_LABEL[status]))
    end
    Audit.log(ctx, 'court.edit', row.number, { title = f.title, status = status })
    local fresh = loadRow(row.id)
    push(fresh)
    return true, viewOf(ctx, fresh)
end

local function chargeSnapshot(list)
    local out = {}
    for _, c in ipairs(list or {}) do
        local penal = c.id and Penal and Penal.get and Penal.get(c.id) or nil
        out[#out + 1] = {
            id = c.id,
            title = c.title or (penal and penal.title) or 'Charge',
            class = penal and penal.class or nil,
            count = c.count or 1,
            fine = penal and penal.fine or 0,
            months = penal and penal.months or 0,
            points = penal and penal.points or 0,
        }
    end
    return out
end

local function execute(ctx, row, sentence)
    local result = { recorded = false, jailed = false, paid = 0, missing = {} }
    if not row.defendant_cid then
        result.reason = 'no_defendant'
        result.executed = false
        return result
    end
    local reason = ('Court case %s'):format(row.number)
    if sentence.months > 0 then
        if Prison and Prison.jail then
            local ok, res = pcall(Prison.jail, ctx, row.defendant_cid, sentence.months, reason, row.report_id)
            if not ok then print(('^1[vr-mdt] court jail failed: %s^0'):format(tostring(res))) end
            result.jailed = ok and res == true
        else
            result.missing[#result.missing + 1] = 'prison'
        end
    end
    if Sentencing and Sentencing.record then
        if sentence.fine > 0 and Sentencing.collect then
            local okc, got = pcall(Sentencing.collect, row.defendant_cid, sentence.fine, reason)
            result.paid = okc and tonumber(got) or 0
            if result.paid > 0 then
                Bridge.addSocietyMoney(Config.Fines.society, result.paid, 'court fine')
            end
        end
        local ok, res = pcall(Sentencing.record, {
            cid = row.defendant_cid,
            name = row.defendant_name,
            source = 'court',
            charges = chargeSnapshot(U.decode(row.charges, {})),
            fine = sentence.fine,
            paid = result.paid,
            months = sentence.months,
            reportId = row.report_id,
            jailed = result.jailed,
            officerCid = ctx.cid,
            officerName = ctx.name,
            reason = sentence.notes and ('%s. %s'):format(reason, sentence.notes):sub(1, 255) or reason,
        })
        if not ok then print(('^1[vr-mdt] court sentencing failed: %s^0'):format(tostring(res))) end
        result.recorded = ok and res ~= nil and res ~= false
    else
        result.missing[#result.missing + 1] = 'sentencing'
    end
    result.executed = #result.missing == 0 and result.recorded and (sentence.months == 0 or result.jailed)
    return result
end

local function sentenceText(verdict, s)
    local parts = { ('Verdict: %s.'):format(VERDICT_LABEL[verdict]) }
    if verdict == 'guilty' or verdict == 'plea' then
        local terms = {}
        if s.months > 0 then terms[#terms + 1] = s.months == 1 and '1 month' or ('%d months'):format(s.months) end
        if s.fine > 0 then terms[#terms + 1] = ('$%d fine'):format(s.fine) end
        parts[#parts + 1] = #terms > 0 and ('Sentence: %s.'):format(table.concat(terms, ', ')) or 'No sentence.'
        if s.apply then
            parts[#parts + 1] = s.executed and 'Sentence applied.' or 'Sentence recorded but not applied.'
        end
    end
    if s.notes then parts[#parts + 1] = s.notes end
    return table.concat(parts, ' ')
end

function Court.get(id)
    id = V.id(id)
    local row = id and loadRow(id)
    return row and toCase(row) or nil
end

function Court.forCitizen(cid, limit)
    cid = V.cid(cid)
    if not cid then return {} end
    limit = V.int(limit, 1, 50) or 10
    local rows = Db.query(('SELECT %s FROM `vr_mdt_court_cases` WHERE `defendant_cid` = ? ORDER BY `updated_at` DESC LIMIT ?'):format(LIST_COLUMNS), { cid, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = toRow(r) end
    return out
end

function Court.upcoming(days)
    local now = U.now()
    days = V.int(days, 1, 60) or Config.Court.calendarDays
    local rows = Db.query([[SELECT `id`, `number`, `title`, `status`, `defendant_name`, `judge_name`, `judge_cid`, `prosecutor_cid`, `defense_cid`, `hearing_at`, `courtroom`
        FROM `vr_mdt_court_cases` WHERE `hearing_at` IS NOT NULL AND `hearing_at` >= ? AND `hearing_at` <= ? AND `status` IN ('scheduled', 'in_session')
        ORDER BY `hearing_at` ASC LIMIT 50]], { now - 3600, now + days * 86400 })
    return rows
end

Api.register('court.list', 'court.view', function(src, ctx, data)
    local status = data.status == nil and 'all' or V.enum(data.status, LIST_FILTERS)
    local page = data.page == nil and 1 or V.int(data.page, 1, 1000)
    local okQ = data.q == nil or type(data.q) == 'string'
    local q = okQ and V.str(data.q, 48) or nil
    local mine = flag(data.mine)
    if not status or not page or not okQ or mine == nil then return false, 'bad_request' end
    local base, baseParams = {}, {}
    if mine then
        base[#base + 1] = '(`judge_cid` = ? OR `prosecutor_cid` = ? OR `defense_cid` = ? OR `created_by_cid` = ?)'
        for _ = 1, 4 do baseParams[#baseParams + 1] = ctx.cid end
    end
    if q then
        local like = U.like(q)
        base[#base + 1] = '(`number` LIKE ? OR `title` LIKE ? OR `defendant_name` LIKE ?)'
        baseParams[#baseParams + 1] = like
        baseParams[#baseParams + 1] = like
        baseParams[#baseParams + 1] = like
    end
    local where, params = { table.unpack(base) }, { table.unpack(baseParams) }
    if status == 'open' then
        where[#where + 1] = "`status` IN ('filed', 'scheduled', 'in_session')"
    elseif status ~= 'all' then
        where[#where + 1] = '`status` = ?'
        params[#params + 1] = status
    end
    local clause = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    params[#params + 1] = PAGE + 1
    params[#params + 1] = (page - 1) * PAGE
    local rows = Db.query(('SELECT %s, `judge_cid`, `prosecutor_cid`, `defense_cid` FROM `vr_mdt_court_cases`%s ORDER BY `updated_at` DESC, `id` DESC LIMIT ? OFFSET ?'):format(LIST_COLUMNS, clause), params)
    if not rows then return false, 'server_error' end
    local more = #rows > PAGE
    local out = {}
    for i = 1, math.min(#rows, PAGE) do out[#out + 1] = toRow(rows[i], ctx.cid) end
    local countClause = #base > 0 and (' WHERE ' .. table.concat(base, ' AND ')) or ''
    local countRows = Db.query(('SELECT `status`, COUNT(*) AS `n` FROM `vr_mdt_court_cases`%s GROUP BY `status`'):format(countClause), baseParams) or {}
    local counts = { all = 0, open = 0 }
    for _, s in ipairs(STATUSES) do counts[s] = 0 end
    for _, r in ipairs(countRows) do
        local n = tonumber(r.n) or 0
        if counts[r.status] then counts[r.status] = n end
        counts.all = counts.all + n
        if r.status == 'filed' or r.status == 'scheduled' or r.status == 'in_session' then counts.open = counts.open + n end
    end
    return true, { rows = out, page = page, more = more, counts = counts }
end, { rate = 300 })

Api.register('court.get', 'court.view', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = loadRow(id)
    if not row then return false, 'not_found' end
    return true, viewOf(ctx, row)
end, { rate = 150 })

Api.register('court.calendar', 'court.view', function(src, ctx)
    local rows = Court.upcoming(Config.Court.calendarDays)
    if not rows then return false, 'server_error' end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, number = r.number, title = r.title, status = r.status, defendant = r.defendant_name, judge = r.judge_name,
            hearingAt = r.hearing_at, courtroom = r.courtroom, mine = roleIn(r, ctx.cid) ~= nil,
        }
    end
    return true, { hearings = out, courtrooms = Config.Court.courtrooms, days = Config.Court.calendarDays }
end, { rate = 500 })

Api.register('court.save', 'court.manage', function(src, ctx, data)
    local okId, id = optional(data.id, V.id)
    if not okId then return false, 'bad_request' end
    local row
    if id then
        row = loadRow(id)
        if not row then return false, 'not_found' end
        if isLocked(row) then return false, 'locked' end
        if row.verdict then return saveFinal(ctx, row, data) end
    end
    local f, err = readFields(data)
    if not f then return false, err end
    if row then return update(ctx, row, f, data) end
    return create(ctx, f)
end, { rate = 1000 })

Api.register('court.schedule', 'court.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = loadRow(id)
    if not row then return false, 'not_found' end
    if isFinal(row) then return false, 'locked' end
    if data.clear == true then
        if not row.hearing_at then return true, viewOf(ctx, row) end
        local done = Db.update("UPDATE `vr_mdt_court_cases` SET `hearing_at` = NULL, `courtroom` = NULL, `status` = 'filed', `updated_at` = ? WHERE `id` = ?", { U.now(), id })
        if done == nil then return false, 'save_failed' end
        addEvent(id, ctx, 'scheduled', 'Hearing cancelled')
        Audit.log(ctx, 'court.unschedule', row.number)
        local fresh = loadRow(id)
        push(fresh)
        return true, viewOf(ctx, fresh)
    end
    local now = U.now()
    local at = V.int(data.hearingAt, now - 300, now + Config.Court.maxHearingDays * 86400)
    if not at then return false, 'bad_time' end
    local room
    if #Config.Court.courtrooms > 0 then
        room = V.enum(data.courtroom, Config.Court.courtrooms)
    else
        room = V.str(data.courtroom, 48)
    end
    if not room then return false, 'bad_request' end
    local done = Db.update("UPDATE `vr_mdt_court_cases` SET `hearing_at` = ?, `courtroom` = ?, `status` = 'scheduled', `updated_at` = ? WHERE `id` = ?", { at, room, now, id })
    if done == nil then return false, 'save_failed' end
    addEvent(id, ctx, 'scheduled', ('Hearing set for %s UTC in %s'):format(os.date('!%Y-%m-%d %H:%M', at), room))
    Audit.log(ctx, 'court.schedule', row.number, { at = at, courtroom = room })
    local fresh = loadRow(id)
    push(fresh)
    return true, viewOf(ctx, fresh)
end, { rate = 800 })

Api.register('court.note', 'court.view', function(src, ctx, data)
    local id = V.id(data.id)
    local text = V.text(data.text, 1000)
    if not id then return false, 'bad_request' end
    local row = loadRow(id)
    if not row then return false, 'not_found' end
    if not canNote(ctx, row) then return false, 'not_allowed' end
    if not text then return false, 'bad_request' end
    if not addEvent(id, ctx, 'note', text) then return false, 'save_failed' end
    Db.update('UPDATE `vr_mdt_court_cases` SET `updated_at` = ? WHERE `id` = ?', { U.now(), id })
    Audit.log(ctx, 'court.note', row.number)
    push(row)
    return true, viewOf(ctx, loadRow(id))
end, { rate = 800 })

Api.register('court.verdict', 'court.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = loadRow(id)
    if not row then return false, 'not_found' end
    if not canVerdict(ctx, row) then return false, 'not_judge' end
    if isFinal(row) then return false, 'locked' end
    local verdict = V.enum(data.verdict, VERDICTS)
    local okF, fine = optional(data.fine, V.int, 0, Config.Court.maxFine)
    local okM, months = optional(data.months, V.int, 0, Config.Court.maxMonths)
    local okN, notes = optional(data.notes, V.text, 1000)
    local apply = flag(data.apply)
    if not verdict or not okF or not okM or not okN or apply == nil then return false, 'bad_request' end
    local convicted = verdict == 'guilty' or verdict == 'plea'
    local sentence = {
        fine = convicted and (fine or 0) or 0,
        months = convicted and (months or 0) or 0,
        notes = notes,
        apply = convicted and apply,
        executed = false,
        recorded = false,
        jailed = false,
    }
    local execution
    if sentence.apply then
        execution = execute(ctx, row, sentence)
        sentence.executed = execution.executed
        sentence.recorded = execution.recorded
        sentence.jailed = execution.jailed
        sentence.missing = #execution.missing > 0 and execution.missing or nil
        sentence.reason = execution.reason
    end
    local status = verdict == 'dismissed' and 'dismissed' or 'verdict'
    local done = Db.update('UPDATE `vr_mdt_court_cases` SET `verdict` = ?, `sentence` = ?, `status` = ?, `updated_at` = ? WHERE `id` = ?', {
        verdict, json.encode(sentence), status, U.now(), id,
    })
    if done == nil then return false, 'save_failed' end
    addEvent(id, ctx, 'verdict', sentenceText(verdict, sentence))
    Audit.log(ctx, 'court.verdict', row.number, { verdict = verdict, fine = sentence.fine, months = sentence.months, apply = sentence.apply, executed = sentence.executed })
    local fresh = loadRow(id)
    push(fresh)
    local view = viewOf(ctx, fresh)
    view.executed = sentence.executed
    view.missing = sentence.missing
    return true, view
end, { rate = 1000 })
