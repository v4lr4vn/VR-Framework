Db = { ready = false }

local waiting = {}

local TABLE = [[CREATE TABLE IF NOT EXISTS `vr_business_licences` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `number` VARCHAR(24) DEFAULT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `holder` VARCHAR(80) NOT NULL,
    `type` VARCHAR(40) NOT NULL,
    `business` VARCHAR(64) NOT NULL,
    `business_key` VARCHAR(64) NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'active',
    `issued` INT UNSIGNED NOT NULL DEFAULT 0,
    `expires` INT UNSIGNED NOT NULL DEFAULT 0,
    `note` VARCHAR(160) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `number` (`number`),
    KEY `citizenid` (`citizenid`),
    KEY `business_key` (`business_key`)
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
        MySQL.query.await(TABLE)
    end)
    if not ok then print(('^1[vr-cityhall] schema: %s^0'):format(tostring(err))) end
    if GetResourceState('vr-core') == 'started' then
        pcall(function()
            exports['vr-core']:GetCoreObject({ 'Functions' }).Functions.RegisterCharacterTable('vr_business_licences', 'citizenid')
        end)
    end
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
