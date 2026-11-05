Patients = {}
MedReports = {}

local TYPES = { 'treatment', 'transport', 'death', 'checkup', 'other' }
local OUTCOMES = { 'treated_released', 'transported', 'admitted', 'deceased', 'refused' }
local REGIONS = { 'head', 'neck', 'chest', 'abdomen', 'back', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }
local KINDS = { 'gunshot', 'stab', 'fracture', 'burn', 'laceration', 'blunt', 'other' }
local SEVERITIES = { 'minor', 'moderate', 'severe', 'critical' }
local READ = { 'patients.view', 'medreports.create' }
local PAGE = 50
local PROFILE_FIELDS = { 'allergies', 'conditions', 'medications', 'notes' }
local LIST_COLUMNS = '`id`, `cid`, `name`, `type`, `title`, `injuries`, `outcome`, `call_id`, `author_cid`, `author_name`, `author_callsign`, `created_at`, `updated_at`'

Db.schema('patients', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_patients` (
        `cid` VARCHAR(64) NOT NULL,
        `allergies` TEXT DEFAULT NULL,
        `conditions` TEXT DEFAULT NULL,
        `medications` TEXT DEFAULT NULL,
        `notes` TEXT DEFAULT NULL,
        `emergency_contact` VARCHAR(96) DEFAULT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('medreports', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_medreports` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `cid` VARCHAR(64) DEFAULT NULL,
        `name` VARCHAR(64) NOT NULL,
        `type` VARCHAR(16) NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `body` MEDIUMTEXT DEFAULT NULL,
        `injuries` LONGTEXT DEFAULT NULL,
        `treatment` TEXT DEFAULT NULL,
        `outcome` VARCHAR(24) DEFAULT NULL,
        `call_id` INT UNSIGNED DEFAULT NULL,
        `author_cid` VARCHAR(64) DEFAULT NULL,
        `author_name` VARCHAR(64) DEFAULT NULL,
        `author_callsign` VARCHAR(24) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `cid` (`cid`),
        KEY `author_cid` (`author_cid`),
        KEY `created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

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

local function isEms(ctx)
    return ctx.dept == 'ems'
end

local function canEdit(ctx, row)
    return Core.can(ctx, 'medreports.create') and (row.author_cid == ctx.cid or Core.can(ctx, 'medreports.edit_any'))
end

local function cleanInjury(e)
    if type(e) ~= 'table' then return nil end
    local region = V.enum(e.region, REGIONS)
    local kind = V.enum(e.kind, KINDS)
    local severity = V.enum(e.severity, SEVERITIES)
    if not region or not kind or not severity then return nil end
    return { region = region, kind = kind, severity = severity }
end

local function toProfile(r)
    r = r or {}
    return {
        allergies = r.allergies,
        conditions = r.conditions,
        medications = r.medications,
        notes = r.notes,
        emergencyContact = r.emergency_contact,
        updatedAt = r.updated_at,
        updatedBy = r.updated_by,
    }
end

local function toRow(r)
    local injuries = U.decode(r.injuries, {})
    return {
        id = r.id,
        cid = r.cid,
        name = r.name,
        type = r.type,
        title = r.title,
        outcome = r.outcome,
        callId = r.call_id,
        injuryCount = type(injuries) == 'table' and #injuries or 0,
        author = { cid = r.author_cid, name = r.author_name, callsign = r.author_callsign },
        createdAt = r.created_at,
        updatedAt = r.updated_at,
    }
end

local function toReport(ctx, r)
    local out = toRow(r)
    out.body = r.body
    out.treatment = r.treatment
    out.injuries = U.decode(r.injuries, {})
    if ctx then
        out.canEdit = canEdit(ctx, r)
        out.canDelete = ctx.isboss == true
    end
    return out
end

local function loadReport(id)
    return Db.single('SELECT * FROM `vr_mdt_medreports` WHERE `id` = ? LIMIT 1', { id })
end

local function pushChanged(payload)
    Push.dept('ems', 'medreports:changed', payload, function(c)
        return Core.can(c, READ)
    end)
end

function Patients.profile(cid)
    cid = V.cid(cid)
    if not cid then return nil end
    return toProfile(Db.single('SELECT * FROM `vr_mdt_patients` WHERE `cid` = ? LIMIT 1', { cid }))
end

function Patients.bloodtype(person)
    local md = person and person.metadata
    if type(md) ~= 'table' then return nil end
    return V.str(md.bloodtype, 8)
end

function MedReports.forCitizen(cid, limit)
    cid = V.cid(cid)
    if not cid then return {} end
    limit = V.int(limit, 1, 50) or Config.Ems.recentReports
    local rows = Db.query(('SELECT %s FROM `vr_mdt_medreports` WHERE `cid` = ? ORDER BY `created_at` DESC, `id` DESC LIMIT ?'):format(LIST_COLUMNS), { cid, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = toRow(r) end
    return out
end

function MedReports.get(id)
    id = V.id(id)
    local row = id and loadReport(id)
    return row and toReport(nil, row) or nil
end

local function recentPatients()
    local rows = Db.query([[SELECT `cid`, `name`, MAX(`created_at`) AS `last` FROM `vr_mdt_medreports` WHERE `cid` IS NOT NULL
        GROUP BY `cid`, `name` ORDER BY `last` DESC LIMIT 20]]) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { cid = r.cid, name = r.name, lastSeen = tonumber(r.last) } end
    return out
end

local function markProfiles(list)
    if #list == 0 then return list end
    local marks, params = {}, {}
    for i, p in ipairs(list) do
        marks[i] = '?'
        params[i] = p.cid
    end
    local rows = Db.query(('SELECT `cid` FROM `vr_mdt_patients` WHERE `cid` IN (%s)'):format(table.concat(marks, ', ')), params) or {}
    local has = {}
    for _, r in ipairs(rows) do has[r.cid] = true end
    for _, p in ipairs(list) do p.profile = has[p.cid] == true end
    return list
end

Api.register('patients.search', 'patients.view', function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    if data.q ~= nil and type(data.q) ~= 'string' then return false, 'bad_request' end
    local q = V.str(data.q, 48)
    if not q then return true, { recent = true, list = markProfiles(recentPatients()) } end
    local out = {}
    for _, p in ipairs(People.search(q, 25)) do
        out[#out + 1] = { cid = p.cid, name = p.name, dob = p.dob, gender = p.gender, phone = p.phone }
    end
    return true, { recent = false, list = markProfiles(out) }
end, { rate = 300 })

Api.register('patients.get', 'patients.view', function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    local person = People.get(cid)
    if not person then return false, 'not_found' end
    local identity = People.public(person)
    identity.bloodtype = Patients.bloodtype(person)
    return true, {
        identity = identity,
        profile = Patients.profile(cid),
        reports = MedReports.forCitizen(cid, Config.Ems.recentReports),
    }
end, { rate = 200 })

Api.register('patients.save', 'patients.edit', function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    local values = {}
    for _, key in ipairs(PROFILE_FIELDS) do
        local v = data[key]
        if v ~= nil and type(v) ~= 'string' then return false, 'bad_request' end
        values[key] = V.text(v, 1000)
    end
    local contact = data.emergencyContact
    if contact ~= nil and type(contact) ~= 'string' then return false, 'bad_request' end
    values.emergency_contact = V.str(contact, 96)
    if not People.get(cid) then return false, 'not_found' end
    local done = Db.update([[INSERT INTO `vr_mdt_patients` (`cid`, `allergies`, `conditions`, `medications`, `notes`, `emergency_contact`, `updated_at`, `updated_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `allergies` = VALUES(`allergies`), `conditions` = VALUES(`conditions`),
        `medications` = VALUES(`medications`), `notes` = VALUES(`notes`), `emergency_contact` = VALUES(`emergency_contact`),
        `updated_at` = VALUES(`updated_at`), `updated_by` = VALUES(`updated_by`)]], {
        cid, values.allergies, values.conditions, values.medications, values.notes, values.emergency_contact, U.now(), ctx.name,
    })
    if done == nil then return false, 'save_failed' end
    Audit.log(ctx, 'patients.save', cid)
    return true, Patients.profile(cid)
end, { rate = 800 })

Api.register('medreports.list', READ, function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    local page = data.page == nil and 1 or V.int(data.page, 1, 1000)
    local mine = flag(data.mine)
    local okQ = data.q == nil or type(data.q) == 'string'
    local okC, cid = optional(data.cid, V.cid)
    if not page or mine == nil or not okQ or not okC then return false, 'bad_request' end
    local q = V.str(data.q, 48)
    local where, params = {}, {}
    if mine then
        where[#where + 1] = '`author_cid` = ?'
        params[#params + 1] = ctx.cid
    end
    if cid then
        where[#where + 1] = '`cid` = ?'
        params[#params + 1] = cid
    end
    if q then
        local like = U.like(q)
        where[#where + 1] = '(`title` LIKE ? OR `name` LIKE ? OR `cid` LIKE ? OR `author_name` LIKE ?)'
        for _ = 1, 4 do params[#params + 1] = like end
    end
    local clause = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    params[#params + 1] = PAGE + 1
    params[#params + 1] = (page - 1) * PAGE
    local rows = Db.query(('SELECT %s FROM `vr_mdt_medreports`%s ORDER BY `created_at` DESC, `id` DESC LIMIT ? OFFSET ?'):format(LIST_COLUMNS, clause), params)
    if not rows then return false, 'server_error' end
    local out = {}
    for i = 1, math.min(#rows, PAGE) do out[#out + 1] = toRow(rows[i]) end
    return true, { rows = out, page = page, more = #rows > PAGE }
end, { rate = 300 })

Api.register('medreports.get', READ, function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = loadReport(id)
    if not row then return false, 'not_found' end
    return true, toReport(ctx, row)
end, { rate = 150 })

local function readReport(data)
    local title = V.str(data.title, 96, 3)
    local rtype = V.enum(data.type, TYPES)
    if not title or not rtype then return nil, 'bad_request' end
    local patient
    if data.cid ~= nil and data.cid ~= '' then
        local cid = V.cid(data.cid)
        if not cid then return nil, 'bad_request' end
        local person = People.get(cid)
        if not person then return nil, 'unknown_person' end
        patient = { cid = cid, name = person.name }
    else
        local name = V.str(data.name, 64, 2)
        if not name then return nil, 'bad_request' end
        patient = { name = name }
    end
    local okB, body = optional(data.body, V.text, Config.Ems.bodyLength)
    local okT, treatment = optional(data.treatment, V.text, 2000)
    local okO, outcome = optional(data.outcome, V.enum, OUTCOMES)
    local okC, callId = optional(data.callId, V.id)
    if not okB or not okT or not okO or not okC then return nil, 'bad_request' end
    if data.injuries ~= nil and type(data.injuries) ~= 'table' then return nil, 'bad_request' end
    local injuries = V.list(data.injuries or {}, Config.Ems.maxInjuries, cleanInjury)
    return {
        title = title, type = rtype, patient = patient, body = body, treatment = treatment,
        outcome = outcome, callId = callId, injuries = injuries,
    }
end

Api.register('medreports.save', 'medreports.create', function(src, ctx, data)
    if not isEms(ctx) then return false, 'not_allowed' end
    local okId, id = optional(data.id, V.id)
    if not okId then return false, 'bad_request' end
    local row
    if id then
        row = loadReport(id)
        if not row then return false, 'not_found' end
        if not canEdit(ctx, row) then return false, 'not_allowed' end
    end
    local f, err = readReport(data)
    if not f then return false, err end
    local now = U.now()
    local injuries = json.encode(f.injuries)
    if row then
        local done = Db.update([[UPDATE `vr_mdt_medreports` SET `cid` = ?, `name` = ?, `type` = ?, `title` = ?, `body` = ?, `injuries` = ?, `treatment` = ?,
            `outcome` = ?, `call_id` = ?, `updated_at` = ? WHERE `id` = ?]], {
            f.patient.cid, f.patient.name, f.type, f.title, f.body, injuries, f.treatment, f.outcome, f.callId, now, id,
        })
        if done == nil then return false, 'save_failed' end
        Audit.log(ctx, 'medreports.edit', id, { title = f.title, author = row.author_cid })
    else
        id = Db.insert([[INSERT INTO `vr_mdt_medreports` (`cid`, `name`, `type`, `title`, `body`, `injuries`, `treatment`, `outcome`, `call_id`,
            `author_cid`, `author_name`, `author_callsign`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            f.patient.cid, f.patient.name, f.type, f.title, f.body, injuries, f.treatment, f.outcome, f.callId,
            ctx.cid, ctx.name, ctx.callsign, now, now,
        })
        if not id then return false, 'save_failed' end
        Audit.log(ctx, 'medreports.create', id, { title = f.title, cid = f.patient.cid })
    end
    pushChanged({ id = id, cid = f.patient.cid })
    return true, toReport(ctx, loadReport(id))
end, { rate = 1000 })

Api.register('medreports.delete', 'medreports.create', function(src, ctx, data)
    if not isEms(ctx) or not ctx.isboss then return false, 'not_allowed' end
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = loadReport(id)
    if not row then return false, 'not_found' end
    local done = Db.update('DELETE FROM `vr_mdt_medreports` WHERE `id` = ?', { id })
    if done == nil then return false, 'save_failed' end
    Audit.log(ctx, 'medreports.delete', id, { title = row.title, cid = row.cid, author = row.author_cid })
    pushChanged({ id = id, cid = row.cid, deleted = true })
    return true, { id = id }
end, { rate = 1000 })
