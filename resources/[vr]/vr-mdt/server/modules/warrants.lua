Warrants = {}
Bolos = {}

local HISTORY = { 'served', 'denied', 'revoked', 'expired' }
local BOLO_KINDS = { 'person', 'vehicle', 'other' }
local PAGE = 50
local lastExpire = -math.huge
local activeBolos = {}

Db.schema('warrants', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_warrants` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `cid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `reason` TEXT NOT NULL,
        `charges` LONGTEXT DEFAULT NULL,
        `report_id` INT UNSIGNED DEFAULT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
        `created_by_cid` VARCHAR(64) DEFAULT NULL,
        `created_by_name` VARCHAR(64) DEFAULT NULL,
        `approved_by_cid` VARCHAR(64) DEFAULT NULL,
        `approved_by_name` VARCHAR(64) DEFAULT NULL,
        `decision_note` TEXT DEFAULT NULL,
        `closed_by_name` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `decided_at` INT UNSIGNED DEFAULT NULL,
        `expires_at` INT UNSIGNED DEFAULT NULL,
        `served_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `cid` (`cid`),
        KEY `status` (`status`, `expires_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('bolos', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_bolos` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(16) NOT NULL,
        `subject` VARCHAR(96) DEFAULT NULL,
        `plate` VARCHAR(8) DEFAULT NULL,
        `cid` VARCHAR(64) DEFAULT NULL,
        `title` VARCHAR(96) NOT NULL,
        `details` TEXT DEFAULT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'active',
        `created_by_cid` VARCHAR(64) DEFAULT NULL,
        `created_by_name` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `closed_at` INT UNSIGNED DEFAULT NULL,
        `closed_by_name` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `status` (`status`),
        KEY `plate` (`plate`),
        KEY `cid` (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function days()
    return V.int(Config.Warrants.days, 1, 365) or 7
end

local function expireNow(force)
    local now = GetGameTimer()
    if not force and now - lastExpire < 30000 then return end
    lastExpire = now
    local n = Db.update("UPDATE `vr_mdt_warrants` SET `status` = 'expired' WHERE `status` = 'active' AND `expires_at` <= ?", { U.now() })
    if n and n > 0 then
        Push.dept('police', 'warrants:changed', { expired = n })
        Push.dept('doj', 'warrants:changed', { expired = n })
    end
end
Warrants.expire = expireNow

local function shape(r)
    local status = r.status
    if status == 'active' and r.expires_at and tonumber(r.expires_at) <= U.now() then status = 'expired' end
    return {
        id = r.id,
        cid = r.cid,
        name = r.name,
        reason = r.reason,
        charges = U.decode(r.charges, {}),
        report_id = r.report_id,
        status = status,
        created_by_cid = r.created_by_cid,
        created_by_name = r.created_by_name,
        approved_by_cid = r.approved_by_cid,
        approved_by_name = r.approved_by_name,
        decision_note = r.decision_note,
        closed_by_name = r.closed_by_name,
        created_at = r.created_at,
        decided_at = r.decided_at,
        expires_at = r.expires_at,
        served_at = r.served_at,
    }
end

local function load(id)
    local r = Db.single('SELECT * FROM `vr_mdt_warrants` WHERE `id` = ?', { id })
    return r and shape(r) or nil
end

local function changed(w, action)
    local payload = { id = w.id, cid = w.cid, status = w.status, action = action }
    Push.dept('police', 'warrants:changed', payload)
    Push.dept('doj', 'warrants:changed', payload)
    TriggerEvent('vr-mdt:server:warrantChanged', w, action)
end

function Warrants.forCitizen(cid)
    cid = V.cid(cid)
    if not cid then return {} end
    expireNow()
    local rows = Db.query('SELECT * FROM `vr_mdt_warrants` WHERE `cid` = ? ORDER BY `id` DESC LIMIT 50', { cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = shape(r) end
    return out
end

function Warrants.activeCids(cids)
    local out = {}
    if #cids == 0 then return out end
    local params = { U.now() }
    for _, c in ipairs(cids) do params[#params + 1] = c end
    local rows = Db.query(("SELECT DISTINCT `cid` FROM `vr_mdt_warrants` WHERE `status` = 'active' AND `expires_at` > ? AND `cid` IN (%s)"):format(Records.placeholders(#cids)), params) or {}
    for _, r in ipairs(rows) do out[r.cid] = true end
    return out
end

function Warrants.approverOnline()
    for _, ctx in ipairs(Core.onlineContexts()) do
        if Core.can(ctx, 'warrants.approve') then return true end
    end
    return false
end

function Warrants.canDecide(ctx)
    if Core.can(ctx, 'warrants.approve') then return true, false end
    if ctx.dept ~= 'police' then return false, false end
    local grade = V.int(Config.Warrants.selfApproveGrade, 0, 100) or 3
    if not ctx.isboss and (ctx.grade or 0) < grade then return false, false end
    if Warrants.approverOnline() then return false, false end
    return true, true
end

local function canRevoke(ctx, w)
    if Core.can(ctx, 'warrants.approve') then return true end
    if ctx.dept == 'police' and ctx.isboss then return true end
    if w.approved_by_cid and w.approved_by_cid == ctx.cid then return true end
    if w.status == 'pending' and w.created_by_cid == ctx.cid then return true end
    return false
end

local function cleanCharges(list)
    if list == nil then return {} end
    if not Records.isList(list) or #list > 25 then return nil end
    local out = {}
    for _, e in ipairs(list) do
        if type(e) ~= 'table' then return nil end
        local id = V.id(e.id)
        local title = V.str(e.title, 96)
        local count = e.count == nil and 1 or V.int(e.count, 1, 20)
        if not count then return nil end
        if id and Penal and Penal.get then
            local ok, charge = pcall(Penal.get, id)
            if ok and type(charge) == 'table' then title = V.str(charge.title, 96) or title end
        end
        if not title then return nil end
        out[#out + 1] = { id = id, title = title, count = count }
    end
    return out
end

local function notifyCid(cid, msg, kind)
    local p = Core.playerByCid(cid)
    if p then Core.notify(p.source, msg, kind) end
end

Api.register('warrants.list', { 'records.view', 'warrants.approve' }, function(src, ctx, data)
    local filter = data.status == nil and 'all' or V.enum(data.status, { 'all', 'pending', 'active', 'history' })
    local q = data.q ~= nil and data.q ~= '' and V.str(data.q, 48) or nil
    local page = data.page == nil and 1 or V.int(data.page, 1, 1000)
    if not filter or not page or (data.q ~= nil and data.q ~= '' and not q) then return false, 'bad_request' end
    expireNow()
    local where, params = {}, {}
    if filter == 'pending' or filter == 'active' then
        where[#where + 1] = '`status` = ?'
        params[#params + 1] = filter
    elseif filter == 'history' then
        where[#where + 1] = ("`status` IN (%s)"):format(Records.placeholders(#HISTORY))
        for _, s in ipairs(HISTORY) do params[#params + 1] = s end
    end
    if q then
        local like = U.like(q)
        where[#where + 1] = '(LOWER(`name`) LIKE LOWER(?) OR `cid` = ? OR LOWER(`reason`) LIKE LOWER(?))'
        params[#params + 1] = like
        params[#params + 1] = q:upper()
        params[#params + 1] = like
    end
    params[#params + 1] = PAGE + 1
    params[#params + 1] = (page - 1) * PAGE
    local sql = ('SELECT * FROM `vr_mdt_warrants` %s ORDER BY %s LIMIT ? OFFSET ?'):format(
        #where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or '',
        filter == 'active' and '`expires_at` ASC' or '`id` DESC')
    local rows = Db.query(sql, params)
    if not rows then return false, 'server_error' end
    local items = {}
    for i = 1, math.min(#rows, PAGE) do items[#items + 1] = shape(rows[i]) end
    local counts = Db.query("SELECT `status`, COUNT(*) AS `n` FROM `vr_mdt_warrants` WHERE `status` IN ('pending', 'active') GROUP BY `status`") or {}
    local c = { pending = 0, active = 0 }
    for _, r in ipairs(counts) do c[r.status] = tonumber(r.n) or 0 end
    local decide, fallback = Warrants.canDecide(ctx)
    return true, { items = items, more = #rows > PAGE, page = page, counts = c, canDecide = decide, fallback = fallback, days = days() }
end, { rate = 300 })

Api.register('warrants.get', { 'records.view', 'warrants.approve' }, function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    expireNow()
    local w = load(id)
    if not w then return false, 'not_found' end
    return true, w
end, { rate = 200 })

Api.register('warrants.create', 'warrants.create', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local reason = V.text(data.reason, 2000, 3)
    local charges = cleanCharges(data.charges)
    local reportId = data.reportId ~= nil and V.id(data.reportId) or nil
    if not cid or not reason or not charges or (data.reportId ~= nil and not reportId) then return false, 'bad_request' end
    local name = Core.nameOf(cid)
    if not name then return false, 'not_found' end
    local id = Db.insert([[INSERT INTO `vr_mdt_warrants` (`cid`, `name`, `reason`, `charges`, `report_id`, `status`, `created_by_cid`, `created_by_name`, `created_at`)
        VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)]], { cid, name, reason, json.encode(charges), reportId, ctx.cid, ctx.name, U.now() })
    if not id then return false, 'save_failed' end
    local w = load(id)
    Audit.log(ctx, 'warrants.create', id, { cid = cid, charges = #charges })
    changed(w, 'created')
    for _, other in ipairs(Core.onlineContexts()) do
        if Core.can(other, 'warrants.approve') then
            Core.notify(other.src, ('New warrant request for %s.'):format(name), 'primary')
        end
    end
    return true, w
end, { rate = 2000 })

Api.register('warrants.decide', { 'warrants.approve', 'warrants.create' }, function(src, ctx, data)
    local id = V.id(data.id)
    local approve = V.bool(data.approve)
    local note = data.note ~= nil and data.note ~= '' and V.text(data.note, 500) or nil
    if not id or approve == nil or (data.note ~= nil and data.note ~= '' and not note) then return false, 'bad_request' end
    if not approve and not note then return false, 'note_required' end
    local allowed, fallback = Warrants.canDecide(ctx)
    if not allowed then return false, 'not_allowed' end
    local w = load(id)
    if not w then return false, 'not_found' end
    if w.status ~= 'pending' then return false, 'not_pending' end
    local now = U.now()
    local n
    if approve then
        n = Db.update([[UPDATE `vr_mdt_warrants` SET `status` = 'active', `approved_by_cid` = ?, `approved_by_name` = ?, `decision_note` = ?, `decided_at` = ?, `expires_at` = ?
            WHERE `id` = ? AND `status` = 'pending']], { ctx.cid, ctx.name, note, now, now + days() * 86400, id })
    else
        n = Db.update([[UPDATE `vr_mdt_warrants` SET `status` = 'denied', `approved_by_cid` = ?, `approved_by_name` = ?, `decision_note` = ?, `decided_at` = ?
            WHERE `id` = ? AND `status` = 'pending']], { ctx.cid, ctx.name, note, now, id })
    end
    if n == nil then return false, 'save_failed' end
    if n == 0 then return false, 'not_pending' end
    w = load(id)
    Audit.log(ctx, approve and 'warrants.approve' or 'warrants.deny', id, { cid = w.cid, fallback = fallback or nil, note = note })
    changed(w, approve and 'approved' or 'denied')
    if w.created_by_cid then
        notifyCid(w.created_by_cid, ('Your warrant for %s was %s.'):format(w.name, approve and 'approved' or 'denied'), approve and 'success' or 'error')
    end
    return true, w
end, { rate = 800 })

Api.register('warrants.serve', 'warrants.create', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local w = load(id)
    if not w then return false, 'not_found' end
    if w.status ~= 'active' then return false, 'not_active' end
    local n = Db.update([[UPDATE `vr_mdt_warrants` SET `status` = 'served', `served_at` = ?, `closed_by_name` = ? WHERE `id` = ? AND `status` = 'active' AND `expires_at` > ?]],
        { U.now(), ctx.name, id, U.now() })
    if n == nil then return false, 'save_failed' end
    if n == 0 then return false, 'not_active' end
    w = load(id)
    Audit.log(ctx, 'warrants.serve', id, { cid = w.cid })
    changed(w, 'served')
    return true, w
end, { rate = 800 })

Api.register('warrants.revoke', { 'warrants.approve', 'warrants.create' }, function(src, ctx, data)
    local id = V.id(data.id)
    local note = data.note ~= nil and data.note ~= '' and V.text(data.note, 500) or nil
    if not id or (data.note ~= nil and data.note ~= '' and not note) then return false, 'bad_request' end
    local w = load(id)
    if not w then return false, 'not_found' end
    if w.status ~= 'pending' and w.status ~= 'active' then return false, 'not_active' end
    if not canRevoke(ctx, w) then return false, 'not_allowed' end
    local n = Db.update([[UPDATE `vr_mdt_warrants` SET `status` = 'revoked', `closed_by_name` = ?, `decision_note` = COALESCE(?, `decision_note`), `decided_at` = COALESCE(`decided_at`, ?)
        WHERE `id` = ? AND `status` IN ('pending', 'active')]], { ctx.name, note, U.now(), id })
    if n == nil then return false, 'save_failed' end
    if n == 0 then return false, 'not_active' end
    w = load(id)
    Audit.log(ctx, 'warrants.revoke', id, { cid = w.cid, note = note })
    changed(w, 'revoked')
    return true, w
end, { rate = 800 })

local function boloShape(r)
    return {
        id = r.id,
        kind = r.kind,
        subject = r.subject,
        plate = r.plate,
        cid = r.cid,
        title = r.title,
        details = r.details,
        status = r.status,
        created_by_cid = r.created_by_cid,
        created_by_name = r.created_by_name,
        created_at = r.created_at,
        closed_at = r.closed_at,
        closed_by_name = r.closed_by_name,
    }
end

local function sortedActive()
    local out = {}
    for _, b in pairs(activeBolos) do out[#out + 1] = U.copy(b) end
    table.sort(out, function(a, b) return a.id > b.id end)
    return out
end

function Bolos.active()
    return sortedActive()
end

function Bolos.forPlate(plate)
    plate = V.plate(plate)
    local out = {}
    if not plate then return out end
    for _, b in ipairs(sortedActive()) do
        if b.plate == plate then out[#out + 1] = b end
    end
    return out
end

function Bolos.forCitizen(cid)
    local out = {}
    if not V.cid(cid) then return out end
    for _, b in ipairs(sortedActive()) do
        if b.cid == cid then out[#out + 1] = b end
    end
    return out
end

local function boloChanged(b, action)
    local payload = { id = b.id, status = b.status, action = action }
    Push.dept('police', 'bolos:changed', payload)
    Push.dept('doj', 'bolos:changed', payload)
    TriggerEvent('vr-mdt:server:boloChanged', b, action)
end

Api.register('bolos.list', { 'records.view', 'bolos.manage' }, function(src, ctx, data)
    local status = data.status == nil and 'active' or V.enum(data.status, { 'active', 'closed' })
    local page = data.page == nil and 1 or V.int(data.page, 1, 1000)
    if not status or not page then return false, 'bad_request' end
    if status == 'active' then return true, { items = sortedActive(), more = false, page = 1 } end
    local rows = Db.query("SELECT * FROM `vr_mdt_bolos` WHERE `status` = 'closed' ORDER BY `closed_at` DESC, `id` DESC LIMIT ? OFFSET ?", { PAGE + 1, (page - 1) * PAGE })
    if not rows then return false, 'server_error' end
    local items = {}
    for i = 1, math.min(#rows, PAGE) do items[#items + 1] = boloShape(rows[i]) end
    return true, { items = items, more = #rows > PAGE, page = page }
end, { rate = 300 })

Api.register('bolos.create', 'bolos.manage', function(src, ctx, data)
    local kind = V.enum(data.kind, BOLO_KINDS)
    local title = V.str(data.title, 96, 3)
    local details = data.details ~= nil and data.details ~= '' and V.text(data.details, 2000) or nil
    local subject = data.subject ~= nil and data.subject ~= '' and V.str(data.subject, 96) or nil
    local plate = data.plate ~= nil and data.plate ~= '' and V.plate(data.plate) or nil
    local cid = data.cid ~= nil and data.cid ~= '' and V.cid(data.cid) or nil
    if not kind or not title then return false, 'bad_request' end
    if (data.details ~= nil and data.details ~= '' and not details) or (data.subject ~= nil and data.subject ~= '' and not subject)
        or (data.plate ~= nil and data.plate ~= '' and not plate) or (data.cid ~= nil and data.cid ~= '' and not cid) then
        return false, 'bad_request'
    end
    if kind ~= 'vehicle' then plate = nil end
    if kind ~= 'person' then cid = nil end
    if cid then
        local name = Core.nameOf(cid)
        if not name then return false, 'not_found' end
        subject = subject or name
    end
    if plate and not subject then
        local row = Bridge.vehicles.byPlate and Bridge.vehicles.byPlate(plate)
        subject = row and ('%s %s'):format(Records.vehicleLabel(row.model), plate) or plate
    end
    local now = U.now()
    local id = Db.insert([[INSERT INTO `vr_mdt_bolos` (`kind`, `subject`, `plate`, `cid`, `title`, `details`, `status`, `created_by_cid`, `created_by_name`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)]], { kind, subject, plate, cid, title, details, ctx.cid, ctx.name, now })
    if not id then return false, 'save_failed' end
    local b = { id = id, kind = kind, subject = subject, plate = plate, cid = cid, title = title, details = details, status = 'active',
        created_by_cid = ctx.cid, created_by_name = ctx.name, created_at = now }
    activeBolos[id] = b
    Audit.log(ctx, 'bolos.create', id, { kind = kind, title = title, plate = plate, cid = cid })
    boloChanged(b, 'created')
    return true, U.copy(b)
end, { rate = 1500 })

Api.register('bolos.close', 'bolos.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local n = Db.update("UPDATE `vr_mdt_bolos` SET `status` = 'closed', `closed_at` = ?, `closed_by_name` = ? WHERE `id` = ? AND `status` = 'active'", { U.now(), ctx.name, id })
    if n == nil then return false, 'save_failed' end
    if n == 0 then
        if Db.scalar('SELECT 1 FROM `vr_mdt_bolos` WHERE `id` = ?', { id }) then return false, 'not_active' end
        return false, 'not_found'
    end
    activeBolos[id] = nil
    local r = Db.single('SELECT * FROM `vr_mdt_bolos` WHERE `id` = ?', { id })
    local b = r and boloShape(r) or { id = id, status = 'closed' }
    Audit.log(ctx, 'bolos.close', id)
    boloChanged(b, 'closed')
    return true, b
end, { rate = 800 })

Db.ready(function()
    expireNow(true)
    local rows = Db.query("SELECT * FROM `vr_mdt_bolos` WHERE `status` = 'active' ORDER BY `id` DESC LIMIT 500") or {}
    for _, r in ipairs(rows) do activeBolos[r.id] = boloShape(r) end
end)

CreateThread(function()
    while true do
        Wait(60000)
        if Db.isReady() then expireNow(true) end
    end
end)
