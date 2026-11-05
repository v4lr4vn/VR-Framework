local U = Bridge.util
local db = Bridge.db
local I = { name = 'esx' }

local function x(src) return Bridge.fw.raw(src) end

function I.items(src)
    local out = {}
    local p = x(src)
    if not p then return out end
    for _, s in pairs(p.getInventory and p.getInventory() or {}) do
        if (tonumber(s.count) or 0) > 0 then out[#out + 1] = { name = s.name, count = tonumber(s.count), metadata = nil } end
    end
    for _, w in pairs(p.getLoadout and p.getLoadout() or {}) do
        out[#out + 1] = { name = w.name, count = 1, metadata = { ammo = w.ammo, components = w.components }, weapon = true }
    end
    return out
end

function I.count(src, item)
    local p = x(src)
    local it = p and p.getInventoryItem and p.getInventoryItem(item)
    return it and tonumber(it.count) or 0
end

function I.add(src, item, count, metadata)
    local p = x(src)
    if not p then return false end
    if item:upper():find('^WEAPON_') then
        p.addWeapon(item, metadata and metadata.ammo or 0)
        return true
    end
    if p.canCarryItem and not p.canCarryItem(item, count) then return false end
    p.addInventoryItem(item, count)
    return true
end

function I.remove(src, item, count)
    local p = x(src)
    if not p then return false end
    if item:upper():find('^WEAPON_') then
        p.removeWeapon(item)
        return true
    end
    if I.count(src, item) < count then return false end
    p.removeInventoryItem(item, count)
    return true
end

function I.canCarry(src, item, count)
    local p = x(src)
    return p ~= nil and (not p.canCarryItem or p.canCarryItem(item, count) == true)
end

function I.itemExists(item)
    local items = Bridge.fw.core().Items
    return type(items) == 'table' and items[item] ~= nil
end

function I.label(item)
    local items = Bridge.fw.core().Items
    return type(items) == 'table' and items[item] and items[item].label or nil
end

function I.has(src, item, count) return I.count(src, item) >= (tonumber(count) or 1) end

function I.search(src, item)
    local n = I.count(src, item)
    if n <= 0 then return {} end
    return { { name = item, count = n, metadata = {}, slot = nil } }
end

function I.getSlot() return nil end
function I.setMetadata() return false end
function I.removeExact(src, item, count) return I.remove(src, item, count) end

function I.item(name)
    local items = Bridge.fw.core().Items
    local d = type(items) == 'table' and items[name]
    if not d then return nil end
    return { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = true }
end

function I.itemDefs()
    local out = {}
    for name, d in pairs(Bridge.fw.core().Items or {}) do out[name] = { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = true } end
    return out
end

function I.image(item) return ('nui://esx_inventoryhud/html/img/items/%s.png'):format(item) end

function I.registerStash() return false end
function I.openStash() return false end
function I.stashItems() return {} end
function I.stashAdd() return false end
function I.stashRemove() return false end
function I.registerShop() return false end

function I.clear(src)
    for _, s in ipairs(I.items(src)) do I.remove(src, s.name, s.count) end
    return true
end

local function ensureTable()
    db.query([[CREATE TABLE IF NOT EXISTS `vr_bridge_confiscated` (
        `cid` VARCHAR(64) NOT NULL,
        `items` LONGTEXT NOT NULL,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
end

function I.confiscate(src)
    local p = Bridge.player(src)
    if not p then return false end
    ensureTable()
    local items = I.items(src)
    if #items == 0 then return true end
    if db.query('INSERT INTO `vr_bridge_confiscated` (`cid`, `items`, `at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `items` = VALUES(`items`), `at` = VALUES(`at`)', { p.cid, json.encode(items), os.time() }) == nil then return false end
    for _, s in ipairs(items) do I.remove(src, s.name, s.count) end
    return true
end

function I.giveBack(src)
    local p = Bridge.player(src)
    if not p then return false end
    ensureTable()
    local row = db.single('SELECT `items` FROM `vr_bridge_confiscated` WHERE `cid` = ?', { p.cid })
    if not row then return true end
    db.update('DELETE FROM `vr_bridge_confiscated` WHERE `cid` = ?', { p.cid })
    for _, s in ipairs(U.decode(row.items, {})) do I.add(src, s.name, s.count, s.metadata) end
    return true
end

function I.onCreateItem() return nil end

return I
