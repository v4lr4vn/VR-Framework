Db = { ready = false, vehicles = false }

local waiting = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `vr_mechanic_locations` (
        `id` VARCHAR(40) NOT NULL,
        `data` LONGTEXT NOT NULL,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_mechanic_jobs` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(12) NOT NULL,
        `workshop` VARCHAR(40) DEFAULT NULL,
        `plate` VARCHAR(15) DEFAULT NULL,
        `mechanic` VARCHAR(64) NOT NULL,
        `mechanic_name` VARCHAR(64) NOT NULL,
        `customer` VARCHAR(64) DEFAULT NULL,
        `customer_name` VARCHAR(64) DEFAULT NULL,
        `details` TEXT DEFAULT NULL,
        `amount` INT UNSIGNED NOT NULL DEFAULT 0,
        `commission` INT UNSIGNED NOT NULL DEFAULT 0,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `mechanic` (`mechanic`),
        KEY `plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_mechanic_orders` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `source` VARCHAR(10) NOT NULL,
        `status` VARCHAR(10) NOT NULL,
        `plate` VARCHAR(15) NOT NULL,
        `vehicle` VARCHAR(64) DEFAULT NULL,
        `customer` VARCHAR(64) DEFAULT NULL,
        `customer_name` VARCHAR(64) DEFAULT NULL,
        `workshop` VARCHAR(40) DEFAULT NULL,
        `job` VARCHAR(40) NOT NULL,
        `changes` LONGTEXT NOT NULL,
        `keep` LONGTEXT DEFAULT NULL,
        `items` LONGTEXT NOT NULL,
        `tasks` LONGTEXT NOT NULL,
        `total` INT UNSIGNED NOT NULL DEFAULT 0,
        `mechanic` VARCHAR(64) DEFAULT NULL,
        `mechanic_name` VARCHAR(64) DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `status` (`status`),
        KEY `customer` (`customer`),
        KEY `job_status` (`job`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

function Db.onReady(fn)
    if Db.ready then CreateThread(fn) else waiting[#waiting + 1] = fn end
end

function Db.log(kind, mech, customer, d)
    MySQL.insert('INSERT INTO vr_mechanic_jobs (kind, workshop, plate, mechanic, mechanic_name, customer, customer_name, details, amount, commission, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        kind, d.workshop, d.plate, mech.cid, mech.name, customer and customer.cid or nil, customer and customer.name or nil,
        d.details, math.floor(d.amount or 0), math.floor(d.commission or 0), os.time(),
    })
end

MySQL.ready(function()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[vr-mechanic] schema: %s^0'):format(tostring(err))) end
    end
    local ok, rows = pcall(MySQL.query.await, "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_vehicles'")
    Db.vehicles = ok and rows and rows[1] and tonumber(rows[1].n) == 1 or false
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
