local db = {}
Bridge.db = db

local provider

local function resolve()
    if provider then return provider end
    local forced = GetConvar('vr_bridge:database', '')
    if forced ~= '' and forced ~= 'auto' and GetResourceState(forced) ~= 'missing' then
        provider = forced
        return provider
    end
    for _, name in ipairs({ 'vr-mysql', 'oxmysql' }) do
        if GetResourceState(name) ~= 'missing' then
            provider = name
            return provider
        end
    end
    error('[vr-bridge] no MySQL resource found (vr-mysql or oxmysql)')
end

local function call(kind, sql, params)
    local name = resolve()
    Bridge.util.waitFor(name, 30000)
    local p = promise.new()
    local ok, err = pcall(function()
        exports[name][kind](nil, sql, params or {}, function(result, failure)
            if failure then
                print(('^1[vr-bridge] db %s failed: %s^0'):format(kind, tostring(failure)))
                return p:resolve({ nil })
            end
            p:resolve({ result })
        end, Bridge.resource, true)
    end)
    if not ok then
        print(('^1[vr-bridge] db %s failed: %s^0'):format(kind, tostring(err)))
        return nil
    end
    local out = Citizen.Await(p)
    return out and out[1]
end

function db.query(sql, params) return call('query', sql, params) end
function db.single(sql, params) return call('single', sql, params) end
function db.scalar(sql, params) return call('scalar', sql, params) end
function db.insert(sql, params) return call('insert', sql, params) end
function db.update(sql, params) return call('update', sql, params) end

function db.provider() return resolve() end

function db.tableExists(name)
    return tonumber(db.scalar('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) == 1
end

function db.columnExists(tbl, column)
    return tonumber(db.scalar('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, column })) == 1
end

return db
