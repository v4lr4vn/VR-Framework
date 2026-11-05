-- Restaurants: shared state and helpers. Business rules are in business.lua, admin tools in admin.lua.
Rest = { biz = {}, byCid = {}, duty = {}, stations = {}, bans = {}, ready = false, loaded = false }

local last = {}

local BUSINESSES = [[CREATE TABLE IF NOT EXISTS `vr_rest_businesses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(48) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    `owner` VARCHAR(64) NOT NULL DEFAULT '',
    `owner_name` VARCHAR(64) NOT NULL DEFAULT '',
    `max_wage` INT UNSIGNED NOT NULL DEFAULT 0,
    `owner_wage` INT UNSIGNED NOT NULL DEFAULT 0,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `licence_days` INT UNSIGNED NOT NULL DEFAULT 30,
    `licence_number` VARCHAR(16) NOT NULL DEFAULT '',
    `licence_expires` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` VARCHAR(12) NOT NULL DEFAULT 'open',
    `closed_until` INT UNSIGNED NOT NULL DEFAULT 0,
    `closed_reason` VARCHAR(16) NOT NULL DEFAULT '',
    `strikes` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_strike` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_inspected` INT UNSIGNED NOT NULL DEFAULT 0,
    `balance` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Tables made by the first version get the new columns. One statement, a no-op when they exist.
local BUSINESSES_UPGRADE = [[ALTER TABLE `vr_rest_businesses`
    ADD COLUMN IF NOT EXISTS `price` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `licence_days` INT UNSIGNED NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS `licence_number` VARCHAR(16) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS `licence_expires` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `status` VARCHAR(12) NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS `closed_until` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `closed_reason` VARCHAR(16) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS `strikes` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `last_strike` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `last_inspected` INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `balance` BIGINT NOT NULL DEFAULT 0]]

local STATIONS = [[CREATE TABLE IF NOT EXISTS `vr_rest_stations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(16) NOT NULL,
    `label` VARCHAR(32) NOT NULL DEFAULT '',
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    `radius` DOUBLE NOT NULL DEFAULT 1.5,
    `dirt` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `business` (`business`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local INSPECTIONS = [[CREATE TABLE IF NOT EXISTS `vr_rest_inspections` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business` INT UNSIGNED NOT NULL,
    `at` INT UNSIGNED NOT NULL,
    `by_name` VARCHAR(64) NOT NULL DEFAULT '',
    `hygiene` INT NOT NULL DEFAULT 0,
    `licence_ok` TINYINT NOT NULL DEFAULT 0,
    `outcome` VARCHAR(24) NOT NULL DEFAULT '',
    `fine` INT UNSIGNED NOT NULL DEFAULT 0,
    `note` VARCHAR(200) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `business` (`business`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local BANS = [[CREATE TABLE IF NOT EXISTS `vr_rest_bans` (
    `cid` VARCHAR(64) NOT NULL,
    `until_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local RANKS = [[CREATE TABLE IF NOT EXISTS `vr_rest_ranks` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business` INT UNSIGNED NOT NULL,
    `level` INT NOT NULL,
    `label` VARCHAR(24) NOT NULL,
    `wage` INT UNSIGNED NOT NULL DEFAULT 0,
    `perms` VARCHAR(128) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `business` (`business`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- One business per character: the character id is the key.
local STAFF = [[CREATE TABLE IF NOT EXISTS `vr_rest_staff` (
    `cid` VARCHAR(64) NOT NULL,
    `business` INT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL DEFAULT '',
    `rank_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`cid`),
    KEY `business` (`business`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Rest.fail(code, data)
    return { ok = false, error = code, data = data }
end

function Rest.info(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return { src = src, cid = p.cid, name = p.name or 'Citizen' }
end

function Rest.notify(src, text, kind)
    if src then Bridge.notify(src, text, kind or 'inform', nil, 'Restaurant') end
end

function Rest.throttle(src, key, ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function Rest.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

function Rest.num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function Rest.int(v, lo, hi)
    v = Rest.num(v)
    if not v then return nil end
    v = math.floor(v + 0.5)
    if lo and v < lo then return nil end
    if hi and v > hi then return nil end
    return v
end

function Rest.text(v, min, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, max)
    if #v < min then return nil end
    return v
end

function Rest.distance(src, x, y, z)
    local p = Bridge.coords(src)
    if not p then return nil end
    local dx, dy, dz = p.x - x, p.y - y, p.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Each restaurant keeps its own money. The framework's society accounts only exist for jobs and gangs,
-- so a restaurant could never use them. The balance lives on the business row.
Rest.bank = {}

function Rest.bank.balance(b) return b and b.balance or 0 end

function Rest.bank.add(b, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not b or amount <= 0 then return false end
    b.balance = (b.balance or 0) + amount
    MySQL.query('UPDATE vr_rest_businesses SET balance = balance + ? WHERE id = ?', { amount, b.id })
    return true
end

function Rest.bank.remove(b, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not b or amount <= 0 or (b.balance or 0) < amount then return false end
    b.balance = b.balance - amount
    MySQL.query('UPDATE vr_rest_businesses SET balance = GREATEST(balance - ?, 0) WHERE id = ?', { amount, b.id })
    return true
end

function Rest.view(b)
    return { id = b.id, label = b.label, x = b.x, y = b.y, z = b.z, w = b.w, closed = Rest.isClosed and Rest.isClosed(b) or false }
end

function Rest.stationView(s)
    return { id = s.id, business = s.business, kind = s.kind, label = s.label, x = s.x, y = s.y, z = s.z, w = s.w, radius = s.radius }
end

function Rest.stationList()
    local out = {}
    for _, s in pairs(Rest.stations) do out[#out + 1] = Rest.stationView(s) end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

function Rest.pushStations()
    TriggerClientEvent('vr-restaurant:client:stations', -1, Rest.stationList())
end

function Rest.list()
    local out = {}
    for _, b in pairs(Rest.biz) do out[#out + 1] = Rest.view(b) end
    table.sort(out, function(a, c) return a.id < c.id end)
    return out
end

-- Tells every client where the restaurants are.
function Rest.push()
    TriggerClientEvent('vr-restaurant:client:spots', -1, Rest.list())
end

local waiting = {}
function Rest.onReady(fn)
    if Rest.ready then return CreateThread(fn) end
    waiting[#waiting + 1] = fn
end

local function permsToText(list) return table.concat(list or {}, ',') end

local function permsFromText(text)
    local valid, out = {}, {}
    for _, p in ipairs(Config.Perms) do valid[p.id] = true end
    for id in tostring(text or ''):gmatch('[^,]+') do
        if valid[id] then out[#out + 1] = id end
    end
    return out
end
Rest.permsToText, Rest.permsFromText = permsToText, permsFromText

-- Which business each character belongs to. Anyone whose answer changed is told, so their
-- cleaning points and menus update straight away.
function Rest.index()
    local before = Rest.byCid or {}
    Rest.byCid = {}
    for id, b in pairs(Rest.biz) do
        if b.owner ~= '' then Rest.byCid[b.owner] = id end
        for cid in pairs(b.staff) do Rest.byCid[cid] = id end
    end
    if not Rest.loaded then return end
    for cid, id in pairs(Rest.byCid) do
        if before[cid] ~= id then
            local src = Bridge.source(cid)
            if src then TriggerClientEvent('vr-restaurant:client:mine', src, id) end
        end
    end
    for cid in pairs(before) do
        if not Rest.byCid[cid] then
            local src = Bridge.source(cid)
            if src then TriggerClientEvent('vr-restaurant:client:mine', src, false) end
        end
    end
end

lib.callback.register('vr-restaurant:mine', function(src)
    local who = Rest.info(src)
    return who and Rest.byCid[who.cid] or false
end)

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(BUSINESSES)
        MySQL.query.await(RANKS)
        MySQL.query.await(STAFF)
        pcall(function() MySQL.query.await(BUSINESSES_UPGRADE) end)
        MySQL.query.await(STATIONS)
        MySQL.query.await(INSPECTIONS)
        MySQL.query.await(BANS)
    end)
    if not ok then print(('^1[vr-restaurant] schema: %s^0'):format(tostring(err))) end
    if ok then
        for _, r in ipairs(MySQL.query.await('SELECT * FROM vr_rest_businesses') or {}) do
            Rest.biz[r.id] = {
                id = r.id, label = r.label, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0.0) + 0.0,
                owner = r.owner or '', ownerName = r.owner_name or '',
                maxWage = tonumber(r.max_wage) or 0, ownerWage = tonumber(r.owner_wage) or 0,
                price = tonumber(r.price) or 0, licenceDays = tonumber(r.licence_days) or Config.Licence.defaultDays,
                licenceNumber = r.licence_number or '', licenceExpires = tonumber(r.licence_expires) or 0,
                status = r.status or 'open', closedUntil = tonumber(r.closed_until) or 0, closedReason = r.closed_reason or '',
                strikes = tonumber(r.strikes) or 0, lastStrike = tonumber(r.last_strike) or 0, lastInspected = tonumber(r.last_inspected) or 0,
                balance = math.max(0, math.floor(tonumber(r.balance) or 0)),
                ranks = {}, staff = {}, stations = {}, history = {},
            }
        end
        for _, r in ipairs(MySQL.query.await('SELECT id, business, kind, label, x, y, z, w, radius, dirt FROM vr_rest_stations') or {}) do
            local b = Rest.biz[r.business]
            if b then
                local s = { id = r.id, business = r.business, kind = r.kind, label = r.label or '', x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0.0) + 0.0, radius = (tonumber(r.radius) or 1.5) + 0.0, dirt = math.max(0.0, math.min(100.0, (tonumber(r.dirt) or 0) + 0.0)) }
                b.stations[s.id] = s
                Rest.stations[s.id] = s
            end
        end
        for _, r in ipairs(MySQL.query.await('SELECT cid, until_at FROM vr_rest_bans') or {}) do
            Rest.bans[r.cid] = tonumber(r.until_at) or 0
        end
        for _, r in ipairs(MySQL.query.await('SELECT business, at, by_name, hygiene, licence_ok, outcome, fine, note FROM vr_rest_inspections ORDER BY id DESC LIMIT 400') or {}) do
            local b = Rest.biz[r.business]
            if b and #b.history < Config.Inspect.history then
                b.history[#b.history + 1] = { at = r.at, by = r.by_name, hygiene = r.hygiene, licence = r.licence_ok == 1, outcome = r.outcome, fine = r.fine, note = r.note }
            end
        end
        for _, r in ipairs(MySQL.query.await('SELECT id, business, level, label, wage, perms FROM vr_rest_ranks') or {}) do
            local b = Rest.biz[r.business]
            if b then b.ranks[r.id] = { id = r.id, level = r.level, label = r.label, wage = tonumber(r.wage) or 0, perms = permsFromText(r.perms) } end
        end
        for _, r in ipairs(MySQL.query.await('SELECT cid, business, name, rank_id FROM vr_rest_staff') or {}) do
            local b = Rest.biz[r.business]
            if b and b.ranks[r.rank_id] then b.staff[r.cid] = { cid = r.cid, name = r.name, rank = r.rank_id } end
        end
        Rest.index()
    end
    Rest.ready = true
    Rest.loaded = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
    Rest.push()
    Rest.pushStations()
end)

lib.callback.register('vr-restaurant:stations', function()
    if not Rest.loaded then return {} end
    return Rest.stationList()
end)

lib.callback.register('vr-restaurant:spots', function()
    if not Rest.loaded then return {} end
    return Rest.list()
end)

AddEventHandler('playerJoining', function()
    if Rest.loaded then
        TriggerClientEvent('vr-restaurant:client:spots', source, Rest.list())
        TriggerClientEvent('vr-restaurant:client:stations', source, Rest.stationList())
    end
end)

exports('GetBusinesses', function() return Rest.list() end)
exports('GetBusinessOf', function(src)
    local who = Rest.info(src)
    local id = who and Rest.byCid[who.cid]
    return id and Rest.view(Rest.biz[id]) or nil
end)
