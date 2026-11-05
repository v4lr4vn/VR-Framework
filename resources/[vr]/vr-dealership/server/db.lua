Db = { ready = false }

local waiting = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `vr_dealership_display` (
        `dealer` VARCHAR(40) NOT NULL,
        `slot` INT UNSIGNED NOT NULL,
        `model` VARCHAR(50) NOT NULL,
        PRIMARY KEY (`dealer`, `slot`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_dealership_locations` (
        `id` VARCHAR(40) NOT NULL,
        `data` LONGTEXT NOT NULL,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_dealership_sales` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `dealer` VARCHAR(40) NOT NULL,
        `model` VARCHAR(50) NOT NULL,
        `plate` VARCHAR(15) NOT NULL,
        `price` INT UNSIGNED NOT NULL,
        `payment` VARCHAR(12) NOT NULL,
        `buyer` VARCHAR(64) NOT NULL,
        `buyer_name` VARCHAR(64) NOT NULL,
        `seller` VARCHAR(64) DEFAULT NULL,
        `seller_name` VARCHAR(64) DEFAULT NULL,
        `commission` INT UNSIGNED NOT NULL DEFAULT 0,
        `loan_id` INT UNSIGNED DEFAULT NULL,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `dealer_at` (`dealer`, `at`),
        KEY `seller` (`seller`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

function Db.onReady(fn)
    if Db.ready then CreateThread(fn) else waiting[#waiting + 1] = fn end
end

MySQL.ready(function()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[vr-dealership] schema: %s^0'):format(tostring(err))) end
    end
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
