Db = { ready = false }

local waiting = {}

local BANKS = [[CREATE TABLE IF NOT EXISTS `vr_bankheist_banks` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL,
    `data` MEDIUMTEXT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local STATE = [[CREATE TABLE IF NOT EXISTS `vr_bankheist_state` (
    `bank` VARCHAR(50) NOT NULL,
    `ended` BIGINT NOT NULL DEFAULT 0,
    `times` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`bank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(BANKS)
        MySQL.query.await(STATE)
    end)
    if not ok then print(('^1[vr-bankheist] schema: %s^0'):format(tostring(err))) end
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
