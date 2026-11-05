Vehicles = {}

local flagCache = {}

Db.schema('vehicles', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_vehicles` (
        `plate` VARCHAR(8) NOT NULL,
        `notes` TEXT DEFAULT NULL,
        `flags` LONGTEXT DEFAULT NULL,
        `updated_at` INT UNSIGNED DEFAULT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`plate`),
        KEY `updated_at` (`updated_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

function Vehicles.flags(plate)
    plate = V.plate(plate)
    return U.copy(plate and flagCache[plate] or {})
end

local function shapeRows(rows, extra)
    local cids, seen = {}, {}
    for _, r in ipairs(rows) do
        if r.ownerCid and not seen[r.ownerCid] then
            seen[r.ownerCid] = true
            cids[#cids + 1] = r.ownerCid
        end
    end
    local names = Records.ownerNames(cids)
    local out, plates = {}, {}
    for _, r in ipairs(rows) do
        local plate = V.plate(r.plate)
        if plate and not plates[plate] then
            plates[plate] = true
            out[#out + 1] = {
                plate = plate,
                model = r.model,
                label = Records.vehicleLabel(r.model),
                owner = r.ownerCid and names[r.ownerCid] or nil,
                ownerCid = r.ownerCid,
                flags = Vehicles.flags(plate),
            }
        end
    end
    for _, plate in ipairs(extra or {}) do
        if not plates[plate] then
            plates[plate] = true
            out[#out + 1] = { plate = plate, model = nil, label = nil, owner = nil, ownerCid = nil, flags = Vehicles.flags(plate), unregistered = true }
        end
    end
    return out
end

function Vehicles.search(q, limit)
    limit = limit or Config.Records.searchLimit
    local like = U.like(q:upper())
    local rows = Bridge.vehicles.search and Bridge.vehicles.search(q, limit)
    if not rows then return nil end
    local extra = {}
    if #rows < limit then
        local profiles = Db.query('SELECT `plate` FROM `vr_mdt_vehicles` WHERE `plate` LIKE ? ORDER BY `plate` LIMIT ?', { like, limit - #rows }) or {}
        for _, p in ipairs(profiles) do extra[#extra + 1] = p.plate end
    end
    return shapeRows(rows, extra)
end

function Vehicles.byPlate(plates)
    if #plates == 0 then return {} end
    local rows = Bridge.vehicles.byPlates and Bridge.vehicles.byPlates(plates) or {}
    local registered = {}
    for _, r in ipairs(rows) do registered[V.plate(r.plate) or r.plate] = true end
    local extra = {}
    for _, p in ipairs(plates) do
        if not registered[p] then extra[#extra + 1] = p end
    end
    return shapeRows(rows, extra)
end

local function save(ctx, plate, column, value)
    return Db.update(([[INSERT INTO `vr_mdt_vehicles` (`plate`, `%s`, `updated_at`, `updated_by`) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `%s` = VALUES(`%s`), `updated_at` = VALUES(`updated_at`), `updated_by` = VALUES(`updated_by`)]]):format(column, column, column),
        { plate, value, U.now(), ctx.name })
end

Api.register('vehicles.search', 'records.view', function(src, ctx, data)
    local q = V.str(data.q, 32)
    if not q then return false, 'bad_request' end
    if #q < 2 then return true, {} end
    local list = Vehicles.search(q)
    if not list then return false, 'server_error' end
    return true, list
end, { rate = 300 })

Api.register('vehicles.recent', 'records.view', function(src, ctx)
    local rows = Db.query("SELECT `plate` FROM `vr_mdt_vehicles` WHERE `flags` IS NOT NULL AND `flags` <> '[]' ORDER BY `updated_at` DESC LIMIT ?", { Config.Records.recentLimit })
    if not rows then return false, 'server_error' end
    local plates = {}
    for _, r in ipairs(rows) do plates[#plates + 1] = r.plate end
    local list = Vehicles.byPlate(plates)
    local order = {}
    for i, p in ipairs(plates) do order[p] = i end
    table.sort(list, function(a, b) return (order[a.plate] or 0) < (order[b.plate] or 0) end)
    return true, list
end, { rate = 500 })

Api.register('vehicles.get', 'records.view', function(src, ctx, data)
    local plate = V.plate(data.plate)
    if not plate then return false, 'bad_request' end
    local row = Bridge.vehicles.byPlate and Bridge.vehicles.byPlate(plate)
    local profile = Db.single('SELECT `notes`, `flags`, `updated_at`, `updated_by` FROM `vr_mdt_vehicles` WHERE `plate` = ?', { plate })
    local out = {
        plate = plate,
        registered = row ~= nil,
        model = row and row.model or nil,
        label = row and Records.vehicleLabel(row.model) or nil,
        garage = row and row.garage or nil,
        state = row and tonumber(row.state) or nil,
        notes = profile and profile.notes or '',
        flags = profile and Records.flagsOf(profile.flags) or {},
        updatedAt = profile and profile.updated_at or nil,
        updatedBy = profile and profile.updated_by or nil,
        flagOptions = Config.VehicleFlags,
        owner = nil,
    }
    if row and row.ownerCid then
        local person = People.get(row.ownerCid)
        out.owner = People.public(person)
        if out.owner then
            local prof = Citizens and Citizens.profiles and Citizens.profiles({ row.ownerCid })[row.ownerCid]
            out.owner.mugshot = prof and prof.mugshot or nil
            out.owner.flags = Citizens and Citizens.flags and Citizens.flags(row.ownerCid) or {}
        end
    end
    out.bolos = Records.optional(Bolos and Bolos.forPlate, plate)
    out.reports = Records.optional(Reports and Reports.forPlate, plate, 25)
    return true, out
end, { rate = 250 })

Api.register('vehicles.flags', 'records.edit', function(src, ctx, data)
    local plate = V.plate(data.plate)
    local flags = Records.cleanFlags(data.flags, Config.VehicleFlags)
    if not plate or not flags then return false, 'bad_request' end
    if save(ctx, plate, 'flags', json.encode(flags)) == nil then return false, 'save_failed' end
    local added, removed = Records.flagDiff(flagCache[plate], flags)
    flagCache[plate] = #flags > 0 and flags or nil
    Audit.log(ctx, 'vehicles.flags', plate, { added = added, removed = removed })
    return true, { flags = flags, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 500 })

Api.register('vehicles.notes', 'records.edit', function(src, ctx, data)
    local plate = V.plate(data.plate)
    local notes = Records.notes(data.notes)
    if not plate or not notes then return false, 'bad_request' end
    if save(ctx, plate, 'notes', notes) == nil then return false, 'save_failed' end
    Audit.log(ctx, 'vehicles.notes', plate, { length = #notes })
    return true, { notes = notes, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 800 })

Db.ready(function()
    local rows = Db.query("SELECT `plate`, `flags` FROM `vr_mdt_vehicles` WHERE `flags` IS NOT NULL AND `flags` <> '[]'") or {}
    for _, r in ipairs(rows) do
        local flags = Records.flagsOf(r.flags)
        if #flags > 0 then flagCache[r.plate] = flags end
    end
end)
