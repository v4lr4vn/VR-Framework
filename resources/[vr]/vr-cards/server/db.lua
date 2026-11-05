Db = { ready = false }

local waiting = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `vr_cards_copies` (
        `uid` VARCHAR(16) NOT NULL,
        `card` VARCHAR(40) NOT NULL,
        `foil` VARCHAR(8) NOT NULL DEFAULT 'none',
        `serial` INT UNSIGNED NOT NULL DEFAULT 0,
        `centering` TINYINT UNSIGNED NOT NULL,
        `corners` TINYINT UNSIGNED NOT NULL,
        `edges` TINYINT UNSIGNED NOT NULL,
        `surface` TINYINT UNSIGNED NOT NULL,
        `grade` TINYINT UNSIGNED DEFAULT NULL,
        `cert` VARCHAR(16) DEFAULT NULL,
        `state` VARCHAR(10) NOT NULL DEFAULT 'item',
        `holder` VARCHAR(64) DEFAULT NULL,
        `pulled_by` VARCHAR(64) DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`uid`),
        KEY `card` (`card`),
        KEY `state_holder` (`state`, `holder`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_prints` (
        `card` VARCHAR(40) NOT NULL,
        `n` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`card`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_dex` (
        `citizenid` VARCHAR(64) NOT NULL,
        `card` VARCHAR(40) NOT NULL,
        `first_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`citizenid`, `card`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_binders` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `title` VARCHAR(64) NOT NULL,
        `created_by` VARCHAR(64) DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_binder_slots` (
        `binder` INT UNSIGNED NOT NULL,
        `slot` INT UNSIGNED NOT NULL,
        `uid` VARCHAR(16) NOT NULL,
        PRIMARY KEY (`binder`, `slot`),
        UNIQUE KEY `uid` (`uid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_grading` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `uid` VARCHAR(16) NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `tier` VARCHAR(16) NOT NULL,
        `fee` INT UNSIGNED NOT NULL DEFAULT 0,
        `submitted` INT UNSIGNED NOT NULL,
        `ready_at` INT UNSIGNED NOT NULL,
        `notified` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `collected` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`citizenid`, `collected`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_cards_settings` (
        `key` VARCHAR(40) NOT NULL,
        `value` LONGTEXT NOT NULL,
        PRIMARY KEY (`key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

function Db.onReady(fn)
    if Db.ready then CreateThread(fn) else waiting[#waiting + 1] = fn end
end

MySQL.ready(function()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[vr-cards] schema: %s^0'):format(tostring(err))) end
    end
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
