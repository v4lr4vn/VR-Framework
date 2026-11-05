local tables = {
    vr = { players = 'vr_players', playerColumn = 'citizenid', vehicles = 'player_vehicles', vehicleColumn = 'plate' },
    qb = { players = 'players', playerColumn = 'citizenid', vehicles = 'player_vehicles', vehicleColumn = 'plate' },
    qbx = { players = 'players', playerColumn = 'citizenid', vehicles = 'player_vehicles', vehicleColumn = 'id' },
    esx = { players = 'users', playerColumn = 'identifier', vehicles = 'owned_vehicles', vehicleColumn = 'plate' },
    ox = { players = 'character_inventory', playerColumn = 'charid', vehicles = 'vehicles', vehicleColumn = 'id' },
}

local layout = {}
for k, v in pairs(tables[shared.framework] or tables.vr) do layout[k] = v end
if GetResourceState('vr-garages') ~= 'missing' then
    layout.vehicles, layout.vehicleColumn = 'player_vehicles', 'plate'
end
local STASHES = 'vr_inventory_stashes'

local Q = {
    SELECT_STASH = ('SELECT data FROM `%s` WHERE owner = ? AND name = ?'):format(STASHES),
    UPSERT_STASH = ('INSERT INTO `%s` (data, owner, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)'):format(STASHES),
    DELETE_STASH = ('DELETE FROM `%s` WHERE owner = ? AND name = ?'):format(STASHES),
    SELECT_PLAYER = ('SELECT inventory FROM `%s` WHERE `%s` = ?'):format(layout.players, layout.playerColumn),
    UPDATE_PLAYER = ('UPDATE `%s` SET inventory = ? WHERE `%s` = ?'):format(layout.players, layout.playerColumn),
    SELECT_TRUNK = ('SELECT trunk FROM `%s` WHERE `%s` = ?'):format(layout.vehicles, layout.vehicleColumn),
    SELECT_GLOVEBOX = ('SELECT glovebox FROM `%s` WHERE `%s` = ?'):format(layout.vehicles, layout.vehicleColumn),
    EXISTS_VEHICLE = ('SELECT 1 FROM `%s` WHERE `%s` = ?'):format(layout.vehicles, layout.vehicleColumn),
    UPDATE_TRUNK = ('UPDATE `%s` SET trunk = ? WHERE `%s` = ?'):format(layout.vehicles, layout.vehicleColumn),
    UPDATE_GLOVEBOX = ('UPDATE `%s` SET glovebox = ? WHERE `%s` = ?'):format(layout.vehicles, layout.vehicleColumn),
}

if shared.framework == 'ox' then
    Q.UPDATE_PLAYER = ('INSERT INTO `%s` (inventory, `%s`) VALUES (?, ?) ON DUPLICATE KEY UPDATE inventory = VALUES(inventory)'):format(layout.players, layout.playerColumn)
end

db = { ready = false, layout = layout, stashTable = STASHES }

local function safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        print(('^1[vr-inventory] database error: %s^0'):format(tostring(result)))
        return nil, result
    end
    return result
end

local function tableExists(name)
    local ok, result = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    return ok and tonumber(result) and tonumber(result) > 0
end

local function columnExists(tableName, column)
    local ok, result = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?', { tableName, column })
    return ok and tonumber(result) and tonumber(result) > 0
end

local function migrate()
    if GetResourceKvpString and GetResourceKvpString('vr-inventory:migrated') == '1' then return end
    if not tableExists('ox_inventory') then
        if SetResourceKvp then SetResourceKvp('vr-inventory:migrated', '1') end
        return
    end
    local count = tonumber(safe(MySQL.scalar.await, ('SELECT COUNT(*) FROM `%s`'):format(STASHES))) or 0
    if count == 0 then
        local moved = safe(MySQL.update.await, ('INSERT IGNORE INTO `%s` (owner, name, data, lastupdated) SELECT IFNULL(owner, \'\'), name, data, lastupdated FROM `ox_inventory`'):format(STASHES))
        if moved then print(('[vr-inventory] copied %s stashes from the old ox_inventory table'):format(tostring(moved))) end
    end
    if SetResourceKvp then SetResourceKvp('vr-inventory:migrated', '1') end
end

function db.setup()
    safe(MySQL.query.await, ([[CREATE TABLE IF NOT EXISTS `%s` (
        `owner` varchar(60) NOT NULL DEFAULT '',
        `name` varchar(100) NOT NULL,
        `data` longtext DEFAULT NULL,
        `lastupdated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        UNIQUE KEY `owner_name` (`owner`, `name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(STASHES))

    migrate()

    if tableExists(layout.vehicles) then
        if not columnExists(layout.vehicles, 'glovebox') then safe(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `glovebox` LONGTEXT NULL'):format(layout.vehicles)) end
        if not columnExists(layout.vehicles, 'trunk') then safe(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `trunk` LONGTEXT NULL'):format(layout.vehicles)) end
    end

    if shared.framework == 'ox' then
        safe(MySQL.query.await, ([[CREATE TABLE IF NOT EXISTS `%s` (
            `%s` INT UNSIGNED NOT NULL,
            `inventory` LONGTEXT NULL,
            PRIMARY KEY (`%s`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(layout.players, layout.playerColumn, layout.playerColumn))
    end

    if tableExists(layout.players) and not columnExists(layout.players, 'inventory') then
        safe(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `inventory` LONGTEXT NULL'):format(layout.players))
    end

    local clear = server.clearstashes
    if type(clear) == 'string' and clear:match('^%d+ %a+$') then
        local unit = clear:match('%a+$'):upper()
        if unit == 'DAY' or unit == 'WEEK' or unit == 'MONTH' or unit == 'YEAR' then
            safe(MySQL.update.await, ('DELETE FROM `%s` WHERE lastupdated < (NOW() - INTERVAL %s)'):format(STASHES, clear:upper()))
        end
    end

    db.ready = true
end

local function decode(value)
    if type(value) == 'string' then
        local ok, result = pcall(json.decode, value)
        if ok then return result end
        return nil
    end
    if type(value) == 'table' then return value end
    return nil
end

function db.loadPlayer(identifier)
    return decode(safe(MySQL.scalar.await, Q.SELECT_PLAYER, { identifier }))
end

function db.savePlayer(owner, data)
    return safe(MySQL.update.await, Q.UPDATE_PLAYER, { data, owner })
end

function db.loadStash(owner, name)
    return decode(safe(MySQL.scalar.await, Q.SELECT_STASH, { owner and tostring(owner) or '', name }))
end

function db.saveStash(owner, name, data)
    return safe(MySQL.update.await, Q.UPSERT_STASH, { data, owner and tostring(owner) or '', name })
end

function db.deleteStash(owner, name)
    return safe(MySQL.update.await, Q.DELETE_STASH, { owner and tostring(owner) or '', name })
end

function db.loadTrunk(id)
    local exists = safe(MySQL.scalar.await, Q.EXISTS_VEHICLE, { id })
    if not exists then return nil, false end
    return decode(safe(MySQL.scalar.await, Q.SELECT_TRUNK, { id })), true
end

function db.loadGlovebox(id)
    local exists = safe(MySQL.scalar.await, Q.EXISTS_VEHICLE, { id })
    if not exists then return nil, false end
    return decode(safe(MySQL.scalar.await, Q.SELECT_GLOVEBOX, { id })), true
end

function db.saveTrunk(id, data)
    return safe(MySQL.update.await, Q.UPDATE_TRUNK, { data, id })
end

function db.saveGlovebox(id, data)
    return safe(MySQL.update.await, Q.UPDATE_GLOVEBOX, { data, id })
end

function db.saveMany(players, trunks, gloveboxes, stashes)
    local pending, saved = 0, 0
    local function run(query, rows)
        if #rows == 0 then return end
        pending = pending + 1
        CreateThread(function()
            local ok = #rows > 1 and pcall(MySQL.prepare.await, query, rows)
            if ok then
                saved = saved + #rows
            else
                for i = 1, #rows do
                    if safe(MySQL.update.await, query, rows[i]) then saved = saved + 1 end
                end
            end
            pending = pending - 1
        end)
    end
    run(Q.UPDATE_PLAYER, players)
    run(Q.UPDATE_TRUNK, trunks)
    run(Q.UPDATE_GLOVEBOX, gloveboxes)
    run(Q.UPSERT_STASH, stashes)
    while pending > 0 do Wait(0) end
    return saved
end
