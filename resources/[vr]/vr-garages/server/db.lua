Db = { ready = false }

local waiting = {}

local VEHICLES = [[CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(50) DEFAULT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `vehicle` VARCHAR(50) DEFAULT NULL,
    `hash` VARCHAR(50) DEFAULT NULL,
    `mods` LONGTEXT DEFAULT NULL,
    `plate` VARCHAR(15) NOT NULL,
    `fakeplate` VARCHAR(50) DEFAULT NULL,
    `garage` VARCHAR(50) DEFAULT NULL,
    `fuel` INT(11) DEFAULT 100,
    `engine` FLOAT DEFAULT 1000,
    `body` FLOAT DEFAULT 1000,
    `state` INT(11) DEFAULT 1,
    `depotprice` INT(11) NOT NULL DEFAULT 0,
    `drivingdistance` INT(50) DEFAULT NULL,
    `status` TEXT DEFAULT NULL,
    `balance` INT(11) NOT NULL DEFAULT 0,
    `paymentamount` INT(11) NOT NULL DEFAULT 0,
    `paymentsleft` INT(11) NOT NULL DEFAULT 0,
    `financetime` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate` (`plate`),
    KEY `citizenid` (`citizenid`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

local EXTRA = {
    { 'fleet', 'VARCHAR(60) DEFAULT NULL' },
    { 'nickname', 'VARCHAR(32) DEFAULT NULL' },
    { 'impound_reason', 'VARCHAR(128) DEFAULT NULL' },
    { 'impound_until', 'INT UNSIGNED NOT NULL DEFAULT 0' },
    { 'impound_by', 'VARCHAR(64) DEFAULT NULL' },
    { 'impound_at', 'INT UNSIGNED NOT NULL DEFAULT 0' },
}

local LOCATIONS = [[CREATE TABLE IF NOT EXISTS `vr_garage_locations` (
    `id` VARCHAR(40) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `updated` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

local function columns(tbl)
    local rows = MySQL.query.await('SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tbl }) or {}
    local out = {}
    for i = 1, #rows do out[rows[i].c] = true end
    return out
end

-- A player_vehicles table that already existed (from another framework or an old
-- import) can have an `id` that is not AUTO_INCREMENT. Then every insert fails with
-- "Field 'id' doesn't have a default value". Fix it in place.
local function repairId()
    local rows = MySQL.query.await("SELECT COLUMN_KEY AS k, EXTRA AS e, DATA_TYPE AS t FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles' AND COLUMN_NAME = 'id'") or {}
    local col = rows[1]
    local hasPrimary = (MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles' AND INDEX_NAME = 'PRIMARY'") or 0) > 0
    if not col then
        if hasPrimary then
            MySQL.query.await('ALTER TABLE `player_vehicles` ADD COLUMN `id` INT(11) NOT NULL AUTO_INCREMENT FIRST, ADD UNIQUE KEY `id` (`id`)')
        else
            MySQL.query.await('ALTER TABLE `player_vehicles` ADD COLUMN `id` INT(11) NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (`id`)')
        end
        print('^3[vr-garages] player_vehicles had no id column, added one^0')
        return
    end
    local extra = tostring(col.e or ''):lower()
    if extra:find('auto_increment', 1, true) then return end
    local keyed = col.k ~= nil and col.k ~= ''
    if keyed then
        MySQL.query.await('ALTER TABLE `player_vehicles` MODIFY `id` INT(11) NOT NULL AUTO_INCREMENT')
    elseif hasPrimary then
        MySQL.query.await('ALTER TABLE `player_vehicles` MODIFY `id` INT(11) NOT NULL AUTO_INCREMENT, ADD UNIQUE KEY `id` (`id`)')
    else
        MySQL.query.await('ALTER TABLE `player_vehicles` MODIFY `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`)')
    end
    print('^3[vr-garages] player_vehicles.id was not AUTO_INCREMENT, fixed it^0')
end

function Db.hasTable(name)
    return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) == 1
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(VEHICLES)
        MySQL.query.await(LOCATIONS)
        local fixed, fixErr = pcall(repairId)
        if not fixed then print(('^1[vr-garages] could not fix player_vehicles.id: %s. Run: ALTER TABLE player_vehicles MODIFY id INT(11) NOT NULL AUTO_INCREMENT;^0'):format(tostring(fixErr))) end
        local have = columns('player_vehicles')
        for _, col in ipairs(EXTRA) do
            if not have[col[1]] then MySQL.query.await(('ALTER TABLE `player_vehicles` ADD COLUMN `%s` %s'):format(col[1], col[2])) end
        end
    end)
    if not ok then print(('^1[vr-garages] schema: %s^0'):format(tostring(err))) end
    Db.properties = Db.hasTable('properties')
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
