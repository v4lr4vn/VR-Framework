Db = { ready = false }

local waiting = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `vr_bank_accounts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `number` VARCHAR(16) NOT NULL,
        `type` VARCHAR(12) NOT NULL,
        `owner` VARCHAR(64) NOT NULL,
        `label` VARCHAR(48) NOT NULL,
        `balance` BIGINT NOT NULL DEFAULT 0,
        `frozen` TINYINT(1) NOT NULL DEFAULT 0,
        `closed` TINYINT(1) NOT NULL DEFAULT 0,
        `interest_at` INT UNSIGNED NOT NULL DEFAULT 0,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `number` (`number`),
        KEY `owner` (`type`, `owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_members` (
        `account_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `role` VARCHAR(12) NOT NULL DEFAULT 'member',
        `added` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`account_id`, `citizenid`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_transactions` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `account_id` INT UNSIGNED NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `amount` BIGINT NOT NULL,
        `balance` BIGINT DEFAULT NULL,
        `other` VARCHAR(64) DEFAULT NULL,
        `reason` VARCHAR(128) DEFAULT NULL,
        `actor` VARCHAR(64) DEFAULT NULL,
        `actor_name` VARCHAR(64) DEFAULT NULL,
        `card_id` VARCHAR(20) DEFAULT NULL,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `account_at` (`account_id`, `at`),
        KEY `card_at` (`card_id`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_cards` (
        `id` VARCHAR(20) NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        `holder` VARCHAR(64) NOT NULL,
        `holder_name` VARCHAR(64) NOT NULL,
        `pin_hash` CHAR(64) NOT NULL,
        `pin_salt` CHAR(16) NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'active',
        `fails` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `locked_until` INT UNSIGNED NOT NULL DEFAULT 0,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `holder` (`holder`),
        KEY `account` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_credit` (
        `citizenid` VARCHAR(64) NOT NULL,
        `score` SMALLINT NOT NULL,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_credit_log` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `delta` SMALLINT NOT NULL,
        `score` SMALLINT NOT NULL,
        `reason` VARCHAR(64) NOT NULL,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid_at` (`citizenid`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_loans` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `principal` BIGINT NOT NULL,
        `interest` BIGINT NOT NULL,
        `total` BIGINT NOT NULL,
        `remaining` BIGINT NOT NULL,
        `installment` BIGINT NOT NULL,
        `arrears` BIGINT NOT NULL DEFAULT 0,
        `fees` BIGINT NOT NULL DEFAULT 0,
        `term` SMALLINT UNSIGNED NOT NULL,
        `paid_count` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `missed` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `missed_total` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `interval_h` SMALLINT UNSIGNED NOT NULL,
        `next_due` INT UNSIGNED NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'active',
        `rate` DECIMAL(5,2) NOT NULL DEFAULT 0,
        `kind` VARCHAR(12) NOT NULL DEFAULT 'loan',
        `plate` VARCHAR(12) DEFAULT NULL,
        `model` VARCHAR(64) DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        `closed_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `status_due` (`status`, `next_due`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_cases` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `loan_id` INT UNSIGNED DEFAULT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `amount` BIGINT NOT NULL,
        `original` BIGINT NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'open',
        `claimed_by` VARCHAR(64) DEFAULT NULL,
        `claimed_name` VARCHAR(64) DEFAULT NULL,
        `claimed_until` INT UNSIGNED NOT NULL DEFAULT 0,
        `log` TEXT DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `status` (`status`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_repos` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `plate` VARCHAR(12) NOT NULL,
        `case_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `model` VARCHAR(64) DEFAULT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'held',
        `seized_by` VARCHAR(64) DEFAULT NULL,
        `seized_name` VARCHAR(64) DEFAULT NULL,
        `seized_at` INT UNSIGNED NOT NULL,
        `released_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `plate_status` (`plate`, `status`),
        KEY `case_id` (`case_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_staged` (
        `plate` VARCHAR(12) NOT NULL,
        `case_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `model` VARCHAR(64) DEFAULT NULL,
        `x` DOUBLE DEFAULT NULL,
        `y` DOUBLE DEFAULT NULL,
        `z` DOUBLE DEFAULT NULL,
        `h` DOUBLE DEFAULT NULL,
        `staged_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`plate`),
        KEY `case_id` (`case_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `vr_bank_repo_spots` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `x` DOUBLE NOT NULL,
        `y` DOUBLE NOT NULL,
        `z` DOUBLE NOT NULL,
        `h` DOUBLE NOT NULL,
        `added_by` VARCHAR(64) DEFAULT NULL,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

function Db.tableExists(name)
    return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) == 1
end

function Db.columnExists(tbl, column)
    return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, column }) == 1
end

Db.vehicles = false

MySQL.ready(function()
    for i = 1, #SCHEMA do
        local ok, err = pcall(MySQL.query.await, SCHEMA[i])
        if not ok then print(('^1[vr-banking] schema: %s^0'):format(tostring(err))) end
    end
    if not Db.columnExists('vr_bank_loans', 'kind') then
        pcall(MySQL.query.await, "ALTER TABLE `vr_bank_loans` ADD COLUMN `kind` VARCHAR(12) NOT NULL DEFAULT 'loan'")
    end
    local v = Config.Vehicles
    Db.vehicles = Db.tableExists(v.table) and Db.columnExists(v.table, v.owner) and Db.columnExists(v.table, v.plate) and Db.columnExists(v.table, v.model)
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
