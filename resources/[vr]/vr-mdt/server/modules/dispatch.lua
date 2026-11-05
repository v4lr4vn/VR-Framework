Dispatch = {}

local calls = {}
local byId = {}
local nextId = 1
local clientAlerts = {}
local lastEmergency = {}
local alertCooldown = {}

local MAX_INFO = 8
local MAX_NOTES = 60

Db.schema('calls', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_calls` (
        `id` INT UNSIGNED NOT NULL,
        `code` VARCHAR(16) NOT NULL,
        `title` VARCHAR(64) NOT NULL,
        `priority` TINYINT UNSIGNED NOT NULL,
        `description` TEXT DEFAULT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `jobs` VARCHAR(255) NOT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `closed_at` INT UNSIGNED DEFAULT NULL,
        `data` LONGTEXT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local responderTypes = { leo = true, ems = true }

local function visibleTo(call, ctx)
    if not ctx or not Units.seesDispatch(ctx) then return false end
    if ctx.dept == 'dispatch' then return true end
    for _, j in ipairs(call.jobs) do
        if j == ctx.deptType or j == ctx.job then return true end
    end
    return false
end
Dispatch.visibleTo = visibleTo

local function unitList(call)
    local out = {}
    for _, u in pairs(call.units) do out[#out + 1] = u end
    table.sort(out, function(a, b) return a.attachedAt < b.attachedAt end)
    return out
end

local function payload(call)
    return {
        id = call.id,
        codeName = call.codeName,
        code = call.code,
        title = call.title,
        description = call.description,
        priority = call.priority,
        icon = call.icon,
        coords = call.coords,
        street = call.street,
        info = call.info,
        caller = call.caller,
        jobs = call.jobs,
        units = unitList(call),
        notes = call.notes,
        status = call.status,
        createdAt = call.createdAt,
        closedAt = call.closedAt,
        closedBy = call.closedBy,
        origin = call.origin,
        blip = call.blip,
    }
end
Dispatch.payload = payload

local function persist(call)
    local data = json.encode({ codeName = call.codeName, info = call.info, caller = call.caller, notes = call.notes, units = unitList(call), origin = call.origin, street = call.street, closedBy = call.closedBy })
    CreateThread(function()
        Db.update([[INSERT INTO `vr_mdt_calls` (`id`, `code`, `title`, `priority`, `description`, `x`, `y`, `z`, `jobs`, `created_at`, `closed_at`, `data`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `priority` = VALUES(`priority`), `description` = VALUES(`description`), `closed_at` = VALUES(`closed_at`), `data` = VALUES(`data`)]],
            { call.id, call.code, call.title, call.priority, call.description, call.coords.x, call.coords.y, call.coords.z, table.concat(call.jobs, ','), call.createdAt, call.closedAt, data })
    end)
end

local function pushCall(call)
    local p = payload(call)
    Push.where(function(ctx) return visibleTo(call, ctx) end, 'dispatch:call', p)
    TriggerEvent('vr-mdt:server:callUpdated', p)
end

local function trim()
    local active, closed = 0, 0
    for i = #calls, 1, -1 do
        local c = calls[i]
        if c.status == 'closed' then
            closed = closed + 1
            if closed > Config.Dispatch.keepClosed then
                table.remove(calls, i)
                byId[c.id] = nil
                Push.where(function(ctx) return visibleTo(c, ctx) end, 'dispatch:remove', { id = c.id })
            end
        else
            active = active + 1
            if active > Config.Dispatch.maxCalls then
                c.status = 'closed'
                c.closedAt = U.now()
                persist(c)
                pushCall(c)
            end
        end
    end
end

local function cleanJobs(jobs, fallback)
    if type(jobs) == 'string' then jobs = { jobs } end
    if type(jobs) ~= 'table' then return fallback end
    local out, seen = {}, {}
    for i = 1, math.min(#jobs, 8) do
        local j = V.str(jobs[i], 32)
        j = j and j:lower()
        local info = j and Bridge.jobs()[j]
        if j and not seen[j] and (responderTypes[j] or (info and responderTypes[info.type])) then
            seen[j] = true
            out[#out + 1] = j
        end
    end
    return #out > 0 and out or fallback
end

local function cleanInfo(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i = 1, math.min(#list, MAX_INFO) do
        local e = list[i]
        if type(e) == 'table' then
            local label, value = V.str(e.label, 24), V.str(e.value, 80)
            if label and value then out[#out + 1] = { label = label, value = value } end
        end
    end
    return out
end

local function cleanBlip(b, fallback)
    if type(b) ~= 'table' then return fallback end
    return {
        sprite = V.int(b.sprite, 1, 900) or fallback.sprite,
        color = V.int(b.color, 0, 85) or fallback.color,
        scale = V.num(b.scale, 0.3, 2.0) or fallback.scale,
        flash = b.flash == true,
    }
end

local LEGACY_INFO = {
    { 'gender', 'Gender' }, { 'vehicle', 'Vehicle' }, { 'plate', 'Plate' }, { 'color', 'Colour' },
    { 'weapon', 'Weapon' }, { 'heading', 'Heading' }, { 'doors', 'Doors' }, { 'class', 'Class' },
    { 'speed', 'Speed' }, { 'number', 'Phone' }, { 'name', 'Name' },
}

local function legacyInfo(data)
    local info = {}
    for _, f in ipairs(LEGACY_INFO) do
        local v = data[f[1]]
        if type(v) == 'number' then v = tostring(v) end
        v = V.str(v, 80)
        if v then info[#info + 1] = { label = f[2], value = v } end
    end
    return info
end

local function iconOf(value)
    local icon = V.str(value, 24)
    if not icon or not icon:match('^[%l%d%-]+$') or icon:sub(1, 3) == 'fa-' then return nil end
    return icon
end

function Dispatch.create(data, opts)
    if type(data) ~= 'table' then return nil end
    opts = opts or {}
    local codeName = V.str(data.codeName, 32)
    local preset = Codes[codeName or ''] or Codes.custom
    local coords = V.vec(data.coords)
    if not coords and opts.src then
        local ped = GetPlayerPed(opts.src)
        if ped and ped ~= 0 then coords = U.vec(GetEntityCoords(ped)) end
    end
    if not coords then return nil end

    local info = cleanInfo(data.info)
    if #info == 0 then info = legacyInfo(data) end

    local call = {
        id = nextId,
        codeName = codeName or 'custom',
        code = V.str(data.code, 16) or preset.code,
        title = V.str(data.title, 64) or V.str(data.message, 64) or preset.title,
        description = V.text(data.description or data.information, 600),
        priority = V.int(data.priority, 1, 3) or preset.priority,
        icon = iconOf(data.icon) or preset.icon,
        coords = { x = U.round(coords.x, 2), y = U.round(coords.y, 2), z = U.round(coords.z, 2) },
        street = V.str(data.street, 96),
        info = info,
        caller = opts.caller,
        jobs = opts.jobs or cleanJobs(data.jobs, preset.jobs),
        units = {},
        notes = {},
        status = 'active',
        createdAt = U.now(),
        origin = opts.origin or 'export',
        blip = cleanBlip(data.blip or data.alert, preset.blip),
    }
    nextId = nextId + 1
    calls[#calls + 1] = call
    byId[call.id] = call
    persist(call)

    local p = payload(call)
    for _, ctx in ipairs(Core.onlineContexts()) do
        if visibleTo(call, ctx) then
            TriggerClientEvent('vr-mdt:client:alert', ctx.src, p)
        end
    end
    TriggerEvent('vr-mdt:server:callCreated', p)
    trim()
    return call
end

function Dispatch.get(id)
    return byId[id]
end

function Dispatch.list(ctx)
    local active, closed = {}, {}
    for i = #calls, 1, -1 do
        local c = calls[i]
        if visibleTo(c, ctx) then
            if c.status == 'closed' then closed[#closed + 1] = payload(c) else active[#active + 1] = payload(c) end
        end
    end
    return active, closed
end

local function unitEntry(ctx)
    return {
        cid = ctx.cid,
        name = ctx.name,
        callsign = ctx.callsign,
        dept = ctx.dept,
        attachedAt = U.now(),
    }
end

local function addNote(call, ctx, text, system)
    call.notes[#call.notes + 1] = {
        at = U.now(),
        cid = ctx and ctx.cid or nil,
        name = ctx and ctx.name or nil,
        callsign = ctx and ctx.callsign or nil,
        text = text,
        system = system == true,
    }
    while #call.notes > MAX_NOTES do table.remove(call.notes, 1) end
end

local function label(ctx)
    return ctx.callsign or ctx.name
end

function Dispatch.attach(ctx, call)
    if call.units[ctx.cid] then return true end
    for _, c in ipairs(calls) do
        if c ~= call and c.units[ctx.cid] and c.status ~= 'closed' then
            c.units[ctx.cid] = nil
            addNote(c, ctx, ('%s detached'):format(label(ctx)), true)
            persist(c)
            pushCall(c)
        end
    end
    call.units[ctx.cid] = unitEntry(ctx)
    addNote(call, ctx, ('%s attached'):format(label(ctx)), true)
    Units.set(ctx, 'enroute', call.id)
    persist(call)
    pushCall(call)
    return true
end

function Dispatch.detach(ctx, call)
    if not call.units[ctx.cid] then return true end
    call.units[ctx.cid] = nil
    addNote(call, ctx, ('%s detached'):format(label(ctx)), true)
    local u = Units.get(ctx.cid)
    if u and u.callId == call.id then Units.set(ctx, 'available', nil) end
    persist(call)
    pushCall(call)
    return true
end

local function close(call, ctx)
    call.status = 'closed'
    call.closedAt = U.now()
    call.closedBy = ctx and label(ctx) or nil
    addNote(call, ctx, ctx and ('Closed by %s'):format(label(ctx)) or 'Closed', true)
    for cid in pairs(call.units) do
        local p = Core.playerByCid(cid)
        local uctx = p and Core.context(p.source)
        local u = Units.get(cid)
        if uctx and u and u.callId == call.id then Units.set(uctx, 'available', nil) end
    end
    persist(call)
    pushCall(call)
    trim()
end

local function findVisible(ctx, id)
    id = V.id(id)
    local call = id and byId[id]
    if not call or not visibleTo(call, ctx) then return nil end
    return call
end

Api.register('dispatch.list', nil, function(src, ctx)
    if not Units.seesDispatch(ctx) then return false, 'not_allowed' end
    local active, closed = Dispatch.list(ctx)
    return true, { active = active, closed = closed, units = Units.list(), me = Units.entry(ctx) }
end, { rate = 400 })

Api.register('dispatch.get', nil, function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    if not call then return false, 'not_found' end
    return true, payload(call)
end, { rate = 100 })

Api.register('dispatch.attach', nil, function(src, ctx, data)
    if not Units.isUnit(ctx) then return false, 'not_a_unit' end
    local call = findVisible(ctx, data.id)
    if not call then return false, 'not_found' end
    if call.status == 'closed' then return false, 'call_closed' end
    Dispatch.attach(ctx, call)
    return true, payload(call)
end, { rate = 400 })

Api.register('dispatch.detach', nil, function(src, ctx, data)
    if not Units.isUnit(ctx) then return false, 'not_a_unit' end
    local call = findVisible(ctx, data.id)
    if not call then return false, 'not_found' end
    Dispatch.detach(ctx, call)
    return true, payload(call)
end, { rate = 400 })

Api.register('dispatch.assign', 'dispatch.manage', function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    local cid = V.cid(data.cid)
    if not call or not cid then return false, 'not_found' end
    if call.status == 'closed' then return false, 'call_closed' end
    local p = Core.playerByCid(cid)
    local target = p and Core.context(p.source)
    if not target or not Units.isUnit(target) then return false, 'unit_unavailable' end
    if not visibleTo(call, target) then
        if ctx.dept ~= 'dispatch' then return false, 'unit_unavailable' end
        local jobs = {}
        for _, j in ipairs(call.jobs or {}) do jobs[#jobs + 1] = j end
        jobs[#jobs + 1] = target.deptType
        call.jobs = jobs
        addNote(call, ctx, ('%s added %s to this call'):format(label(ctx), Config.Departments[target.dept].short or target.dept), true)
        local p2 = payload(call)
        for _, other in ipairs(Core.onlineContexts()) do
            if other.dept == target.dept and other.src ~= target.src and visibleTo(call, other) then
                TriggerClientEvent('vr-mdt:client:alert', other.src, p2)
            end
        end
    end
    Dispatch.attach(target, call)
    addNote(call, ctx, ('%s assigned %s'):format(label(ctx), label(target)), true)
    Core.notify(target.src, ('You were assigned to %s %s'):format(call.code, call.title), 'primary')
    TriggerClientEvent('vr-mdt:client:assigned', target.src, payload(call))
    Audit.log(ctx, 'dispatch.assign', call.id, { cid = cid })
    return true, payload(call)
end, { rate = 300 })

Api.register('dispatch.unassign', 'dispatch.manage', function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    local cid = V.cid(data.cid)
    if not call or not cid then return false, 'not_found' end
    local u = call.units[cid]
    if not u then return true, payload(call) end
    local p = Core.playerByCid(cid)
    local target = p and Core.context(p.source)
    if target then
        Dispatch.detach(target, call)
    else
        call.units[cid] = nil
        persist(call)
        pushCall(call)
    end
    Audit.log(ctx, 'dispatch.unassign', call.id, { cid = cid })
    return true, payload(call)
end, { rate = 300 })

Api.register('dispatch.note', nil, function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    local text = V.str(data.text, 250)
    if not call then return false, 'not_found' end
    if not text then return false, 'bad_request' end
    addNote(call, ctx, text, false)
    persist(call)
    pushCall(call)
    return true, payload(call)
end, { rate = 800 })

Api.register('dispatch.priority', 'dispatch.manage', function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    local p = V.int(data.priority, 1, 3)
    if not call or not p then return false, 'bad_request' end
    if call.priority ~= p then
        call.priority = p
        addNote(call, ctx, ('Priority set to %d by %s'):format(p, label(ctx)), true)
        persist(call)
        pushCall(call)
    end
    return true, payload(call)
end, { rate = 300 })

Api.register('dispatch.close', nil, function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    if not call then return false, 'not_found' end
    if call.status == 'closed' then return true, payload(call) end
    if not call.units[ctx.cid] and not Core.can(ctx, 'dispatch.manage') then return false, 'not_allowed' end
    close(call, ctx)
    Audit.log(ctx, 'dispatch.close', call.id)
    return true, payload(call)
end, { rate = 400 })

Api.register('dispatch.reopen', 'dispatch.manage', function(src, ctx, data)
    local call = findVisible(ctx, data.id)
    if not call then return false, 'not_found' end
    if call.status ~= 'closed' then return true, payload(call) end
    call.status = 'active'
    call.closedAt = nil
    call.closedBy = nil
    addNote(call, ctx, ('Reopened by %s'):format(label(ctx)), true)
    persist(call)
    pushCall(call)
    Audit.log(ctx, 'dispatch.reopen', call.id)
    return true, payload(call)
end, { rate = 400 })

Api.register('dispatch.create', 'dispatch.manage', function(src, ctx, data)
    local title = V.str(data.title, 64)
    local coords = V.vec(data.coords)
    if not title then return false, 'bad_request' end
    local jobs = cleanJobs(data.jobs, ctx.dept == 'dispatch' and { 'leo', 'ems' } or { ctx.deptType })
    local call = Dispatch.create({
        codeName = 'custom',
        code = V.str(data.code, 16) or '10-00',
        title = title,
        description = data.description,
        priority = V.int(data.priority, 1, 3) or 2,
        coords = coords,
        street = data.street,
    }, { src = src, jobs = jobs, origin = 'manual' })
    if not call then return false, 'bad_request' end
    addNote(call, ctx, ('Created by %s'):format(label(ctx)), true)
    persist(call)
    pushCall(call)
    Audit.log(ctx, 'dispatch.create', call.id, { title = call.title })
    return true, payload(call)
end, { rate = 1000 })

Api.register('dispatch.history', nil, function(src, ctx, data)
    if not Units.seesDispatch(ctx) then return false, 'not_allowed' end
    local page = V.int(data.page, 1, 500) or 1
    local a, b = ctx.deptType, ctx.job
    if ctx.dept == 'dispatch' then a, b = 'leo', 'ems' end
    local rows = Db.query([[SELECT `id`, `code`, `title`, `priority`, `description`, `x`, `y`, `z`, `jobs`, `created_at`, `closed_at` FROM `vr_mdt_calls`
        WHERE FIND_IN_SET(?, `jobs`) > 0 OR FIND_IN_SET(?, `jobs`) > 0 ORDER BY `id` DESC LIMIT 50 OFFSET ?]], { a, b, (page - 1) * 50 })
    if not rows then return false, 'server_error' end
    return true, rows
end, { rate = 400 })

local function allowClientAlert(src)
    local now = GetGameTimer()
    local limit = Config.Dispatch.clientAlertLimit
    local log = clientAlerts[src] or {}
    local keep = {}
    for _, t in ipairs(log) do
        if now - t < limit.seconds * 1000 then keep[#keep + 1] = t end
    end
    if #keep >= limit.count then
        clientAlerts[src] = keep
        return false
    end
    keep[#keep + 1] = now
    clientAlerts[src] = keep
    return true
end

local function senderCoords(src, given)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local here = GetEntityCoords(ped)
    local c = V.vec(given)
    if c and #(vector3(c.x, c.y, c.z) - here) <= Config.Dispatch.maxAlertDistance then return c end
    return U.vec(here)
end

local function isResponder(src)
    local ctx = Core.context(src)
    return ctx ~= nil and Units.seesDispatch(ctx), ctx
end

RegisterNetEvent('vr-mdt:server:alert', function(codeName, data)
    local src = source
    if type(codeName) ~= 'string' or type(data) ~= 'table' then return end
    local preset = Codes[codeName]
    if not preset then return end
    local responder, ctx = isResponder(src)
    if preset.reserved and not responder then return end
    if not allowClientAlert(src) then return end
    local key = src .. ':' .. codeName
    local now = GetGameTimer()
    if alertCooldown[key] and now - alertCooldown[key] < (Config.AutoAlerts.cooldown or 20) * 1000 and codeName ~= 'custom' then return end
    alertCooldown[key] = now
    local coords = senderCoords(src, data.coords)
    if not coords then return end
    local clean = {
        codeName = codeName,
        coords = coords,
        street = data.street,
        info = data.info,
        description = codeName == 'custom' and data.description or nil,
        title = codeName == 'custom' and data.title or nil,
        code = codeName == 'custom' and data.code or nil,
    }
    local jobs = preset.jobs
    if codeName == 'custom' then jobs = cleanJobs(data.jobs, preset.jobs) end
    local caller
    if preset.reserved and ctx then caller = { name = ctx.name, callsign = ctx.callsign } end
    Dispatch.create(clean, { jobs = jobs, origin = 'auto', caller = caller })
end)

local function phoneOk(src)
    local items = Config.Dispatch.phoneItems
    if not items or #items == 0 or Bridge.inventoryName == 'none' then return true end
    for _, item in ipairs(items) do
        local ok, n = pcall(Bridge.inventory.count, src, item)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    return false
end

function Dispatch.emergency(src, kind, anonymous, text, street)
    local player = Core.player(src)
    if not player then return false, 'not_loaded' end
    local status = Bridge.status(src)
    if status.cuffed then return false, 'cuffed' end
    if status.dead then return false, 'cant_now' end
    if not phoneOk(src) then return false, 'no_phone' end
    local msg = V.text(text, 300)
    if not msg then return false, 'empty_message' end
    local now = GetGameTimer()
    if lastEmergency[src] and now - lastEmergency[src] < Config.Dispatch.emergencyCooldown * 1000 then return false, 'cooldown' end
    lastEmergency[src] = now
    local codeName = kind == '311' and '311call' or '911call'
    local caller = anonymous and { anonymous = true } or { name = player.name, phone = V.str(player.phone, 20) }
    local call = Dispatch.create({ codeName = codeName, description = msg, street = street }, {
        src = src,
        jobs = Config.Dispatch.emergency[kind] or Codes[codeName].jobs,
        origin = kind,
        caller = caller,
    })
    if not call then return false, 'server_error' end
    return true, call.id
end

RegisterNetEvent('vr-mdt:server:emergency', function(kind, anonymous, text, street)
    local src = source
    if kind ~= '911' and kind ~= '311' then return end
    local ok, err = Dispatch.emergency(src, kind, anonymous == true, text, V.str(street, 96))
    if ok then
        Core.notify(src, kind == '911' and 'Your 911 call was sent.' or 'Your 311 call was sent.', 'success')
    else
        local msg = ({
            cuffed = "You can't call while handcuffed.",
            cant_now = "You can't call right now.",
            no_phone = 'You need a phone.',
            empty_message = 'Say what the emergency is.',
            cooldown = 'Wait a moment before calling again.',
        })[err] or "The call didn't go through."
        Core.notify(src, msg, 'error')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    clientAlerts[src] = nil
    lastEmergency[src] = nil
    local prefix = src .. ':'
    for k in pairs(alertCooldown) do
        if k:sub(1, #prefix) == prefix then alertCooldown[k] = nil end
    end
end)

local ALIASES = { 'vr-dispatch', 'ps-dispatch' }

Core.exportAs('SendAlert', function(data, src)
    local call = Dispatch.create(data, { src = tonumber(src), origin = 'export' })
    return call and call.id or nil
end, ALIASES)

Core.exportAs('GetDispatchCalls', function()
    local out = {}
    for _, c in ipairs(calls) do out[#out + 1] = payload(c) end
    return out
end, ALIASES)

Core.exportAs('GetDispatchCall', function(id)
    local c = byId[tonumber(id) or -1]
    return c and payload(c) or nil
end, ALIASES)

Core.exportAs('AddCallResponse', function(src, id, message)
    local ctx = Core.context(tonumber(src) or -1)
    local c = byId[tonumber(id) or -1]
    local text = V.str(message, 250)
    if not ctx or not c or not text then return false end
    addNote(c, ctx, text, false)
    persist(c)
    pushCall(c)
    return true
end, ALIASES)

Core.exportAs('AttachUnit', function(src, id)
    local ctx = Core.context(tonumber(src) or -1)
    local c = byId[tonumber(id) or -1]
    if not ctx or not c or not visibleTo(c, ctx) then return false end
    return Dispatch.attach(ctx, c)
end, ALIASES)

Core.exportAs('DetachUnit', function(src, id)
    local ctx = Core.context(tonumber(src) or -1)
    local c = byId[tonumber(id) or -1]
    if not ctx or not c then return false end
    return Dispatch.detach(ctx, c)
end, ALIASES)

Db.ready(function()
    local maxId = tonumber(Db.scalar('SELECT MAX(`id`) FROM `vr_mdt_calls`')) or 0
    if maxId >= nextId then nextId = maxId + 1 end
end)
