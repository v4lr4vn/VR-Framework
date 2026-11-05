Db = { ready = false }

local waiting = {}

local TABLE = [[CREATE TABLE IF NOT EXISTS `vr_civjobs_progress` (
    `cid` VARCHAR(100) NOT NULL,
    `job` VARCHAR(40) NOT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    `done` INT NOT NULL DEFAULT 0,
    `earned` BIGINT NOT NULL DEFAULT 0,
    `data` TEXT DEFAULT NULL,
    PRIMARY KEY (`cid`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local SETUP = [[CREATE TABLE IF NOT EXISTS `vr_civjobs_setup` (
    `job` VARCHAR(40) NOT NULL,
    `field` VARCHAR(60) NOT NULL,
    `value` MEDIUMTEXT NOT NULL,
    PRIMARY KEY (`job`, `field`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

function Db.await()
    local deadline = GetGameTimer() + 15000
    while not Db.ready and GetGameTimer() < deadline do Wait(50) end
    return Db.ready
end

local function register()
    if GetResourceState('vr-core') ~= 'started' then return end
    pcall(function()
        exports['vr-core']:GetCoreObject({ 'Functions' }).Functions.RegisterCharacterTable('vr_civjobs_progress', 'cid')
    end)
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(TABLE)
        MySQL.query.await(SETUP)
    end)
    if not ok then print(('^1[vr-civjobs] schema: %s^0'):format(tostring(err))) end
    register()
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)

AddEventHandler('onResourceStart', function(name)
    if name == 'vr-core' then register() end
end)
