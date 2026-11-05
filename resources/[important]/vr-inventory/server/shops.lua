local U = InvUtil

Shops = {}
local locationKey = shared.target and 'targets' or 'locations'

local function setupShopItems(shop, shopName, groups)
    for i = 1, shop.slots do
        local slot = shop.items[i]
        if slot then
            if slot.grade and not groups then
                print(('^3[vr-inventory] shop "%s" slot %s (%s) has a grade but the shop has no group^0'):format(shopName, i, slot.name))
                slot.grade = nil
            end

            local item = Items(slot.name)
            if item then
                local price = slot.price or 0
                if server.randomprices and (not slot.currency or slot.currency == 'money') then
                    price = math.ceil(price * (math.random(80, 120) / 100))
                end
                local data = {
                    name = item.name,
                    slot = i,
                    weight = item.weight,
                    count = slot.count,
                    price = price,
                    metadata = slot.metadata,
                    license = slot.license,
                    currency = slot.currency,
                    grade = slot.grade,
                }
                if data.metadata then data.weight = Inventory.SlotWeight(item, { metadata = U.deepclone(data.metadata) }, true) end
                shop.items[i] = data
            else
                print(('^3[vr-inventory] shop "%s" sells "%s" which does not exist^0'):format(shopName, tostring(slot.name)))
                shop.items[i] = nil
            end
        end
    end
end

local function registerShopType(shopType, properties)
    if type(properties) ~= 'table' or type(properties.inventory) ~= 'table' then return end
    local locations = properties[locationKey] or properties.locations

    if locations then
        Shops[shopType] = properties
    else
        local shop = {
            label = properties.name,
            id = shopType,
            groups = properties.groups or properties.jobs,
            items = U.deepclone(properties.inventory),
            slots = #properties.inventory,
            type = 'shop',
        }
        Shops[shopType] = shop
        setupShopItems(shop, properties.name, shop.groups)
    end
end

local function createShop(shopType, id)
    local shop = Shops[shopType]
    if not shop then return end

    local store = (shop[locationKey] or shop.locations)
    store = store and store[id]
    if not store then return end

    local groups = shop.groups or shop.jobs
    local coords

    if shared.target and shop.targets then
        if store.length then
            coords = vector3(store.loc.x, store.loc.y, store.loc.z + math.abs(store.minZ - store.maxZ) / 2)
        else
            coords = store.coords or store.loc
        end
    else
        coords = store
    end

    shop[id] = {
        label = shop.name,
        id = shopType .. ' ' .. id,
        groups = groups,
        items = U.deepclone(shop.inventory),
        slots = #shop.inventory,
        type = 'shop',
        coords = U.toVec3(coords),
        distance = shared.target and shop.targets and shop.targets[id] and shop.targets[id].distance or nil,
    }

    setupShopItems(shop[id], shop.name, groups)
    return shop[id]
end

for shopType, details in pairs(InvData('shops')) do registerShopType(shopType, details) end

exports('RegisterShop', registerShopType)

local function resolveShop(currentShop)
    local shopType, shopId = currentShop:match('^(.-) (%d+)$')
    if not shopType then shopType = currentShop end
    shopId = tonumber(shopId)
    local root = Shops[shopType]
    if not root then return end
    return shopId and root[shopId] or root, shopType, shopId
end

lib.callback.register('vr-inventory:openShop', function(source, data)
    local playerInv = Inventory(source)
    if not playerInv then return end

    local shop
    if type(data) == 'table' and type(data.type) == 'string' then
        shop = Shops[data.type]
        if not shop then return end

        if not shop.items then
            local id = tonumber(data.id)
            if not id then return end
            shop = shop[id] or createShop(data.type, id)
            if not shop then return end
        end

        if shop.groups and not server.hasGroup(playerInv, shop.groups) then return end

        if shop.coords and U.isVec3(shop.coords) then
            local ped = GetPlayerPed(source)
            if U.dist(GetEntityCoords(ped), shop.coords) > 10 then return end
        end

        local shopType, shopId = shop.id:match('^(.-) (%d+)$')
        local hooks <close> = TriggerEventHooks('openShop', {
            source = source,
            shopId = shopId or shop.id,
            shopType = shopType or shop.id,
            label = shop.label,
            slots = shop.slots,
            items = shop.items,
            groups = shop.groups,
            coords = shop.coords,
            distance = shop.distance,
        })
        if not hooks.success then return end

        playerInv:closeInventory(true)
        playerInv:openInventory(playerInv)
        playerInv.currentShop = shop.id
    else
        return
    end

    return Inventory.Summary(playerInv), {
        id = shop.id,
        label = shop.label,
        type = 'shop',
        slots = shop.slots,
        items = U.values(shop.items),
        groups = shop.groups,
        coords = shop.coords,
        distance = shop.distance,
    }
end)

local function canAfford(inv, currency, price)
    if price >= 0 and Inventory.GetItemCount(inv, currency) >= price then return true end
    local label = currency == 'money' and (locale('$') .. U.groupDigits(price)) or (U.groupDigits(price) .. ' ' .. (Items(currency) and Items(currency).label or currency))
    return { type = 'error', description = locale('cannot_afford', label) }
end

local function isRequiredGrade(grade, rank)
    if type(grade) == 'table' then
        for i = 1, #grade do
            if grade[i] == rank then return true end
        end
        return false
    end
    return (rank or -1) >= grade
end

lib.callback.register('vr-inventory:buyItem', function(source, data)
    if type(data) ~= 'table' or data.toType ~= 'player' then return end
    if not U.isInt(data.fromSlot) or not U.isInt(data.toSlot) then return end

    data.count = math.max(1, math.floor(tonumber(data.count) or 1))

    local playerInv = Inventory(source)
    if not playerInv or not playerInv.currentShop then return end
    if not U.slotIn(data.toSlot, playerInv.slots) then return end

    local shop, shopType, shopId = resolveShop(playerInv.currentShop)
    if not shop or not shop.items then return end

    local fromData = shop.items[data.fromSlot]
    local toData = playerInv.items[data.toSlot]
    if not fromData then return end

    if fromData.count then
        if fromData.count < 1 then return false, false, { type = 'error', description = locale('shop_nostock') } end
        if data.count > fromData.count then data.count = fromData.count end
    end

    if fromData.license and server.hasLicense and not server.hasLicense(playerInv, fromData.license) then
        return false, false, { type = 'error', description = locale('item_unlicensed') }
    end

    if fromData.grade then
        local _, rank = server.hasGroup(playerInv, shop.groups)
        if not isRequiredGrade(fromData.grade, rank) then return false, false, { type = 'error', description = locale('stash_lowgrade') } end
    end

    local currency = fromData.currency or 'money'
    local fromItem = Items(fromData.name)
    if not fromItem then return end

    local result = fromItem.cb and fromItem.cb('buying', fromItem, playerInv, data.fromSlot, shop)
    if result == false then return false end

    local activeSlots <close> = InvLocks({ SlotLock(playerInv.id, data.toSlot), SlotLock(shop.id, data.fromSlot) })
    if not activeSlots then return false end

    local toItem = toData and Items(toData.name)
    local metadata, count = Items.Metadata(playerInv, fromItem, fromData.metadata and U.deepclone(fromData.metadata) or {}, data.count)
    local price = count * fromData.price

    if toData == nil or (toItem and fromItem.name == toItem.name and fromItem.stack and U.matches(toData.metadata, metadata)) then
        local newWeight = playerInv.weight + (fromItem.weight + (metadata and metadata.weight or 0)) * count
        if newWeight > playerInv.maxWeight then return false, false, { type = 'error', description = locale('cannot_carry') } end

        local afford = canAfford(playerInv, currency, price)
        if afford ~= true then return false, false, afford end

        if fromData.count then fromData.count = fromData.count - count end

        local hooks <close> = TriggerEventHooks('buyItem', {
            source = source,
            shopType = shopType,
            shopId = shopId,
            toInventory = playerInv.id,
            toSlot = data.toSlot,
            fromSlot = fromData,
            itemName = fromData.name,
            metadata = metadata,
            count = count,
            price = fromData.price,
            totalPrice = price,
            currency = currency,
        })

        if not hooks.success or not Inventory.SetSlot(playerInv, fromItem, count, metadata, data.toSlot) then
            if fromData.count then fromData.count = fromData.count + count end
            hooks.success = false
            return false
        end

        Inventory.RemoveItem(playerInv, currency, price)
        if server.syncInventory then server.syncInventory(playerInv) end

        local cost = currency == 'money' and (locale('$') .. U.groupDigits(price)) or (U.groupDigits(price) .. ' ' .. (Items(currency) and Items(currency).label or currency))
        local message = locale('purchased_for', count, metadata and metadata.label or fromItem.label, cost)

        if server.loglevel > 0 and (server.loglevel > 1 or fromData.price >= 500) then
            lib.logger(playerInv.owner, 'buyItem', ('"%s" %s'):format(playerInv.label, message:lower()), ('shop:%s'):format(shop.label))
        end

        return true, { data.toSlot, playerInv.items[data.toSlot], fromData.count and fromData or nil, playerInv.weight }, { type = 'success', description = message }
    end

    return false, false, { type = 'error', description = locale('unable_stack_items') }
end)

server.shops = Shops
