Citizens = {}

local flagCache = {}

Db.schema('profiles', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_profiles` (
        `citizenid` VARCHAR(64) NOT NULL,
        `mugshot` CHAR(32) DEFAULT NULL,
        `notes` TEXT DEFAULT NULL,
        `flags` LONGTEXT DEFAULT NULL,
        `updated_at` INT UNSIGNED DEFAULT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`citizenid`),
        KEY `updated_at` (`updated_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

function Citizens.flags(cid)
    return U.copy(flagCache[cid] or {})
end

function Citizens.profile(cid)
    local row = Db.single('SELECT `mugshot`, `notes`, `flags`, `updated_at`, `updated_by` FROM `vr_mdt_profiles` WHERE `citizenid` = ?', { cid })
    if not row then return { mugshot = nil, notes = '', flags = {}, updatedAt = nil, updatedBy = nil } end
    return {
        mugshot = row.mugshot,
        notes = row.notes or '',
        flags = Records.flagsOf(row.flags),
        updatedAt = row.updated_at,
        updatedBy = row.updated_by,
    }
end

function Citizens.profiles(cids)
    local out = {}
    if #cids == 0 then return out end
    local rows = Db.query(('SELECT `citizenid`, `mugshot` FROM `vr_mdt_profiles` WHERE `citizenid` IN (%s)'):format(Records.placeholders(#cids)), cids) or {}
    for _, r in ipairs(rows) do out[r.citizenid] = { mugshot = r.mugshot } end
    return out
end

local function exists(cid)
    return People.exists(cid)
end
Citizens.exists = exists

local function save(ctx, cid, column, value)
    return Db.update(([[INSERT INTO `vr_mdt_profiles` (`citizenid`, `%s`, `updated_at`, `updated_by`) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `%s` = VALUES(`%s`), `updated_at` = VALUES(`updated_at`), `updated_by` = VALUES(`updated_by`)]]):format(column, column, column),
        { cid, value, U.now(), ctx.name })
end

local function licencesOf(cid)
    local held = Bridge.licences.get and Bridge.licences.get(cid) or {}
    local out = {}
    for key, label in pairs(Config.Licences) do
        out[#out + 1] = { key = key, label = label, value = held[key] == true }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function hasValue(list, v)
    if type(list) ~= 'table' then return false end
    for _, x in pairs(list) do
        if x == v then return true end
    end
    return false
end

local function propertyLabel(id, d)
    if type(d.apartment) == 'string' and d.apartment ~= '' then return ('%s #%s'):format(d.apartment, id) end
    return ('%s %s'):format(type(d.street) == 'string' and d.street ~= '' and d.street or 'House', id)
end

function Citizens.properties(cid)
    if GetResourceState('vr-housing') ~= 'started' then return {} end
    local ok, all = pcall(function() return exports['vr-housing']:GetProperties() end)
    if not ok or type(all) ~= 'table' then return {} end
    local out = {}
    for key, p in pairs(all) do
        local d = type(p) == 'table' and (type(p.propertyData) == 'table' and p.propertyData or p) or nil
        if d then
            local owner = d.owner == cid
            if owner or hasValue(d.has_access, cid) then
                local id = tostring(d.property_id or p.property_id or key)
                out[#out + 1] = {
                    id = id,
                    label = propertyLabel(id, d),
                    street = type(d.street) == 'string' and d.street or nil,
                    region = type(d.region) == 'string' and d.region or nil,
                    apartment = type(d.apartment) == 'string' and d.apartment or nil,
                    role = owner and 'owner' or 'keyholder',
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.role ~= b.role then return a.role == 'owner' end
        return a.label < b.label
    end)
    while #out > Config.Records.profileListLimit do table.remove(out) end
    return out
end

local function vehiclesOf(cid)
    local rows = Bridge.vehicles.ofOwner and Bridge.vehicles.ofOwner(cid, Config.Records.profileListLimit) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            plate = r.plate,
            model = r.model,
            label = Records.vehicleLabel(r.model),
            garage = r.garage,
            state = tonumber(r.state),
            flags = Vehicles and Vehicles.flags and Vehicles.flags(r.plate) or {},
        }
    end
    return out
end

local function weaponsOf(cid)
    local rows = Db.query('SELECT `serial`, `item`, `label`, `registered_at`, `flags` FROM `vr_mdt_weapons` WHERE `owner_cid` = ? ORDER BY `registered_at` DESC LIMIT ?', { cid, Config.Records.profileListLimit }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { serial = r.serial, item = r.item, label = r.label, registeredAt = r.registered_at, flags = Records.flagsOf(r.flags) }
    end
    return out
end

function Citizens.summary(people)
    local cids = {}
    for _, p in ipairs(people) do cids[#cids + 1] = p.cid end
    local profiles = Citizens.profiles(cids)
    local wanted = Warrants and Warrants.activeCids and Warrants.activeCids(cids) or {}
    local out = {}
    for _, p in ipairs(people) do
        local prof = profiles[p.cid]
        out[#out + 1] = {
            cid = p.cid,
            name = p.name,
            dob = p.dob,
            phone = p.phone,
            gender = p.gender,
            mugshot = prof and prof.mugshot or nil,
            flags = Citizens.flags(p.cid),
            hasWarrant = wanted[p.cid] == true,
        }
    end
    return out
end

Api.register('citizens.search', 'records.view', function(src, ctx, data)
    local q = V.str(data.q, 48)
    if not q then return false, 'bad_request' end
    return true, Citizens.summary(People.search(q, Config.Records.searchLimit))
end, { rate = 300 })

Api.register('citizens.recent', 'records.view', function(src, ctx)
    local rows = Db.query('SELECT `citizenid` FROM `vr_mdt_profiles` ORDER BY `updated_at` DESC LIMIT ?', { Config.Records.recentLimit })
    if not rows then return false, 'server_error' end
    local cids = {}
    for _, r in ipairs(rows) do cids[#cids + 1] = r.citizenid end
    if #cids == 0 then return true, {} end
    local byCid = People.many(cids)
    local people = {}
    for _, cid in ipairs(cids) do
        if byCid[cid] then people[#people + 1] = byCid[cid] end
    end
    return true, Citizens.summary(people)
end, { rate = 500 })

Api.register('citizens.get', 'records.view', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    local person = People.get(cid)
    if not person then return false, 'not_found' end
    local md = person.metadata or {}
    local profile = Citizens.profile(cid)
    local out = People.public(person)
    out.licences = licencesOf(cid)
    out.fingerprint = type(md.fingerprint) == 'string' and md.fingerprint or nil
    out.bloodtype = type(md.bloodtype) == 'string' and md.bloodtype or nil
    out.mugshot = profile.mugshot
    out.notes = profile.notes
    out.flags = profile.flags
    out.updatedAt = profile.updatedAt
    out.updatedBy = profile.updatedBy
    out.properties = Citizens.properties(cid)
    out.vehicles = vehiclesOf(cid)
    out.weapons = weaponsOf(cid)
    out.warrants = Records.optional(Warrants and Warrants.forCitizen, cid)
    out.bolos = Records.optional(Bolos and Bolos.forCitizen, cid)
    out.prison = Prison and Prison.status and Prison.status(cid) or nil
    out.reports = Records.optional(Reports and Reports.forCitizen, cid, 25)
    out.sentences = Records.optional(Sentencing and Sentencing.forCitizen, cid)
    return true, out
end, { rate = 250 })

Api.register('citizens.notes', 'records.edit', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local notes = Records.notes(data.notes)
    if not cid or not notes then return false, 'bad_request' end
    if not exists(cid) then return false, 'not_found' end
    if save(ctx, cid, 'notes', notes) == nil then return false, 'save_failed' end
    Audit.log(ctx, 'citizens.notes', cid, { length = #notes })
    return true, { notes = notes, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 800 })

Api.register('citizens.flags', 'records.edit', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local flags = Records.cleanFlags(data.flags, Config.CitizenFlags)
    if not cid or not flags then return false, 'bad_request' end
    if not exists(cid) then return false, 'not_found' end
    if save(ctx, cid, 'flags', json.encode(flags)) == nil then return false, 'save_failed' end
    local added, removed = Records.flagDiff(flagCache[cid], flags)
    flagCache[cid] = #flags > 0 and flags or nil
    Audit.log(ctx, 'citizens.flags', cid, { added = added, removed = removed })
    return true, { flags = flags, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 500 })

Api.register('citizens.licence', 'licences.edit', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local key = V.enum(data.licence, Config.Licences)
    local value = V.bool(data.value)
    if not cid or not key or value == nil then return false, 'bad_request' end
    if not exists(cid) then return false, 'not_found' end
    if not Bridge.licences.set(cid, key, value) then return false, 'save_failed' end
    local p = Core.playerByCid(cid)
    if p then
        Core.notify(p.source, ('Your %s was %s.'):format(Config.Licences[key]:lower(), value and 'granted' or 'revoked'), value and 'success' or 'error')
    end
    Audit.log(ctx, 'citizens.licence', cid, { licence = key, value = value })
    return true, { key = key, label = Config.Licences[key], value = value }
end, { rate = 500 })

Api.register('citizens.mugshot', 'mugshots.take', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local id = V.imageId(data.imageId)
    if not cid or not id then return false, 'bad_request' end
    local kind = Db.scalar('SELECT `kind` FROM `vr_mdt_images` WHERE `id` = ?', { id })
    if kind == nil then return false, 'not_found' end
    if kind ~= 'mugshot' then return false, 'bad_request' end
    if not exists(cid) then return false, 'not_found' end
    if save(ctx, cid, 'mugshot', id) == nil then return false, 'save_failed' end
    Audit.log(ctx, 'citizens.mugshot', cid, { image = id })
    return true, { mugshot = id, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 1000 })

Api.register('mugshots.target', 'mugshots.take', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    if cid == ctx.cid then return false, 'cant_self' end
    local p = Core.playerByCid(cid)
    if not p then return false, 'not_online' end
    local target = p.source
    local mine, theirs = GetPlayerPed(src), GetPlayerPed(target)
    if not mine or mine == 0 or not theirs or theirs == 0 then return false, 'not_nearby' end
    if #(GetEntityCoords(mine) - GetEntityCoords(theirs)) > Config.Mugshot.distance then return false, 'not_nearby' end
    return true, { src = target, countdown = Config.Mugshot.countdown, fov = Config.Mugshot.fov }
end, { rate = 1500 })

Db.ready(function()
    local rows = Db.query("SELECT `citizenid`, `flags` FROM `vr_mdt_profiles` WHERE `flags` IS NOT NULL AND `flags` <> '[]'") or {}
    for _, r in ipairs(rows) do
        local flags = Records.flagsOf(r.flags)
        if #flags > 0 then flagCache[r.citizenid] = flags end
    end
end)
