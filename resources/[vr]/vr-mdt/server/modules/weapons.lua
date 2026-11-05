Weapons = {}

local hookId = nil

Db.schema('weapons', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_weapons` (
        `serial` VARCHAR(32) NOT NULL,
        `item` VARCHAR(64) DEFAULT NULL,
        `label` VARCHAR(64) NOT NULL,
        `owner_cid` VARCHAR(64) DEFAULT NULL,
        `owner_name` VARCHAR(64) DEFAULT NULL,
        `registered_at` INT UNSIGNED NOT NULL,
        `source` VARCHAR(16) NOT NULL DEFAULT 'auto',
        `notes` TEXT DEFAULT NULL,
        `flags` LONGTEXT DEFAULT NULL,
        `updated_at` INT UNSIGNED DEFAULT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`serial`),
        KEY `owner_cid` (`owner_cid`),
        KEY `owner_name` (`owner_name`),
        KEY `registered_at` (`registered_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function shape(r)
    return {
        serial = r.serial,
        item = r.item,
        label = r.label,
        owner = r.owner_name,
        ownerCid = r.owner_cid,
        registeredAt = r.registered_at,
        source = r.source,
        flags = Records.flagsOf(r.flags),
    }
end

function Weapons.record(serial, item, label, cid, name, source)
    serial = Records.serial(serial)
    if not serial then return false end
    local id = Db.update([[INSERT IGNORE INTO `vr_mdt_weapons` (`serial`, `item`, `label`, `owner_cid`, `owner_name`, `registered_at`, `source`)
        VALUES (?, ?, ?, ?, ?, ?, ?)]], { serial, V.str(item, 64), V.str(label, 64) or V.str(item, 64) or 'Weapon', cid, V.str(name, 64), U.now(), source or 'auto' })
    return id ~= nil and id > 0
end

function Weapons.onCreateItem(payload)
    if type(payload) ~= 'table' then return end
    local item, md = payload.item, payload.metadata
    if type(item) ~= 'table' or not item.weapon or type(md) ~= 'table' then return end
    local serial = Records.serial(md.serial)
    local src = math.tointeger(tonumber(payload.inventoryId))
    if not serial or not src then return end
    local p = Core.player(src)
    if not p then return end
    local cid, name = p.cid, p.name
    local itemName, label = item.name, item.label
    CreateThread(function()
        if Weapons.record(serial, itemName, label, cid, name, 'auto') then
            Audit.log(nil, 'weapons.autoRegister', serial, { cid = cid, item = itemName })
        end
    end)
end

function Weapons.registerHook()
    local res = Bridge.inventoryResource
    if not res or GetResourceState(res) ~= 'started' then return false end
    local ok, id = pcall(Bridge.inventory.onCreateItem, Weapons.onCreateItem)
    if ok and id then hookId = id end
    return ok and id ~= nil
end

Api.register('weapons.search', 'records.view', function(src, ctx, data)
    local q = V.str(data.q, 48)
    if not q then return false, 'bad_request' end
    if #q < 2 then return true, {} end
    local like = U.like(q)
    local rows = Db.query([[SELECT `serial`, `item`, `label`, `owner_cid`, `owner_name`, `registered_at`, `source`, `flags` FROM `vr_mdt_weapons`
        WHERE `serial` LIKE ? OR LOWER(`owner_name`) LIKE LOWER(?) OR LOWER(`label`) LIKE LOWER(?) OR `owner_cid` = ?
        ORDER BY `registered_at` DESC LIMIT ?]], { U.like(q:upper()), like, like, q:upper(), Config.Records.searchLimit })
    if not rows then return false, 'server_error' end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = shape(r) end
    return true, out
end, { rate = 300 })

function Weapons.searchSerial(q, limit)
    local rows = Db.query('SELECT `serial`, `item`, `label`, `owner_cid`, `owner_name`, `registered_at`, `source`, `flags` FROM `vr_mdt_weapons` WHERE `serial` LIKE ? ORDER BY `registered_at` DESC LIMIT ?',
        { U.like(q:upper()), limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = shape(r) end
    return out
end

Api.register('weapons.recent', 'records.view', function(src, ctx)
    local rows = Db.query('SELECT `serial`, `item`, `label`, `owner_cid`, `owner_name`, `registered_at`, `source`, `flags` FROM `vr_mdt_weapons` ORDER BY `registered_at` DESC LIMIT ?', { Config.Records.recentLimit })
    if not rows then return false, 'server_error' end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = shape(r) end
    return true, out
end, { rate = 500 })

Api.register('weapons.get', 'records.view', function(src, ctx, data)
    local serial = Records.serial(data.serial)
    if not serial then return false, 'bad_request' end
    local r = Db.single('SELECT * FROM `vr_mdt_weapons` WHERE `serial` = ?', { serial })
    if not r then return false, 'not_found' end
    local out = shape(r)
    out.notes = r.notes or ''
    out.updatedAt = r.updated_at
    out.updatedBy = r.updated_by
    out.flagOptions = Config.WeaponFlags
    if r.owner_cid then
        local person = People.get(r.owner_cid)
        out.ownerProfile = People.public(person)
        if out.ownerProfile then
            local prof = Citizens and Citizens.profiles and Citizens.profiles({ r.owner_cid })[r.owner_cid]
            out.ownerProfile.mugshot = prof and prof.mugshot or nil
            out.ownerProfile.flags = Citizens and Citizens.flags and Citizens.flags(r.owner_cid) or {}
            local md = person.metadata or {}
            out.ownerProfile.weaponLicence = type(md.licences) == 'table' and md.licences.weapon == true
        end
    end
    return true, out
end, { rate = 250 })

local function update(ctx, serial, column, value)
    return Db.update(('UPDATE `vr_mdt_weapons` SET `%s` = ?, `updated_at` = ?, `updated_by` = ? WHERE `serial` = ?'):format(column), { value, U.now(), ctx.name, serial })
end

Api.register('weapons.flags', 'records.edit', function(src, ctx, data)
    local serial = Records.serial(data.serial)
    local flags = Records.cleanFlags(data.flags, Config.WeaponFlags)
    if not serial or not flags then return false, 'bad_request' end
    local before = Db.single('SELECT `flags` FROM `vr_mdt_weapons` WHERE `serial` = ?', { serial })
    if not before then return false, 'not_found' end
    if update(ctx, serial, 'flags', json.encode(flags)) == nil then return false, 'save_failed' end
    local added, removed = Records.flagDiff(Records.flagsOf(before.flags), flags)
    Audit.log(ctx, 'weapons.flags', serial, { added = added, removed = removed })
    return true, { flags = flags, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 500 })

Api.register('weapons.notes', 'records.edit', function(src, ctx, data)
    local serial = Records.serial(data.serial)
    local notes = Records.notes(data.notes)
    if not serial or not notes then return false, 'bad_request' end
    if not Db.scalar('SELECT 1 FROM `vr_mdt_weapons` WHERE `serial` = ?', { serial }) then return false, 'not_found' end
    if update(ctx, serial, 'notes', notes) == nil then return false, 'save_failed' end
    Audit.log(ctx, 'weapons.notes', serial, { length = #notes })
    return true, { notes = notes, updatedAt = U.now(), updatedBy = ctx.name }
end, { rate = 800 })

Api.register('weapons.register', 'records.edit', function(src, ctx, data)
    local serial = Records.serial(data.serial)
    local label = V.str(data.label, 64)
    local item = data.item ~= nil and V.str(data.item, 64) or nil
    if not serial or not label or (data.item ~= nil and not item) then return false, 'bad_request' end
    local cid, name = nil, nil
    if data.cid ~= nil and data.cid ~= '' then
        cid = V.cid(data.cid)
        if not cid then return false, 'bad_request' end
        name = Core.nameOf(cid)
        if not name then return false, 'not_found' end
    end
    if Db.scalar('SELECT 1 FROM `vr_mdt_weapons` WHERE `serial` = ?', { serial }) then return false, 'already_exists' end
    if not Weapons.record(serial, item, label, cid, name, 'manual') then return false, 'save_failed' end
    Audit.log(ctx, 'weapons.register', serial, { label = label, cid = cid })
    local r = Db.single('SELECT * FROM `vr_mdt_weapons` WHERE `serial` = ?', { serial })
    return true, r and shape(r) or { serial = serial, label = label }
end, { rate = 1000 })

AddEventHandler('onResourceStart', function(res)
    if res == Bridge.inventoryResource then
        SetTimeout(1000, Weapons.registerHook)
    end
end)

Db.ready(function()
    if not hookId then Weapons.registerHook() end
end)
