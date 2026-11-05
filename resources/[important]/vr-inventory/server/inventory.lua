local U = InvUtil

Inventory = {}
Inventories = {}
RegisteredStashes = {}

local Class = {}
Class.__index = Class

local locks = {}
local lockMeta = {
    __close = function(self)
        for i = 1, #self do locks[self[i]] = nil end
    end,
}

function InvLocks(ids)
    for i = 1, #ids do
        if locks[ids[i]] then return false end
    end
    for i = 1, #ids do locks[ids[i]] = true end
    return setmetatable(ids, lockMeta)
end

function SlotLock(invId, slot)
    return ('inventory-%s:slot-%s'):format(invId, slot)
end

function InvLog(owner, event, message, ...)
    if server.loglevel > 0 then lib.logger(owner, event, message, ...) end
end

function Class:openInventory(inv)
    if not self.player then return end
    inv = inv and inv ~= self and Inventory(inv) or nil
    self.open = inv and inv.id or self.id
    if inv then
        inv:set('open', true)
        inv.openedBy[self.id] = true
    end
    U.fire('openedInventory', self.id, inv and inv.id)
end

function Class:closeInventory(noEvent)
    if not self.player or not self.open then return end
    local inv = self.open ~= self.id and Inventory(self.open)
    if inv then
        inv.openedBy[self.id] = nil
        inv:set('open', false)
    end
    self.open = false
    self.currentShop = nil
    self.containerSlot = nil
    if not noEvent then TriggerClientEvent('vr-inventory:closeInventory', self.id, true) end
    U.fire('closedInventory', self.id, inv and inv.id)
end

function Class:syncSlotsWithPlayer(slots, weight)
    TriggerClientEvent('vr-inventory:updateSlots', self.id, slots, weight)
end

function Class:syncSlotsWithClients(slots, syncOwner)
    for playerId in pairs(self.openedBy) do
        if self.id ~= playerId then
            local target = Inventories[playerId]
            if target then TriggerClientEvent('vr-inventory:updateSlots', playerId, slots, target.weight) end
        end
    end
    if syncOwner and self.player then
        TriggerClientEvent('vr-inventory:updateSlots', self.id, slots, self.weight)
    end
end

local Vehicles = InvData('vehicles')
Inventory.Vehicles = Vehicles

for _, stash in pairs(InvData('stashes')) do
    RegisteredStashes[stash.name] = {
        name = stash.name,
        label = stash.label,
        owner = stash.owner,
        slots = stash.slots,
        maxWeight = stash.weight,
        groups = stash.groups or stash.jobs,
        coords = shared.target and stash.target and stash.target.loc or stash.coords,
        distance = stash.distance or 10,
    }
end

local function plateOf(text)
    if type(text) ~= 'string' then return text end
    if server.trimplate then text = U.trim(text) end
    return text
end

Inventory.plateOf = plateOf

local function vehicleStorage(kind, model, class)
    local list = Vehicles[kind]
    if not list then return nil end
    return (list.models and list.models[model]) or list[class]
end

local function loadInventoryData(data, player, ignoreSecurityChecks)
    local inventory

    if not data.type and type(data.id) == 'string' then
        if data.id:find('^glove') then data.type = 'glovebox'
        elseif data.id:find('^trunk') then data.type = 'trunk'
        elseif data.id:find('^evidence%-') then data.type = 'policeevidence' end
    end

    if data.type == 'trunk' or data.type == 'glovebox' then
        if type(data.id) ~= 'string' then return false end
        local plate = plateOf(data.id:sub(6))
        data.id = data.id:sub(1, 5) .. plate
        inventory = Inventories[data.id]

        if not inventory then
            local entity

            if data.netid then
                entity = NetworkGetEntityFromNetworkId(data.netid)
                if not entity or entity == 0 then return false end
            else
                local vehicles = GetAllVehicles()
                for i = 1, #vehicles do
                    local text = GetVehicleNumberPlateText(vehicles[i])
                    if text and plateOf(text) == plate then
                        entity = vehicles[i]
                        data.netid = NetworkGetNetworkIdFromEntity(entity)
                        break
                    end
                end
                if not entity then return false end
            end

            data.entityId = entity
            local model, class = GetEntityModel(entity), nil
            local asker = player and player.player and player.id or NetworkGetEntityOwner(entity)
            if asker and asker > 0 and data.netid then
                local m, c = lib.callback.await('vr-inventory:getVehicleData', asker, data.netid)
                model = m or model
                class = c
            end

            local storage = vehicleStorage(data.type, model, class)
            if not storage then return false end
            local dbId = server.getOwnedVehicleId and server.getOwnedVehicleId(entity) or plate

            inventory = Inventory.Create(data.id, plate, data.type, storage[1], 0, storage[2], false, nil, nil, dbId)
        end
    elseif data.type == 'policeevidence' then
        inventory = Inventory.Create(data.id, locale('police_evidence'), data.type, 100, 0, 100000, false)
    else
        local stash = RegisteredStashes[data.id]

        if stash then
            if not ignoreSecurityChecks and player and stash.groups and not server.hasGroup(player, stash.groups) then return false end

            local owner
            if stash.owner then
                if stash.owner == true then
                    if ignoreSecurityChecks or not player then
                        owner = data.owner or (player and player.owner)
                    else
                        owner = player.owner
                    end
                else
                    owner = stash.owner
                end
            end

            inventory = Inventories[owner and ('%s:%s'):format(stash.name, owner) or stash.name]

            if not inventory then
                inventory = Inventory.Create(stash.name, stash.label or stash.name, 'stash', stash.slots, 0, stash.maxWeight, owner, nil, stash.groups)
                if inventory then
                    inventory.coords = stash.coords
                    inventory.distance = stash.distance
                    inventory.instance = stash.instance
                end
            end
        end
    end

    if inventory and data.netid then
        inventory.entityId = data.entityId or NetworkGetEntityFromNetworkId(data.netid)
        inventory.netid = data.netid
    end

    return inventory or false
end

setmetatable(Inventory, {
    __call = function(self, inv, player, ignoreSecurityChecks)
        if Inventory.Lock then return false end
        if not inv then return self end
        if type(inv) == 'table' then
            if getmetatable(inv) == Class then return inv end
            if inv.id == nil then return false end
            if not inv.owner and Inventories[inv.id] then return Inventories[inv.id] end
            return loadInventoryData(inv, player, ignoreSecurityChecks)
        end
        if type(inv) == 'string' and tonumber(inv) and Inventories[tonumber(inv)] then inv = tonumber(inv) end
        return Inventories[inv] or loadInventoryData({ id = inv }, player, ignoreSecurityChecks)
    end,
})

Inventory.Class = Class

local function getInventory(inv, owner)
    if not inv then return Inventory end
    local kind = type(inv)
    if kind == 'table' or kind == 'number' then return Inventory(inv) end
    return Inventory({ id = inv, owner = owner })
end

exports('Inventory', function(inv, owner) return getInventory(inv, owner) or nil end)
exports('GetInventory', function(inv, owner) return getInventory(inv, owner) or nil end)

function Inventory.GetInventories(invType, detailed)
    if type(invType) ~= 'string' then error(('expected invType to be a string (received %s)'):format(type(invType))) end
    local out = {}
    for _, inv in pairs(Inventories) do
        if inv.type == invType then out[#out + 1] = detailed and inv or inv.id end
    end
    return out
end

exports('GetInventories', Inventory.GetInventories)

exports('GetInventoryItems', function(inv, owner)
    local inventory = getInventory(inv, owner)
    return inventory and inventory.items or nil
end)

function Inventory.GetContainerFromSlot(inv, slotId)
    local inventory = Inventory(inv)
    local slotData = inventory and inventory.items[slotId]
    if not slotData or not slotData.metadata.container then return end
    local container = Inventory(slotData.metadata.container)
    if not container then
        local size = slotData.metadata.size or { 5, 1000 }
        container = Inventory.Create(slotData.metadata.container, slotData.label, 'container', size[1], 0, size[2], false)
    end
    return container
end

exports('GetContainerFromSlot', Inventory.GetContainerFromSlot)

function Inventory.CloseAll(inv, ignoreId)
    if not inv then
        for _, data in pairs(Inventories) do
            for playerId in pairs(data.openedBy) do
                local playerInv = Inventory(playerId)
                if playerInv then playerInv:closeInventory(true) end
            end
        end
        return TriggerClientEvent('vr-inventory:closeInventory', -1, true)
    end
    local inventory = Inventory(inv)
    if not inventory then return end
    for playerId in pairs(inventory.openedBy) do
        local playerInv = Inventory(playerId)
        if playerInv and playerId ~= ignoreId then playerInv:closeInventory() end
    end
end

function Inventory.Set(inv, k, v)
    inv = Inventory(inv)
    if not inv then return end
    if type(v) == 'number' then v = math.floor(v + 0.5) end

    if k == 'open' and v == false then
        if inv.type ~= 'player' then
            if inv.player then
                inv.type = 'player'
            elseif inv.type == 'drop' and not next(inv.items) and not next(inv.openedBy) then
                return Inventory.Remove(inv)
            else
                inv.time = os.time()
            end
        end
        if inv.player then inv.containerSlot = nil end
    elseif k == 'maxWeight' and v < 1000 then
        v = v * 1000
    end

    inv[k] = v
end

function Inventory.Get(inv, key)
    inv = Inventory(inv)
    if inv then return inv[key] end
end

local function minimal(inv)
    inv = Inventory(inv)
    local out = {}
    for k, v in pairs(inv.items) do
        if v.name and v.count > 0 then
            out[#out + 1] = { name = v.name, count = v.count, slot = k, metadata = next(v.metadata) and v.metadata or nil }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

Inventory.minimal = minimal

local function buildSlot(item, slot, count, metadata, weight)
    return {
        name = item.name, label = item.label, weight = weight or item.weight, slot = slot, count = count,
        description = item.description, metadata = metadata or {}, stack = item.stack, close = item.close,
    }
end

Inventory.buildSlot = buildSlot

function Inventory.SetSlot(inv, item, count, metadata, slot)
    inv = Inventory(inv)
    if not inv or not inv.slots then return false, 'invalid_inventory' end
    if type(count) ~= 'number' then return false, 'invalid_count' end
    count = math.floor(count + 0.5)

    if type(item) ~= 'table' then
        item = Items(item)
        if not item then return false, 'invalid_item' end
    end

    local current = inv.items[slot]
    local newCount = current and current.count + count or count
    local newWeight = current and inv.weight - current.weight or inv.weight

    if current and newCount < 1 then
        TriggerClientEvent('vr-inventory:itemNotify', inv.id, { current, 'ui_removed', current.count })
        current = nil
    else
        current = buildSlot(item, slot, newCount, metadata)
        local weight = Inventory.SlotWeight(item, current)
        current.weight = weight
        newWeight = newWeight + weight
        TriggerClientEvent('vr-inventory:itemNotify', inv.id, { current, count < 0 and 'ui_removed' or 'ui_added', math.abs(count) })
    end

    inv.weight = newWeight
    inv.items[slot] = current
    inv.changed = true
    return true, current
end

function Inventory.GetAccountItemCounts(inv)
    local inventory = Inventory(inv)
    if not inventory then return end
    local accounts = U.clone(server.accounts)
    for _, v in pairs(inventory.items) do
        if accounts[v.name] then accounts[v.name] = accounts[v.name] + v.count end
    end
    return accounts
end

function Inventory.SlotWeight(item, slot, ignoreCount)
    local weight = ignoreCount and item.weight or item.weight * (slot.count or 1)
    if not slot.metadata then slot.metadata = {} end
    local meta = slot.metadata

    if item.ammoname and meta.ammo then
        local ammo = Items(item.ammoname)
        if ammo then weight = weight + ammo.weight * meta.ammo end
    end

    if item.hash == Hashes.petrolcan then meta.weight = 15000 * ((tonumber(meta.ammo) or 0) / 100) end

    if type(meta.components) == 'table' then
        for i = #meta.components, 1, -1 do
            local component = Items(meta.components[i])
            if component then weight = weight + component.weight end
        end
    end

    if meta.weight then
        weight = weight + (ignoreCount and meta.weight or meta.weight * (slot.count or 1))
    end

    return weight
end

function Inventory.CalculateWeight(items)
    local weight = 0
    for _, v in pairs(items) do
        local item = Items(v.name)
        if item then weight = weight + Inventory.SlotWeight(item, v) end
    end
    return weight
end

local activeIdentifiers = {}

local function hasActiveInventory(playerId, owner)
    local active = activeIdentifiers[owner]
    if active then
        if active == playerId then
            print(('^1[vr-inventory] tried to load the inventory of player.%s twice^0'):format(playerId))
            return true
        end
        local inventory = Inventory(active)
        if inventory then
            if GetPlayerEndpoint(active) then
                DropPlayer(tostring(playerId), ("Character '%s' is already in use."):format(owner))
                print(('[vr-inventory] dropped player.%s (character %s is in use by player.%s)'):format(playerId, owner, active))
                return true
            end
            Inventory.CloseAll(inventory)
            db.savePlayer(owner, json.encode(minimal(inventory)))
            Inventory.Remove(inventory)
            Wait(100)
        end
    end
    activeIdentifiers[owner] = playerId
end

RegisterCommand('clearActiveIdentifier', function(source, args)
    if source ~= 0 then return end
    local active = activeIdentifiers[args[1]] or activeIdentifiers[tonumber(args[1])]
    local inventory = active and Inventory(active)
    if not inventory then return end
    if GetPlayerEndpoint(active) then DropPlayer(tostring(active), 'Kicked') end
    Inventory.CloseAll(inventory)
    db.savePlayer(inventory.owner, json.encode(minimal(inventory)))
    Inventory.Remove(inventory)
end, true)

function Inventory.Create(id, label, invType, slots, weight, maxWeight, owner, items, groups, dbId)
    if invType == 'player' and hasActiveInventory(id, owner) then return end

    local self = {
        id = id,
        label = label or id,
        type = invType,
        slots = slots,
        weight = weight or 0,
        maxWeight = maxWeight or shared.playerweight,
        owner = owner,
        items = type(items) == 'table' and items or nil,
        open = false,
        set = Inventory.Set,
        get = Inventory.Get,
        minimal = minimal,
        time = os.time(),
        groups = groups,
        openedBy = {},
        dbId = dbId,
    }

    if invType == 'drop' or invType == 'temp' or invType == 'dumpster' then
        self.datastore = true
    else
        self.changed = false
        if invType ~= 'glovebox' and invType ~= 'trunk' then
            self.dbId = id
            if invType ~= 'player' and owner and type(owner) ~= 'boolean' then
                self.id = ('%s:%s'):format(self.id, owner)
            end
        end
    end

    if not self.items then
        self.items, self.weight = Inventory.Load(self.dbId, invType, owner)
    elseif (weight or 0) == 0 and next(self.items) then
        self.weight = Inventory.CalculateWeight(self.items)
    end

    Inventories[self.id] = setmetatable(self, Class)
    return Inventories[self.id]
end

function Inventory.Remove(inv)
    inv = Inventory(inv)
    if not inv then return end

    if inv.type == 'drop' then
        TriggerClientEvent('vr-inventory:removeDrop', -1, inv.id)
        Inventory.Drops[inv.id] = nil
    elseif inv.player then
        activeIdentifiers[inv.owner] = nil
    end

    for playerId in pairs(inv.openedBy) do
        if inv.id ~= playerId then
            local target = Inventories[playerId]
            if target then target:closeInventory() end
        end
    end

    if not inv.datastore and (inv.changed or inv.player) then Inventory.Save(inv) end
    Inventories[inv.id] = nil
end

exports('RemoveInventory', Inventory.Remove)

function Inventory.UpdateVehicle(oldPlate, newPlate)
    oldPlate = plateOf(tostring(oldPlate):upper())
    newPlate = plateOf(tostring(newPlate):upper())

    for _, prefix in ipairs({ 'trunk', 'glove' }) do
        local inv = Inventories[prefix .. oldPlate]
        if inv then
            Inventory.CloseAll(inv)
            Inventories[inv.id] = nil
            inv.label = newPlate
            inv.dbId = type(inv.dbId) == 'number' and inv.dbId or newPlate
            inv.id = prefix .. newPlate
            Inventories[inv.id] = inv
        end
    end
end

exports('UpdateVehicle', Inventory.UpdateVehicle)

local function serialise(inv, now)
    local buffer = {}
    for k, v in pairs(inv.items) do
        if not Items.UpdateDurability(inv, v, Items(v.name), nil, now) then
            buffer[#buffer + 1] = { name = v.name, count = v.count, slot = k, metadata = next(v.metadata) and v.metadata or nil }
        end
    end
    table.sort(buffer, function(a, b) return a.slot < b.slot end)
    return next(buffer) and json.encode(buffer) or nil
end

function Inventory.Save(inv)
    inv = Inventory(inv)
    if not inv or inv.datastore then return end
    local data = serialise(inv, os.time())
    inv.changed = false

    if inv.player then
        if server.savePlayers == false then return end
        return db.savePlayer(inv.owner, data)
    elseif inv.type == 'trunk' then
        return db.saveTrunk(inv.dbId, data)
    elseif inv.type == 'glovebox' then
        return db.saveGlovebox(inv.dbId, data)
    end
    return db.saveStash(inv.owner, inv.dbId, data)
end

local function randomLoot(loot)
    local items = {}
    local size = #loot
    if size == 0 then return items end
    local used = {}
    for _ = 1, math.random(0, 3) do
        if #items >= size then break end
        local index = math.random(1, size)
        for _ = 1, size do
            if not used[index] then break end
            index = (index % size) + 1
        end
        local entry = loot[index]
        used[index] = true
        if entry and math.random(1, 100) <= (entry[4] or 80) then
            local count = math.random(entry[2], entry[3])
            if count > 0 then items[#items + 1] = { entry[1], count } end
        end
    end
    return items
end

local function generateItems(inv, invType, items)
    if items == nil then
        if invType == 'dumpster' then items = randomLoot(server.dumpsterloot)
        elseif invType == 'vehicle' then items = randomLoot(server.vehicleloot) end
    end
    items = items or {}

    local out, total, slot = {}, 0, 0
    for i = 1, #items do
        local v = items[i]
        local item = Items(v[1])
        if not item then
            print(('^3[vr-inventory] can not generate "%s", the item does not exist^0'):format(tostring(v[1])))
        else
            local metadata, count = Items.Metadata(inv, item, U.deepclone(v[3] or {}), v[2])
            slot = slot + 1
            local data = buildSlot(item, slot, count, metadata)
            data.weight = Inventory.SlotWeight(item, data)
            total = total + data.weight
            out[slot] = data
        end
    end
    return out, total
end

Inventory.generateItems = generateItems

function Inventory.Load(id, invType, owner)
    if not invType then return {}, 0 end
    local result

    if invType == 'trunk' or invType == 'glovebox' then
        local exists
        if id then
            if invType == 'trunk' then result, exists = db.loadTrunk(id) else result, exists = db.loadGlovebox(id) end
        end
        if not exists and server.randomloot then return generateItems(id, 'vehicle') end
    elseif invType == 'dumpster' then
        if server.randomloot then return generateItems(id, invType) end
    elseif id then
        result = db.loadStash(owner or '', id)
    end

    local items, weight = {}, 0
    if type(result) == 'table' then
        local now = os.time()
        for _, v in pairs(result) do
            local item = type(v) == 'table' and Items(v.name)
            if item and U.slotIn(v.slot) and tonumber(v.count) and v.count > 0 then
                v.metadata = Items.CheckMetadata(v.metadata or {}, item, v.name, now)
                local data = buildSlot(item, v.slot, v.count, v.metadata)
                data.weight = Inventory.SlotWeight(item, data)
                weight = weight + data.weight
                items[v.slot] = data
            end
        end
    end
    return items, weight
end

local function assertMetadata(metadata)
    if metadata and type(metadata) ~= 'table' then metadata = { type = metadata } end
    return metadata
end

Inventory.assertMetadata = assertMetadata

local function matcher(strict)
    return strict and U.matches or U.contains
end

function Inventory.GetItem(inv, item, metadata, returnsCount)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return end
    item = returnsCount and item or U.clone(item)
    inv = Inventory(inv)
    local count = 0
    if inv then
        local now = os.time()
        metadata = assertMetadata(metadata)
        for _, v in pairs(inv.items) do
            if v.name == item.name and (not metadata or U.contains(v.metadata, metadata)) and not Items.UpdateDurability(inv, v, item, nil, now) then
                count = count + v.count
            end
        end
    end
    if returnsCount then return count end
    item.count = count
    return item
end

exports('GetItem', Inventory.GetItem)

function Inventory.SwapSlots(fromInventory, toInventory, slot1, slot2)
    local fromSlot = fromInventory.items[slot1] and U.clone(fromInventory.items[slot1]) or nil
    local toSlot = toInventory.items[slot2] and U.clone(toInventory.items[slot2]) or nil
    if fromSlot then fromSlot.slot = slot2 end
    if toSlot then toSlot.slot = slot1 end
    fromInventory.items[slot1], toInventory.items[slot2] = toSlot, fromSlot
    fromInventory.changed, toInventory.changed = true, true
    return fromSlot, toSlot
end

exports('SwapSlots', function(fromInventory, toInventory, slot1, slot2)
    fromInventory, toInventory = Inventory(fromInventory), Inventory(toInventory)
    if not fromInventory or not toInventory then return end
    return Inventory.SwapSlots(fromInventory, toInventory, slot1, slot2)
end)

function Inventory.ContainerWeight(container, metaWeight, playerInventory)
    playerInventory.weight = playerInventory.weight - container.weight
    container.weight = Items(container.name).weight + metaWeight
    container.metadata.weight = metaWeight
    playerInventory.weight = playerInventory.weight + container.weight
end

function Inventory.SetItem(inv, item, count, metadata)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return false, 'invalid_item' end
    if type(count) ~= 'number' then return false, 'invalid_count' end
    count = math.floor(count + 0.5)
    if count < 0 then return false, 'negative_count' end
    inv = Inventory(inv)
    if not inv then return false, 'invalid_inventory' end

    inv.changed = true
    local current = Inventory.GetItem(inv, item.name, metadata, true)

    if count > current then
        return Inventory.AddItem(inv, item.name, count - current, metadata)
    elseif count < current then
        return Inventory.RemoveItem(inv, item.name, current - count, metadata)
    end
    return true
end

exports('SetItem', Inventory.SetItem)

function Inventory.GetCurrentWeapon(inv)
    inv = Inventory(inv)
    if inv and inv.player then
        local weapon = inv.weapon and inv.items[inv.weapon]
        if weapon and Items(weapon.name) and Items(weapon.name).weapon then return weapon end
        inv.weapon = nil
    end
end

exports('GetCurrentWeapon', Inventory.GetCurrentWeapon)

function Inventory.GetSlot(inv, slotId)
    if not inv or type(slotId) ~= 'number' then return end
    inv = Inventory(inv)
    local slot = inv and inv.items[slotId]
    if slot and not Items.UpdateDurability(inv, slot, Items(slot.name), nil, os.time()) then return slot end
end

exports('GetSlot', Inventory.GetSlot)

function Inventory.SetDurability(inv, slotId, durability)
    if not inv or type(slotId) ~= 'number' or type(durability) ~= 'number' then return end
    inv = Inventory(inv)
    local slot = inv and inv.items[slotId]
    if not slot then return end
    Items.UpdateDurability(inv, slot, Items(slot.name), durability)
    if inv.player and server.syncInventory then server.syncInventory(inv) end
end

exports('SetDurability', Inventory.SetDurability)

function Inventory.SetMetadata(inv, slotId, metadata)
    if not inv or type(slotId) ~= 'number' then return end
    inv = Inventory(inv)
    local slot = inv and inv.items[slotId]
    if not slot then return end

    local item = Items(slot.name)
    local previous = slot.metadata.durability
    slot.metadata = type(metadata) == 'table' and metadata or { type = metadata }
    inv.changed = true

    inv.weight = inv.weight - slot.weight
    slot.weight = Inventory.SlotWeight(item, slot)
    inv.weight = inv.weight + slot.weight

    if slot.metadata.durability ~= previous and slot.metadata.durability ~= nil then
        local value = slot.metadata.durability
        slot.metadata.durability = previous
        Items.UpdateDurability(inv, slot, item, value)
    else
        inv:syncSlotsWithClients({ { item = slot, inventory = inv.id } }, true)
    end

    if inv.player and server.syncInventory then server.syncInventory(inv) end
end

exports('SetMetadata', Inventory.SetMetadata)

local function notifyRefresh(inv, event, payload)
    if inv.player then TriggerClientEvent(event, inv.id, payload) end
    for playerId in pairs(inv.openedBy) do
        if playerId ~= inv.id then TriggerClientEvent(event, playerId, payload) end
    end
end

function Inventory.SetSlotCount(inv, slots)
    inv = Inventory(inv)
    if not inv or type(slots) ~= 'number' then return end
    inv.changed = true
    inv.slots = math.floor(slots)
    notifyRefresh(inv, 'vr-inventory:refreshSlotCount', { inventoryId = inv.id, slots = inv.slots })
end

exports('SetSlotCount', Inventory.SetSlotCount)

function Inventory.SetMaxWeight(inv, maxWeight)
    inv = Inventory(inv)
    if not inv or type(maxWeight) ~= 'number' then return end
    inv.maxWeight = maxWeight
    notifyRefresh(inv, 'vr-inventory:refreshMaxWeight', { inventoryId = inv.id, maxWeight = inv.maxWeight })
end

exports('SetMaxWeight', Inventory.SetMaxWeight)

function Inventory.AddItem(inv, item, count, metadata, slot, cb)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return false, 'invalid_item' end
    if type(count) ~= 'number' then return false, 'invalid_count' end
    count = math.floor(count + 0.5)
    if count <= 0 then return false, 'negative_count' end

    inv = Inventory(inv)
    if not inv or not inv.slots then return false, 'invalid_inventory' end

    local invoking = server.loglevel > 1 and GetInvokingResource()
    local toSlot, slotMetadata, slotCount
    metadata = assertMetadata(metadata)

    if slot and not U.slotIn(slot, inv.slots) then slot = nil end

    if slot then
        local slotData = inv.items[slot]
        slotMetadata, slotCount = Items.Metadata(inv, item, metadata and U.deepclone(metadata) or {}, count)
        if not slotData or (item.stack and slotData.name == item.name and U.matches(slotData.metadata, slotMetadata)) then
            toSlot = slot
        end
    end

    if not toSlot then
        local items = inv.items
        slotMetadata, slotCount = Items.Metadata(inv, item, metadata and U.deepclone(metadata) or {}, count)

        for i = 1, inv.slots do
            local slotData = items[i]
            if item.stack and slotData ~= nil and slotData.name == item.name and U.matches(slotData.metadata, slotMetadata) then
                toSlot = i
                break
            elseif not item.stack and not slotData then
                if type(toSlot) ~= 'table' then toSlot = {} end
                toSlot[#toSlot + 1] = { slot = i, count = slotCount, metadata = slotMetadata }
                if count == slotCount then break end
                count = count - 1
                slotMetadata, slotCount = Items.Metadata(inv, item, metadata and U.deepclone(metadata) or {}, count)
            elseif not toSlot and not slotData then
                toSlot = i
            end
        end
    end

    if not toSlot then
        if cb then return cb(false, 'inventory_full') end
        return false, 'inventory_full'
    end

    inv.changed = true
    local success, response = false, nil

    if type(toSlot) == 'number' then
        Inventory.SetSlot(inv, item, slotCount, slotMetadata, toSlot)
        if inv.player and server.syncInventory then server.syncInventory(inv) end
        inv:syncSlotsWithClients({ { item = inv.items[toSlot], inventory = inv.id } }, true)
        if invoking then lib.logger(inv.owner, 'addItem', ('"%s" added %sx %s to "%s"'):format(invoking, slotCount, item.name, inv.label)) end
        success, response = true, inv.items[toSlot]
    else
        local added = 0
        for i = 1, #toSlot do
            local data = toSlot[i]
            added = added + data.count
            Inventory.SetSlot(inv, item, data.count, data.metadata, data.slot)
            toSlot[i] = { item = inv.items[data.slot], inventory = inv.id }
        end
        if inv.player and server.syncInventory then server.syncInventory(inv) end
        inv:syncSlotsWithClients(toSlot, true)
        if invoking then lib.logger(inv.owner, 'addItem', ('"%s" added %sx %s to "%s"'):format(invoking, added, item.name, inv.label)) end
        for i = 1, #toSlot do toSlot[i] = toSlot[i].item end
        success, response = true, toSlot
    end

    if cb then return cb(success, response) end
    return success, response
end

exports('AddItem', Inventory.AddItem)

function Inventory.Search(inv, search, items, metadata)
    if not items then return false end
    inv = Inventory(inv)
    if not inv then return false end
    local list = inv.items

    if search == 'slots' then search = 1 elseif search == 'count' then search = 2 end
    if type(items) == 'string' then items = { items } end
    if type(items) ~= 'table' then return false end

    metadata = assertMetadata(metadata)
    local total = #items
    local out = {}

    for i = 1, total do
        local name = U.itemName(items[i])
        if name then
            if search == 1 then out[name] = {} elseif search == 2 then out[name] = 0 end
            for _, v in pairs(list) do
                if v.name == name then
                    if not v.metadata then v.metadata = {} end
                    if not metadata or U.contains(v.metadata, metadata) then
                        if search == 1 then
                            out[name][#out[name] + 1] = list[v.slot]
                        elseif search == 2 then
                            out[name] = out[name] + v.count
                        end
                    end
                end
            end
            if search == 1 then table.sort(out[name], function(a, b) return a.slot < b.slot end) end
        end
    end

    if next(out) then
        if total == 1 then return out[U.itemName(items[1])] end
        return out
    end
    return false
end

exports('Search', Inventory.Search)

function Inventory.GetItemSlots(inv, item, metadata, strict)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return end
    inv = Inventory(inv)
    if not inv or not inv.slots then return end

    local total, slots, empty = 0, {}, inv.slots
    if strict == nil then strict = true end
    local match = matcher(strict)

    for k, v in pairs(inv.items) do
        empty = empty - 1
        if v.name == item.name then
            if metadata and v.metadata == nil then v.metadata = {} end
            if not metadata or match(v.metadata, metadata) then
                total = total + v.count
                slots[k] = v.count
            end
        end
    end

    return slots, total, empty
end

exports('GetItemSlots', Inventory.GetItemSlots)

function Inventory.RemoveItem(inv, item, count, metadata, slot, ignoreTotal, strict)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return false, 'invalid_item' end
    if type(count) ~= 'number' then return false, 'invalid_count' end
    count = math.floor(count + 0.5)
    if count <= 0 then return false, 'negative_count' end

    inv = Inventory(inv)
    if not inv or not inv.slots then return false, 'invalid_inventory' end

    if slot then
        local slotItem = inv.items[slot]
        if not slotItem then return false, 'no_item_in_slot' end
        if count > slotItem.count then
            if not ignoreTotal then return false, 'not_enough_items_in_slot' end
            count = slotItem.count
        end
    end

    metadata = assertMetadata(metadata)
    if strict == nil then strict = true end
    local itemSlots, total = Inventory.GetItemSlots(inv, item, metadata, strict)
    if not itemSlots then return false end

    if total and count > total then
        if not ignoreTotal then return false, 'not_enough_items' end
        count = total
    end

    local removed, want, changed = 0, count, {}

    if slot and itemSlots[slot] then
        removed = count
        local ok, err = Inventory.SetSlot(inv, item, -count, inv.items[slot].metadata, slot)
        if not ok then error(('failed to remove %sx %s from inventory-%s:slot-%s (%s)'):format(count, item.name, inv.id, slot, err)) end
        changed[#changed + 1] = inv.items[slot] or slot
    elseif total > 0 and not slot then
        local order = {}
        for k in pairs(itemSlots) do order[#order + 1] = k end
        table.sort(order)
        for _, k in ipairs(order) do
            local have = itemSlots[k]
            if removed >= want then break end
            if have == count then
                TriggerClientEvent('vr-inventory:itemNotify', inv.id, { inv.items[k], 'ui_removed', have })
                removed = want
                inv.weight = inv.weight - inv.items[k].weight
                inv.items[k] = nil
                changed[#changed + 1] = k
            elseif have > count then
                local ok, err = Inventory.SetSlot(inv, item, -count, inv.items[k].metadata, k)
                if not ok then error(('failed to remove %sx %s from inventory-%s:slot-%s (%s)'):format(count, item.name, inv.id, k, err)) end
                changed[#changed + 1] = inv.items[k] or k
                removed = want
            else
                TriggerClientEvent('vr-inventory:itemNotify', inv.id, { inv.items[k], 'ui_removed', have })
                removed = removed + have
                count = count - have
                inv.weight = inv.weight - inv.items[k].weight
                inv.items[k] = nil
                changed[#changed + 1] = k
            end
        end
    end

    if removed > 0 then
        inv.changed = true
        if inv.player and server.syncInventory then server.syncInventory(inv) end

        local sync = {}
        for i = 1, #changed do
            local v = changed[i]
            sync[i] = { item = type(v) == 'number' and { slot = v } or v, inventory = inv.id }
        end
        inv:syncSlotsWithClients(sync, true)

        local invoking = server.loglevel > 1 and GetInvokingResource()
        if invoking then lib.logger(inv.owner, 'removeItem', ('"%s" removed %sx %s from "%s"'):format(invoking, removed, item.name, inv.label)) end
        return true
    end

    return false, 'not_enough_items'
end

exports('RemoveItem', Inventory.RemoveItem)

function Inventory.CanCarryItem(inv, item, count, metadata)
    if type(item) ~= 'table' then item = Items(item) end
    if not item then return end
    inv = Inventory(inv)
    if not inv then return end

    local itemSlots, _, emptySlots = Inventory.GetItemSlots(inv, item, type(metadata) == 'table' and metadata or (metadata and { type = metadata } or nil))
    if not itemSlots then return end

    local weight = (type(metadata) == 'table' and metadata.weight) or item.weight
    if next(itemSlots) or emptySlots > 0 then
        count = count or 1
        if not item.stack and emptySlots < count then return false end
        if weight == 0 then return true end
        return inv.weight + weight * count <= inv.maxWeight
    end
    return false
end

exports('CanCarryItem', Inventory.CanCarryItem)

function Inventory.CanCarryAmount(inv, item)
    if type(item) ~= 'table' then item = Items(item) end
    inv = Inventory(inv)
    if inv and item then
        if item.weight <= 0 then return math.huge end
        return math.floor((inv.maxWeight - inv.weight) / item.weight)
    end
end

exports('CanCarryAmount', Inventory.CanCarryAmount)

function Inventory.CanCarryWeight(inv, weight)
    inv = Inventory(inv)
    if not inv then return end
    local available = inv.maxWeight - inv.weight
    return available >= (weight or 0), available
end

exports('CanCarryWeight', Inventory.CanCarryWeight)

function Inventory.CanSwapItem(inv, firstItem, firstItemCount, testItem, testItemCount)
    inv = Inventory(inv)
    if not inv then return end
    local first = Inventory.GetItem(inv, firstItem)
    local test = Inventory.GetItem(inv, testItem)
    if first and test and first.count >= firstItemCount then
        local without = inv.weight - first.weight * firstItemCount
        return without + test.weight * testItemCount <= inv.maxWeight
    end
end

exports('CanSwapItem', Inventory.CanSwapItem)

function Inventory.GetEmptySlot(inv)
    local inventory = Inventory(inv)
    if not inventory then return end
    for i = 1, inventory.slots do
        if not inventory.items[i] then return i end
    end
end

exports('GetEmptySlot', Inventory.GetEmptySlot)

function Inventory.GetSlotForItem(inv, itemName, metadata)
    local inventory = Inventory(inv)
    local item = Items(itemName)
    if not inventory or not item then return end
    metadata = assertMetadata(metadata)
    local empty
    for i = 1, inventory.slots do
        local slotData = inventory.items[i]
        if not slotData and not empty then empty = i end
        if item.stack and slotData and slotData.name == item.name and U.matches(slotData.metadata, metadata or {}) then return i end
    end
    return empty
end

exports('GetSlotForItem', Inventory.GetSlotForItem)

local function slotsWith(inv, itemName, metadata, strict, first)
    local inventory = Inventory(inv)
    local item = Items(itemName)
    if not inventory or not item then return end
    metadata = assertMetadata(metadata)
    local match = matcher(strict)
    local now = os.time()
    local out = {}
    for i = 1, inventory.slots do
        local slotData = inventory.items[i]
        if slotData and slotData.name == item.name and (not metadata or match(slotData.metadata, metadata)) then
            if not Items.UpdateDurability(inventory, slotData, item, nil, now) and inventory.items[i] then
                if first then return slotData end
                out[#out + 1] = slotData
            end
        end
    end
    for slot, slotData in pairs(inventory.items) do
        if slot > inventory.slots and slotData.name == item.name and (not metadata or match(slotData.metadata, metadata)) then
            if first then return slotData end
            out[#out + 1] = slotData
        end
    end
    if first then return nil end
    return out
end

function Inventory.GetSlotWithItem(inv, itemName, metadata, strict)
    return slotsWith(inv, itemName, metadata, strict, true)
end

exports('GetSlotWithItem', Inventory.GetSlotWithItem)

function Inventory.GetSlotIdWithItem(inv, itemName, metadata, strict)
    local slot = Inventory.GetSlotWithItem(inv, itemName, metadata, strict)
    return slot and slot.slot
end

exports('GetSlotIdWithItem', Inventory.GetSlotIdWithItem)

function Inventory.GetSlotsWithItem(inv, itemName, metadata, strict)
    return slotsWith(inv, itemName, metadata, strict, false)
end

exports('GetSlotsWithItem', Inventory.GetSlotsWithItem)

function Inventory.GetSlotIdsWithItem(inv, itemName, metadata, strict)
    local items = Inventory.GetSlotsWithItem(inv, itemName, metadata, strict)
    if not items then return end
    for i = 1, #items do items[i] = items[i].slot end
    return items
end

exports('GetSlotIdsWithItem', Inventory.GetSlotIdsWithItem)

function Inventory.GetItemCount(inv, itemName, metadata, strict)
    local inventory = Inventory(inv)
    local item = Items(itemName)
    if not inventory or not item then return 0 end
    metadata = assertMetadata(metadata)
    local match = matcher(strict)
    local count = 0
    for _, slotData in pairs(inventory.items) do
        if slotData.name == item.name and (not metadata or match(slotData.metadata, metadata)) then count = count + slotData.count end
    end
    return count
end

exports('GetItemCount', Inventory.GetItemCount)

RegisterNetEvent('vr-inventory:removeItem', function(name, count, metadata, slot)
    local src = source
    if type(name) ~= 'string' or type(count) ~= 'number' then return end
    if slot ~= nil and not U.isInt(slot) then return end
    Inventory.RemoveItem(src, name, count, metadata, slot)
end)

Inventory.Drops = {}

function Inventory.GenerateId(prefix)
    while true do
        local id = ('%s-%s'):format(prefix or 'drop', math.random(100000, 999999))
        if not Inventories[id] then return id end
    end
end

function Inventory.CustomDrop(prefix, items, coords, slots, maxWeight, instance, model)
    local dropId = Inventory.GenerateId('drop')
    local inventory = Inventory.Create(dropId, ('%s %s'):format(prefix or 'Drop', dropId:gsub('%D', '')), 'drop', slots or shared.dropslots, 0, maxWeight or shared.dropweight, false, {})
    if not inventory then return end
    inventory.items, inventory.weight = generateItems(inventory, 'drop', items)
    inventory.coords = U.toVec3(coords)
    Inventory.Drops[dropId] = { coords = inventory.coords, instance = instance, model = model }
    TriggerClientEvent('vr-inventory:createDrop', -1, dropId, Inventory.Drops[dropId])
    return dropId
end

exports('CustomDrop', Inventory.CustomDrop)
U.localEvent('customDrop', Inventory.CustomDrop)

exports('CreateDropFromPlayer', function(playerId)
    local playerInventory = Inventory(playerId)
    if not playerInventory or not playerInventory.player or not next(playerInventory.items) then return end

    local dropId = Inventory.GenerateId('drop')
    local items = {}
    for slot, data in pairs(playerInventory.items) do items[slot] = U.deepclone(data) end
    local inventory = Inventory.Create(dropId, ('Drop %s'):format(dropId:gsub('%D', '')), 'drop', playerInventory.slots, playerInventory.weight, playerInventory.maxWeight, false, items)
    if not inventory then return end

    local coords = GetEntityCoords(GetPlayerPed(playerId))
    inventory.coords = vector3(coords.x, coords.y, coords.z - 0.2)
    Inventory.Drops[dropId] = { coords = inventory.coords, instance = Player(playerId).state.instance }

    Inventory.Clear(playerInventory)
    TriggerClientEvent('vr-inventory:createDrop', -1, dropId, Inventory.Drops[dropId])
    return dropId
end)

function Inventory.Confiscate(source)
    local inv = Inventory(source)
    if not inv or not inv.player then return end
    db.saveStash(inv.owner, inv.owner, json.encode(minimal(inv)))
    U.wipe(inv.items)
    inv.weight = 0
    inv.changed = true
    inv.weapon = nil
    TriggerClientEvent('vr-inventory:inventoryConfiscated', inv.id)
    if server.syncInventory then server.syncInventory(inv) end
end

exports('ConfiscateInventory', Inventory.Confiscate)

function Inventory.Return(source)
    local inv = Inventory(source)
    if not inv or not inv.player then return end

    local items = db.loadStash(inv.owner, inv.owner)
    if not items then return end
    db.deleteStash(inv.owner, inv.owner)

    local inventory, total = {}, 0
    if type(items) == 'table' then
        for i = 1, #items do
            local data = items[i]
            if type(data) ~= 'table' then break end
            local item = Items(data.name)
            if item and U.slotIn(data.slot) then
                local slot = buildSlot(item, data.slot, data.count, data.metadata or {})
                slot.weight = Inventory.SlotWeight(item, slot)
                total = total + slot.weight
                inventory[data.slot] = slot
            end
        end
    end

    inv.changed = true
    inv.weight = total
    inv.items = inventory

    TriggerClientEvent('vr-inventory:inventoryReturned', inv.id, U.values(inventory), total)
    if server.syncInventory then server.syncInventory(inv) end
end

exports('ReturnInventory', Inventory.Return)

function Inventory.Clear(inv, keep)
    inv = Inventory(inv)
    if not inv or not next(inv.items) then return end

    local update, newWeight = {}, 0

    if keep then
        local kept = {}
        local list = type(keep) == 'string' and { keep } or (type(keep) == 'table' and keep or {})
        local set = {}
        for i = 1, #list do set[list[i]] = true end
        for slot, v in pairs(inv.items) do
            if set[v.name] then
                kept[slot] = v
                newWeight = newWeight + v.weight
            else
                update[#update + 1] = { item = { slot = slot }, inventory = inv.id }
            end
        end
        inv.items = kept
    else
        for slot in pairs(inv.items) do update[#update + 1] = { item = { slot = slot }, inventory = inv.id } end
        U.wipe(inv.items)
    end

    inv.weight = newWeight
    inv.changed = true
    inv:syncSlotsWithClients(update, true)

    if not inv.player then
        if inv.open then
            local playerInv = Inventory(inv.open)
            if playerInv then playerInv:closeInventory() end
        end
        return
    end

    if server.syncInventory then server.syncInventory(inv) end
    inv.weapon = nil
end

exports('ClearInventory', Inventory.Clear)

local function checkStashProperties(properties)
    local name, slots, maxWeight, coords = properties.name, properties.slots, properties.maxWeight, properties.coords
    if type(name) ~= 'string' then error(('received %s for stash name (expected string)'):format(type(name))) end
    if type(slots) ~= 'number' then error(('received %s for stash slots (expected number)'):format(type(slots))) end
    if type(maxWeight) ~= 'number' then error(('received %s for stash maxWeight (expected number)'):format(type(maxWeight))) end

    if coords then
        if U.isVec3(coords) then
            coords = U.toVec3(coords)
        elseif type(coords) == 'table' and U.tableType(coords) == 'array' then
            local list = {}
            for i = 1, #coords do list[i] = U.toVec3(coords[i]) end
            coords = list
        else
            error(('received %s for stash coords (expected vector3 or array of vector3)'):format(type(coords)))
        end
    end

    return name, slots, maxWeight, coords
end

function Inventory.RegisterStash(name, label, slots, maxWeight, owner, groups, coords, instance)
    name, slots, maxWeight, coords = checkStashProperties({ name = name, slots = slots, maxWeight = maxWeight, coords = coords })

    if RegisteredStashes[name] then
        for _, stash in pairs(Inventories) do
            if stash.type == 'stash' and stash.dbId == name then
                stash.label = label or stash.label
                stash.slots = slots or stash.slots
                stash.maxWeight = maxWeight or stash.maxWeight
                stash.groups = groups or stash.groups
                stash.coords = coords or stash.coords
                stash.instance = instance or stash.instance
            end
        end
    end

    RegisteredStashes[name] = {
        name = name, label = label, owner = owner, slots = slots, maxWeight = maxWeight,
        groups = groups, coords = coords, instance = instance, distance = 10,
    }
end

exports('RegisterStash', Inventory.RegisterStash)

function Inventory.CreateTemporaryStash(properties)
    properties.name = Inventory.GenerateId('temp')
    local name, slots, maxWeight, coords = checkStashProperties(properties)
    local inventory = Inventory.Create(name, properties.label, 'temp', slots, 0, maxWeight, properties.owner, {}, properties.groups)
    if not inventory then return end
    inventory.items, inventory.weight = generateItems(inventory, 'drop', properties.items)
    inventory.coords = coords
    inventory.instance = properties.instance
    return inventory.id
end

exports('CreateTemporaryStash', Inventory.CreateTemporaryStash)

function Inventory.InspectInventory(playerId, invId)
    local inventory = invId ~= playerId and Inventory(invId)
    local playerInventory = Inventory(playerId)
    if playerInventory and inventory then
        playerInventory:openInventory(inventory)
        TriggerClientEvent('vr-inventory:viewInventory', playerId, Inventory.Summary(playerInventory), Inventory.Summary(inventory, true))
    end
end

exports('InspectInventory', Inventory.InspectInventory)

function Inventory.Summary(inv, withItems)
    if not inv then return nil end
    local out = {
        id = inv.id,
        label = inv.label,
        type = inv.type,
        slots = inv.slots,
        weight = inv.weight,
        maxWeight = inv.maxWeight,
        coords = inv.coords,
        distance = inv.distance,
        instance = inv.instance,
    }
    if withItems then out.items = U.values(inv.items) end
    return out
end
