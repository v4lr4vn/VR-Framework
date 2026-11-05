local I = { name = 'ox' }
local RES = Bridge.inventoryResource or 'ox_inventory'
local function ox() return exports[RES] end
local function up() return GetResourceState(RES) == 'started' end

local function slotOut(s)
    if type(s) ~= 'table' or not s.name then return nil end
    return { name = s.name, count = tonumber(s.count) or 0, metadata = s.metadata or {}, slot = s.slot, label = s.label, weight = s.weight }
end

function I.count(inv, item, metadata) return tonumber(ox():Search(inv, 'count', item, metadata)) or 0 end
function I.has(inv, item, count, metadata) return I.count(inv, item, metadata) >= (tonumber(count) or 1) end
function I.add(inv, item, count, metadata, slot) local ok = ox():AddItem(inv, item, count or 1, metadata, slot) return ok ~= false and ok ~= nil end
function I.remove(inv, item, count, metadata, slot) return ox():RemoveItem(inv, item, count or 1, metadata, slot) == true end
function I.canCarry(inv, item, count, metadata) return ox():CanCarryItem(inv, item, count or 1, metadata) == true end
function I.itemExists(item) return ox():Items(item) ~= nil end
function I.label(item) local d = ox():Items(item) return d and d.label or nil end

function I.item(name)
    local d = ox():Items(name)
    if not d then return nil end
    return { name = d.name or name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.stack ~= false, close = d.close ~= false, description = d.description }
end

function I.itemDefs()
    local out = {}
    for name, d in pairs(ox():Items() or {}) do
        out[name] = { name = name, label = d.label or name, weight = tonumber(d.weight) or 0, stack = d.stack ~= false, description = d.description }
    end
    return out
end

function I.items(inv)
    local out = {}
    for _, s in pairs(ox():GetInventoryItems(inv) or {}) do
        local o = slotOut(s)
        if o then out[#out + 1] = o end
    end
    return out
end

function I.search(inv, item, metadata)
    local out = {}
    local list = ox():Search(inv, 'slots', item, metadata)
    if type(list) ~= 'table' then return out end
    for _, s in pairs(list) do
        local o = slotOut(s)
        if o then out[#out + 1] = o end
    end
    table.sort(out, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return out
end

function I.getSlot(inv, slot) return slotOut(ox():GetSlot(inv, slot)) end
function I.setMetadata(inv, slot, metadata) ox():SetMetadata(inv, slot, metadata) return true end

function I.removeExact(inv, item, count, metadata)
    local found = metadata and I.search(inv, item, metadata)[1]
    if metadata and not found then return false end
    return I.remove(inv, item, count, nil, found and found.slot or nil)
end

function I.registerStash(id, label, slots, weight, owner, groups, coords)
    if not up() then return false end
    ox():RegisterStash(id, label, slots, weight, owner, groups, coords)
    return true
end

function I.openStash(src, id)
    if not up() then return false end
    return ox():forceOpenInventory(src, 'stash', id) ~= false
end

function I.stashItems(id)
    local out = {}
    for _, s in pairs(ox():GetInventoryItems(id) or {}) do
        local o = slotOut(s)
        if o then out[#out + 1] = o end
    end
    return out
end

function I.stashAdd(id, item, count, metadata) return I.add(id, item, count, metadata) end
function I.stashRemove(id, item, count, metadata, slot) return I.remove(id, item, count, metadata, slot) end

function I.registerShop(name, data)
    if not up() then return false end
    ox():RegisterShop(name, data)
    return true
end

function I.confiscate(src)
    if not up() then return false end
    ox():ConfiscateInventory(src)
    return true
end

function I.giveBack(src)
    if not up() then return false end
    ox():ReturnInventory(src)
    return true
end

function I.clear(src, keep)
    if not up() then return false end
    ox():ClearInventory(src, keep)
    return true
end

function I.onCreateItem(fn)
    if not up() then return nil end
    return ox():registerHook('createItem', fn, { print = false })
end

function I.image(item)
    return ('nui://%s/web/images/%s.png'):format(RES, item)
end

return I
