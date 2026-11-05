Db = {}

local schemas = {}
local readyCallbacks = {}
local isReady = false
local bdb = Bridge.db

local function run(kind, sql, params)
    local ok, result = pcall(bdb[kind], sql, params)
    if not ok then
        print(('^1[vr-mdt] db: %s^0'):format(tostring(result)))
        return nil
    end
    return result
end

function Db.query(sql, params)
    return run('query', sql, params)
end

function Db.single(sql, params)
    return run('single', sql, params)
end

function Db.scalar(sql, params)
    return run('scalar', sql, params)
end

function Db.insert(sql, params)
    return run('insert', sql, params)
end

function Db.update(sql, params)
    return run('update', sql, params)
end

function Db.schema(name, sql)
    schemas[#schemas + 1] = { name = name, sql = sql }
end

function Db.ready(cb)
    if isReady then
        CreateThread(cb)
    else
        readyCallbacks[#readyCallbacks + 1] = cb
    end
end

function Db.isReady()
    return isReady
end

function Db.columnExists(tbl, column)
    local n = Db.scalar([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
    ]], { tbl, column })
    return tonumber(n) == 1
end

local function widenIds()
    local rows = Db.query([[
        SELECT TABLE_NAME AS t, COLUMN_NAME AS c, IS_NULLABLE AS n FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'vr\_mdt\_%' AND DATA_TYPE = 'varchar' AND CHARACTER_MAXIMUM_LENGTH < 64
          AND (COLUMN_NAME IN ('cid', 'citizenid', 'created_by', 'updated_by') OR COLUMN_NAME LIKE '%\_cid')
    ]]) or {}
    for _, r in ipairs(rows) do
        Db.query(('ALTER TABLE `%s` MODIFY `%s` VARCHAR(64) %s'):format(r.t, r.c, r.n == 'YES' and 'DEFAULT NULL' or 'NOT NULL'))
    end
end

CreateThread(function()
    local provider = bdb.provider()
    if not Bridge.util.waitFor(provider, 60000) then
        print(('^1[vr-mdt] %s did not start, the MDT is offline^0'):format(provider))
        return
    end
    for _, s in ipairs(schemas) do
        if Db.query(s.sql) == nil then
            print(('^1[vr-mdt] could not create table for %s^0'):format(s.name))
        end
    end
    widenIds()
    isReady = true
    for _, cb in ipairs(readyCallbacks) do
        local ok, err = pcall(cb)
        if not ok then print(('^1[vr-mdt] startup: %s^0'):format(tostring(err))) end
    end
    readyCallbacks = {}
end)
