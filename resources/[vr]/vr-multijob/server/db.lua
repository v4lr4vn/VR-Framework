Db = { ready = false }

local waiting = {}

local TABLE = [[CREATE TABLE IF NOT EXISTS `vr_multijobs` (
    `citizenid` VARCHAR(100) NOT NULL,
    `jobdata` TEXT DEFAULT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Db.onReady(fn)
    if Db.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

local function register()
    if GetResourceState('vr-core') ~= 'started' then return end
    pcall(function()
        exports['vr-core']:GetCoreObject({ 'Functions' }).Functions.RegisterCharacterTable('vr_multijobs', 'citizenid')
    end)
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(TABLE)
    end)
    if not ok then print(('^1[vr-multijob] schema: %s^0'):format(tostring(err))) end
    register()
    Db.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)

AddEventHandler('onResourceStart', function(name)
    if name == 'vr-core' then register() end
end)

function Db.await()
    local tries = 0
    while not Db.ready and tries < 200 do
        Wait(50)
        tries = tries + 1
    end
    return Db.ready
end
