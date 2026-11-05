Booking = {}

local areas = {}

Db.schema('booking_areas', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_booking_areas` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `label` VARCHAR(48) NOT NULL,
        `x` DOUBLE NOT NULL,
        `y` DOUBLE NOT NULL,
        `z` DOUBLE NOT NULL,
        `radius` DOUBLE NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function cfg()
    return Config.Booking or {}
end

local function rebuild()
    local out = {}
    for i, a in ipairs(cfg().areas or {}) do
        if a.coords then
            out[#out + 1] = { id = 'c' .. i, label = a.label or 'Station', x = a.coords.x + 0.0, y = a.coords.y + 0.0, z = a.coords.z + 0.0, radius = tonumber(a.radius) or 40.0 }
        end
    end
    for _, r in ipairs(Db.query('SELECT * FROM `vr_mdt_booking_areas` ORDER BY `id`') or {}) do
        out[#out + 1] = { id = tonumber(r.id), label = r.label, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), radius = tonumber(r.radius) }
    end
    areas = out
end

local function push(target)
    TriggerClientEvent('vr-mdt:client:bookingAreas', target or -1, areas)
end

function Booking.areaAt(c)
    if not c then return nil end
    for _, a in ipairs(areas) do
        local dx, dy, dz = c.x - a.x, c.y - a.y, c.z - a.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) <= a.radius then return a end
    end
    return nil
end

Db.ready(function()
    rebuild()
    push(-1)
end)

Bridge.on('playerLoaded', function(src)
    if src then SetTimeout(1500, function() push(tonumber(src)) end) end
end)

Bridge.callback.register('vr-mdt:booking:areas', function()
    return areas
end)

---------------------------------------------------------------------------
-- Checks shared by every step
---------------------------------------------------------------------------

local function cleanCharges(list)
    if type(list) ~= 'table' then return nil end
    local merged, order = {}, {}
    for _, e in ipairs(list) do
        local id = type(e) == 'table' and V.id(e.id)
        local count = type(e) == 'table' and V.int(e.count, 1, Config.Sentencing.maxCount)
        if not id or not count then return nil end
        if not merged[id] then
            merged[id] = 0
            order[#order + 1] = id
        end
        merged[id] = math.min(merged[id] + count, Config.Sentencing.maxCount)
    end
    if #order == 0 or #order > Config.Sentencing.maxChargesPerPerson then return nil end
    local out = {}
    for _, id in ipairs(order) do out[#out + 1] = { id = id, count = merged[id] } end
    return out
end

-- Returns ctx, targetPlayer, areaLabel, or nil and an error code.
local function check(src, data)
    if not cfg().enabled then return nil, 'disabled' end
    local ctx, err = Core.context(src)
    if not ctx then return nil, err end
    if ctx.dept ~= 'police' then return nil, 'not_allowed' end
    if not (Core.can(ctx, 'sentencing.apply') and Core.can(ctx, 'reports.create')) then return nil, 'not_allowed' end
    local target = V.int(data.target, 1, 65535)
    if not target or target == src then return nil, 'bad_request' end
    local tp = Core.player(target)
    if not tp or not tp.cid then return nil, 'not_found' end
    local mine, theirs = Core.pedCoords(src), Core.pedCoords(target)
    if not mine or not theirs then return nil, 'not_found' end
    if #(mine - theirs) > (tonumber(cfg().range) or 6.0) then return nil, 'too_far' end
    local area = Booking.areaAt(mine)
    if not area then return nil, 'not_at_station' end
    if cfg().requireRestrained then
        local st = Bridge.status(target)
        if not (type(st) == 'table' and st.cuffed) then return nil, 'not_restrained' end
    end
    if Prison and Prison.status and Prison.status(tp.cid) then return nil, 'already_jailed' end
    return ctx, tp, area.label
end

local function charged(list)
    local totals = Penal.totals(list)
    if #totals.items ~= #list then return nil end
    for _, it in ipairs(totals.items) do
        if not it.active then return nil end
    end
    return totals
end

---------------------------------------------------------------------------
-- Callbacks used by the officer's menu
---------------------------------------------------------------------------

Bridge.callback.register('vr-mdt:booking:charges', function(src, data)
    if type(data) ~= 'table' then return { ok = false, error = 'bad_request' } end
    local ctx, tp = check(src, data)
    if not ctx then return { ok = false, error = tp } end
    return {
        ok = true,
        target = { src = tp.source or data.target, name = tp.name },
        categories = Penal.list(false),
        maxCount = Config.Sentencing.maxCount,
        maxCharges = Config.Sentencing.maxChargesPerPerson,
        pleaReduction = Config.Sentencing.pleaReduction,
        notesMax = cfg().notesMax or 600,
    }
end)

Bridge.callback.register('vr-mdt:booking:quote', function(src, data)
    if type(data) ~= 'table' then return { ok = false, error = 'bad_request' } end
    local ctx, tp = check(src, data)
    if not ctx then return { ok = false, error = tp } end
    local list = cleanCharges(data.charges)
    local totals = list and charged(list)
    if not totals then return { ok = false, error = 'no_charges' } end
    local plea = data.plea == true
    local b = Sentencing.bounds(totals, plea)
    return {
        ok = true,
        name = tp.name,
        plea = plea,
        total = { fine = totals.fine, months = totals.months, class = totals.class },
        max = { fine = b.fine, months = b.months },
        min = { fine = b.minFine, months = b.minMonths },
        items = totals.items,
    }
end)

Bridge.callback.register('vr-mdt:booking:apply', function(src, data)
    if type(data) ~= 'table' then return { ok = false, error = 'bad_request' } end
    local ctx, tp, where = check(src, data)
    if not ctx then return { ok = false, error = tp } end
    local list = cleanCharges(data.charges)
    local totals = list and charged(list)
    if not totals then return { ok = false, error = 'no_charges' } end
    local plea = data.plea == true
    local b = Sentencing.bounds(totals, plea)
    local fine = data.fine == nil and b.fine or V.int(data.fine, 0, 100000000)
    local months = data.months == nil and b.months or V.int(data.months, 0, 100000)
    if not fine or not months then return { ok = false, error = 'bad_request' } end
    if fine > b.fine or months > b.months then return { ok = false, error = 'above_max' } end
    if fine < b.minFine or months < b.minMonths then return { ok = false, error = 'below_min' } end
    local notes = data.notes ~= nil and data.notes ~= '' and V.text(data.notes, cfg().notesMax or 600) or nil
    if data.notes ~= nil and data.notes ~= '' and not notes then return { ok = false, error = 'bad_request' } end

    local now = U.now()
    local title = ('Booking: %s'):format(tp.name):sub(1, 96)
    local body = notes or ('Booked at %s.'):format(where)
    local reportId = Db.insert([[INSERT INTO `vr_mdt_reports` (`type`, `title`, `body`, `location`, `call_id`, `case_id`, `author_cid`, `author_name`, `author_callsign`,
        `created_at`, `updated_at`, `locked`, `tags`) VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?, ?, 0, ?)]],
        { 'arrest', title, body, where, ctx.cid, ctx.name, ctx.callsign, now, now, json.encode({ 'booking' }) })
    if not reportId then return { ok = false, error = 'save_failed' } end
    local personId = Db.insert([[INSERT INTO `vr_mdt_report_people` (`report_id`, `cid`, `name`, `callsign`, `role`, `charges`, `notes`)
        VALUES (?, ?, ?, NULL, 'suspect', ?, NULL)]], { reportId, tp.cid, tp.name, json.encode(list) })
    if not personId then return { ok = false, error = 'save_failed' } end
    local person = Db.single('SELECT * FROM `vr_mdt_report_people` WHERE `id` = ?', { personId })
    if not person then return { ok = false, error = 'save_failed' } end

    local ok, result, err = Sentencing.applyPerson(ctx, person, plea, fine, months)
    if not ok then return { ok = false, error = err or 'failed' } end
    Audit.log(ctx, 'booking', tp.cid, { report = reportId, fine = fine, months = months, plea = plea, where = where })
    local s = result and result.sentence or {}
    return { ok = true, name = tp.name, reportId = reportId, fine = fine, paid = s.paid or 0, months = months, jailed = s.jailed == true, warnings = result and result.warnings or {} }
end)

---------------------------------------------------------------------------
-- Admin: where booking is allowed
---------------------------------------------------------------------------

RegisterCommand('bookingarea', function(src, args)
    if src <= 0 or not Bridge.isAdmin(src) then return end
    local sub = tostring(args[1] or ''):lower()
    if sub == 'add' then
        local radius = tonumber(args[2])
        local label = table.concat(args, ' ', 3)
        local c = Core.pedCoords(src)
        if not c or not radius or radius < 5.0 or radius > 500.0 or label == '' then
            return Core.notify(src, 'Use /bookingarea add <radius 5-500> <name>, standing in the middle of the station', 'error')
        end
        local id = Db.insert('INSERT INTO `vr_mdt_booking_areas` (`label`, `x`, `y`, `z`, `radius`) VALUES (?, ?, ?, ?, ?)', { label:sub(1, 48), c.x, c.y, c.z, radius })
        if not id then return Core.notify(src, 'Could not save the booking area', 'error') end
        rebuild()
        push(-1)
        Core.notify(src, ('Booking area %d added: %s'):format(id, label), 'success')
    elseif sub == 'remove' then
        local id = V.id(args[2])
        if not id then return Core.notify(src, 'Use /bookingarea remove <id>', 'error') end
        local n = Db.update('DELETE FROM `vr_mdt_booking_areas` WHERE `id` = ?', { id })
        rebuild()
        push(-1)
        Core.notify(src, n and n > 0 and 'Booking area removed' or 'No area with that id', n and n > 0 and 'success' or 'error')
    elseif sub == 'list' then
        if #areas == 0 then return Core.notify(src, 'No booking areas', 'inform') end
        for _, a in ipairs(areas) do
            Core.notify(src, ('%s  #%s  radius %d'):format(a.label, tostring(a.id), math.floor(a.radius)), 'inform')
        end
    else
        Core.notify(src, '/bookingarea add <radius> <name> | remove <id> | list', 'inform')
    end
end, false)

exports('IsBookingArea', function(x, y, z)
    return Booking.areaAt({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }) ~= nil
end)
