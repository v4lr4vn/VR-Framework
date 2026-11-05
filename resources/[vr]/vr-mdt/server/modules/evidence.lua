Evidence = {}

local KINDS = { photo = true, note = true, item = true }
local READ_PERMS = { 'cases.view', 'reports.create', 'reports.view' }
local registered = {}

Db.schema('evidence', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_evidence` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `case_id` INT UNSIGNED DEFAULT NULL,
        `report_id` INT UNSIGNED DEFAULT NULL,
        `kind` VARCHAR(8) NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `description` TEXT DEFAULT NULL,
        `image_id` CHAR(32) DEFAULT NULL,
        `location` VARCHAR(96) DEFAULT NULL,
        `collected_by_cid` VARCHAR(64) NOT NULL,
        `collected_by_name` VARCHAR(64) NOT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `case_id` (`case_id`),
        KEY `report_id` (`report_id`)
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

function Evidence.fromRow(r)
    return {
        id = int(r.id),
        caseId = int(r.case_id),
        reportId = int(r.report_id),
        kind = r.kind,
        title = r.title,
        description = r.description,
        imageId = r.image_id,
        location = r.location,
        collectedBy = { cid = r.collected_by_cid, name = r.collected_by_name },
        createdAt = int(r.created_at),
    }
end

function Evidence.get(id)
    local r = Db.single('SELECT * FROM `vr_mdt_evidence` WHERE `id` = ?', { id })
    return r and Evidence.fromRow(r) or nil
end

function Evidence.list(opts)
    local rows
    if opts.caseId then
        rows = Db.query('SELECT * FROM `vr_mdt_evidence` WHERE `case_id` = ? ORDER BY `id` DESC LIMIT ?', { opts.caseId, Config.Evidence.maxPerCase })
    elseif opts.reportId then
        rows = Db.query('SELECT * FROM `vr_mdt_evidence` WHERE `report_id` = ? ORDER BY `id` DESC LIMIT ?', { opts.reportId, Config.Evidence.maxPerCase })
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = Evidence.fromRow(r) end
    return out
end

local function changed(caseId, reportId)
    Push.where(function(c) return Core.can(c, READ_PERMS) end, 'evidence:changed', { caseId = caseId, reportId = reportId })
end

local function reportExists(id)
    return Db.scalar('SELECT 1 FROM `vr_mdt_reports` WHERE `id` = ?', { id }) ~= nil
end

local function imageUsable(id)
    local kind = Db.scalar('SELECT `kind` FROM `vr_mdt_images` WHERE `id` = ?', { id })
    return kind == 'evidence' or kind == 'report'
end

local function imageShared(id, exceptEvidence)
    if Db.scalar('SELECT 1 FROM `vr_mdt_report_images` WHERE `image_id` = ? LIMIT 1', { id }) then return true end
    return Db.scalar('SELECT 1 FROM `vr_mdt_evidence` WHERE `image_id` = ? AND `id` <> ? LIMIT 1', { id, exceptEvidence or 0 }) ~= nil
end

Api.register('evidence.list', READ_PERMS, function(src, ctx, data)
    local caseId, caseOk = optional(data.caseId, V.id)
    local reportId, reportOk = optional(data.reportId, V.id)
    if not caseOk or not reportOk or (not caseId and not reportId) then return false, 'bad_request' end
    if caseId then
        if not Core.can(ctx, 'cases.view') then return false, 'not_allowed' end
        return true, Evidence.list({ caseId = caseId })
    end
    if not Core.can(ctx, { 'reports.create', 'reports.view' }) then return false, 'not_allowed' end
    return true, Evidence.list({ reportId = reportId })
end, { rate = 150 })

Api.register('evidence.add', 'evidence.manage', function(src, ctx, data)
    local kind = V.enum(data.kind, KINDS)
    local caseId, caseOk = optional(data.caseId, V.id)
    local reportId, reportOk = optional(data.reportId, V.id)
    local description, descOk = optional(data.description, V.text, 2000)
    local location, locOk = optional(data.location, V.str, 96)
    if not kind or not caseOk or not reportOk or not descOk or not locOk or (not caseId and not reportId) then return false, 'bad_request' end
    local title = V.str(data.title, 96, 2)
    local imageId
    if kind == 'photo' then
        imageId = V.imageId(data.imageId)
        if not imageId then return false, 'bad_request' end
        if not title and (data.title == nil or data.title == '') then title = 'Photograph' end
    end
    if not title then return false, 'bad_request' end
    if caseId and not Cases.exists(caseId) then return false, 'unknown_case' end
    if reportId and not reportExists(reportId) then return false, 'not_found' end
    if imageId and not imageUsable(imageId) then return false, 'unknown_image' end
    if caseId and (int(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_evidence` WHERE `case_id` = ?', { caseId })) or 0) >= Config.Evidence.maxPerCase then
        return false, 'too_many'
    end
    local id = Db.insert([[INSERT INTO `vr_mdt_evidence` (`case_id`, `report_id`, `kind`, `title`, `description`, `image_id`, `location`, `collected_by_cid`, `collected_by_name`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { caseId, reportId, kind, title, description, imageId, location, ctx.cid, ctx.callsign and ('%s %s'):format(ctx.callsign, ctx.name) or ctx.name, U.now() })
    if not id then return false, 'save_failed' end
    if caseId then Db.update('UPDATE `vr_mdt_cases` SET `updated_at` = ? WHERE `id` = ?', { U.now(), caseId }) end
    Audit.log(ctx, 'evidence.add', id, { kind = kind, title = title, case = caseId, report = reportId })
    changed(caseId, reportId)
    return true, Evidence.get(id)
end, { rate = 800 })

Api.register('evidence.update', 'evidence.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = Evidence.get(id)
    if not row then return false, 'not_found' end
    local title = data.title == nil and row.title or V.str(data.title, 96, 2)
    local description, descOk = row.description, true
    if data.description ~= nil then description, descOk = optional(data.description, V.text, 2000) end
    local location, locOk = row.location, true
    if data.location ~= nil then location, locOk = optional(data.location, V.str, 96) end
    local caseId, caseOk = row.caseId, true
    if data.caseId ~= nil then caseId, caseOk = optional(data.caseId, V.id) end
    if not title or not descOk or not locOk or not caseOk then return false, 'bad_request' end
    if caseId and caseId ~= row.caseId and not Cases.exists(caseId) then return false, 'unknown_case' end
    if not caseId and not row.reportId then return false, 'bad_request' end
    if Db.update('UPDATE `vr_mdt_evidence` SET `title` = ?, `description` = ?, `location` = ?, `case_id` = ? WHERE `id` = ?', { title, description, location, caseId, id }) == nil then
        return false, 'save_failed'
    end
    Audit.log(ctx, 'evidence.update', id, { title = title, case = caseId, from = row.caseId ~= caseId and row.caseId or nil })
    changed(caseId, row.reportId)
    if row.caseId and row.caseId ~= caseId then changed(row.caseId, nil) end
    return true, Evidence.get(id)
end, { rate = 400 })

Api.register('evidence.remove', 'evidence.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = Evidence.get(id)
    if not row then return false, 'not_found' end
    if Db.update('DELETE FROM `vr_mdt_evidence` WHERE `id` = ?', { id }) == nil then return false, 'save_failed' end
    if row.imageId and not imageShared(row.imageId, id) then Images.delete(row.imageId) end
    Audit.log(ctx, 'evidence.remove', id, { kind = row.kind, title = row.title, case = row.caseId, report = row.reportId })
    changed(row.caseId, row.reportId)
    return true, { removed = true }
end, { rate = 400 })

function Evidence.stashId(caseId)
    return ('mdt_case_%d'):format(caseId)
end

function Evidence.registerLocker(caseId)
    local id = Evidence.stashId(caseId)
    if registered[id] then return id end
    local groups = {}
    for _, job in ipairs(Core.jobsOfDept('police')) do groups[job] = 0 end
    if next(groups) == nil then groups.police = 0 end
    local ok, err = pcall(Bridge.inventory.registerStash, id, ('Case #%d evidence'):format(caseId), Config.Evidence.stashSlots, Config.Evidence.stashWeight, nil, groups)
    if not ok or err == false then
        print(('^1[vr-mdt] could not register evidence locker %s: %s^0'):format(id, tostring(err)))
        return nil
    end
    registered[id] = true
    return id
end

Api.register('evidence.locker', 'evidence.manage', function(src, ctx, data)
    local caseId = V.id(data.caseId)
    if not caseId then return false, 'bad_request' end
    local row = Db.single('SELECT `id`, `title` FROM `vr_mdt_cases` WHERE `id` = ?', { caseId })
    if not row then return false, 'not_found' end
    local id = Evidence.registerLocker(caseId)
    if not id then return false, 'no_inventory' end
    Audit.log(ctx, 'evidence.locker', caseId, { stash = id })
    return true, { id = id, label = ('Case #%d evidence'):format(caseId) }
end, { rate = 1000 })

Api.register('evidence.open', 'evidence.manage', function(src, ctx, data)
    local id = type(data.id) == 'string' and data.id or ''
    if #id > 24 or not id:match('^mdt_case_%d+$') or not registered[id] then return false, 'bad_request' end
    if not Bridge.inventory.openStash(src, id) then return false, 'no_inventory' end
    return true, { id = id }
end, { rate = 1000 })
