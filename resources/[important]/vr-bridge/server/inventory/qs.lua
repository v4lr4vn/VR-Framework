local I = { name = 'qs' }
local RES = Bridge.inventoryResource or 'qs-inventory'
local function qs() return exports[RES] end

local function matches(md, want)
    if type(want) ~= 'table' then return true end
    if type(md) ~= 'table' then return next(want) == nil end
    for k, v in pairs(want) do
        if md[k] ~= v then return false end
    end
    return true
end

function I.items(src)
    local out = {}
    local ok, list = pcall(function() return qs():GetInventory(src) end)
    for key, s in pairs(ok and type(list) == 'table' and list or {}) do
        if type(s) == 'table' and s.name then
            out[#out + 1] = { name = s.name, count = tonumber(s.amount or s.count) or 0, metadata = s.info or s.metadata or {}, slot = tonumber(s.slot) or tonumber(key), label = s.label }
        end
    end
    return out
end

function I.count(src, item, metadata)
    if metadata == nil then
        local ok, n = pcall(function() return qs():GetItemTotalAmount(src, item) end)
        if ok and tonumber(n) then return tonumber(n) end
    end
    local n = 0
    for _, s in ipairs(I.items(src)) do if s.name == item and matches(s.metadata, metadata) then n = n + s.count end end
    return n
end

function I.has(src, item, count, metadata) return I.count(src, item, metadata) >= (tonumber(count) or 1) end

function I.add(src, item, count, metadata, slot)
    local ok, out = pcall(function() return qs():AddItem(src, item, count or 1, slot, metadata) end)
    return ok and out ~= false
end

function I.remove(src, item, count, metadata, slot)
    if metadata and not slot then
        local found = I.search(src, item, metadata)[1]
        if not found then return false end
        slot = found.slot
    end
    local ok, out = pcall(function() return qs():RemoveItem(src, item, count or 1, slot) end)
    return ok and out ~= false
end

function I.removeExact(src, item, count, metadata) return I.remove(src, item, count, metadata) end

function I.canCarry(src, item, count)
    local ok, out = pcall(function() return qs():CanCarryItem(src, item, count or 1) end)
    return not ok or out ~= false
end

local function defs()
    local ok, list = pcall(function() return qs():GetItemList() end)
    return ok and type(list) == 'table' and list or {}
end

function I.itemExists(item) return defs()[item] ~= nil end
function I.label(item) local d = defs()[item] return d and d.label or nil end

function I.item(name)
    local d = defs()[name]
    if not d then return nil end
    return { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.unique ~= true, description = d.description, image = d.image }
end

function I.itemDefs()
    local out = {}
    for name, d in pairs(defs()) do out[name] = { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.unique ~= true, description = d.description, image = d.image } end
    return out
end

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
    local ok = pcall(function() qs():SetItemMetadata(src, slot, metadata) end)
    return ok
end

local stashes = {}

function I.registerStash(id, label, slots, weight)
    stashes[id] = { label = label, slots = slots, weight = weight }
    return true
end

function I.openStash(src, id)
    local s = stashes[id] or { label = id, slots = 50, weight = 100000 }
    TriggerClientEvent('__vrb_inv_stash:' .. Bridge.resource, src, id, s)
    return true
end

function I.stashItems(id)
    local out = {}
    local ok, list = pcall(function() return qs():GetStashItems(id) end)
    for key, s in pairs(ok and type(list) == 'table' and list or {}) do
        if type(s) == 'table' and s.name then
            out[#out + 1] = { name = s.name, count = tonumber(s.amount) or 0, metadata = s.info or {}, slot = tonumber(s.slot) or tonumber(key) }
        end
    end
    return out
end

function I.stashAdd(id, item, count, metadata, slot)
    local ok, out = pcall(function() return qs():AddItemIntoStash(id, item, count or 1, slot, metadata) end)
    return ok and out ~= false
end

function I.stashRemove(id, item, count, _, slot)
    local ok, out = pcall(function() return qs():RemoveItemIntoStash(id, item, count or 1, slot) end)
    return ok and out ~= false
end

function I.registerShop() return false end
function I.confiscate() return false end
function I.giveBack() return false end

function I.clear(src, keep)
    return pcall(function() qs():ClearInventory(src, keep) end)
end

function I.onCreateItem() return nil end

function I.image(item)
    local d = defs()[item]
    return ('nui://%s/html/images/%s'):format(RES, d and d.image or (item .. '.png'))
end

return I
