Reports = {}

local TYPES = { incident = true, arrest = true, traffic = true, use_of_force = true, investigation = true, other = true }
local ROLES = { suspect = true, victim = true, witness = true, officer = true, other = true }
local VIEW = { 'reports.create', 'reports.view' }
local WRITE = { 'reports.create', 'reports.edit_any' }

Db.schema('reports', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_reports` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `type` VARCHAR(16) NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `body` MEDIUMTEXT NOT NULL,
        `location` VARCHAR(96) DEFAULT NULL,
        `call_id` INT UNSIGNED DEFAULT NULL,
        `case_id` INT UNSIGNED DEFAULT NULL,
        `author_cid` VARCHAR(64) NOT NULL,
        `author_name` VARCHAR(64) NOT NULL,
        `author_callsign` VARCHAR(24) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        `locked` TINYINT(1) NOT NULL DEFAULT 0,
        `tags` LONGTEXT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `author_cid` (`author_cid`),
        KEY `case_id` (`case_id`),
        KEY `type` (`type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('report_people', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_report_people` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `report_id` INT UNSIGNED NOT NULL,
        `cid` VARCHAR(64) DEFAULT NULL,
        `name` VARCHAR(64) NOT NULL,
        `callsign` VARCHAR(24) DEFAULT NULL,
        `role` VARCHAR(16) NOT NULL,
        `charges` LONGTEXT DEFAULT NULL,
        `notes` TEXT DEFAULT NULL,
        `sentenced` TINYINT(1) NOT NULL DEFAULT 0,
        `sentence_id` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `report_id` (`report_id`),
        KEY `cid` (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('report_vehicles', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_report_vehicles` (
        `report_id` INT UNSIGNED NOT NULL,
        `plate` VARCHAR(8) NOT NULL,
        `label` VARCHAR(64) DEFAULT NULL,
        `note` VARCHAR(255) DEFAULT NULL,
        PRIMARY KEY (`report_id`, `plate`),
        KEY `plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('report_images', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_report_images` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `report_id` INT UNSIGNED NOT NULL,
        `image_id` CHAR(32) NOT NULL,
        `caption` VARCHAR(128) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `report_image` (`report_id`, `image_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function flag(v)
    return v == true or v == 1 or v == '1'
end

local function int(v)
    v = tonumber(v)
    return v and math.tointeger(math.floor(v)) or nil
end

local function marks(n)
    return ('?,'):rep(n):sub(1, -2)
end

local function optional(v, fn, ...)
    if v == nil or v == '' then return nil, true end
    local x = fn(v, ...)
    return x, x ~= nil
end

local function callsignOf(md)
    md = type(md) == 'table' and md or {}
    return type(md.callsign) == 'string' and md.callsign ~= 'NO CALLSIGN' and md.callsign or nil
end

function Reports.lookup(cids)
    local out, list, seen = {}, {}, {}
    for _, cid in ipairs(cids or {}) do
        if not seen[cid] then
            seen[cid] = true
            list[#list + 1] = cid
        end
    end
    if #list == 0 then return out end
    local found = Bridge.chars.many(list) or {}
    local byUpper = {}
    for key, c in pairs(found) do byUpper[tostring(key):upper()] = c end
    for _, cid in ipairs(list) do
        local c = found[cid] or byUpper[cid:upper()]
        if c then
            out[cid] = { cid = cid, name = c.name, police = Core.deptOf(c.job) == 'police', callsign = callsignOf(c.metadata) }
        end
    end
    return out
end

function Reports.rights(ctx, r)
    local author = r.author_cid == ctx.cid
    local locked = flag(r.locked)
    local editor = (author and Core.can(ctx, 'reports.create')) or Core.can(ctx, 'reports.edit_any')
    return {
        edit = editor and (not locked or ctx.isboss == true),
        lock = Core.can(ctx, 'reports.edit_any'),
        delete = Core.can(ctx, 'reports.delete'),
        sentence = Core.can(ctx, 'sentencing.apply'),
        evidence = Core.can(ctx, 'evidence.manage'),
        link = Core.can(ctx, 'cases.manage'),
    }
end

local function header(r)
    return {
        id = int(r.id),
        type = r.type,
        title = r.title,
        location = r.location,
        callId = int(r.call_id),
        caseId = int(r.case_id),
        author = { cid = r.author_cid, name = r.author_name, callsign = r.author_callsign },
        createdAt = int(r.created_at),
        updatedAt = int(r.updated_at),
        locked = flag(r.locked),
        tags = U.decode(r.tags, {}),
    }
end

local function expandPerson(p, sentence)
    local items, totals
    if sentence then
        items = sentence.charges
        totals = Penal.sum(items)
    else
        local t = Penal.totals(U.decode(p.charges, {}))
        items, totals = t.items, t
    end
    return {
        id = int(p.id),
        cid = p.cid,
        name = p.name,
        callsign = p.callsign,
        role = p.role,
        notes = p.notes,
        charges = items,
        totals = { fine = totals.fine, months = totals.months, points = totals.points, class = totals.class },
        sentenced = flag(p.sentenced),
        sentence = sentence,
    }
end

local function peopleOf(reportId)
    return Db.query('SELECT * FROM `vr_mdt_report_people` WHERE `report_id` = ? ORDER BY `id`', { reportId }) or {}
end

function Reports.load(id, ctx)
    local r = Db.single('SELECT * FROM `vr_mdt_reports` WHERE `id` = ?', { id })
    if not r then return nil end
    local out = header(r)
    out.body = r.body or ''
    local rows = peopleOf(id)
    local sentenceIds = {}
    for _, p in ipairs(rows) do
        if int(p.sentence_id) then sentenceIds[#sentenceIds + 1] = int(p.sentence_id) end
    end
    local sentences = Sentencing.byIds(sentenceIds)
    out.people = {}
    out.officers = { { cid = r.author_cid, name = r.author_name, callsign = r.author_callsign, author = true } }
    for _, p in ipairs(rows) do
        local person = expandPerson(p, sentences[int(p.sentence_id) or -1])
        out.people[#out.people + 1] = person
        if p.role == 'officer' then
            out.officers[#out.officers + 1] = { cid = p.cid, name = p.name, callsign = p.callsign, personId = person.id }
        end
    end
    out.vehicles = Db.query('SELECT `plate`, `label`, `note` FROM `vr_mdt_report_vehicles` WHERE `report_id` = ? ORDER BY `plate`', { id }) or {}
    out.images = {}
    for _, img in ipairs(Db.query('SELECT `image_id`, `caption` FROM `vr_mdt_report_images` WHERE `report_id` = ? ORDER BY `id`', { id }) or {}) do
        out.images[#out.images + 1] = { id = img.image_id, caption = img.caption }
    end
    if out.caseId then
        local c = Db.single('SELECT `id`, `title`, `status` FROM `vr_mdt_cases` WHERE `id` = ?', { out.caseId })
        out.case = c and { id = int(c.id), title = c.title, status = c.status } or nil
    end
    out.evidenceCount = int(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_evidence` WHERE `report_id` = ?', { id })) or 0
    out.rules = { pleaReduction = Config.Sentencing.pleaReduction, maxDiscretion = Config.Sentencing.maxDiscretion }
    if ctx then out.can = Reports.rights(ctx, r) end
    return out
end

function Reports.changed(id, deleted)
    Push.where(function(c) return Core.can(c, VIEW) end, 'reports:changed', { id = id, deleted = deleted == true or nil })
end

local function cleanCharges(list)
    if type(list) ~= 'table' or #list > Config.Sentencing.maxChargesPerPerson then return nil end
    local out, at = {}, {}
    for i = 1, #list do
        local e = list[i]
        if type(e) ~= 'table' then return nil end
        local id = V.id(e.id)
        local count = e.count == nil and 1 or V.int(e.count, 1, Config.Sentencing.maxCount)
        if not id or not count then return nil end
        if at[id] then
            at[id].count = math.min(at[id].count + count, Config.Sentencing.maxCount)
        else
            at[id] = { id = id, count = count }
            out[#out + 1] = at[id]
        end
    end
    return out
end

local function cleanPeople(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Reports.maxPeople then return nil end
    local out = {}
    for i = 1, #list do
        local p = list[i]
        if type(p) ~= 'table' then return nil end
        local role = V.enum(p.role, ROLES)
        local id, idOk = optional(p.id, V.id)
        local cid, cidOk = optional(p.cid, V.cid)
        local notes, notesOk = optional(p.notes, V.text, 1000)
        local name = V.str(p.name, 64, 2)
        if not role or not idOk or not cidOk or not notesOk or (not cid and not name) then return nil end
        if role == 'officer' and not cid then return nil end
        local charges = {}
        if role == 'suspect' and p.charges ~= nil then
            charges = cleanCharges(p.charges)
            if not charges then return nil end
        end
        out[#out + 1] = { id = id, cid = cid, name = name, role = role, notes = notes, charges = charges }
    end
    return out
end

local function cleanVehicles(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Reports.maxVehicles then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local v = list[i]
        if type(v) ~= 'table' then return nil end
        local plate = V.plate(v.plate)
        local vlabel, labelOk = optional(v.label, V.str, 64)
        local note, noteOk = optional(v.note, V.str, 255)
        if not plate or not labelOk or not noteOk then return nil end
        if not seen[plate] then
            seen[plate] = true
            out[#out + 1] = { plate = plate, label = vlabel, note = note }
        end
    end
    return out
end

local function cleanImages(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Reports.maxImages then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local img = list[i]
        if type(img) ~= 'table' then return nil end
        local id = V.imageId(img.id)
        local caption, captionOk = optional(img.caption, V.str, 128)
        if not id or not captionOk then return nil end
        if not seen[id] then
            seen[id] = true
            out[#out + 1] = { id = id, caption = caption }
        end
    end
    return out
end

local function cleanTags(list)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > Config.Reports.maxTags then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local t = V.str(list[i], 24)
        if not t then return nil end
        if not seen[t:lower()] then
            seen[t:lower()] = true
            out[#out + 1] = t
        end
    end
    return out
end

local function cleanReport(data)
    local h = {
        type = V.enum(data.type, TYPES),
        title = V.str(data.title, 96, 3),
        body = data.body == nil and '' or V.text(data.body, Config.Reports.maxBody, 0),
    }
    local ok1, ok2, ok3, ok4
    h.id, ok1 = optional(data.id, V.id)
    h.location, ok2 = optional(data.location, V.str, 96)
    h.callId, ok3 = optional(data.callId, V.id)
    h.caseId, ok4 = optional(data.caseId, V.id)
    h.tags = cleanTags(data.tags)
    h.people = cleanPeople(data.people)
    h.vehicles = cleanVehicles(data.vehicles)
    h.images = cleanImages(data.images)
    if not h.type or not h.title or not h.body or not ok1 or not ok2 or not ok3 or not ok4 then return nil end
    if not h.tags or not h.people or not h.vehicles or not h.images then return nil end
    return h
end

local function callExists(id)
    if Dispatch and Dispatch.get and Dispatch.get(id) then return true end
    return Db.scalar('SELECT 1 FROM `vr_mdt_calls` WHERE `id` = ?', { id }) ~= nil
end

local function chargesAllowed(charges, previous)
    local had = {}
    for _, e in ipairs(previous or {}) do had[tonumber(e.id) or -1] = true end
    for _, e in ipairs(charges) do
        local c = Penal.get(e.id)
        if not c then return false, 'unknown_charge' end
        if not c.active and not had[e.id] then return false, 'charge_inactive' end
    end
    return true
end

local function resolvePeople(h, existing, authorCid)
    local byId = {}
    for _, r in ipairs(existing) do byId[int(r.id)] = r end
    local cids = {}
    for _, p in ipairs(h.people) do
        if p.cid then cids[#cids + 1] = p.cid end
    end
    local found = Reports.lookup(cids)
    local out, seen = {}, {}
    for _, p in ipairs(h.people) do
        local old = p.id and byId[p.id]
        if p.id and not old then return nil, 'bad_request' end
        if old and flag(old.sentenced) then
            out[#out + 1] = { id = p.id, keep = true, notes = p.notes }
            seen[(old.cid or old.name:lower()) .. ':' .. old.role] = true
        else
            local key = (p.cid or p.name:lower()) .. ':' .. p.role
            local skip = seen[key] or (p.role == 'officer' and p.cid == authorCid)
            if not skip then
                seen[key] = true
                local who = p.cid and found[p.cid]
                if p.cid and not who then return nil, 'unknown_person' end
                if p.role == 'officer' then
                    local wasOfficer = old and old.role == 'officer' and old.cid == p.cid
                    if not who.police and not wasOfficer then return nil, 'not_officer' end
                end
                if p.role == 'suspect' then
                    local ok, err = chargesAllowed(p.charges, old and old.role == 'suspect' and U.decode(old.charges, {}) or nil)
                    if not ok then return nil, err end
                end
                out[#out + 1] = {
                    id = p.id,
                    cid = p.cid,
                    name = who and who.name or p.name,
                    callsign = p.role == 'officer' and who and who.callsign or nil,
                    role = p.role,
                    notes = p.notes,
                    charges = p.role == 'suspect' and p.charges or {},
                }
            end
        end
    end
    return out
end

local function imagesExist(images)
    if #images == 0 then return true end
    local ids = {}
    for i, img in ipairs(images) do ids[i] = img.id end
    local n = Db.scalar(('SELECT COUNT(*) FROM `vr_mdt_images` WHERE `id` IN (%s)'):format(marks(#ids)), ids)
    return int(n) == #ids
end

local function imageInUse(id)
    if Db.scalar('SELECT 1 FROM `vr_mdt_report_images` WHERE `image_id` = ? LIMIT 1', { id }) then return true end
    return Db.scalar('SELECT 1 FROM `vr_mdt_evidence` WHERE `image_id` = ? LIMIT 1', { id }) ~= nil
end

local function writePeople(reportId, people, existing)
    local keep = {}
    for _, p in ipairs(people) do
        if p.keep then
            keep[p.id] = true
            Db.update('UPDATE `vr_mdt_report_people` SET `notes` = ? WHERE `id` = ? AND `report_id` = ?', { p.notes, p.id, reportId })
        elseif p.id then
            keep[p.id] = true
            Db.update('UPDATE `vr_mdt_report_people` SET `cid` = ?, `name` = ?, `callsign` = ?, `role` = ?, `charges` = ?, `notes` = ? WHERE `id` = ? AND `report_id` = ? AND `sentenced` = 0', {
                p.cid, p.name, p.callsign, p.role, json.encode(p.charges), p.notes, p.id, reportId,
            })
        else
            local id = Db.insert('INSERT INTO `vr_mdt_report_people` (`report_id`, `cid`, `name`, `callsign`, `role`, `charges`, `notes`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                reportId, p.cid, p.name, p.callsign, p.role, json.encode(p.charges), p.notes,
            })
            if id then keep[id] = true end
        end
    end
    for _, r in ipairs(existing) do
        local id = int(r.id)
        if not keep[id] and not flag(r.sentenced) then
            Db.update('DELETE FROM `vr_mdt_report_people` WHERE `id` = ? AND `sentenced` = 0', { id })
        end
    end
end

local function writeVehicles(reportId, vehicles)
    Db.update('DELETE FROM `vr_mdt_report_vehicles` WHERE `report_id` = ?', { reportId })
    for _, v in ipairs(vehicles) do
        Db.insert('INSERT INTO `vr_mdt_report_vehicles` (`report_id`, `plate`, `label`, `note`) VALUES (?, ?, ?, ?)', { reportId, v.plate, v.label, v.note })
    end
end

local function writeImages(reportId, images)
    local before = {}
    for _, r in ipairs(Db.query('SELECT `image_id` FROM `vr_mdt_report_images` WHERE `report_id` = ?', { reportId }) or {}) do before[r.image_id] = true end
    Db.update('DELETE FROM `vr_mdt_report_images` WHERE `report_id` = ?', { reportId })
    for _, img in ipairs(images) do
        before[img.id] = nil
        Db.insert('INSERT INTO `vr_mdt_report_images` (`report_id`, `image_id`, `caption`) VALUES (?, ?, ?)', { reportId, img.id, img.caption })
    end
    for id in pairs(before) do
        if not imageInUse(id) then Images.delete(id) end
    end
end

Api.register('reports.save', WRITE, function(src, ctx, data)
    local h = cleanReport(data)
    if not h then return false, 'bad_request' end
    local row
    if h.id then
        row = Db.single('SELECT * FROM `vr_mdt_reports` WHERE `id` = ?', { h.id })
        if not row then return false, 'not_found' end
        local author = row.author_cid == ctx.cid
        if not ((author and Core.can(ctx, 'reports.create')) or Core.can(ctx, 'reports.edit_any')) then return false, 'not_allowed' end
        if flag(row.locked) and not ctx.isboss then return false, 'locked' end
    elseif not Core.can(ctx, 'reports.create') then
        return false, 'not_allowed'
    end
    if h.callId and not callExists(h.callId) then return false, 'unknown_call' end
    if h.caseId and not Db.scalar('SELECT 1 FROM `vr_mdt_cases` WHERE `id` = ?', { h.caseId }) then return false, 'unknown_case' end
    if not imagesExist(h.images) then return false, 'unknown_image' end
    local existing = h.id and peopleOf(h.id) or {}
    local people, err = resolvePeople(h, existing, row and row.author_cid or ctx.cid)
    if not people then return false, err end
    local now = U.now()
    local id = h.id
    local tags = json.encode(h.tags)
    if id then
        local n = Db.update([[UPDATE `vr_mdt_reports` SET `type` = ?, `title` = ?, `body` = ?, `location` = ?, `call_id` = ?, `case_id` = ?, `tags` = ?, `updated_at` = ?
            WHERE `id` = ?]], { h.type, h.title, h.body, h.location, h.callId, h.caseId, tags, now, id })
        if n == nil then return false, 'save_failed' end
    else
        id = Db.insert([[INSERT INTO `vr_mdt_reports` (`type`, `title`, `body`, `location`, `call_id`, `case_id`, `author_cid`, `author_name`, `author_callsign`,
            `created_at`, `updated_at`, `locked`, `tags`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)]],
            { h.type, h.title, h.body, h.location, h.callId, h.caseId, ctx.cid, ctx.name, ctx.callsign, now, now, tags })
        if not id then return false, 'save_failed' end
    end
    writePeople(id, people, existing)
    writeVehicles(id, h.vehicles)
    writeImages(id, h.images)
    Audit.log(ctx, h.id and 'reports.edit' or 'reports.create', id, { title = h.title, type = h.type })
    Reports.changed(id)
    return true, Reports.load(id, ctx)
end, { rate = 1200 })

Api.register('reports.get', VIEW, function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local r = Reports.load(id, ctx)
    if not r then return false, 'not_found' end
    return true, r
end, { rate = 100 })

Api.register('reports.list', VIEW, function(src, ctx, data)
    local size = Config.Reports.pageSize
    local page = V.int(data.page or 1, 1, 10000)
    local q, qOk = optional(data.q, V.str, 64)
    local typ, typeOk = optional(data.type, V.enum, TYPES)
    local cid, cidOk = optional(data.cid, V.cid)
    if not page or not qOk or not typeOk or not cidOk or (data.mine ~= nil and V.bool(data.mine) == nil) then return false, 'bad_request' end
    local where, params = { '1 = 1' }, {}
    if typ then
        where[#where + 1] = 'r.`type` = ?'
        params[#params + 1] = typ
    end
    if data.mine == true then
        where[#where + 1] = "(r.`author_cid` = ? OR EXISTS (SELECT 1 FROM `vr_mdt_report_people` p WHERE p.report_id = r.id AND p.role = 'officer' AND p.cid = ?))"
        params[#params + 1] = ctx.cid
        params[#params + 1] = ctx.cid
    end
    if cid then
        where[#where + 1] = 'EXISTS (SELECT 1 FROM `vr_mdt_report_people` p WHERE p.report_id = r.id AND p.cid = ?)'
        params[#params + 1] = cid
    end
    if q then
        local like = U.like(q)
        local num = q:match('^#?(%d+)$')
        where[#where + 1] = '(r.`title` LIKE ? OR r.`author_name` LIKE ? OR r.`author_callsign` LIKE ? OR r.`location` LIKE ? OR EXISTS (SELECT 1 FROM `vr_mdt_report_people` p WHERE p.report_id = r.id AND p.name LIKE ?)'
            .. (num and ' OR r.`id` = ?' or '') .. ')'
        for _ = 1, 5 do params[#params + 1] = like end
        if num then params[#params + 1] = tonumber(num) end
    end
    local sqlWhere = table.concat(where, ' AND ')
    local total = int(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_reports` r WHERE ' .. sqlWhere, params))
    if total == nil then return false, 'server_error' end
    local listParams = U.copy(params)
    listParams[#listParams + 1] = size
    listParams[#listParams + 1] = (page - 1) * size
    local rows = Db.query('SELECT r.* FROM `vr_mdt_reports` r WHERE ' .. sqlWhere .. ' ORDER BY r.`id` DESC LIMIT ? OFFSET ?', listParams)
    if not rows then return false, 'server_error' end
    local items, byId, ids = {}, {}, {}
    for _, r in ipairs(rows) do
        local item = header(r)
        item.suspects = {}
        item.peopleCount = 0
        item.sentenced = false
        items[#items + 1] = item
        byId[item.id] = item
        ids[#ids + 1] = item.id
    end
    if #ids > 0 then
        local people = Db.query(('SELECT `report_id`, `name`, `role`, `sentenced` FROM `vr_mdt_report_people` WHERE `report_id` IN (%s) ORDER BY `id`'):format(marks(#ids)), ids) or {}
        for _, p in ipairs(people) do
            local item = byId[int(p.report_id)]
            if item and p.role ~= 'officer' then
                item.peopleCount = item.peopleCount + 1
                if p.role == 'suspect' and #item.suspects < 4 then item.suspects[#item.suspects + 1] = p.name end
                if flag(p.sentenced) then item.sentenced = true end
            end
        end
    end
    return true, { items = items, total = total, page = page, pages = math.max(1, math.ceil(total / size)), pageSize = size }
end, { rate = 200 })

Api.register('reports.lock', 'reports.edit_any', function(src, ctx, data)
    local id = V.id(data.id)
    local locked = V.bool(data.locked)
    if not id or locked == nil then return false, 'bad_request' end
    local row = Db.single('SELECT `id`, `title`, `locked` FROM `vr_mdt_reports` WHERE `id` = ?', { id })
    if not row then return false, 'not_found' end
    if flag(row.locked) ~= locked then
        if Db.update('UPDATE `vr_mdt_reports` SET `locked` = ?, `updated_at` = ? WHERE `id` = ?', { locked and 1 or 0, U.now(), id }) == nil then return false, 'save_failed' end
        Audit.log(ctx, locked and 'reports.lock' or 'reports.unlock', id, { title = row.title })
        Reports.changed(id)
    end
    return true, Reports.load(id, ctx)
end, { rate = 400 })

Api.register('reports.delete', 'reports.delete', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local row = Db.single('SELECT `id`, `title`, `author_cid` FROM `vr_mdt_reports` WHERE `id` = ?', { id })
    if not row then return false, 'not_found' end
    local images = Db.query('SELECT `image_id` FROM `vr_mdt_report_images` WHERE `report_id` = ?', { id }) or {}
    if Db.update('DELETE FROM `vr_mdt_reports` WHERE `id` = ?', { id }) == nil then return false, 'save_failed' end
    Db.update('DELETE FROM `vr_mdt_report_people` WHERE `report_id` = ?', { id })
    Db.update('DELETE FROM `vr_mdt_report_vehicles` WHERE `report_id` = ?', { id })
    Db.update('DELETE FROM `vr_mdt_report_images` WHERE `report_id` = ?', { id })
    Db.update('UPDATE `vr_mdt_sentences` SET `report_id` = NULL WHERE `report_id` = ?', { id })
    Db.update('UPDATE `vr_mdt_evidence` SET `report_id` = NULL WHERE `report_id` = ?', { id })
    for _, img in ipairs(images) do
        if not imageInUse(img.image_id) then Images.delete(img.image_id) end
    end
    Audit.log(ctx, 'reports.delete', id, { title = row.title, author = row.author_cid })
    Reports.changed(id, true)
    return true, { deleted = true }
end, { rate = 800 })

function Reports.forCitizen(cid, limit)
    cid = V.cid(cid)
    if not cid then return {} end
    limit = V.int(limit, 1, 100) or 20
    local rows = Db.query([[SELECT r.`id`, r.`title`, r.`type`, r.`created_at`, r.`author_name`, r.`author_callsign`, p.`role`
        FROM `vr_mdt_report_people` p JOIN `vr_mdt_reports` r ON r.id = p.report_id
        WHERE p.`cid` = ? ORDER BY r.`id` DESC LIMIT ?]], { cid, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = int(r.id), title = r.title, type = r.type, role = r.role, created_at = int(r.created_at),
            author = r.author_callsign and ('%s %s'):format(r.author_callsign, r.author_name) or r.author_name,
        }
    end
    return out
end

function Reports.forPlate(plate, limit)
    plate = V.plate(plate)
    if not plate then return {} end
    limit = V.int(limit, 1, 100) or 20
    local rows = Db.query([[SELECT r.`id`, r.`title`, r.`type`, r.`created_at` FROM `vr_mdt_report_vehicles` v
        JOIN `vr_mdt_reports` r ON r.id = v.report_id WHERE v.`plate` = ? ORDER BY r.`id` DESC LIMIT ?]], { plate, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { id = int(r.id), title = r.title, type = r.type, created_at = int(r.created_at) } end
    return out
end

function Reports.search(q, limit)
    q = V.str(q, 64)
    if not q then return {} end
    limit = V.int(limit, 1, 50) or 10
    local num = q:match('^#?(%d+)$')
    local rows
    if num then
        rows = Db.query('SELECT `id`, `title`, `type`, `created_at` FROM `vr_mdt_reports` WHERE `id` = ? OR `title` LIKE ? ORDER BY `id` DESC LIMIT ?', { tonumber(num), U.like(q), limit })
    else
        rows = Db.query('SELECT `id`, `title`, `type`, `created_at` FROM `vr_mdt_reports` WHERE `title` LIKE ? ORDER BY `id` DESC LIMIT ?', { U.like(q), limit })
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = { id = int(r.id), title = r.title, type = r.type, created_at = int(r.created_at) } end
    return out
end
