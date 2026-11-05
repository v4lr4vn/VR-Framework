Penal = {}

local CLASSES = { infraction = 1, misdemeanor = 2, felony = 3 }
local CLASS_LIST = { 'infraction', 'misdemeanor', 'felony' }
local VIEW_DEPTS = { police = true, doj = true }

local cache = { categories = {}, byCat = {}, byId = {} }

Db.schema('charge_categories', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_charge_categories` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(48) NOT NULL,
        `sort` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('charges', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_charges` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `category_id` INT UNSIGNED NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `description` TEXT DEFAULT NULL,
        `class` VARCHAR(16) NOT NULL,
        `fine` INT UNSIGNED NOT NULL DEFAULT 0,
        `months` INT UNSIGNED NOT NULL DEFAULT 0,
        `points` INT UNSIGNED NOT NULL DEFAULT 0,
        `sort` INT NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        `updated_at` INT UNSIGNED NOT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `category_id` (`category_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local SEED = {
    { name = 'Traffic', charges = {
        { 'Speeding', 'infraction', 250, 0, 1, 'Driving above the posted speed limit by up to 30 mph.' },
        { 'Excessive speeding', 'misdemeanor', 750, 0, 3, 'Driving more than 30 mph above the posted speed limit.' },
        { 'Running a red light or stop sign', 'infraction', 200, 0, 1, 'Failing to stop at a red signal or a stop sign.' },
        { 'Illegal parking', 'infraction', 100, 0, 0, 'Parking in a prohibited, obstructive or reserved space.' },
        { 'Failure to yield to an emergency vehicle', 'infraction', 400, 0, 2, 'Not pulling over for an emergency vehicle using lights and siren.' },
        { 'Driving without a valid licence', 'misdemeanor', 750, 0, 2, 'Operating a motor vehicle without a valid driver licence.' },
        { 'Reckless driving', 'misdemeanor', 1200, 5, 4, 'Driving with wilful disregard for the safety of people or property.' },
        { 'Driving under the influence', 'misdemeanor', 2000, 10, 4, 'Operating a vehicle while impaired by alcohol or drugs.' },
        { 'Hit and run', 'felony', 3000, 15, 4, 'Leaving the scene of a collision involving injury or damage without stopping.' },
        { 'Felony evading', 'felony', 4000, 20, 5, 'Fleeing from police in a vehicle after being signalled to stop.' },
    } },
    { name = 'Property', charges = {
        { 'Trespassing', 'misdemeanor', 500, 0, 0, 'Entering or staying on property after being told to leave, or where entry is posted as forbidden.' },
        { 'Vandalism', 'misdemeanor', 750, 5, 0, 'Wilfully damaging or defacing property that belongs to someone else.' },
        { 'Petty theft', 'misdemeanor', 500, 5, 0, 'Taking property worth less than $1,000.' },
        { 'Possession of stolen property', 'misdemeanor', 1000, 10, 0, 'Knowingly holding property that was stolen.' },
        { 'Grand theft', 'felony', 2000, 15, 0, 'Taking property worth $1,000 or more.' },
        { 'Grand theft auto', 'felony', 3000, 20, 0, "Taking a motor vehicle without the owner's consent." },
        { 'Burglary', 'felony', 3500, 25, 0, 'Entering a building or vehicle with intent to commit theft or another felony.' },
        { 'Robbery', 'felony', 5000, 30, 0, 'Taking property from a person by force or fear.' },
        { 'Armed robbery', 'felony', 8000, 45, 0, 'Robbery committed with a firearm or another deadly weapon.' },
        { 'Robbery of a financial institution', 'felony', 15000, 60, 0, 'Robbing a bank, vault or armoured cash transport.' },
        { 'Arson', 'felony', 6000, 35, 0, 'Wilfully setting fire to a structure, vehicle or land.' },
    } },
    { name = 'Violence', charges = {
        { 'Assault', 'misdemeanor', 1000, 10, 0, 'Attempting or threatening to cause bodily harm to another person.' },
        { 'Battery', 'misdemeanor', 1500, 12, 0, 'Unlawful use of force or violence on another person.' },
        { 'Assault with a deadly weapon', 'felony', 5000, 30, 0, 'Assault using a weapon or force likely to cause great bodily injury.' },
        { 'Assault on a public servant', 'felony', 6000, 35, 0, 'Assaulting an on-duty officer, medic, firefighter or other public servant.' },
        { 'Kidnapping', 'felony', 8000, 45, 0, 'Moving or holding a person against their will by force or fear.' },
        { 'Vehicular manslaughter', 'felony', 8000, 40, 6, 'Causing a death through negligent or unlawful driving.' },
        { 'Manslaughter', 'felony', 12000, 60, 0, 'Unlawfully killing a person without intent to kill.' },
        { 'Attempted murder', 'felony', 15000, 75, 0, 'Trying to kill another person with intent.' },
        { 'Murder', 'felony', 25000, 120, 0, 'Unlawfully killing another person with intent.' },
        { 'Murder of a public servant', 'felony', 35000, 150, 0, 'Killing an on-duty public servant.' },
    } },
    { name = 'Weapons', charges = {
        { 'Brandishing a weapon', 'misdemeanor', 1000, 10, 0, 'Drawing or showing a weapon in a threatening way.' },
        { 'Carrying a firearm without a licence', 'misdemeanor', 2000, 15, 0, 'Carrying a legal firearm without a valid weapon licence.' },
        { 'Discharging a firearm in public', 'felony', 3000, 20, 0, 'Firing a weapon in a public place without lawful reason.' },
        { 'Possession of a prohibited weapon', 'felony', 5000, 30, 0, 'Holding a weapon civilians may not own, such as a sawn-off shotgun or a suppressor.' },
        { 'Possession of a firearm by a prohibited person', 'felony', 6000, 30, 0, 'Holding a firearm after a felony conviction or while barred by court order.' },
        { 'Possession of an automatic firearm', 'felony', 10000, 45, 0, 'Holding a fully automatic firearm.' },
        { 'Weapons trafficking', 'felony', 15000, 60, 0, 'Selling, moving or supplying firearms or ammunition illegally.' },
    } },
    { name = 'Narcotics', charges = {
        { 'Possession of drug paraphernalia', 'infraction', 250, 0, 0, 'Holding equipment used to take or prepare illegal drugs.' },
        { 'Possession of a controlled substance', 'misdemeanor', 1000, 5, 0, 'Holding a small personal amount of an illegal drug.' },
        { 'Possession with intent to distribute', 'felony', 5000, 25, 0, 'Holding drugs in a quantity or packaging that shows intent to sell.' },
        { 'Sale of a controlled substance', 'felony', 6000, 30, 0, 'Selling or offering to sell an illegal drug.' },
        { 'Manufacturing a controlled substance', 'felony', 10000, 45, 0, 'Cooking, growing or processing illegal drugs.' },
        { 'Drug trafficking', 'felony', 15000, 60, 0, 'Moving large quantities of illegal drugs for distribution.' },
    } },
    { name = 'Public order', charges = {
        { 'Jaywalking', 'infraction', 100, 0, 0, 'Crossing a road away from a crossing or against the signal.' },
        { 'Public intoxication', 'infraction', 300, 0, 0, 'Being drunk or high in public and unable to care for yourself.' },
        { 'Disturbing the peace', 'infraction', 350, 0, 0, 'Unreasonable noise, challenges to fight or offensive conduct in public.' },
        { 'Indecent exposure', 'misdemeanor', 750, 5, 0, 'Exposing yourself in public where it is likely to offend.' },
        { 'Harassment', 'misdemeanor', 1000, 8, 0, 'Repeated conduct that alarms, torments or threatens another person.' },
        { 'Inciting a riot', 'felony', 4000, 20, 0, 'Urging a group to violence or destruction of property.' },
    } },
    { name = 'Obstruction & government', charges = {
        { 'Failure to identify', 'infraction', 500, 0, 0, 'Refusing to give your name to an officer while lawfully detained.' },
        { 'Evading on foot', 'misdemeanor', 800, 5, 0, 'Running from an officer after being told to stop.' },
        { 'Resisting arrest', 'misdemeanor', 1000, 8, 0, 'Physically resisting or delaying an officer making a lawful arrest.' },
        { 'Obstruction of justice', 'misdemeanor', 1500, 10, 0, 'Hindering an investigation, hiding evidence or helping a suspect avoid arrest.' },
        { 'False report to emergency services', 'misdemeanor', 1500, 5, 0, 'Knowingly reporting a false emergency or crime.' },
        { 'Contempt of court', 'misdemeanor', 2000, 10, 0, 'Disobeying or disrespecting the court during proceedings.' },
        { 'Impersonating a public servant', 'felony', 5000, 25, 0, 'Pretending to be a police officer, medic or government official.' },
        { 'Escape from custody', 'felony', 5000, 30, 0, 'Escaping or trying to escape from police custody or prison.' },
        { 'Perjury', 'felony', 6000, 30, 0, 'Knowingly lying under oath.' },
        { 'Bribery of a public official', 'felony', 8000, 30, 0, 'Offering money or favours to influence a public official.' },
    } },
}

local function flag(v)
    return v == true or v == 1 or v == '1'
end

local function int(v)
    v = tonumber(v)
    return v and math.tointeger(math.floor(v)) or 0
end

local function toCharge(r, cat)
    return {
        id = int(r.id),
        categoryId = int(r.category_id),
        category = cat and cat.name or nil,
        title = r.title,
        description = r.description,
        class = r.class,
        fine = int(r.fine),
        months = int(r.months),
        points = int(r.points),
        sort = int(r.sort),
        active = flag(r.active),
        updatedAt = int(r.updated_at),
        updatedBy = r.updated_by,
    }
end

function Penal.reload()
    local cats = Db.query('SELECT `id`, `name`, `sort` FROM `vr_mdt_charge_categories` ORDER BY `sort`, `id`')
    local rows = Db.query('SELECT * FROM `vr_mdt_charges` ORDER BY `sort`, `title`, `id`')
    if not cats or not rows then return false end
    local categories, byCat, byId = {}, {}, {}
    for _, c in ipairs(cats) do
        local cat = { id = int(c.id), name = c.name, sort = int(c.sort), charges = {} }
        categories[#categories + 1] = cat
        byCat[cat.id] = cat
    end
    for _, r in ipairs(rows) do
        local cat = byCat[int(r.category_id)]
        local charge = toCharge(r, cat)
        byId[charge.id] = charge
        if cat then cat.charges[#cat.charges + 1] = charge end
    end
    cache.categories, cache.byCat, cache.byId = categories, byCat, byId
    return true
end

function Penal.get(id)
    local c = cache.byId[tonumber(id) or -1]
    return c and U.copy(c) or nil
end

function Penal.category(id)
    local c = cache.byCat[tonumber(id) or -1]
    return c and { id = c.id, name = c.name, sort = c.sort, count = #c.charges } or nil
end

function Penal.list(all)
    local out = {}
    for _, cat in ipairs(cache.categories) do
        local list = {}
        for _, c in ipairs(cat.charges) do
            if all or c.active then list[#list + 1] = U.copy(c) end
        end
        if all or #list > 0 then
            out[#out + 1] = { id = cat.id, name = cat.name, sort = cat.sort, charges = list }
        end
    end
    return out
end

function Penal.rank(class)
    return CLASSES[class] or 0
end

function Penal.classes()
    return CLASS_LIST
end

function Penal.expand(list)
    local items = {}
    if type(list) ~= 'table' then return items end
    for _, e in ipairs(list) do
        local c = type(e) == 'table' and cache.byId[tonumber(e.id) or -1]
        if c then
            items[#items + 1] = {
                id = c.id, title = c.title, class = c.class, category = c.category,
                fine = c.fine, months = c.months, points = c.points, active = c.active,
                count = V.int(e.count, 1, Config.Sentencing.maxCount) or 1,
            }
        end
    end
    return items
end

function Penal.sum(items)
    local out = { fine = 0, months = 0, points = 0, class = nil }
    for _, e in ipairs(type(items) == 'table' and items or {}) do
        local n = tonumber(e.count) or 1
        out.fine = out.fine + (tonumber(e.fine) or 0) * n
        out.months = out.months + (tonumber(e.months) or 0) * n
        out.points = out.points + (tonumber(e.points) or 0) * n
        if Penal.rank(e.class) > Penal.rank(out.class) then out.class = e.class end
    end
    out.fine = int(out.fine)
    out.months = math.min(int(out.months), Config.Prison.maxMonths)
    out.points = int(out.points)
    return out
end

function Penal.totals(list)
    local items = Penal.expand(list)
    local t = Penal.sum(items)
    t.items = items
    return t
end

local function canSee(ctx)
    return VIEW_DEPTS[ctx.dept] == true
end

local function changed(ctx, action, target, details)
    Penal.reload()
    Audit.log(ctx, action, target, details)
    local payload = { at = U.now() }
    Push.dept('police', 'penal:changed', payload)
    Push.dept('doj', 'penal:changed', payload)
end

local function optional(v, fn, ...)
    if v == nil or v == '' then return nil, true end
    local x = fn(v, ...)
    return x, x ~= nil
end

local function nextSort(sql, params)
    return int(Db.scalar(sql, params)) + 10
end

Api.register('penal.list', nil, function(src, ctx, data)
    if not canSee(ctx) then return false, 'not_allowed' end
    local all = data.all == true and Core.can(ctx, 'penal.manage')
    return true, { categories = Penal.list(all), classes = CLASS_LIST, all = all }
end, { rate = 250 })

Api.register('penal.categorySave', 'penal.manage', function(src, ctx, data)
    local id, idOk = optional(data.id, V.id)
    local sort, sortOk = optional(data.sort, V.int, 0, 100000)
    local name = V.str(data.name, 48, 2)
    if not idOk or not sortOk or not name then return false, 'bad_request' end
    if id and not cache.byCat[id] then return false, 'not_found' end
    local dup = Db.scalar('SELECT `id` FROM `vr_mdt_charge_categories` WHERE LOWER(`name`) = LOWER(?) AND `id` <> ? LIMIT 1', { name, id or 0 })
    if dup then return false, 'already_exists' end
    if id then
        local n = Db.update('UPDATE `vr_mdt_charge_categories` SET `name` = ?, `sort` = ? WHERE `id` = ?', { name, sort or cache.byCat[id].sort, id })
        if n == nil then return false, 'save_failed' end
        changed(ctx, 'penal.categoryEdit', id, { name = name })
    else
        sort = sort or nextSort('SELECT COALESCE(MAX(`sort`), 0) FROM `vr_mdt_charge_categories`')
        id = Db.insert('INSERT INTO `vr_mdt_charge_categories` (`name`, `sort`) VALUES (?, ?)', { name, sort })
        if not id then return false, 'save_failed' end
        changed(ctx, 'penal.categoryCreate', id, { name = name })
    end
    return true, Penal.category(id)
end, { rate = 400 })

Api.register('penal.categoryDelete', 'penal.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local cat = cache.byCat[id]
    if not cat then return false, 'not_found' end
    local n = int(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_charges` WHERE `category_id` = ?', { id }))
    if n > 0 then return false, 'category_not_empty' end
    if Db.update('DELETE FROM `vr_mdt_charge_categories` WHERE `id` = ?', { id }) == nil then return false, 'save_failed' end
    changed(ctx, 'penal.categoryDelete', id, { name = cat.name })
    return true, { deleted = true }
end, { rate = 400 })

local function cleanCharge(data)
    local id, idOk = optional(data.id, V.id)
    local sort, sortOk = optional(data.sort, V.int, 0, 100000)
    local description, descOk = optional(data.description, V.text, 1000)
    local active = true
    if data.active ~= nil then active = V.bool(data.active) end
    local c = {
        id = id,
        categoryId = V.id(data.category),
        title = V.str(data.title, 96, 3),
        description = description,
        class = V.enum(data.class, CLASSES),
        fine = V.int(data.fine, 0, Config.Penal.maxFine),
        months = V.int(data.months == nil and 0 or data.months, 0, Config.Prison.maxMonths),
        points = V.int(data.points == nil and 0 or data.points, 0, Config.Penal.maxPoints),
        sort = sort,
        active = active,
    }
    if not idOk or not sortOk or not descOk or active == nil then return nil, 'bad_request' end
    if not c.categoryId or not c.title or not c.class or not c.fine or not c.months or not c.points then return nil, 'bad_request' end
    if c.class == 'infraction' and c.months > 0 then return nil, 'infraction_no_jail' end
    if not cache.byCat[c.categoryId] then return nil, 'unknown_category' end
    if c.id and not cache.byId[c.id] then return nil, 'not_found' end
    return c
end

Api.register('penal.chargeSave', 'penal.manage', function(src, ctx, data)
    local c, err = cleanCharge(data)
    if not c then return false, err end
    local dup = Db.scalar('SELECT `id` FROM `vr_mdt_charges` WHERE `category_id` = ? AND LOWER(`title`) = LOWER(?) AND `id` <> ? LIMIT 1', { c.categoryId, c.title, c.id or 0 })
    if dup then return false, 'already_exists' end
    local now = U.now()
    local by = ctx.callsign and ('%s %s'):format(ctx.callsign, ctx.name) or ctx.name
    local before = c.id and cache.byId[c.id] or nil
    if c.id then
        local sort = c.sort or (before.categoryId == c.categoryId and before.sort or nextSort('SELECT COALESCE(MAX(`sort`), 0) FROM `vr_mdt_charges` WHERE `category_id` = ?', { c.categoryId }))
        local n = Db.update([[UPDATE `vr_mdt_charges` SET `category_id` = ?, `title` = ?, `description` = ?, `class` = ?, `fine` = ?, `months` = ?, `points` = ?,
            `sort` = ?, `active` = ?, `updated_at` = ?, `updated_by` = ? WHERE `id` = ?]],
            { c.categoryId, c.title, c.description, c.class, c.fine, c.months, c.points, sort, c.active and 1 or 0, now, by, c.id })
        if n == nil then return false, 'save_failed' end
        changed(ctx, 'penal.chargeEdit', c.id, {
            title = c.title,
            from = { fine = before.fine, months = before.months, points = before.points, class = before.class, active = before.active },
            to = { fine = c.fine, months = c.months, points = c.points, class = c.class, active = c.active },
        })
    else
        local sort = c.sort or nextSort('SELECT COALESCE(MAX(`sort`), 0) FROM `vr_mdt_charges` WHERE `category_id` = ?', { c.categoryId })
        c.id = Db.insert([[INSERT INTO `vr_mdt_charges` (`category_id`, `title`, `description`, `class`, `fine`, `months`, `points`, `sort`, `active`, `updated_at`, `updated_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { c.categoryId, c.title, c.description, c.class, c.fine, c.months, c.points, sort, c.active and 1 or 0, now, by })
        if not c.id then return false, 'save_failed' end
        changed(ctx, 'penal.chargeCreate', c.id, { title = c.title, fine = c.fine, months = c.months, class = c.class })
    end
    return true, Penal.get(c.id)
end, { rate = 400 })

function Penal.referenced(id)
    local probe = json.encode({ id = id })
    if Db.scalar('SELECT 1 FROM `vr_mdt_report_people` WHERE `charges` IS NOT NULL AND JSON_VALID(`charges`) AND JSON_CONTAINS(`charges`, ?) LIMIT 1', { probe }) then return true end
    if Db.scalar('SELECT 1 FROM `vr_mdt_sentences` WHERE JSON_VALID(`charges`) AND JSON_CONTAINS(`charges`, ?) LIMIT 1', { probe }) then return true end
    return false
end

Api.register('penal.chargeDelete', 'penal.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local c = cache.byId[id]
    if not c then return false, 'not_found' end
    if Penal.referenced(id) then
        if Db.update('UPDATE `vr_mdt_charges` SET `active` = 0, `updated_at` = ? WHERE `id` = ?', { U.now(), id }) == nil then return false, 'save_failed' end
        changed(ctx, 'penal.chargeDeactivate', id, { title = c.title })
        return true, { deactivated = true, charge = Penal.get(id) }
    end
    if Db.update('DELETE FROM `vr_mdt_charges` WHERE `id` = ?', { id }) == nil then return false, 'save_failed' end
    changed(ctx, 'penal.chargeDelete', id, { title = c.title })
    return true, { deleted = true }
end, { rate = 400 })

Api.register('penal.reorder', 'penal.manage', function(src, ctx, data)
    local cats, okCats = optional(data.categories, V.list, 100, V.id)
    local charges, okCharges = optional(data.charges, V.list, 400, V.id)
    if not okCats or not okCharges then return false, 'bad_request' end
    if (not cats or #cats == 0) and (not charges or #charges == 0) then return false, 'bad_request' end
    local moved = 0
    for i, id in ipairs(cats or {}) do
        if cache.byCat[id] then
            Db.update('UPDATE `vr_mdt_charge_categories` SET `sort` = ? WHERE `id` = ?', { i * 10, id })
            moved = moved + 1
        end
    end
    for i, id in ipairs(charges or {}) do
        if cache.byId[id] then
            Db.update('UPDATE `vr_mdt_charges` SET `sort` = ? WHERE `id` = ?', { i * 10, id })
            moved = moved + 1
        end
    end
    if moved == 0 then return false, 'not_found' end
    changed(ctx, 'penal.reorder', nil, { categories = cats and #cats or 0, charges = charges and #charges or 0 })
    return true, { categories = Penal.list(true) }
end, { rate = 400 })

local function seed()
    local cats = Db.scalar('SELECT COUNT(*) FROM `vr_mdt_charge_categories`')
    local charges = Db.scalar('SELECT COUNT(*) FROM `vr_mdt_charges`')
    if cats == nil or charges == nil or int(cats) > 0 or int(charges) > 0 then return end
    if Db.scalar("SELECT 1 FROM `vr_mdt_audit` WHERE `action` = 'penal.seed' LIMIT 1") then return end
    local now, n = U.now(), 0
    for ci, cat in ipairs(SEED) do
        local catId = Db.insert('INSERT INTO `vr_mdt_charge_categories` (`name`, `sort`) VALUES (?, ?)', { cat.name, ci * 10 })
        if not catId then return end
        for i, c in ipairs(cat.charges) do
            local id = Db.insert([[INSERT INTO `vr_mdt_charges` (`category_id`, `title`, `description`, `class`, `fine`, `months`, `points`, `sort`, `active`, `updated_at`, `updated_by`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)]], { catId, c[1], c[6], c[2], c[3], c[4], c[5], i * 10, now, 'System' })
            if id then n = n + 1 end
        end
    end
    Audit.log(nil, 'penal.seed', nil, { categories = #SEED, charges = n })
    print(('^2[vr-mdt] penal code seeded with %d charges^0'):format(n))
end

Db.ready(function()
    seed()
    Penal.reload()
end)
