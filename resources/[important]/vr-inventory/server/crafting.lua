local U = InvUtil

CraftingBenches = {}

local function createBench(id, data)
    local recipes = data.items
    if type(recipes) ~= 'table' then return end

    for i = 1, #recipes do
        local recipe = recipes[i]
        local item = Items(recipe.name)
        if item then
            recipe.weight = item.weight
            recipe.slot = i
        else
            print(('^3[vr-inventory] crafting bench "%s" slot %s makes "%s" which does not exist^0'):format(id, i, tostring(recipe.name)))
        end
        for ingredient, needs in pairs(recipe.ingredients or {}) do
            if needs < 1 then
                local ing = Items(ingredient)
                if ing and not ing.durability then ing.durability = true end
            end
        end
    end

    if shared.target then data.points = nil else data.zones = nil end
    CraftingBenches[id] = data
end

for id, data in pairs(InvData('crafting')) do createBench(data.name or id, data) end

exports('RegisterCraftingBench', function(id, data)
    if type(id) ~= 'string' or type(data) ~= 'table' then return end
    createBench(id, data)
    TriggerClientEvent('vr-inventory:registerCraftingBench', -1, id, data)
end)

local function benchGroups(bench, index)
    if shared.target and bench.zones and bench.zones[index] then return bench.zones[index].groups or bench.groups end
    return bench.groups
end

local function benchCoords(source, bench, index)
    if not bench.zones and not bench.points then return GetEntityCoords(GetPlayerPed(source)) end
    if shared.target and bench.zones then return bench.zones[index] and bench.zones[index].coords end
    return bench.points and bench.points[index]
end

local function canUseBench(source, playerInv, bench, index)
    if not U.isInt(index) and (bench.zones or bench.points) then return false end
    local coords = benchCoords(source, bench, index)
    if not coords then return false end
    local groups = benchGroups(bench, index)
    if groups and not server.hasGroup(playerInv, groups) then return false end
    if U.dist(GetEntityCoords(GetPlayerPed(source)), coords) > 10 then return false end
    return true
end

lib.callback.register('vr-inventory:openCraftingBench', function(source, id, index)
    local left, bench = Inventory(source), CraftingBenches[id]
    if not left then return end

    if bench then
        if not canUseBench(source, left, bench, index) then return end
        if left.open and left.open ~= left.id then
            local other = Inventory(left.open)
            if other then left:closeInventory(true) end
        end
        left:openInventory(left)
    else
        return
    end

    return Inventory.Summary(left)
end)

lib.callback.register('vr-inventory:craftItem', function(source, id, index, recipeId, toSlot)
    local left, bench = Inventory(source), CraftingBenches[id]
    if not left or not bench then return end
    if not canUseBench(source, left, bench, index) then return end
    if not U.isInt(recipeId) then return end
    if toSlot ~= nil and not U.slotIn(toSlot, left.slots) then return end

    local recipe = bench.items[recipeId]
    if not recipe then return end

    local craftedItem = Items(recipe.name)
    if not craftedItem then return end

    local names = {}
    for name in pairs(recipe.ingredients) do names[#names + 1] = name end

    local craftCount = 1
    if type(recipe.count) == 'number' then
        craftCount = recipe.count
    elseif type(recipe.count) == 'table' and recipe.count[1] then
        craftCount = math.random(recipe.count[1], recipe.count[2] or recipe.count[1])
    end

    local newWeight = left.weight
    for name, needs in pairs(recipe.ingredients) do
        if needs >= 1 then
            local item = Items(name)
            if item then newWeight = newWeight - item.weight * needs end
        end
    end
    newWeight = newWeight + (craftedItem.weight + (recipe.metadata and recipe.metadata.weight or 0)) * craftCount
    if newWeight > left.maxWeight then return false, 'cannot_carry' end

    local found = Inventory.Search(left, 'slots', names) or {}
    if #names == 1 then found = { [U.itemName(names[1])] = found } end

    local use = {}

    for name, needs in pairs(recipe.ingredients) do
        local slots = found[U.itemName(name)] or {}
        if #slots == 0 then return false, 'item_not_enough' end
        if needs == 0 then
            local usable = false
            for i = 1, #slots do
                local durability = slots[i].metadata.durability
                if not durability or (durability > 100 and durability > os.time()) or (durability <= 100 and durability > 0) then
                    usable = true
                    break
                end
            end
            if not usable then return false, 'item_not_enough' end
        else
            local remaining = needs

            for i = 1, #slots do
                local slot = slots[i]
                if remaining < 1 then
                    local item = Items(name)
                    local durability = slot.metadata.durability
                    if durability and durability >= remaining * 100 then
                        if durability > 100 then
                            local degrade = (slot.metadata.degrade or item.degrade or 1) * 60
                            local percentage = ((durability - os.time()) * 100) / degrade
                            if percentage >= remaining * 100 then
                                use[slot.slot] = remaining
                                remaining = 0
                                break
                            end
                        else
                            use[slot.slot] = remaining
                            remaining = 0
                            break
                        end
                    end
                elseif remaining <= slot.count then
                    use[slot.slot] = remaining
                    remaining = 0
                    break
                else
                    use[slot.slot] = slot.count
                    remaining = remaining - slot.count
                end
            end

            if remaining > 0 then return false, 'item_not_enough' end
        end
    end

    local lockIds = {}
    for slot in pairs(use) do lockIds[#lockIds + 1] = SlotLock(left.id, slot) end
    local activeSlots <close> = InvLocks(lockIds)
    if not activeSlots then return end

    local hooks <close> = TriggerEventHooks('craftItem', {
        source = source,
        benchId = id,
        benchIndex = index,
        recipe = recipe,
        toInventory = left.id,
        toSlot = toSlot,
    })
    if not hooks.success then return false end

    local success = lib.callback.await('vr-inventory:startCrafting', source, id, recipeId)
    if not success then
        hooks.success = false
        return false
    end

    for slot, count in pairs(use) do
        local invSlot = left.items[slot]
        if not invSlot then hooks.success = false return false end
        if count >= 1 and invSlot.count < count then hooks.success = false return false end
    end

    for slot, count in pairs(use) do
        local invSlot = left.items[slot]
        if count < 1 then
            local item = Items(invSlot.name)
            local durability = invSlot.metadata.durability or 100
            if durability > 100 then
                local degrade = (invSlot.metadata.degrade or item.degrade or 1) * 60
                durability = durability - degrade * count
            else
                durability = durability - count * 100
            end

            if invSlot.count > 1 then
                local emptySlot = Inventory.GetEmptySlot(left)
                if emptySlot then
                    local ok, newItem = Inventory.SetSlot(left, item, 1, U.deepclone(invSlot.metadata), emptySlot)
                    if ok and newItem then Items.UpdateDurability(left, newItem, item, durability < 0 and 0 or durability) end
                end
                left.weight = left.weight - invSlot.weight
                invSlot.count = invSlot.count - 1
                invSlot.weight = Inventory.SlotWeight(item, invSlot)
                left.weight = left.weight + invSlot.weight
                left:syncSlotsWithClients({ { item = invSlot, inventory = left.id } }, true)
            else
                Items.UpdateDurability(left, invSlot, item, durability < 0 and 0 or durability)
            end
        else
            if not Inventory.RemoveItem(left, invSlot.name, count, nil, slot) then hooks.success = false return false end
        end
    end

    Inventory.AddItem(left, craftedItem, craftCount, recipe.metadata and U.deepclone(recipe.metadata) or {}, craftedItem.stack and toSlot or nil)
    return true
end)
