local ready = false
local lastSave = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_keybinds` (
            `license` VARCHAR(64) NOT NULL,
            `binds` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    ready = true
end)

local function waitReady()
    local tries = 0
    while not ready and tries < 300 do
        Wait(100)
        tries = tries + 1
    end
    return ready
end

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'admin') or IsPlayerAceAllowed(src, 'god')
end

local function clean(binds)
    local out, n = {}, 0
    if type(binds) ~= 'table' then return out end
    for id, b in pairs(binds) do
        if n >= 400 then break end
        if type(id) == 'string' and #id <= 96 and id:match('^[%w%-_]+:[%w%-_%.]+$') and type(b) == 'table' then
            local k = tonumber(b.k)
            local m = b.m
            if k and k >= 1 and k <= 254 and k == math.floor(k) and not KeybindConfig.blocked[k]
                and (m == nil or KeyData.modLabels[m]) then
                out[id] = { k = k, m = m }
                n = n + 1
            end
        end
    end
    return out
end

lib.callback.register('vr-keybinds:load', function(src)
    local id = license(src)
    if not id or not waitReady() then return { binds = {}, admin = isAdmin(src) } end
    local raw = MySQL.scalar.await('SELECT `binds` FROM `vr_keybinds` WHERE `license` = ?', { id })
    local binds = {}
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok then binds = clean(data) end
    end
    return { binds = binds, admin = isAdmin(src) }
end)

lib.callback.register('vr-keybinds:save', function(src, binds)
    local id = license(src)
    if not id or not ready then return false end
    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < 500 then return false end
    lastSave[src] = now
    local data = json.encode(clean(binds))
    if #data > 32000 then return false end
    MySQL.update.await('INSERT INTO `vr_keybinds` (`license`, `binds`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `binds` = VALUES(`binds`)', { id, data })
    return true
end)

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)

RegisterCommand('keybindsreset', function(src, args)
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        if src > 0 then TriggerClientEvent('vr-ui:notify', src, { type = 'error', description = 'Usage: /keybindsreset [player id]' }) end
        return
    end
    local id = license(target)
    if not id then return end
    MySQL.update.await('DELETE FROM `vr_keybinds` WHERE `license` = ?', { id })
    TriggerClientEvent('vr-keybinds:reset', target)
    if src > 0 then TriggerClientEvent('vr-ui:notify', src, { type = 'success', description = ('Key bindings reset for %s'):format(GetPlayerName(target)) }) end
end, true)
