Cases = {}

local STATUSES = { open = true, closed = true, cold = true }
local ROLES = { suspect = true, victim = true, witness = true, poi = true }

Db.schema('cases', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_cases` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `title` VARCHAR(96) NOT NULL,
        `status` VARCHAR(8) NOT NULL DEFAULT 'open',
        `summary` MEDIUMTEXT NOT NULL,
        `lead_cid` VARCHAR(64) DEFAULT NULL,
        `lead_name` VARCHAR(64) DEFAULT NULL,
        `created_by` VARCHAR(64) NOT NULL,
        `created_by_name` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('case_people', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_case_people` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `case_id` INT UNSIGNED NOT NULL,
        `cid` VARCHAR(64) DEFAULT NULL,
        `name` VARCHAR(64) NOT NULL,
        `role` VARCHAR(16) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `case_id` (`case_id`),
        KEY `cid` (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('case_officers', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_case_officers` (
        `case_id` INT UNSIGNED NOT NULL,
        `cid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `callsign` VARCHAR(24) DEFAULT NULL,
        PRIMARY KEY (`case_id`, `cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function int(v)
    v = tonumber(v)
    return v and math.tointeger(math.floor(v)) or nil
end

local function optional(v, fn, ...)
    if v == nil or v == '' then return nil, true end
    local x = fn(v, ...)
    return x, x ~= nil
end

local function header(r)
    return {
        id = int(r.id),
        title = r.title,
        status = r.status,
        lead = r.lead_cid and { cid = r.lead_cid, name = r.lead_name } or nil,
        createdBy = { cid = r.created_by, name = r.created_by_name },
        createdAt = int(r.created_at),
        updatedAt = int(r.updated_at),
        reports = int(r.reports),
        evidence = int(r.evidence),
    }
end

function Cases.exists(id)
    return Db.scalar('SELECT 1 FROM `vr_mdt_cases` WHERE `id` = ?', { id }) ~= nil
end

function Cases.changed(id)
    Push.where(function(c) return Core.can(c, 'cases.view') end, 'cases:changed', { id = id })
end

function Cases.load(id, ctx)
    local r = Db.single('SELECT * FROM `vr_mdt_cases` WHERE `id` = ?', { id })
    if not r then return nil end
    local out = header(r)
    out.summary = r.summary or ''
    out.people = {}
    for _, p in ipairs(Db.query('SELECT `id`, `cid`, `name`, `role` FROM `vr_mdt_case_people` WHERE `case_id` = ? ORDER BY `id`', { id }) or {}) do
        out.people[#out.people + 1] = { id = int(p.id), cid = p.cid, name = p.name, role = p.role }
    end
    out.officers = Db.query('SELECT `cid`, `name`, `callsign` FROM `vr_mdt_case_officers` WHERE `case_id` = ? ORDER BY `name`', { id }) or {}
    out.reports = {}
    for _, rep in ipairs(Db.query([[SELECT `id`, `title`, `type`, `author_name`, `author_callsign`, `created_at`, `locked` FROM `vr_mdt_reports`
        WHERE `case_id` = ? ORDER BY `id` DESC LIMIT 100]], { id }) or {}) do
        out.reports[#out.reports + 1] = {
            id = int(rep.id), title = rep.title, type = rep.type, createdAt = int(rep.created_at),
            author = { name = rep.author_name, callsign = rep.author_callsign },
            locked = rep.locked == true or tonumber(rep.locked) == 1,
        }
    end
    out.evidence = Evidence.list({ caseId = id })
    if ctx then
        out.can = {
            manage = Core.can(ctx, 'cases.manage'),
            evidence = Core.can(ctx, 'evidence.manage'),
            reports = Core.can(ctx, { 'reports.create', 'reports.view' }),
        }
    end
    return out
end

local function cleanPeople(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Cases.maxPeople then return nil end
    local out = {}
    for i = 1, #list do
        local p = list[i]
        if type(p) ~= 'table' then return nil end
        local cid, cidOk = optional(p.cid, V.cid)
        local role = V.enum(p.role, ROLES)
        local name = V.str(p.name, 64, 2)
        if not cidOk or not role or (not cid and not name) then return nil end
        out[#out + 1] = { cid = cid, role = role, name = name }
    end
    return out
end

local function cleanOfficers(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Cases.maxOfficers then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local cid = V.cid(type(list[i]) == 'table' and list[i].cid or list[i])
        if not cid then return nil end
        if not seen[cid] then
            seen[cid] = true
            out[#out + 1] = cid
        end
    end
    return out
end

local function cleanCase(data)
    local c = {
        title = V.str(data.title, 96, 3),
        summary = data.summary == nil and '' or V.text(data.summary, Config.Reports.maxBody, 0),
        people = cleanPeople(data.people),
        officers = cleanOfficers(data.officers),
    }
    local ok1, ok2, ok3
    c.id, ok1 = optional(data.id, V.id)
    c.status, ok2 = optional(data.status, V.enum, STATUSES)
    c.leadCid, ok3 = optional(data.leadCid, V.cid)
    if not c.title or not c.summary or not c.people or not c.officers or not ok1 or not ok2 or not ok3 then return nil end
    return c
end

local function resolve(c)
    local cids = {}
    for _, p in ipairs(c.people) do if p.cid then cids[#cids + 1] = p.cid end end
    for _, cid in ipairs(c.officers) do cids[#cids + 1] = cid end
    if c.leadCid then cids[#cids + 1] = c.leadCid end
    local found = Reports.lookup(cids)
    for _, p in ipairs(c.people) do
        if p.cid then
            if not found[p.cid] then return nil, 'unknown_person' end
            p.name = found[p.cid].name
        end
    end
    local officers, seen = {}, {}
    for _, cid in ipairs(c.officers) do
        local who = found[cid]
        if not who then return nil, 'unknown_person' end
        if not who.police then return nil, 'not_officer' end
        officers[#officers + 1] = { cid = cid, name = who.name, callsign = who.callsign }
    end
    c.officers = officers
    if c.leadCid then
        local who = found[c.leadCid]
        if not who then return nil, 'unknown_person' end
        if not who.police then return nil, 'not_officer' end
        c.leadName = who.name
    end
    local people = {}
    for _, p in ipairs(c.people) do
        local key = (p.cid or p.name:lower()) .. ':' .. p.role
        if not seen[key] then
            seen[key] = true
            people[#people + 1] = p
        end
    end
    c.people = people
    return c
end

Api.register('cases.list', 'cases.view', function(src, ctx, data)
    local size = Config.Cases.pageSize
    local page = V.int(data.page or 1, 1, 10000)
    local q, qOk = optional(data.q, V.str, 64)
    local status, statusOk = optional(data.status, V.enum, STATUSES)
    if not page or not qOk or not statusOk then return false, 'bad_request' end
    local where, params = { '1 = 1' }, {}
    if status then
        where[#where + 1] = 'c.`status` = ?'
        params[#params + 1] = status
    end
    if q then
        local like = U.like(q)
        local num = q:match('^#?(%d+)$')
        where[#where + 1] = '(c.`title` LIKE ? OR c.`lead_name` LIKE ? OR EXISTS (SELECT 1 FROM `vr_mdt_case_people` p WHERE p.case_id = c.id AND p.name LIKE ?)'
            .. (num and ' OR c.`id` = ?' or '') .. ')'
        for _ = 1, 3 do params[#params + 1] = like end
        if num then params[#params + 1] = tonumber(num) end
    end
    local sqlWhere = table.concat(where, ' AND ')
    local total = int(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_cases` c WHERE ' .. sqlWhere, params))
    if total == nil then return false, 'server_error' end
    local listParams = U.copy(params)
    listParams[#listParams + 1] = size
    listParams[#listParams + 1] = (page - 1) * size
    local rows = Db.query([[SELECT c.*, (SELECT COUNT(*) FROM `vr_mdt_reports` r WHERE r.case_id = c.id) AS reports,
        (SELECT COUNT(*) FROM `vr_mdt_evidence` e WHERE e.case_id = c.id) AS evidence
        FROM `vr_mdt_cases` c WHERE ]] .. sqlWhere .. ' ORDER BY c.`updated_at` DESC, c.`id` DESC LIMIT ? OFFSET ?', listParams)
    if not rows then return false, 'server_error' end
    local items = {}
    for _, r in ipairs(rows) do items[#items + 1] = header(r) end
    return true, { items = items, total = total, page = page, pages = math.max(1, math.ceil(total / size)), pageSize = size }
end, { rate = 200 })

Api.register('cases.get', 'cases.view', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local c = Cases.load(id, ctx)
    if not c then return false, 'not_found' end
    return true, c
end, { rate = 100 })

Api.register('cases.save', 'cases.manage', function(src, ctx, data)
    local c = cleanCase(data)
    if not c then return false, 'bad_request' end
    if c.id and not Cases.exists(c.id) then return false, 'not_found' end
    if not c.id and not c.leadCid and ctx.dept == 'police' then c.leadCid = ctx.cid end
    local resolved, err = resolve(c)
    if not resolved then return false, err end
    local now = U.now()
    local id = c.id
    if id then
        local n = Db.update([[UPDATE `vr_mdt_cases` SET `title` = ?, `summary` = ?, `status` = COALESCE(?, `status`), `lead_cid` = ?, `lead_name` = ?, `updated_at` = ?
            WHERE `id` = ?]], { c.title, c.summary, c.status, c.leadCid, c.leadName, now, id })
        if n == nil then return false, 'save_failed' end
    else
        id = Db.insert([[INSERT INTO `vr_mdt_cases` (`title`, `status`, `summary`, `lead_cid`, `lead_name`, `created_by`, `created_by_name`, `created_at`, `updated_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { c.title, c.status or 'open', c.summary, c.leadCid, c.leadName, ctx.cid, ctx.name, now, now })
        if not id then return false, 'save_failed' end
    end
    Db.update('DELETE FROM `vr_mdt_case_people` WHERE `case_id` = ?', { id })
    for _, p in ipairs(c.people) do
        Db.insert('INSERT INTO `vr_mdt_case_people` (`case_id`, `cid`, `name`, `role`) VALUES (?, ?, ?, ?)', { id, p.cid, p.name, p.role })
    end
    Db.update('DELETE FROM `vr_mdt_case_officers` WHERE `case_id` = ?', { id })
    for _, o in ipairs(c.officers) do
        Db.insert('INSERT INTO `vr_mdt_case_officers` (`case_id`, `cid`, `name`, `callsign`) VALUES (?, ?, ?, ?)', { id, o.cid, o.name, o.callsign })
    end
    Audit.log(ctx, c.id and 'cases.edit' or 'cases.create', id, { title = c.title })
    Cases.changed(id)
    return true, Cases.load(id, ctx)
end, { rate = 1000 })

Api.register('cases.link', 'cases.manage', function(src, ctx, data)
    local caseId, reportId = V.id(data.caseId), V.id(data.reportId)
    if not caseId or not reportId then return false, 'bad_request' end
    if not Cases.exists(caseId) then return false, 'not_found' end
    local rep = Db.single('SELECT `id`, `case_id` FROM `vr_mdt_reports` WHERE `id` = ?', { reportId })
    if not rep then return false, 'not_found' end
    if int(rep.case_id) ~= caseId then
        if Db.update('UPDATE `vr_mdt_reports` SET `case_id` = ? WHERE `id` = ?', { caseId, reportId }) == nil then return false, 'save_failed' end
        Db.update('UPDATE `vr_mdt_cases` SET `updated_at` = ? WHERE `id` = ?', { U.now(), caseId })
        Audit.log(ctx, 'cases.link', caseId, { report = reportId, from = int(rep.case_id) })
        Cases.changed(caseId)
        if int(rep.case_id) then Cases.changed(int(rep.case_id)) end
        Reports.changed(reportId)
    end
    return true, Cases.load(caseId, ctx)
end, { rate = 400 })

Api.register('cases.unlink', 'cases.manage', function(src, ctx, data)
    local reportId = V.id(data.reportId)
    local caseId, caseOk = optional(data.caseId, V.id)
    if not reportId or not caseOk then return false, 'bad_request' end
    local rep = Db.single('SELECT `id`, `case_id` FROM `vr_mdt_reports` WHERE `id` = ?', { reportId })
    if not rep then return false, 'not_found' end
    local current = int(rep.case_id)
    if caseId and current ~= caseId then return false, 'not_linked' end
    if current then
        if Db.update('UPDATE `vr_mdt_reports` SET `case_id` = NULL WHERE `id` = ?', { reportId }) == nil then return false, 'save_failed' end
        Db.update('UPDATE `vr_mdt_cases` SET `updated_at` = ? WHERE `id` = ?', { U.now(), current })
        Audit.log(ctx, 'cases.unlink', current, { report = reportId })
        Cases.changed(current)
        Reports.changed(reportId)
    end
    return true, current and Cases.load(current, ctx) or { unlinked = true }
end, { rate = 400 })

Api.register('cases.close', 'cases.manage', function(src, ctx, data)
    local id = V.id(data.id)
    local status = data.status == nil and 'closed' or V.enum(data.status, STATUSES)
    if not id or not status then return false, 'bad_request' end
    local row = Db.single('SELECT `id`, `status`, `title` FROM `vr_mdt_cases` WHERE `id` = ?', { id })
    if not row then return false, 'not_found' end
    if row.status ~= status then
        if Db.update('UPDATE `vr_mdt_cases` SET `status` = ?, `updated_at` = ? WHERE `id` = ?', { status, U.now(), id }) == nil then return false, 'save_failed' end
        Audit.log(ctx, 'cases.status', id, { from = row.status, to = status, title = row.title })
        Cases.changed(id)
    end
    return true, Cases.load(id, ctx)
end, { rate = 400 })
