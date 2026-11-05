Db = { ready = false }

local waiting = {}

local KEYS = [[CREATE TABLE IF NOT EXISTS `vr_vehicle_keys` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(15) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `holder` VARCHAR(80) DEFAULT NULL,
    `given_by` VARCHAR(80) DEFAULT NULL,
    `expires` INT UNSIGNED NOT NULL DEFAULT 0,
    `created` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `holding` (`plate`, `citizenid`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(KEYS)
    end)
    if not ok then print(('^1[vr-vehiclekeys] schema: %s^0'):format(tostring(err))) end
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
