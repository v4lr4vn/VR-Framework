local U = InvUtil

local function exploit(playerId, event, message, kick)
    print(('^3[vr-inventory] player.%s (%s) tripped %s: %s^0'):format(tostring(playerId), GetPlayerName(playerId) or '?', event, message))
    lib.logger(playerId, 'vr-inventory:' .. event, message)
    if kick then DropPlayer(tostring(playerId), 'Dropped for suspicious inventory activity.') end
end

InvExploit = exploit

local function itemsOf(...)
    local out = {}
    for _, entry in ipairs({ ... }) do out[#out + 1] = entry end
    return out
end

local function dropItem(source, playerInventory, fromData, data)
    if not fromData then return end

    local toData = U.clone(fromData)
    toData.slot = data.toSlot
    toData.count = data.count
    toData.weight = Inventory.SlotWeight(Items(toData.name), toData)

    if toData.weight > shared.dropweight then return false, 'cannot_carry_other' end

    local dropId = Inventory.GenerateId('drop')

    local hooks <close> = TriggerEventHooks('swapItems', {
        source = source,
        fromInventory = playerInventory.id,
        fromSlot = fromData,
        fromType = playerInventory.type,
        toInventory = 'newdrop',
        toSlot = data.toSlot,
        toType = 'drop',
        count = data.count,
        action = 'move',
        dropId = dropId,
    })

    if not hooks.success then return end
    if Inventories[playerInventory.id] ~= playerInventory then hooks.success = false return end

    fromData.count = fromData.count - data.count
    fromData.weight = Inventory.SlotWeight(Items(fromData.name), fromData)

    if fromData.count < 1 then
        fromData = nil
    else
        toData.metadata = U.deepclone(toData.metadata)
    end

    local slot = data.fromSlot
    playerInventory.weight = playerInventory.weight - toData.weight
    playerInventory.items[slot] = fromData
    if slot == playerInventory.weapon then playerInventory.weapon = nil end

    local inventory = Inventory.Create(dropId, ('Drop %s'):format(dropId:gsub('%D', '')), 'drop', shared.dropslots, toData.weight, shared.dropweight, false, { [data.toSlot] = toData })
    if not inventory then hooks.success = false return end

    inventory.coords = data.coords
    Inventory.Drops[dropId] = { coords = inventory.coords, instance = data.instance }
    playerInventory.changed = true

    TriggerClientEvent('vr-inventory:createDrop', -1, dropId, Inventory.Drops[dropId], playerInventory.open and source, slot)
    InvLog(playerInventory.owner, 'swapSlots', ('%sx %s transferred from "%s" to "%s"'):format(data.count, toData.name, playerInventory.label, dropId))

    if server.syncInventory then server.syncInventory(playerInventory) end

    return true, {
        weight = playerInventory.weight,
        items = { { item = fromData or { slot = data.fromSlot }, inventory = playerInventory.id } },
    }
end

local function validCoords(c)
    return U.isVec3(c) and c.x == c.x and c.y == c.y and c.z == c.z and math.abs(c.x) < 20000 and math.abs(c.y) < 20000 and math.abs(c.z) < 5000
end

local function swapItems(source, data)
    if type(data) ~= 'table' then return end
    if type(data.fromType) ~= 'string' or type(data.toType) ~= 'string' then return end
    if not U.isInt(data.fromSlot) or not U.isInt(data.toSlot) then return end

    if data.fromType ~= data.toType and data.toType ~= 'player' and data.fromType ~= 'player' then
        exploit(source, 'swapItems', 'swap between two non-player inventories', true)
        return
    end

    data.count = math.max(1, math.floor(tonumber(data.count) or 1))

    local playerInventory = Inventory(source)
    if not playerInventory or not playerInventory.open then return end

    local toInventory = (data.toType == 'player' and playerInventory) or Inventory(playerInventory.open)
    local fromInventory = (data.fromType == 'player' and playerInventory) or Inventory(playerInventory.open)

    if not fromInventory or not toInventory then
        playerInventory:closeInventory()
        return
    end

    if data.toType == 'inspect' or data.fromType == 'inspect' or fromInventory.type == 'shop' or toInventory.type == 'shop' then return end

    if not U.slotIn(data.fromSlot, fromInventory.slots) then return end
    if data.toType == 'newdrop' then
        if not U.slotIn(data.toSlot, shared.dropslots) or not validCoords(data.coords) then return end
        local ped = GetPlayerPed(source)
        if ped ~= 0 and U.dist(GetEntityCoords(ped), data.coords) > 4.0 then return end
        data.coords = U.toVec3(data.coords)
    elseif not U.slotIn(data.toSlot, toInventory.slots) then
        return
    end

    local activeSlots <close> = InvLocks({
        SlotLock(fromInventory.id, data.fromSlot),
        SlotLock(toInventory.id, data.toSlot),
    })

    if not activeSlots then
        return false, itemsOf(
            { item = toInventory.items[data.toSlot] or { slot = data.toSlot }, inventory = toInventory.id },
            { item = fromInventory.items[data.fromSlot] or { slot = data.fromSlot }, inventory = fromInventory.id }
        )
    end

    local sameInventory = fromInventory.id == toInventory.id
    local fromOtherPlayer = fromInventory.player and fromInventory ~= playerInventory
    local toOtherPlayer = toInventory.player and toInventory ~= playerInventory
    local toData = toInventory.items[data.toSlot]

    local function partiesPresent()
        return Inventories[playerInventory.id] == playerInventory and Inventories[fromInventory.id] == fromInventory and Inventories[toInventory.id] == toInventory
    end

    if not sameInventory and (fromInventory.type == 'policeevidence' or (toInventory.type == 'policeevidence' and toData)) then
        local group, rank = server.hasGroup(playerInventory, shared.police)
        if not group or server.evidencegrade > rank then return false, 'evidence_cannot_take' end
    end

    if not (data.toType == 'newdrop' or fromInventory ~= toInventory or data.fromSlot ~= data.toSlot) then return end

    local fromData = fromInventory.items[data.fromSlot]

    if not fromData then
        return false, itemsOf(
            { item = { slot = data.fromSlot }, inventory = fromInventory.id },
            { item = toData or { slot = data.toSlot }, inventory = toInventory.id }
        )
    end

    if data.count > fromData.count then data.count = fromData.count end

    if data.toType == 'newdrop' then
        if data.fromType ~= 'player' then return end
        return dropItem(source, fromInventory, fromData, data)
    end

    if fromData.metadata.container and toInventory.type == 'container' then return false end
    if toData and toData.metadata.container and fromInventory.type == 'container' then return false end

    if toInventory.type == 'container' and fromData.metadata.container == toInventory.id then return false end
    if fromInventory.type == 'container' and toData and toData.metadata.container == fromInventory.id then return false end

    local container, containerItem
    if not sameInventory and playerInventory.containerSlot then
        container = fromInventory.type == 'container' and fromInventory or (toInventory.type == 'container' and toInventory or nil)
        if container then containerItem = playerInventory.items[playerInventory.containerSlot] end
    end

    if containerItem and (data.fromType == 'player' and data.fromSlot == playerInventory.containerSlot) then return false end

    local hookPayload = {
        source = source,
        fromInventory = fromInventory.id,
        fromSlot = fromData,
        fromType = fromInventory.type,
        toInventory = toInventory.id,
        toSlot = toData or data.toSlot,
        toType = toInventory.type,
        count = data.count,
    }

    local function containerAllows(name)
        if not containerItem then return true end
        local props = Items.containers[containerItem.name]
        if not props then return true end
        if props.whitelist and not props.whitelist[name] then return false end
        if props.blacklist and props.blacklist[name] then return false end
        return true
    end

    if toData and ((toData.name ~= fromData.name) or not toData.stack or not U.matches(toData.metadata, fromData.metadata)) then
        hookPayload.action = 'swap'

        if not sameInventory then
            local toWeight = toInventory.weight - toData.weight + fromData.weight
            local fromWeight = fromInventory.weight + toData.weight - fromData.weight

            if not (toWeight <= toInventory.maxWeight and fromWeight <= fromInventory.maxWeight) then return false, 'cannot_carry' end

            if containerItem then
                local toContainer = toInventory.type == 'container'
                if not containerAllows(toContainer and fromData.name or toData.name) then return false end
            end

            local hooks <close> = TriggerEventHooks('swapItems', hookPayload)
            if not hooks.success then return end
            if not partiesPresent() then hooks.success = false return end

            if containerItem then
                local toContainer = toInventory.type == 'container'
                Inventory.ContainerWeight(containerItem, toContainer and toWeight or fromWeight, playerInventory)
            end

            if fromOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', fromInventory.id, { fromData, 'ui_removed', fromData.count })
                TriggerClientEvent('vr-inventory:itemNotify', fromInventory.id, { toData, 'ui_added', toData.count })
            elseif toOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', toInventory.id, { fromData, 'ui_added', fromData.count })
                TriggerClientEvent('vr-inventory:itemNotify', toInventory.id, { toData, 'ui_removed', toData.count })
            end

            fromInventory.weight = fromWeight
            toInventory.weight = toWeight
            toData, fromData = Inventory.SwapSlots(fromInventory, toInventory, data.fromSlot, data.toSlot)

            InvLog(playerInventory.owner, 'swapSlots', ('%sx %s transferred from "%s" to "%s" for %sx %s'):format(toData.count, toData.name, fromInventory.owner and fromInventory.label or fromInventory.id, toInventory.owner and toInventory.label or toInventory.id, fromData.count, fromData.name))
        else
            local hooks <close> = TriggerEventHooks('swapItems', hookPayload)
            if not hooks.success then return end
            if not partiesPresent() then hooks.success = false return end
            toData, fromData = Inventory.SwapSlots(fromInventory, toInventory, data.fromSlot, data.toSlot)
        end
    elseif toData and toData.name == fromData.name and U.matches(toData.metadata, fromData.metadata) then
        local origFrom, origTo = fromData.count, toData.count
        local fromCount, toCount = origFrom - data.count, origTo + data.count
        local origFromWeight = fromData.weight

        fromData.count, toData.count = fromCount, toCount
        local fromSlotWeight = Inventory.SlotWeight(Items(fromData.name), fromData)
        local toSlotWeight = Inventory.SlotWeight(Items(toData.name), toData)
        fromData.count, toData.count = origFrom, origTo

        local totalWeight = toInventory.weight - toData.weight + toSlotWeight

        if not (fromInventory.type == 'container' or sameInventory or totalWeight <= toInventory.maxWeight) then return false, 'cannot_carry' end

        hookPayload.action = 'stack'
        local hooks <close> = TriggerEventHooks('swapItems', hookPayload)
        if not hooks.success then return end
        if not partiesPresent() then hooks.success = false return end

        fromData.count, toData.count = fromCount, toCount
        toData.weight = toSlotWeight

        if not sameInventory then
            fromInventory.weight = fromInventory.weight - origFromWeight + fromSlotWeight
            toInventory.weight = totalWeight

            if container then
                Inventory.ContainerWeight(containerItem, toInventory.type == 'container' and toInventory.weight or fromInventory.weight, playerInventory)
            end

            if fromOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', fromInventory.id, { fromData, 'ui_removed', data.count })
            elseif toOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', toInventory.id, { toData, 'ui_added', data.count })
            end

            InvLog(playerInventory.owner, 'swapSlots', ('%sx %s transferred from "%s" to "%s"'):format(data.count, fromData.name, fromInventory.owner and fromInventory.label or fromInventory.id, toInventory.owner and toInventory.label or toInventory.id))
        end

        fromData.weight = fromSlotWeight
    elseif not toData then
        toData = U.clone(fromData)
        toData.count = data.count
        toData.slot = data.toSlot
        toData.weight = Inventory.SlotWeight(Items(toData.name), toData)

        if not (fromInventory.type == 'container' or sameInventory or (toInventory.weight + toData.weight <= toInventory.maxWeight)) then return false, 'cannot_carry_other' end

        local toContainer = toInventory.type == 'container'
        if not sameInventory and container and toContainer and not containerAllows(fromData.name) then return false end

        hookPayload.action = 'move'
        local hooks <close> = TriggerEventHooks('swapItems', hookPayload)
        if not hooks.success then return end
        if not partiesPresent() then hooks.success = false return end

        if not sameInventory then
            fromInventory.weight = fromInventory.weight - toData.weight
            toInventory.weight = toInventory.weight + toData.weight

            if container then
                Inventory.ContainerWeight(containerItem, toContainer and toInventory.weight or fromInventory.weight, playerInventory)
            end

            if fromOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', fromInventory.id, { fromData, 'ui_removed', data.count })
            elseif toOtherPlayer then
                TriggerClientEvent('vr-inventory:itemNotify', toInventory.id, { fromData, 'ui_added', data.count })
            end

            InvLog(playerInventory.owner, 'swapSlots', ('%sx %s transferred from "%s" to "%s"'):format(data.count, fromData.name, fromInventory.owner and fromInventory.label or fromInventory.id, toInventory.owner and toInventory.label or toInventory.id))
        end

        fromData.count = fromData.count - data.count
        fromData.weight = Inventory.SlotWeight(Items(fromData.name), fromData)
        if fromData.count > 0 then toData.metadata = U.deepclone(toData.metadata) end
    else
        return false
    end

    if fromData and fromData.count < 1 then fromData = nil end

    local extra = {}
    if containerItem then
        if (fromInventory.player and not fromOtherPlayer and toInventory.type == 'container') or (toInventory.player and not toOtherPlayer and fromInventory.type == 'container') then
            extra[#extra + 1] = { item = containerItem, inventory = playerInventory.id }
        end
    end

    fromInventory.items[data.fromSlot] = fromData
    toInventory.items[data.toSlot] = toData

    if fromInventory.changed ~= nil then fromInventory.changed = true end
    if toInventory.changed ~= nil then toInventory.changed = true end

    CreateThread(function()
        if sameInventory then
            fromInventory:syncSlotsWithClients({
                { item = fromInventory.items[data.toSlot] or { slot = data.toSlot }, inventory = fromInventory.id },
                { item = fromInventory.items[data.fromSlot] or { slot = data.fromSlot }, inventory = fromInventory.id },
            }, true)
        else
            toInventory:syncSlotsWithClients({ { item = toInventory.items[data.toSlot] or { slot = data.toSlot }, inventory = toInventory.id } }, true)
            fromInventory:syncSlotsWithClients({ { item = fromInventory.items[data.fromSlot] or { slot = data.fromSlot }, inventory = fromInventory.id } }, true)
        end
        if #extra > 0 then playerInventory:syncSlotsWithPlayer(extra, playerInventory.weight) end
    end)

    if server.syncInventory then
        if fromInventory.player then server.syncInventory(fromInventory) end
        if toInventory.player and not sameInventory then server.syncInventory(toInventory) end
    end

    local weaponSlot

    if toInventory.weapon == data.toSlot then
        if not sameInventory then
            toInventory.weapon = nil
            TriggerClientEvent('vr-inventory:disarm', toInventory.id)
        else
            weaponSlot = data.fromSlot
            toInventory.weapon = weaponSlot
        end
    end

    if fromInventory.weapon == data.fromSlot then
        if not sameInventory then
            fromInventory.weapon = nil
            TriggerClientEvent('vr-inventory:disarm', fromInventory.id)
        elseif not weaponSlot then
            weaponSlot = data.toSlot
            fromInventory.weapon = weaponSlot
        end
    end

    return containerItem and containerItem.weight or true, nil, weaponSlot
end

lib.callback.register('vr-inventory:swapItems', swapItems)
Inventory.SwapItems = swapItems

local function giveItem(playerId, slot, target, count)
    if not U.isInt(slot) or type(target) ~= 'number' then return end
    if playerId == target then return end

    local fromInventory = Inventory(playerId)
    local toInventory = Inventory(target)
    if not fromInventory or not toInventory or not fromInventory.player then return end

    count = math.max(1, math.floor(tonumber(count) or 1))

    if not toInventory.player then return end

    local data = fromInventory.items[slot]
    if not data then return end

    if Player(target).state.invBusy then return { 'cannot_give', count, data.label } end

    local item = Items(data.name)
    local distance = U.dist(GetEntityCoords(fromInventory.player.ped), GetEntityCoords(toInventory.player.ped))

    if not item or data.count < count or not Inventory.CanCarryItem(toInventory, item, count, data.metadata) or distance > 15 then
        return { 'cannot_give', count, data.label }
    end

    local toSlot = Inventory.GetSlotForItem(toInventory, data.name, data.metadata)
    if not toSlot then return { 'cannot_give', count, data.label } end

    local activeSlots <close> = InvLocks({ SlotLock(fromInventory.id, slot), SlotLock(toInventory.id, toSlot) })
    if not activeSlots then return { 'cannot_give', count, data.label } end

    local hooks <close> = TriggerEventHooks('swapItems', {
        source = fromInventory.id,
        fromInventory = fromInventory.id,
        fromType = fromInventory.type,
        toInventory = toInventory.id,
        toType = toInventory.type,
        count = count,
        action = 'give',
        fromSlot = data,
    })

    if hooks.success then
        local metadata = U.deepclone(data.metadata)
        if Inventory.AddItem(toInventory, item, count, metadata, toSlot) then
            if Inventory.RemoveItem(fromInventory, item, count, data.metadata, slot) then
                if fromInventory.weapon == slot and not fromInventory.items[slot] then
                    fromInventory.weapon = nil
                    TriggerClientEvent('vr-inventory:disarm', fromInventory.id, true)
                end
                InvLog(fromInventory.owner, 'giveItem', ('"%s" gave %sx %s to "%s"'):format(fromInventory.label, count, data.name, toInventory.label))
                return
            end
            hooks.success = false
            Inventory.RemoveItem(toInventory, item, count, metadata, toSlot)
        end
    end

    return { 'cannot_give', count, data.label }
end

lib.callback.register('vr-inventory:giveItem', giveItem)
U.netEvent('giveItem', function(slot, target, count) giveItem(source, slot, target, count) end)
Inventory.GiveItem = giveItem

local function updateWeapon(source, action, value, slot, specialAmmo)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    if not action then
        inventory.weapon = nil
        return
    end

    local vtype = type(value)

    if vtype == 'table' and action == 'component' then
        local item = U.isInt(value.slot) and inventory.items[value.slot]
        if not item or type(item.metadata.components) ~= 'table' or type(value.component) ~= 'string' then return end
        for k, v in ipairs(item.metadata.components) do
            if v == value.component then
                if not Inventory.AddItem(inventory, value.component, 1) then return end
                table.remove(item.metadata.components, k)
                inventory.weight = inventory.weight - item.weight
                item.weight = Inventory.SlotWeight(Items(item.name), item)
                inventory.weight = inventory.weight + item.weight
                inventory.changed = true
                inventory:syncSlotsWithPlayer({ { item = item } }, inventory.weight)
                if server.syncInventory then server.syncInventory(inventory) end
                return true
            end
        end
        return
    end

    if slot ~= nil and not U.isInt(slot) then return end
    if not slot then slot = inventory.weapon end

    local weapon = slot and inventory.items[slot]
    if not weapon or not weapon.metadata then return end

    local item = Items(weapon.name)
    if not item or not item.weapon then
        inventory.weapon = nil
        return
    end

    if vtype == 'number' then
        if value ~= value then return end
        if value < 0 then value = 0 end
        value = math.floor(value)
    end

    local oldWeight = weapon.weight

    if action == 'load' then
        if vtype ~= 'number' or (weapon.metadata.durability or 0) <= 0 or not item.ammoname then return end
        local diff = value - (weapon.metadata.ammo or 0)
        if diff <= 0 then return end
        if specialAmmo ~= nil and type(specialAmmo) ~= 'string' then return end
        if not Inventory.RemoveItem(inventory, item.ammoname, diff, specialAmmo) then return end
        weapon.metadata.ammo = value
        weapon.metadata.specialAmmo = specialAmmo
        weapon.weight = Inventory.SlotWeight(item, weapon)
    elseif action == 'throw' then
        if not item.throwable then return end
        if not Inventory.RemoveItem(inventory, weapon.name, 1, weapon.metadata, weapon.slot) then return end
        if inventory.weapon == slot and not inventory.items[slot] then inventory.weapon = nil end
    elseif action == 'component' then
        if type(weapon.metadata.components) ~= 'table' then weapon.metadata.components = {} end
        if vtype == 'number' then
            local component = weapon.metadata.components[value]
            if not component then return false end
            if not Inventory.AddItem(inventory, component, 1) then return false end
            table.remove(weapon.metadata.components, value)
            weapon.weight = Inventory.SlotWeight(item, weapon)
        elseif vtype == 'string' then
            local componentSlot = tonumber(value)
            local component = componentSlot and inventory.items[componentSlot]
            local componentItem = component and Items(component.name)
            if not componentItem or not (componentItem.component or componentItem.tint) then return false end
            for i = 1, #weapon.metadata.components do
                local existing = Items(weapon.metadata.components[i])
                if existing and componentItem.type and existing.type == componentItem.type then return false end
            end
            if not Inventory.RemoveItem(inventory, component.name, 1, nil, componentSlot) then return false end
            weapon.metadata.components[#weapon.metadata.components + 1] = component.name
            weapon.weight = Inventory.SlotWeight(item, weapon)
        else
            return
        end
    elseif action == 'ammo' then
        if vtype ~= 'number' then return end
        if Hashes.isCan(item.hash) then
            local safeValue = math.max(0, math.min(100, value))
            weapon.metadata.durability = safeValue
            weapon.metadata.ammo = safeValue
        elseif weapon.metadata.ammo and value < weapon.metadata.ammo then
            local durability = (item.durability or 0) * math.abs((weapon.metadata.ammo or 0.1) - value)
            weapon.metadata.ammo = value
            weapon.metadata.durability = (weapon.metadata.durability or 0) - durability
            weapon.weight = Inventory.SlotWeight(item, weapon)
        end
    elseif action == 'melee' then
        if vtype ~= 'number' then return end
        value = math.min(value, 50)
        weapon.metadata.durability = (weapon.metadata.durability or 0) - ((item.durability or 1) * value)
    else
        return
    end

    if (weapon.metadata.durability or 0) < 0 then weapon.metadata.durability = 0 end
    if item.hash == Hashes.petrolcan then weapon.weight = Inventory.SlotWeight(item, weapon) end

    if action ~= 'throw' then
        if weapon.weight ~= oldWeight and inventory.items[weapon.slot] == weapon then
            inventory.weight = inventory.weight - oldWeight + weapon.weight
        end
        inventory.changed = true
        inventory:syncSlotsWithPlayer({ { item = weapon } }, inventory.weight)
    end

    if server.syncInventory then server.syncInventory(inventory) end
    return true
end

lib.callback.register('vr-inventory:updateWeapon', updateWeapon)
U.netEvent('updateWeapon', function(action, value, slot, specialAmmo)
    updateWeapon(source, action, value, slot, specialAmmo)
end)
Inventory.UpdateWeapon = updateWeapon

lib.callback.register('vr-inventory:removeAmmoFromWeapon', function(source, slot)
    local inventory = Inventory(source)
    if not inventory or inventory.usingItem or not U.isInt(slot) then return end

    local slotData = inventory.items[slot]
    if not slotData or not slotData.metadata.ammo or slotData.metadata.ammo < 1 then return end

    local item = Items(slotData.name)
    if not item or not item.ammoname then return end
    local specialAmmo = slotData.metadata.specialAmmo and { type = slotData.metadata.specialAmmo } or nil

    if Inventory.AddItem(inventory, item.ammoname, slotData.metadata.ammo, specialAmmo) then
        local oldWeight = slotData.weight
        slotData.metadata.ammo = 0
        slotData.weight = Inventory.SlotWeight(item, slotData)
        inventory.weight = inventory.weight - oldWeight + slotData.weight
        inventory.changed = true
        inventory:syncSlotsWithPlayer({ { item = slotData } }, inventory.weight)
        if server.syncInventory then server.syncInventory(inventory) end
        return true
    end
end)
