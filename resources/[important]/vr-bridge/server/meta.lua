local db = Bridge.db
local U = Bridge.util
local store = {}
Bridge.metaStore = store

local cache = {}
local ready = false

local function ensure()
    if ready then return end
    db.query([[CREATE TABLE IF NOT EXISTS `vr_bridge_meta` (
        `cid` VARCHAR(64) NOT NULL,
        `mkey` VARCHAR(64) NOT NULL,
        `mvalue` LONGTEXT DEFAULT NULL,
        PRIMARY KEY (`cid`, `mkey`),
        KEY `mkey` (`mkey`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    ready = true
end

function store.all(cid)
    if type(cid) ~= 'string' then return {} end
    local hit = cache[cid]
    if hit then return hit end
    ensure()
    local out = {}
    for _, r in ipairs(db.query('SELECT `mkey`, `mvalue` FROM `vr_bridge_meta` WHERE `cid` = ?', { cid }) or {}) do
        out[r.mkey] = U.decode(r.mvalue, r.mvalue)
    end
    cache[cid] = out
    return out
end

function store.get(cid, key)
    return store.all(cid)[key]
end

function store.set(cid, key, value)
    if type(cid) ~= 'string' or type(key) ~= 'string' then return false end
    ensure()
    local md = store.all(cid)
    md[key] = value
    if value == nil then
        return db.update('DELETE FROM `vr_bridge_meta` WHERE `cid` = ? AND `mkey` = ?', { cid, key }) ~= nil
    end
    return db.query('INSERT INTO `vr_bridge_meta` (`cid`, `mkey`, `mvalue`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `mvalue` = VALUES(`mvalue`)', { cid, key, json.encode(value) }) ~= nil
end

function store.find(key, value)
    ensure()
    local out = {}
    for _, r in ipairs(db.query('SELECT `cid` FROM `vr_bridge_meta` WHERE `mkey` = ? AND LOWER(`mvalue`) = LOWER(?) LIMIT 20', { key, json.encode(value) }) or {}) do
        out[#out + 1] = r.cid
    end
    return out
end

function store.forget(cid)
    cache[cid] = nil
end

return store
