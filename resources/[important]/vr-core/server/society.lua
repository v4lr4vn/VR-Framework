local Functions = VRCore.Functions
local accounts = {}
local ready = false

local function validName(name)
    return type(name) == 'string' and (VRCore.Shared.Jobs[name] ~= nil or VRCore.Shared.Gangs[name] ~= nil)
end

local function wholeAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge or amount <= 0 then return nil end
    return math.floor(amount)
end

local function load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `vr_society` (
        `name` varchar(50) NOT NULL,
        `money` bigint(20) NOT NULL DEFAULT 0,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local rows = MySQL.query.await('SELECT name, money FROM vr_society') or {}
    for i = 1, #rows do accounts[rows[i].name] = tonumber(rows[i].money) or 0 end
    ready = true
end

MySQL.ready(function()
    local ok, err = pcall(load)
    if not ok then VRCore.ShowError(GetCurrentResourceName(), 'society accounts failed to load: ' .. tostring(err)) end
end)

function Functions.GetSocietyMoney(name)
    if not validName(name) then return 0 end
    return accounts[name] or 0
end

function Functions.AddSocietyMoney(name, amount, reason)
    amount = wholeAmount(amount)
    if not amount or not validName(name) or not ready then return false end
    accounts[name] = (accounts[name] or 0) + amount
    MySQL.update('INSERT INTO vr_society (name, money) VALUES (?, ?) ON DUPLICATE KEY UPDATE money = money + VALUES(money)', { name, amount })
    CoreEmit('Server:OnSocietyMoneyChange', name, amount, 'add', reason or 'unknown', accounts[name])
    CoreLog('society', 'AddSocietyMoney', 'lightgreen', false, '$%s added to %s (%s), new balance %s', amount, name, reason or 'unknown', accounts[name])
    return true
end

function Functions.RemoveSocietyMoney(name, amount, reason)
    amount = wholeAmount(amount)
    if not amount or not validName(name) or not ready then return false end
    if (accounts[name] or 0) < amount then return false end
    accounts[name] = accounts[name] - amount
    MySQL.update('UPDATE vr_society SET money = money - ? WHERE name = ?', { amount, name })
    CoreEmit('Server:OnSocietyMoneyChange', name, amount, 'remove', reason or 'unknown', accounts[name])
    CoreLog('society', 'RemoveSocietyMoney', 'red', false, '$%s removed from %s (%s), new balance %s', amount, name, reason or 'unknown', accounts[name])
    return true
end
