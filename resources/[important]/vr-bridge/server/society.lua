local U = Bridge.util
local db = Bridge.db
local S = {}
Bridge.society = S

local BANKS = {
    ['Renewed-Banking'] = {
        balance = function(name) return exports['Renewed-Banking']:getAccountMoney(name) end,
        add = function(name, amount) return exports['Renewed-Banking']:addAccountMoney(name, amount) end,
        remove = function(name, amount) return exports['Renewed-Banking']:removeAccountMoney(name, amount) end,
    },
    ['qb-banking'] = {
        balance = function(name) return exports['qb-banking']:GetAccountBalance(name) end,
        add = function(name, amount, reason) return exports['qb-banking']:AddMoney(name, amount, reason) end,
        remove = function(name, amount, reason) return exports['qb-banking']:RemoveMoney(name, amount, reason) end,
    },
    ['qb-management'] = {
        balance = function(name) return exports['qb-management']:GetAccount(name) end,
        add = function(name, amount) return exports['qb-management']:AddMoney(name, amount) end,
        remove = function(name, amount) return exports['qb-management']:RemoveMoney(name, amount) end,
    },
    okokBanking = {
        balance = function(name) return exports.okokBanking:GetAccount(name) end,
        add = function(name, amount) return exports.okokBanking:AddMoney(name, amount) end,
        remove = function(name, amount) return exports.okokBanking:RemoveMoney(name, amount) end,
    },
    fd_banking = {
        balance = function(name) return exports.fd_banking:GetAccount(name) end,
        add = function(name, amount, reason) return exports.fd_banking:AddMoney(name, amount, reason) end,
        remove = function(name, amount, reason) return exports.fd_banking:RemoveMoney(name, amount, reason) end,
    },
}

local ready = false

local function ensure()
    if ready then return end
    db.query([[CREATE TABLE IF NOT EXISTS `vr_bridge_society` (
        `name` VARCHAR(64) NOT NULL,
        `balance` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    ready = true
end

local own = {
    balance = function(name)
        ensure()
        return tonumber(db.scalar('SELECT `balance` FROM `vr_bridge_society` WHERE `name` = ?', { name })) or 0
    end,
    add = function(name, amount)
        ensure()
        return db.query('INSERT INTO `vr_bridge_society` (`name`, `balance`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `balance` = `balance` + VALUES(`balance`)', { name, amount }) ~= nil
    end,
    remove = function(name, amount)
        ensure()
        local n = db.update('UPDATE `vr_bridge_society` SET `balance` = `balance` - ? WHERE `name` = ? AND `balance` >= ?', { amount, name, amount })
        return (tonumber(n) or 0) > 0
    end,
    set = function(name, amount)
        ensure()
        return db.query('INSERT INTO `vr_bridge_society` (`name`, `balance`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `balance` = VALUES(`balance`)', { name, amount }) ~= nil
    end,
}

local function chosen()
    local pref = GetConvar('vr_bridge:society', '')
    if pref == '' or pref == 'auto' then
        local cfg = BridgeConfig.society
        pref = type(cfg) == 'table' and cfg[Bridge.framework] or (type(cfg) == 'string' and cfg) or 'auto'
    end
    return pref or 'auto'
end

local function backend()
    local pref = chosen()
    if pref == 'bridge' then return own, 'bridge' end
    if pref ~= 'auto' and BANKS[pref] and U.started(pref) then return BANKS[pref], pref end
    local F = Bridge.fw or {}
    local api = F.societyApi
    if pref == 'auto' and api and (not api.ready or api.ready()) then return api, Bridge.framework end
    if pref == 'auto' then
        for _, name in ipairs({ 'Renewed-Banking', 'qb-banking', 'okokBanking', 'fd_banking', 'qb-management' }) do
            if U.started(name) then return BANKS[name], name end
        end
    end
    return own, 'bridge'
end

S.backend = function()
    local _, name = backend()
    return name
end

local function announce(api, name, amount, operation, reason)
    if api.events then return end
    local balance = S.balance(name)
    TriggerEvent('vr-bridge:societyChanged', name, amount, operation, reason, balance)
end

function S.balance(name)
    if type(name) ~= 'string' or name == '' then return 0 end
    local api = backend()
    local ok, res = pcall(api.balance, name)
    if not ok then
        print(('^1[vr-bridge] society balance failed: %s^0'):format(tostring(res)))
        return 0
    end
    return U.int(res, 0)
end

function S.add(name, amount, reason)
    amount = U.int(amount, 0)
    if type(name) ~= 'string' or name == '' or amount <= 0 then return false end
    local api = backend()
    local ok, res = pcall(api.add, name, amount, reason)
    if not ok then
        print(('^1[vr-bridge] society payment failed: %s^0'):format(tostring(res)))
        return false
    end
    if res == false then return false end
    announce(api, name, amount, 'add', reason)
    return true
end

function S.remove(name, amount, reason)
    amount = U.int(amount, 0)
    if type(name) ~= 'string' or name == '' or amount <= 0 then return false end
    local api = backend()
    if api ~= own and S.balance(name) < amount then return false end
    local ok, res = pcall(api.remove, name, amount, reason)
    if not ok then
        print(('^1[vr-bridge] society withdrawal failed: %s^0'):format(tostring(res)))
        return false
    end
    if res == false then return false end
    announce(api, name, amount, 'remove', reason)
    return true
end

function S.set(name, amount, reason)
    amount = U.int(amount, 0)
    if type(name) ~= 'string' or name == '' or amount < 0 then return false end
    local have = S.balance(name)
    if amount > have then return S.add(name, amount - have, reason) end
    if amount < have then return S.remove(name, have - amount, reason) end
    return true
end

return S
