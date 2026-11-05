if not VRCore.Config.QBBridge then return end

local VRCore    = VRCore
local Functions = VRCore.Functions
local Shared    = VRCore.Shared
local Config    = VRCore.Config

Functions.GetQBPlayers = Functions.GetVRPlayers
CoreExport('GetQBPlayers', Functions.GetVRPlayers)

-- Inventory: scripts written for QBCore call Player.Functions.AddItem(...), exports['qb-inventory']:AddItem(...)
-- and read Player.PlayerData.items. All of it is answered from the slot inventory.
local function inv()
    local name = Config.Resources.inventory
    if name and GetResourceState(name) == 'started' then return exports[name] end
end

local function qbItem(slot)
    if type(slot) ~= 'table' or not slot.name then return nil end
    local def = Shared.Items[slot.name] or {}
    return {
        name = slot.name,
        label = slot.label or def.label or slot.name,
        amount = tonumber(slot.count) or tonumber(slot.amount) or 0,
        weight = slot.weight or def.weight or 0,
        info = type(slot.metadata) == 'table' and slot.metadata or {},
        type = def.type or 'item',
        slot = slot.slot,
        unique = def.unique or false,
        useable = def.useable ~= false,
        image = def.image or (slot.name .. '.png'),
        description = def.description or '',
    }
end

local function slotsOf(src)
    local i = inv()
    local raw = i and i:GetInventoryItems(src)
    local out = {}
    if type(raw) == 'table' then
        for k, v in pairs(raw) do
            local item = qbItem(v)
            if item then out[tonumber(item.slot) or tonumber(k) or (#out + 1)] = item end
        end
    end
    return out
end

local function addItem(src, item, amount, slot, info)
    local i = inv()
    if not i or type(item) ~= 'string' then return false end
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end
    local ok = i:AddItem(src, item, amount, type(info) == 'table' and info or nil, tonumber(slot))
    return ok and true or false
end

local function removeItem(src, item, amount, slot)
    local i = inv()
    if not i or type(item) ~= 'string' then return false end
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end
    local ok = i:RemoveItem(src, item, amount, nil, tonumber(slot))
    return ok and true or false
end

local function itemByName(src, name)
    local i = inv()
    local slot = i and name and i:GetSlotWithItem(src, name)
    return qbItem(slot)
end

local function itemsByName(src, name)
    local i = inv()
    local list = i and name and i:GetSlotsWithItem(src, name)
    local out = {}
    for _, slot in pairs(list or {}) do
        local item = qbItem(slot)
        if item then out[#out + 1] = item end
    end
    return out
end

local function itemBySlot(src, slotNumber)
    local i = inv()
    return qbItem(i and i:GetSlot(src, tonumber(slotNumber)))
end

local function countOf(src, items)
    local i = inv()
    if not i then return 0 end
    if type(items) == 'string' then return tonumber(i:Search(src, 'count', items)) or 0 end
    local total = 0
    for _, name in pairs(items or {}) do total = total + (tonumber(i:Search(src, 'count', name)) or 0) end
    return total
end

local function canAdd(src, item, amount)
    local i = inv()
    if not i then return false, 'no_inventory' end
    if i:CanCarryItem(src, item, tonumber(amount) or 1) then return true end
    return false, 'weight'
end

local function clear(src, keep)
    local i = inv()
    if not i then return false end
    i:ClearInventory(src, keep)
    return true
end

-- Player.Functions additions, applied to every player when it is built.
function VRCore.Player.ExtendMethods(player, t)
    local function src() return player.PlayerData.source end
    t.AddItem = function(item, amount, slot, info) return addItem(src(), item, amount, slot, info) end
    t.RemoveItem = function(item, amount, slot) return removeItem(src(), item, amount, slot) end
    t.GetItemByName = function(item) return itemByName(src(), item) end
    t.GetItemsByName = function(item) return itemsByName(src(), item) end
    t.GetItemBySlot = function(slot) return itemBySlot(src(), slot) end
    t.ClearInventory = function(filter) return clear(src(), filter) end
    t.SetInventory = function() return false end
    t.SetCreditCard = function(card)
        player.PlayerData.charinfo.card = card
        player:UpdateClient('charinfo', player.PlayerData.charinfo)
    end
    t.GetCardSlot = function() return nil end

    local pd = player.PlayerData
    if rawget(pd, 'items') == nil and getmetatable(pd) == nil then
        setmetatable(pd, { __index = function(_, key) if key == 'items' then return slotsOf(src()) end end })
    end
end

-- exports['qb-inventory']:...  (only when no real qb-inventory is installed)
local function free(resource)
    local state = GetResourceState(resource)
    if state == 'missing' or state == 'stopped' or state == 'uninitialized' or state == 'unknown' then return true end
    return GetResourcePath(resource) == GetResourcePath(GetCurrentResourceName())
end

local QBInventory = {
    AddItem = function(src, item, amount, slot, info) return addItem(src, item, amount, slot, info) end,
    RemoveItem = function(src, item, amount, slot) return removeItem(src, item, amount, slot) end,
    HasItem = function(src, items, amount) return Functions.HasItem(src, items, amount) end,
    GetItemByName = itemByName,
    GetItemsByName = itemsByName,
    GetItemBySlot = itemBySlot,
    GetItemCount = countOf,
    CanAddItem = canAdd,
    ClearInventory = clear,
    LoadInventory = function() return {} end,
    SaveInventory = function() end,
    OpenInventory = function(src, identifier)
        local i = inv()
        if i and identifier then i:forceOpenInventory(src, 'stash', identifier) end
    end,
    GetFirstSlotByItem = function(src, name) local s = itemByName(src, name) return s and s.slot end,
}

if free('qb-inventory') then
    for name, fn in pairs(QBInventory) do
        AddEventHandler(('__cfx_export_qb-inventory_%s'):format(name), function(setCB) setCB(fn) end)
    end
end

QBCompat = { inventory = QBInventory, slotsOf = slotsOf }

print('^3[vr-core] qb-core bridge enabled - QBCore scripts can use exports[\'qb-core\'] and exports[\'qb-inventory\']^0')
