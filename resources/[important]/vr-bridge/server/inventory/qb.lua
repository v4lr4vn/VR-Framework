local U = Bridge.util
local db = Bridge.db
local I = { name = 'qb' }
local res = Bridge.inventoryResource or 'qb-inventory'

local function player(src) return Bridge.fw.raw(src) end
local function invoke(p, method, ...) return Bridge.fw.invoke and Bridge.fw.invoke(p, method, ...) end
local function inv() return exports[res] end
local function hasExport(name)
    local ok, fn = pcall(function() return inv()[name] end)
    return ok and fn ~= nil
end

local function defs()
    if Bridge.fw.itemDefs then
        local ok, list = pcall(Bridge.fw.itemDefs)
        if ok and type(list) == 'table' then return list end
    end
    return {}
end

function I.items(src)
    local out = {}
    local p = player(src)
    local list = p and p.PlayerData and p.PlayerData.items or {}
    for slot, s in pairs(list) do
        if type(s) == 'table' and s.name then
            out[#out + 1] = { name = s.name, count = tonumber(s.amount or s.count) or 0, metadata = s.info or s.metadata, slot = tonumber(s.slot) or tonumber(slot) }
        end
    end
    return out
end

local function matches(md, want)
    if type(want) ~= 'table' then return true end
    if type(md) ~= 'table' then return next(want) == nil end
    for k, v in pairs(want) do
        if md[k] ~= v then return false end
    end
    return true
end

function I.count(src, item, metadata)
    local n = 0
    for _, s in ipairs(I.items(src)) do if s.name == item and matches(s.metadata, metadata) then n = n + s.count end end
    return n
end

function I.has(src, item, count, metadata) return I.count(src, item, metadata) >= (tonumber(count) or 1) end

function I.search(src, item, metadata)
    local out = {}
    for _, s in ipairs(I.items(src)) do
        if s.name == item and matches(s.metadata, metadata) then out[#out + 1] = s end
    end
    table.sort(out, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return out
end

function I.getSlot(src, slot)
    for _, s in ipairs(I.items(src)) do
        if s.slot == tonumber(slot) then return s end
    end
    return nil
end

function I.setMetadata(src, slot, metadata)
    local current = I.getSlot(src, slot)
    if not current then return false end
    if hasExport('SetItemData') then
        local ok = pcall(function()
            for k, v in pairs(metadata or {}) do inv():SetItemData(src, current.name, k, v, current.slot) end
        end)
        if ok then return true end
    end
    local p = player(src)
    if not p then return false end
    local items = p.PlayerData.items or {}
    for key, s in pairs(items) do
        if type(s) == 'table' and (tonumber(s.slot) or tonumber(key)) == current.slot then
            s.info = metadata
            invoke(p, 'SetPlayerData', 'items', items)
            return true
        end
    end
    return false
end

function I.removeExact(src, item, count, metadata)
    local found = metadata and I.search(src, item, metadata)[1]
    if metadata and not found then return false end
    return I.remove(src, item, count, nil, found and found.slot or nil)
end

function I.add(src, item, count, metadata)
    local ok, out = pcall(function() return inv():AddItem(src, item, count, false, metadata, Bridge.resource) end)
    if ok then return out ~= false end
    local p = player(src)
    return p ~= nil and invoke(p, 'AddItem', item, count, false, metadata) ~= false
end

function I.remove(src, item, count, metadata, slot)
    local ok, out = pcall(function() return inv():RemoveItem(src, item, count, slot or false, Bridge.resource) end)
    if ok then return out ~= false end
    local p = player(src)
    return p ~= nil and invoke(p, 'RemoveItem', item, count, slot) ~= false
end

function I.canCarry(src, item, count)
    if hasExport('CanAddItem') then
        local ok, out = pcall(function() return inv():CanAddItem(src, item, count) end)
        if ok then return out ~= false end
    end
    return true
end

function I.itemExists(item)
    return defs()[item] ~= nil
end

function I.label(item)
    local d = defs()[item]
    return d and d.label or nil
end

function I.item(name)
    local d = defs()[name]
    if not d then return nil end
    return { name = d.name or name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.unique ~= true, description = d.description, image = d.image }
end

function I.itemDefs()
    local out = {}
    for name, d in pairs(defs()) do
        out[name] = { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.unique ~= true, description = d.description, image = d.image }
    end
    return out
end

function I.image(item)
    local d = defs()[item]
    return ('nui://%s/html/images/%s'):format(res, d and d.image or (item .. '.png'))
end

local stashes = {}

function I.registerStash(id, label, slots, weight)
    stashes[id] = { label = label, slots = slots, weight = weight }
    return true
end

function I.openStash(src, id)
    local s = stashes[id] or { label = id, slots = 50, weight = 100000 }
    if hasExport('OpenInventory') then
        local ok = pcall(function() inv():OpenInventory(src, id, { label = s.label, maxweight = s.weight, slots = s.slots }) end)
        if ok then return true end
    end
    TriggerClientEvent('__vrb_inv_stash:' .. Bridge.resource, src, id, s)
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
    local ok = db.query('INSERT INTO `vr_bridge_confiscated` (`cid`, `items`, `at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `items` = VALUES(`items`), `at` = VALUES(`at`)', { p.cid, json.encode(items), os.time() })
    if ok == nil then return false end
    if hasExport('ClearInventory') then
        pcall(function() inv():ClearInventory(src) end)
    else
        for _, s in ipairs(items) do I.remove(src, s.name, s.count, nil, s.slot) end
    end
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

function I.stashItems() return {} end
function I.stashAdd(id, item, count, metadata)
    local ok, out = pcall(function() return inv():AddItem(id, item, count, false, metadata, Bridge.resource) end)
    return ok and out ~= false
end
function I.stashRemove(id, item, count, _, slot)
    local ok, out = pcall(function() return inv():RemoveItem(id, item, count, slot or false, Bridge.resource) end)
    return ok and out ~= false
end

function I.registerShop(name, data)
    if not hasExport('CreateShop') then return false end
    local items = {}
    for i, it in ipairs(data.inventory or data.items or {}) do
        items[#items + 1] = { name = it.name, price = it.price or 0, amount = it.count or it.amount or 50, slot = i }
    end
    return pcall(function() inv():CreateShop({ name = name, label = data.name or data.label or name, coords = data.coords, items = items }) end)
end

function I.clear(src, keep)
    if hasExport('ClearInventory') then
        return pcall(function() inv():ClearInventory(src, keep) end)
    end
    for _, s in ipairs(I.items(src)) do I.remove(src, s.name, s.count, nil, s.slot) end
    return true
end

function I.onCreateItem() return nil end

return I
