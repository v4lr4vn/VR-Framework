Ia = {}

local DEPT = 'police'
local ACTIVE = { 'open', 'investigating' }
local OUTCOMES = { 'sustained', 'not_sustained', 'exonerated', 'unfounded', 'closed' }
local LABELS = {
    open = 'Open', investigating = 'Investigating', sustained = 'Sustained', not_sustained = 'Not sustained',
    exonerated = 'Exonerated', unfounded = 'Unfounded', closed = 'Closed',
}
local PAGE = 50

Db.schema('ia_files', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_ia_files` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `subject_cid` VARCHAR(64) NOT NULL,
        `subject_name` VARCHAR(64) NOT NULL,
        `complainant` TEXT DEFAULT NULL,
        `summary` MEDIUMTEXT NOT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'open',
        `assigned_cid` VARCHAR(64) DEFAULT NULL,
        `assigned_name` VARCHAR(64) DEFAULT NULL,
        `findings` MEDIUMTEXT DEFAULT NULL,
        `created_by_cid` VARCHAR(64) NOT NULL,
        `created_by_name` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        `closed_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `subject` (`subject_cid`),
        KEY `status_updated` (`status`, `updated_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('ia_notes', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_ia_notes` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `file_id` INT UNSIGNED NOT NULL,
        `author_cid` VARCHAR(64) DEFAULT NULL,
        `author_name` VARCHAR(64) DEFAULT NULL,
        `at` INT UNSIGNED NOT NULL,
        `text` TEXT NOT NULL,
        `system` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `file_id` (`file_id`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function isActive(status)
    return status == 'open' or status == 'investigating'
end

local function shapeFile(r)
    return {
        id = r.id,
        subjectCid = r.subject_cid,
        subjectName = r.subject_name,
        complainant = r.complainant,
        summary = r.summary,
        status = r.status,
        assignedCid = r.assigned_cid,
        assignedName = r.assigned_name,
        findings = r.findings,
        createdByCid = r.created_by_cid,
        createdByName = r.created_by_name,
        createdAt = tonumber(r.created_at),
        updatedAt = tonumber(r.updated_at),
        closedAt = tonumber(r.closed_at),
        notes = tonumber(r.notes),
    }
end

local function shapeNote(r)
    return {
        id = r.id,
        authorCid = r.author_cid,
        authorName = r.author_name,
        at = tonumber(r.at),
        text = r.text,
        system = r.system == true or tonumber(r.system) == 1,
    }
end

local function police(ctx)
    return ctx.dept == DEPT
end

local function visible(ctx, id)
    id = V.id(id)
    if not id then return nil end
    return Db.single('SELECT * FROM `vr_mdt_ia_files` WHERE `id` = ? AND `subject_cid` <> ? LIMIT 1', { id, ctx.cid })
end

local function changed(id, subject)
    Push.dept(DEPT, 'ia:changed', { id = id }, function(c) return c.cid ~= subject and Core.can(c, 'ia.view') end)
end

local function addNote(fileId, ctx, text, system)
    local id = Db.insert('INSERT INTO `vr_mdt_ia_notes` (`file_id`, `author_cid`, `author_name`, `at`, `text`, `system`) VALUES (?, ?, ?, ?, ?, ?)', {
        fileId, ctx and ctx.cid or nil, ctx and ctx.name or nil, U.now(), text, system and 1 or 0,
    })
    Db.update('UPDATE `vr_mdt_ia_files` SET `updated_at` = ? WHERE `id` = ?', { U.now(), fileId })
    return id
end

local function full(ctx, row)
    local file = shapeFile(row)
    local notes = Db.query('SELECT * FROM `vr_mdt_ia_notes` WHERE `file_id` = ? ORDER BY `id` LIMIT 300', { row.id }) or {}
    file.timeline = {}
    for i, n in ipairs(notes) do file.timeline[i] = shapeNote(n) end
    file.notes = #notes
    local m = Roster.member(row.subject_cid, DEPT)
    file.subject = m and { cid = m.cid, name = m.name, callsign = m.callsign, gradeName = m.gradeName, online = m.online, member = true }
        or { cid = row.subject_cid, name = row.subject_name, member = false }
    return file
end

local function canInvestigate(m)
    if not m then return false end
    local perms = Core.permsFor(DEPT, m.job, m.grade, m.isboss)
    return perms['ia.view'] == true
end

Api.register('ia.list', 'ia.view', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    local page = V.int(data.page, 1, 500) or 1
    local filter = V.enum(data.status, { 'active', 'resolved', 'open', 'investigating', 'sustained', 'not_sustained', 'exonerated', 'unfounded', 'closed' })
    if data.status ~= nil and data.status ~= '' and not filter then return false, 'bad_request' end
    local q = V.str(data.q, 48)
    local where, params = { '`subject_cid` <> ?' }, { ctx.cid }
    if filter == 'active' then
        where[#where + 1] = "`status` IN ('open', 'investigating')"
    elseif filter == 'resolved' then
        where[#where + 1] = "`status` NOT IN ('open', 'investigating')"
    elseif filter then
        where[#where + 1] = '`status` = ?'
        params[#params + 1] = filter
    end
    if q then
        local like = U.like(q)
        where[#where + 1] = '(`subject_name` LIKE ? OR `complainant` LIKE ? OR `assigned_name` LIKE ? OR CAST(`id` AS CHAR) = ?)'
        params[#params + 1] = like
        params[#params + 1] = like
        params[#params + 1] = like
        params[#params + 1] = q:gsub('^#', '')
    end
    params[#params + 1] = PAGE + 1
    params[#params + 1] = (page - 1) * PAGE
    local rows = Db.query(([[SELECT f.`id`, f.`subject_cid`, f.`subject_name`, LEFT(f.`complainant`, 120) AS `complainant`, LEFT(f.`summary`, 200) AS `summary`, f.`status`,
        f.`assigned_cid`, f.`assigned_name`, f.`created_by_cid`, f.`created_by_name`, f.`created_at`, f.`updated_at`, f.`closed_at`,
        (SELECT COUNT(*) FROM `vr_mdt_ia_notes` n WHERE n.`file_id` = f.`id` AND n.`system` = 0) AS `notes`
        FROM `vr_mdt_ia_files` f WHERE %s ORDER BY (f.`status` IN ('open', 'investigating')) DESC, f.`updated_at` DESC, f.`id` DESC LIMIT ? OFFSET ?]]):format(table.concat(where, ' AND ')), params)
    if not rows then return false, 'server_error' end
    local items = {}
    for i = 1, math.min(#rows, PAGE) do items[i] = shapeFile(rows[i]) end
    local counts = { active = 0, resolved = 0 }
    for _, r in ipairs(Db.query('SELECT `status`, COUNT(*) AS `n` FROM `vr_mdt_ia_files` WHERE `subject_cid` <> ? GROUP BY `status`', { ctx.cid }) or {}) do
        local n = tonumber(r.n) or 0
        counts[r.status] = n
        if isActive(r.status) then counts.active = counts.active + n else counts.resolved = counts.resolved + n end
    end
    return true, { items = items, page = page, more = #rows > PAGE, counts = counts }
end, { rate = 300 })

Api.register('ia.get', 'ia.view', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    local row = visible(ctx, data.id)
    if not row then return false, 'not_found' end
    return true, full(ctx, row)
end, { rate = 150 })

Api.register('ia.investigators', 'ia.manage', function(src, ctx)
    if not police(ctx) then return false, 'not_allowed' end
    local out = {}
    for _, m in ipairs(Roster.list(DEPT)) do
        if canInvestigate(m) then out[#out + 1] = { cid = m.cid, name = m.name, callsign = m.callsign, gradeName = m.gradeName } end
    end
    return true, out
end, { rate = 500 })

Api.register('ia.save', 'ia.manage', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    if data.complainant ~= nil and type(data.complainant) ~= 'string' then return false, 'bad_request' end
    local complainant = V.text(data.complainant, 400)
    local summary = V.text(data.summary, 8000, 3)
    local status = data.status ~= nil and V.enum(data.status, ACTIVE) or nil
    if not summary or (data.status ~= nil and not status) then return false, 'bad_request' end
    local now = U.now()
    if data.id ~= nil then
        local row = visible(ctx, data.id)
        if not row then return false, 'not_found' end
        local nextStatus = status or row.status
        local reopened = not isActive(row.status) and isActive(nextStatus)
        local closedAt = nil
        if not isActive(nextStatus) then closedAt = tonumber(row.closed_at) end
        local ok = Db.update('UPDATE `vr_mdt_ia_files` SET `complainant` = ?, `summary` = ?, `status` = ?, `closed_at` = ?, `updated_at` = ? WHERE `id` = ?', {
            complainant, summary, nextStatus, closedAt, now, row.id,
        })
        if ok == nil then return false, 'save_failed' end
        if nextStatus ~= row.status then
            addNote(row.id, ctx, reopened and ('Reopened as %s'):format(LABELS[nextStatus]) or ('Status set to %s'):format(LABELS[nextStatus]), true)
        end
        Audit.log(ctx, 'ia.edit', row.id, { subject = row.subject_name, status = nextStatus, from = row.status })
        changed(row.id, row.subject_cid)
        return true, full(ctx, visible(ctx, row.id))
    end
    local subjectCid = V.cid(data.subjectCid)
    if not subjectCid then return false, 'bad_request' end
    if subjectCid == ctx.cid then return false, 'cant_self' end
    local subject = Roster.member(subjectCid, DEPT)
    if not subject then return false, 'not_found' end
    local id = Db.insert([[INSERT INTO `vr_mdt_ia_files` (`subject_cid`, `subject_name`, `complainant`, `summary`, `status`, `created_by_cid`, `created_by_name`, `created_at`, `updated_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { subject.cid, subject.name, complainant, summary, status or 'open', ctx.cid, ctx.name, now, now })
    if not id then return false, 'save_failed' end
    addNote(id, ctx, 'File opened', true)
    Audit.log(ctx, 'ia.create', id, { subject = subject.name, subjectCid = subject.cid })
    changed(id, subject.cid)
    return true, full(ctx, visible(ctx, id))
end, { rate = 1000 })

Api.register('ia.note', 'ia.manage', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    local row = visible(ctx, data.id)
    if not row then return false, 'not_found' end
    local text = V.text(data.text, 2000)
    if not text then return false, 'bad_request' end
    local id = addNote(row.id, ctx, text, false)
    if not id then return false, 'save_failed' end
    Audit.log(ctx, 'ia.note', row.id, { subject = row.subject_name, length = #text })
    changed(row.id, row.subject_cid)
    return true, full(ctx, visible(ctx, row.id))
end, { rate = 600 })

Api.register('ia.assign', 'ia.manage', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    local row = visible(ctx, data.id)
    if not row then return false, 'not_found' end
    local unassign = data.cid == '' or data.cid == false
    local cid = not unassign and V.cid(data.cid) or nil
    if not unassign and not cid then return false, 'bad_request' end
    local m
    if cid then
        if cid == row.subject_cid then return false, 'cant_assign' end
        m = Roster.member(cid, DEPT)
        if not m then return false, 'not_found' end
        if not canInvestigate(m) then return false, 'cant_assign' end
    end
    if (m and m.cid or nil) == row.assigned_cid then return true, full(ctx, row) end
    local status = row.status
    if m and status == 'open' then status = 'investigating' end
    local ok = Db.update('UPDATE `vr_mdt_ia_files` SET `assigned_cid` = ?, `assigned_name` = ?, `status` = ?, `updated_at` = ? WHERE `id` = ?', {
        m and m.cid or nil, m and m.name or nil, status, U.now(), row.id,
    })
    if ok == nil then return false, 'save_failed' end
    addNote(row.id, ctx, m and ('Assigned to %s'):format(m.callsign and (m.callsign .. ' ' .. m.name) or m.name) or 'Unassigned', true)
    Audit.log(ctx, 'ia.assign', row.id, { subject = row.subject_name, to = m and m.name or nil, toCid = m and m.cid or nil })
    if m and m.cid ~= ctx.cid then
        local p = Core.playerByCid(m.cid)
        if p then Core.notify(p.source, ('You were assigned Internal Affairs file #%d.'):format(row.id), 'primary') end
    end
    changed(row.id, row.subject_cid)
    return true, full(ctx, visible(ctx, row.id))
end, { rate = 500 })

Api.register('ia.close', 'ia.manage', function(src, ctx, data)
    if not police(ctx) then return false, 'not_allowed' end
    local row = visible(ctx, data.id)
    if not row then return false, 'not_found' end
    local outcome = V.enum(data.outcome, OUTCOMES)
    local findings = V.text(data.findings, 8000, 3)
    if not outcome or not findings then return false, 'bad_request' end
    local now = U.now()
    local ok = Db.update('UPDATE `vr_mdt_ia_files` SET `status` = ?, `findings` = ?, `closed_at` = ?, `updated_at` = ? WHERE `id` = ?', { outcome, findings, now, now, row.id })
    if ok == nil then return false, 'save_failed' end
    addNote(row.id, ctx, ('Closed as %s'):format(LABELS[outcome]), true)
    Audit.log(ctx, 'ia.close', row.id, { subject = row.subject_name, outcome = outcome, from = row.status })
    changed(row.id, row.subject_cid)
    return true, full(ctx, visible(ctx, row.id))
end, { rate = 800 })
