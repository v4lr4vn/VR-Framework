local U = InvUtil

function server.setPlayerInventory(player, data)
    while not shared.ready do Wait(0) end
    if type(player) ~= 'table' or not player.source or not player.identifier then return end

    if not data then data = db.loadPlayer(player.identifier) end

    local inventory, totalWeight = {}, 0

    if type(data) == 'table' then
        local now = os.time()
        for _, v in pairs(data) do
            if type(v) == 'table' and v.name and U.slotIn(v.slot) and tonumber(v.count) then
                local item = Items(v.name)
                if item and v.count > 0 then
                    v.metadata = Items.CheckMetadata(v.metadata or {}, item, v.name, now)
                    local slot = Inventory.buildSlot(item, v.slot, v.count, v.metadata)
                    slot.weight = Inventory.SlotWeight(item, slot)
                    totalWeight = totalWeight + slot.weight
                    inventory[v.slot] = slot
                end
            elseif server.convertInventory then
                inventory, totalWeight = server.convertInventory(player.source, data)
                break
            end
        end
    end

    player.source = tonumber(player.source)
    local inv = Inventory.Create(player.source, player.name, 'player', shared.playerslots, totalWeight, shared.playerweight, player.identifier, inventory)
    if not inv then return end

    inv.player = server.setPlayerData(player)
    inv.player.source = player.source

    local tries = 0
    repeat
        inv.player.ped = GetPlayerPed(player.source)
        if inv.player.ped == 0 then
            tries = tries + 1
            Wait(0)
        end
    until inv.player.ped ~= 0 or tries > 600 or not Inventories[player.source]

    if server.syncInventory then server.syncInventory(inv) end

    local drops = {}
    for id, drop in pairs(Inventory.Drops) do drops[id] = drop end

    TriggerClientEvent('vr-inventory:setPlayerInventory', player.source, drops, U.values(inventory), totalWeight, inv.player)
end

exports('setPlayerInventory', server.setPlayerInventory)
U.localEvent('setPlayerInventory', server.setPlayerInventory)

function server.playerDropped(source)
    local inv = Inventory(tonumber(source))
    if inv and inv.player then
        inv:closeInventory()
        Inventory.Remove(inv)
    end
end

local registeredDumpsters = {}

local function dumpsterFromCoords(coords)
    for i = 1, #registeredDumpsters do
        if U.dist(coords, registeredDumpsters[i]) < 0.1 then return i end
    end
end

local function closestStashCoords(playerPed, stash)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = stash.distance or 10
    local coords = stash.coords
    if not coords then return end

    if type(coords) == 'table' and not U.isVec3(coords) then
        for i = 1, #coords do
            if U.dist(coords[i], playerCoords) < distance then return coords[i] end
        end
        return
    end

    return U.dist(coords, playerCoords) < distance and coords or nil
end

local function openInventory(source, invType, data, ignoreSecurityChecks)
    if Inventory.Lock then return false end
    if invType ~= nil and type(invType) ~= 'string' then return end
    if invType == nil and data ~= nil then return end

    local left = Inventory(source)
    if not left or not left.player then return end

    left:closeInventory(true)
    Inventory.CloseAll(left, source)

    if invType == 'player' and data == source then data = nil end

    local playerPed = GetPlayerPed(source)
    left.player.ped = playerPed
    local right, closestCoords

    if data ~= nil then
        local isTable = type(data) == 'table'

        if invType == 'stash' then
            if not (isTable or type(data) == 'string' or type(data) == 'number') then return end
            if isTable and type(data.id) ~= 'string' and type(data.id) ~= 'number' then return end
            right = Inventory(data, left, ignoreSecurityChecks)
            if right == false then return false end
            if right and right.type == 'temp' and not ignoreSecurityChecks and right.owner and right.owner ~= true and right.owner ~= left.owner then return end
        elseif isTable then
            if data.netid then
                if not U.isInt(data.netid) then return end
                local entity = NetworkGetEntityFromNetworkId(data.netid)
                if not entity or entity == 0 then return end

                if not ignoreSecurityChecks and U.dist(GetEntityCoords(playerPed), GetEntityCoords(entity)) > 16 then return end

                if invType == 'glovebox' then
                    if not ignoreSecurityChecks and GetVehiclePedIsIn(playerPed, false) ~= entity then return end
                elseif invType == 'trunk' then
                    local lockStatus = ignoreSecurityChecks and 0 or GetVehicleDoorLockStatus(entity)
                    if lockStatus > 1 and lockStatus ~= 8 then return false, false, 'vehicle_locked' end
                else
                    return
                end

                local plate = Inventory.plateOf(GetVehicleNumberPlateText(entity))
                if not plate then return end

                local request = { id = (invType == 'glovebox' and 'glove' or 'trunk') .. plate, netid = data.netid, type = invType }
                right = Inventory(request, left)

                if right and right.netid and request.netid ~= right.netid then
                    local invEntity = NetworkGetEntityFromNetworkId(right.netid)
                    if not (invEntity and invEntity > 0 and DoesEntityExist(invEntity)) or Inventory.plateOf(GetVehicleNumberPlateText(invEntity) or '') ~= plate then
                        Inventory.Remove(right)
                        right = Inventory(request, left)
                    end
                end
            elseif invType == 'drop' then
                if type(data.id) ~= 'string' then return end
                right = Inventories[data.id]
            else
                return
            end
        elseif invType == 'drop' then
            if type(data) ~= 'string' then return end
            right = Inventories[data]
        elseif invType == 'policeevidence' then
            local locker = tonumber(data)
            if not locker or locker % 1 ~= 0 or locker < 0 then return end
            if ignoreSecurityChecks or server.hasGroup(left, shared.police) then
                right = Inventory(('evidence-%s'):format(locker))
            end
        elseif invType == 'dumpster' then
            if shared.networkdumpsters then
                if not U.isVec3(data) then return end
                data = U.toVec3(data)
                local dumpsterId = dumpsterFromCoords(data)
                right = dumpsterId and Inventory(('dumpster-%s'):format(dumpsterId))
                if not right then
                    if U.dist(GetEntityCoords(playerPed), data) > 5 then return end
                    dumpsterId = #registeredDumpsters + 1
                    right = Inventory.Create(('dumpster-%s'):format(dumpsterId), locale('dumpster'), invType, 15, 0, 100000, false)
                    registeredDumpsters[dumpsterId] = data
                end
                if right then
                    right.coords = registeredDumpsters[dumpsterId]
                    right.distance = 5
                end
            else
                if type(data) ~= 'string' or not data:find('^dumpster%d+$') then return end
                right = Inventories[data]
                if not right then
                    local netid = tonumber(data:sub(9))
                    local entity = netid and NetworkGetEntityFromNetworkId(netid)
                    if entity and entity > 0 then
                        right = Inventory.Create(data, locale('dumpster'), invType, 15, 0, 100000, false)
                        if right then
                            right.coords = GetEntityCoords(entity)
                            right.distance = 5
                        end
                    end
                end
            end
        elseif invType == 'container' then
            if not U.slotIn(data, left.slots) then return end
            local slotData = left.items[data]
            if slotData and slotData.metadata.container then
                left.containerSlot = data
                right = Inventory(slotData.metadata.container)
                if not right then
                    local size = slotData.metadata.size or { 5, 1000 }
                    right = Inventory.Create(slotData.metadata.container, slotData.label, invType, size[1], 0, size[2], false)
                end
            else
                left.containerSlot = nil
            end
        elseif invType == 'player' then
            local target = tonumber(data)
            if not target then return end
            right = Inventories[target]
        elseif invType ~= 'glovebox' and invType ~= 'trunk' then
            right = Inventory(data)
        end

        if not right then return end

        if right.type ~= invType and not (right.type == 'temp' and invType == 'stash') then
            if not ignoreSecurityChecks then InvExploit(source, 'openInventory', ('opened %s as %s'):format(tostring(right.type), invType), true) end
            return
        end

        if not ignoreSecurityChecks then
            if right.groups and not server.hasGroup(left, right.groups) then return end
            if right.instance and Player(source).state.instance ~= right.instance then return end
        end

        local hookPayload = { source = source, inventoryId = right.id, inventoryType = right.type }
        if invType == 'container' then hookPayload.slot = left.containerSlot end
        if isTable and data.netid then hookPayload.netId = data.netid end

        if left == right then return end

        if right.player then
            if right.open then return end
            right.coords = not ignoreSecurityChecks and GetEntityCoords(right.player.ped) or nil
            right.distance = 3
        end

        if not ignoreSecurityChecks and right.coords then
            closestCoords = closestStashCoords(playerPed, right)
            if not closestCoords then return end
        end

        local hooks <close> = TriggerEventHooks('openInventory', hookPayload)
        if not hooks.success then return end
    end

    left:openInventory(right)

    local leftData = Inventory.Summary(left)
    local rightData
    if right then
        rightData = Inventory.Summary(right, true)
        if right.player then
            rightData.label = right.player.name or ''
            rightData.type = 'otherplayer'
            rightData.distance = nil
        end
        rightData.coords = closestCoords or right.coords
    end

    return leftData, rightData
end

Inventory.Open = openInventory

lib.callback.register('vr-inventory:openInventory', function(source, invType, data)
    if invType == 'player' and source ~= data then
        local serverId = type(data) == 'table' and data.id or data
        serverId = tonumber(serverId)
        if not serverId or source == serverId then return end

        local left = Inventory(source)
        if not left then return end

        local isPolice = server.hasGroup(left, shared.police)
        local targetState = Player(serverId).state
        local stealable = targetState.canSteal or targetState.dead or targetState.isDead or targetState.isHandcuffed

        if not isPolice and not stealable then return end
        data = serverId
    end

    return openInventory(source, invType, data)
end)

lib.callback.register('vr-inventory:isVehicleATrailer', function(source, netId)
    local entity = U.isInt(netId) and NetworkGetEntityFromNetworkId(netId)
    return entity and entity > 0 and GetVehicleType(entity) == 'trailer' or false
end)

function server.forceOpenInventory(playerId, invType, data)
    local left, right = openInventory(playerId, invType, data, true)
    if left and right then
        TriggerClientEvent('vr-inventory:forceOpenInventory', playerId, left, right)
        return right.id
    end
end

exports('forceOpenInventory', server.forceOpenInventory)

local Licenses = InvData('licenses')

lib.callback.register('vr-inventory:buyLicense', function(source, id)
    local license = U.isInt(id) and Licenses[id]
    if not license then return end
    local inventory = Inventory(source)
    if not inventory then return end
    if license.coords and U.dist(GetEntityCoords(GetPlayerPed(source)), license.coords) > 5 then return end
    if not server.buyLicense then return end
    return server.buyLicense(inventory, license)
end)

local function canPeek(source, target)
    if target == nil or target == source then return Inventory(source) end
    local own = Inventory(source)
    if not own or not own.open or own.open == own.id then return end
    local inv = Inventory(target)
    if inv and inv.id == own.open then return inv end
end

lib.callback.register('vr-inventory:getItemCount', function(source, item, metadata, target)
    local inventory = canPeek(source, target)
    return inventory and Inventory.GetItemCount(inventory, item, metadata, true) or 0
end)

lib.callback.register('vr-inventory:getInventory', function(source, id)
    local inventory = canPeek(source, id)
    if not inventory then return end
    return {
        id = inventory.id,
        label = inventory.label,
        type = inventory.type,
        slots = inventory.slots,
        weight = inventory.weight,
        maxWeight = inventory.maxWeight,
        owned = inventory.owner and true or false,
        items = U.values(inventory.items),
    }
end)

RegisterNetEvent('vr-inventory:usedItemInternal', function(slot)
    local src = source
    local inventory = Inventory(src)
    if not inventory then return end
    local item = inventory.usingItem
    if not item or item.slot ~= slot then return end
    U.fire('usedItem', inventory.id, item.name, item.slot, next(item.metadata or {}) and item.metadata)
    inventory.usingItem = nil
end)

local function notify(source, kind, key, ...)
    lib.notify(source, { type = kind, description = locale(key, ...) })
end

lib.callback.register('vr-inventory:useItem', function(source, itemName, slot, metadata, noAnim)
    local inventory = Inventory(source)
    if not inventory or inventory.usingItem or not inventory.player then return end
    if slot ~= nil and not U.slotIn(slot, inventory.slots) then return end

    local item = Items(itemName)
    local data = item and (slot and inventory.items[slot] or Inventory.GetSlotWithItem(inventory, item.name, metadata, true))
    if not data or data.name ~= item.name then return end

    slot = data.slot
    local durability = data.metadata.durability
    local consume = item.consume
    local label = data.metadata.label or item.label

    if durability and consume then
        if durability > 100 then
            local now = os.time()
            if now > durability then
                Items.UpdateDurability(inventory, data, item, 0)
                return notify(source, 'error', 'no_durability', label)
            elseif consume ~= 0 and consume < 1 then
                local degrade = (data.metadata.degrade or item.degrade or 1) * 60
                local percentage = ((durability - now) * 100) / degrade
                if percentage < consume * 100 then return notify(source, 'error', 'not_enough_durability', label) end
            end
        elseif durability <= 0 then
            return notify(source, 'error', 'no_durability', label)
        elseif consume ~= 0 and consume < 1 and durability < consume * 100 then
            return notify(source, 'error', 'not_enough_durability', label)
        end

        if data.count > 1 and consume < 1 and consume > 0 and not Inventory.GetEmptySlot(inventory) then
            return notify(source, 'error', 'cannot_use', label)
        end
    end

    if data.count < 1 then return end

    local activeSlots <close> = InvLocks({ SlotLock(inventory.id, slot) })
    if not activeSlots then return end

    data = { name = data.name, label = label, count = data.count, slot = slot, metadata = data.metadata, weight = data.weight }

    if item.ammo then
        if inventory.weapon then
            local weapon = inventory.items[inventory.weapon]
            if weapon and (weapon.metadata.durability or 0) > 0 then consume = nil end
        else
            return false
        end
    elseif item.component or item.tint then
        consume = 1
        data.component = true
    elseif consume then
        if data.count >= consume then
            local result = item.cb and item.cb('usingItem', item, inventory, slot)
            if result == false then return end
            if result ~= nil then data.server = result end
        else
            return notify(source, 'error', 'item_not_enough', label)
        end
    elseif not item.weapon and server.UseItem then
        inventory.usingItem = data
        local ok, err = pcall(server.UseItem, source, data.name, data)
        if not ok then print(('^1[vr-inventory] usable item "%s" errored: %s^0'):format(data.name, tostring(err))) end
        return true
    end

    data.consume = consume

    local hooks <close> = TriggerEventHooks('usingItem', {
        source = source,
        inventoryId = inventory.id,
        item = inventory.items[slot],
        consume = consume,
    })
    if not hooks.success then return false end

    local success = lib.callback.await('vr-inventory:usingItem', source, data, noAnim)

    if item.weapon then inventory.weapon = success and slot or nil end
    if not success then hooks.success = false return end

    inventory.usingItem = data

    if consume and consume ~= 0 and not data.component then
        data = inventory.items[data.slot]
        if not data then hooks.success = false return end

        durability = consume ~= 0 and consume < 1 and data.metadata.durability

        if durability then
            if durability > 100 then
                local degrade = (data.metadata.degrade or item.degrade or 1) * 60
                durability = durability - degrade * consume
            else
                durability = durability - consume * 100
            end

            if data.count > 1 then
                local emptySlot = Inventory.GetEmptySlot(inventory)
                if emptySlot then
                    local ok, newItem = Inventory.SetSlot(inventory, item, 1, U.deepclone(data.metadata), emptySlot)
                    if ok and newItem then Items.UpdateDurability(inventory, newItem, item, durability) end
                end
                durability = 0
            else
                Items.UpdateDurability(inventory, data, item, durability)
            end

            if durability <= 0 then durability = false end
        end

        if not durability then
            Inventory.RemoveItem(inventory.id, data.name, consume < 1 and 1 or consume, nil, data.slot)
        else
            inventory.changed = true
            if server.syncInventory then server.syncInventory(inventory) end
        end

        if item.cb then item.cb('usedItem', item, inventory, data.slot) end
    end

    return true
end)

U.netEvent('closeInventory', function()
    local inventory = Inventories[source]
    if inventory and inventory.open then
        local secondary = Inventories[inventory.open]
        if secondary and secondary ~= inventory then secondary:closeInventory() end
        inventory:closeInventory(true)
    end
end)

local stateKeys = { invBusy = true, canSteal = true }
local stateRate = {}

RegisterNetEvent('vr-inventory:state', function(key, value)
    local src = source
    if not stateKeys[key] or type(value) ~= 'boolean' then return end
    local now = GetGameTimer()
    local rate = stateRate[src]
    if rate and now - rate.t < 1000 then
        rate.n = rate.n + 1
        if rate.n > 20 then return end
    else
        stateRate[src] = { t = now, n = 1 }
    end
    local state = Player(src).state
    if state[key] ~= value then state:set(key, value, true) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    stateRate[src] = nil
    server.playerDropped(src)
    if GetNumPlayerIndices() == 0 then Inventory.SaveInventories(false, true) end
end)

local isSaving = false

local function saveInventories(clear)
    if isSaving then return end
    isSaving = true

    local now = os.time()
    local players, trunks, gloveboxes, stashes = {}, {}, {}, {}

    for _, inv in pairs(Inventories) do
        for _, v in pairs(inv.items) do Items.UpdateDurability(inv, v, Items(v.name), nil, now) end

        if not inv.datastore and inv.changed then
            local buffer = {}
            for slot, v in pairs(inv.items) do
                buffer[#buffer + 1] = { name = v.name, count = v.count, slot = slot, metadata = next(v.metadata) and v.metadata or nil }
            end
            table.sort(buffer, function(a, b) return a.slot < b.slot end)
            local data = next(buffer) and json.encode(buffer) or nil
            inv.changed = false

            if inv.player then
                if server.savePlayers ~= false then players[#players + 1] = { data, inv.owner } end
            elseif inv.type == 'trunk' then
                trunks[#trunks + 1] = { data, inv.dbId }
            elseif inv.type == 'glovebox' then
                gloveboxes[#gloveboxes + 1] = { data, inv.dbId }
            else
                stashes[#stashes + 1] = { data, inv.owner and tostring(inv.owner) or '', inv.dbId }
            end
        end
    end

    local total = #players + #trunks + #gloveboxes + #stashes
    if total > 0 then
        local ok, err = pcall(db.saveMany, players, trunks, gloveboxes, stashes)
        if not ok then print(('^1[vr-inventory] save failed: %s^0'):format(tostring(err))) end
        if server.loglevel > 1 then print(('[vr-inventory] saved %s inventories'):format(total)) end
    end

    isSaving = false
    if not clear then return end

    for _, inv in pairs(Inventories) do
        if not inv.open and not inv.player then
            if inv.type == 'glovebox' or inv.type == 'trunk' then
                if not inv.netid or NetworkGetEntityFromNetworkId(inv.netid) ~= inv.entityId then Inventory.Remove(inv) end
            elseif inv.type ~= 'drop' and now - inv.time >= server.cleartime then
                Inventory.Remove(inv)
            end
        end
    end
end

function Inventory.SaveInventories(lock, clear)
    Inventory.Lock = lock or nil
    Inventory.CloseAll()
    saveInventories(clear)
end

CreateThread(function()
    while true do
        Wait(300000)
        saveInventories(true)
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function() Inventory.SaveInventories(true, false) end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if type(eventData) == 'table' and eventData.secondsRemaining == 60 then Inventory.SaveInventories(true, true) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == shared.resource then Inventory.SaveInventories(true, false) end
end)

lib.addCommand({ 'additem', 'giveitem' }, {
    help = 'Give an item to a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id' },
        { name = 'item', type = 'string', help = 'Item name' },
        { name = 'count', type = 'number', help = 'Amount', optional = true },
        { name = 'type', help = 'Sets the "type" metadata', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local item = Items(args.item)
    if not item then return end
    local inventory = Inventory(args.target)
    if not inventory then return end
    local count = args.count and math.max(args.count, 1) or 1
    local ok, response = Inventory.AddItem(inventory, item.name, count, args.type and { type = tonumber(args.type) or args.type })
    if not ok then return print(('[vr-inventory] could not give %sx %s to player %s (%s)'):format(count, item.name, args.target, tostring(response))) end
    local actor = Inventory(source) or { label = 'console', owner = 'console' }
    InvLog(actor.owner, 'admin', ('"%s" gave %sx %s to "%s"'):format(actor.label, count, item.name, inventory.label))
end)

lib.addCommand('removeitem', {
    help = 'Remove an item from a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id' },
        { name = 'item', type = 'string', help = 'Item name' },
        { name = 'count', type = 'number', help = 'Amount', optional = true },
        { name = 'type', help = 'Only remove items with this "type" metadata', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local item = Items(args.item)
    if not item then return end
    local inventory = Inventory(args.target)
    if not inventory then return end
    local count = args.count and math.max(args.count, 1) or 1
    local ok, response = Inventory.RemoveItem(inventory, item.name, count, args.type and { type = tonumber(args.type) or args.type }, nil, true)
    if not ok then return print(('[vr-inventory] could not remove %sx %s from player %s (%s)'):format(count, item.name, args.target, tostring(response))) end
    local actor = Inventory(source) or { label = 'console', owner = 'console' }
    InvLog(actor.owner, 'admin', ('"%s" removed %sx %s from "%s"'):format(actor.label, count, item.name, inventory.label))
end)

lib.addCommand('setitem', {
    help = 'Set how many of an item a player has',
    params = {
        { name = 'target', type = 'playerId', help = 'Player id' },
        { name = 'item', type = 'string', help = 'Item name' },
        { name = 'count', type = 'number', help = 'Amount', optional = true },
        { name = 'type', help = 'Only count items with this "type" metadata', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local item = Items(args.item)
    if not item then return end
    local inventory = Inventory(args.target)
    if not inventory then return end
    local count = args.count and math.max(args.count, 0) or 0
    local ok, response = Inventory.SetItem(inventory, item.name, count, args.type and { type = tonumber(args.type) or args.type })
    if not ok then return print(('[vr-inventory] could not set %s to %sx for player %s (%s)'):format(item.name, count, args.target, tostring(response))) end
    local actor = Inventory(source) or { label = 'console', owner = 'console' }
    InvLog(actor.owner, 'admin', ('"%s" set "%s" %s count to %sx'):format(actor.label, inventory.label, item.name, count))
end)

lib.addCommand('clearevidence', {
    help = 'Clear a police evidence locker',
    params = { { name = 'locker', type = 'number', help = 'Locker number' } },
}, function(source, args)
    if not server.isPlayerBoss then return end
    local inventory = Inventory(source)
    if not inventory then return end
    local group, grade = server.hasGroup(inventory, shared.police)
    if not group or not server.isPlayerBoss(source, group, grade) then return end
    local id = ('evidence-%s'):format(math.floor(args.locker))
    local loaded = Inventories[id]
    if loaded then Inventory.Clear(loaded) end
    db.deleteStash('', id)
end)

lib.addCommand('takeinv', {
    help = 'Confiscate a player inventory (restore with /restoreinv)',
    params = { { name = 'target', type = 'playerId', help = 'Player id' } },
    restricted = 'group.admin',
}, function(_, args) Inventory.Confiscate(args.target) end)

lib.addCommand({ 'restoreinv', 'returninv' }, {
    help = 'Restore a confiscated player inventory',
    params = { { name = 'target', type = 'playerId', help = 'Player id' } },
    restricted = 'group.admin',
}, function(_, args) Inventory.Return(args.target) end)

lib.addCommand('clearinv', {
    help = 'Wipe every item from an inventory',
    params = { { name = 'invId', help = 'Inventory id, player id or "me"' } },
    restricted = 'group.admin',
}, function(source, args)
    Inventory.Clear(tonumber(args.invId) or (args.invId == 'me' and source) or args.invId)
end)

lib.addCommand('saveinv', {
    help = 'Save every pending inventory change',
    params = { { name = 'lock', help = 'Lock inventories until a restart or an unlocked save', optional = true } },
    restricted = 'group.admin',
}, function(_, args) Inventory.SaveInventories(args.lock == 'true', false) end)

lib.addCommand('viewinv', {
    help = 'Look inside an inventory without touching it',
    params = { { name = 'invId', help = 'Inventory id or player id' } },
    restricted = 'group.admin',
}, function(source, args)
    Inventory.InspectInventory(source, tonumber(args.invId) or args.invId)
end)

CreateThread(function()
    db.setup()
    shared.ready = true
    U.fire('itemList', ItemList)
    U.fire('loadInventory', Inventory)
    local count = 0
    for _ in pairs(ItemList) do count = count + 1 end
    print(('[vr-inventory] loaded %d items'):format(count))
end)
