local U = InvUtil

local currentWeapon
local StashTarget
local invBusy = true
local invOpen = false
local invHotkeys = false
local usingItem = false
local currentInstance
local playerPed = cache.ped
local IsPedCuffed = IsPedCuffed
local relayed = {}

local function setState(key, value)
    if key == 'invOpen' then invOpen = value
    elseif key == 'invHotkeys' then invHotkeys = value
    elseif key == 'invBusy' then invBusy = value end
    LocalPlayer.state:set(key, value, false)
    if (key == 'invBusy' or key == 'canSteal') and relayed[key] ~= value then
        relayed[key] = value
        TriggerServerEvent('vr-inventory:state', key, value == true)
    end
end

exports('getCurrentWeapon', function() return currentWeapon end)

U.netEvent('disarm', function(noAnim)
    currentWeapon = Weapon.Disarm(currentWeapon, noAnim)
end)

U.netEvent('clearWeapons', function()
    Weapon.ClearAll(currentWeapon)
    currentWeapon = nil
end)

exports('setStashTarget', function(id, owner)
    StashTarget = id and { id = id, owner = owner } or nil
end)

lib.onCache('ped', function(ped)
    playerPed = ped
    Utils.WeaponWheel()
end)

setState('invBusy', true)
setState('invHotkeys', false)
setState('canUseWeapons', false)

function client.hasGroup(group)
    if not PlayerData.loaded or not PlayerData.groups then return end
    if type(group) == 'table' then
        for name, required in pairs(group) do
            if type(name) == 'number' then name, required = required, 0 end
            local rank = PlayerData.groups[name]
            if rank then
                if type(required) == 'table' then
                    if U.inArray(required, rank) then return name, rank end
                elseif rank >= (required or 0) then
                    return name, rank
                end
            end
        end
    elseif group then
        local rank = PlayerData.groups[group]
        if rank then return group, rank end
    end
end

local function onPlayerData(key, value)
    if key == 'groups' then
        Inventory.Stashes()
        Inventory.Evidence()
        Shops.refresh()
    elseif key == 'dead' and value then
        currentWeapon = Weapon.Disarm(currentWeapon)
        client.closeInventory()
    end
    if key == 'groups' or key == 'dead' or key == 'ped' then Utils.WeaponWheel() end
end

function client.setPlayerData(key, value)
    PlayerData[key] = value
    onPlayerData(key, value)
end

local function canOpenInventory()
    if not PlayerData.loaded then return false end
    if IsPauseMenuActive() or invOpen == nil then return false end
    if invBusy or (currentWeapon and (currentWeapon.timer or 0) > 0) then return false end
    if PlayerData.dead or IsPedFatallyInjured(playerPed) then return false end
    if PlayerData.cuffed or IsPedCuffed(playerPed) then return false end
    return true
end

local function canOpenTarget(ped)
    return IsPedFatallyInjured(ped)
        or IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3)
        or IsPedCuffed(ped)
        or IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)
        or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
        or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_enter', 3)
        or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

local defaultInventory = {
    type = 'newdrop',
    slots = shared.dropslots,
    weight = 0,
    maxWeight = shared.dropweight,
    items = {},
}

local currentInventory = defaultInventory

local function closeTrunk()
    if currentInventory.type ~= 'trunk' then return end
    local coords = GetEntityCoords(playerPed, true)
    Utils.PlayAnimAdvanced(0, 'anim@heists@fleeca_bank@scope_out@return_case', 'trevor_action', coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(playerPed), 2.0, 2.0, 1000, 49, 0.25)
    local entity, door = currentInventory.entity, currentInventory.door
    CreateThread(function()
        Wait(900)
        if not entity then return end
        if type(door) == 'table' then
            for i = 1, #door do SetVehicleDoorShut(entity, door[i], false) end
        elseif door then
            SetVehicleDoorShut(entity, door, false)
        end
    end)
end

local function playerSummary(left)
    left.items = U.values(PlayerData.inventory)
    left.groups = PlayerData.groups
    left.id = 'player'
    return left
end

local function rightSummary(right)
    if not right then return nil end
    local copy = {}
    for k, v in pairs(right) do
        if k ~= 'entity' then copy[k] = v end
    end
    if type(copy.items) == 'table' and U.tableType(copy.items) ~= 'array' then copy.items = U.values(copy.items) end
    return copy
end

local function showInventory(left, right)
    setState('invOpen', true)
    SetInterval(client.interval, 100)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    closeTrunk()
    if client.screenblur then Utils.blurIn() end

    currentInventory = right or defaultInventory

    SendNUIMessage({
        action = 'open',
        data = { left = playerSummary(left), right = rightSummary(currentInventory) },
    })
end

function client.openInventory(inv, data)
    if invOpen == nil then return end

    if invOpen then
        if not inv and currentInventory.type == 'newdrop' then return client.closeInventory() end

        if IsNuiFocused() then
            if inv == 'container' and PlayerData.inventory[data] and currentInventory.id == PlayerData.inventory[data].metadata.container then
                return client.closeInventory()
            end

            if currentInventory.type == 'drop' and (not data or currentInventory.id == (type(data) == 'table' and data.id or data)) then
                return client.closeInventory()
            end

            if inv ~= 'drop' and inv ~= 'container' then
                if (type(data) == 'table' and data.id or data) == currentInventory.id then return end
                return client.closeInventory()
            end
        end
    elseif IsNuiFocused() then
        Wait(100)
    end

    if inv == 'dumpster' and cache.vehicle then
        return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
    end

    if not canOpenInventory() then
        return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
    end

    local left, right, accessError

    if inv == 'player' and data ~= cache.serverId then
        local targetId, targetPed, serverId

        if not data then
            targetId, targetPed = Utils.GetClosestPlayer()
            serverId = targetId and GetPlayerServerId(targetId)
            data = serverId
        else
            serverId = type(data) == 'table' and data.id or data
            targetId = serverId and GetPlayerFromServerId(serverId)
            targetPed = targetId and GetPlayerPed(targetId)
        end

        if not serverId or serverId == cache.serverId then return end

        local targetCoords = targetPed and targetPed ~= 0 and GetEntityCoords(targetPed)
        local state = Player(serverId).state
        local stealable = state.canSteal or state.isDead or state.dead or state.isHandcuffed

        if not targetCoords or #(targetCoords - GetEntityCoords(playerPed)) > 1.8 or (not client.hasGroup(shared.police) and not stealable) then
            return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
        end
    end

    if inv == 'shop' and invOpen == false then
        if cache.vehicle then return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') }) end
        left, right, accessError = lib.callback.await('vr-inventory:openShop', 200, data)
    elseif inv == 'crafting' then
        if cache.vehicle then return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') }) end
        left, right, accessError = lib.callback.await('vr-inventory:openCraftingBench', 200, data.id, data.index)

        if left then
            local bench = CraftingBenches[data.id]
            if not bench or not bench.items then return end

            local coords, distance
            if not bench.zones and not bench.points then
                coords = GetEntityCoords(cache.ped)
                distance = 2
            else
                coords = shared.target and bench.zones and bench.zones[data.index].coords or bench.points and bench.points[data.index]
                distance = coords and shared.target and bench.zones and bench.zones[data.index].distance or 2
            end

            right = {
                type = 'crafting',
                id = data.id,
                label = bench.label or locale('crafting_bench'),
                index = data.index,
                slots = bench.slots,
                items = bench.items,
                coords = coords,
                distance = distance,
            }
        end
    elseif invOpen ~= nil then
        if inv == 'policeevidence' and not data then
            local input = lib.inputDialog(locale('police_evidence'), {
                { label = locale('locker_number'), type = 'number', required = true, icon = 'hashtag', min = 0 },
            })
            if not input or not input[1] then return end
            data = input[1]
        end

        local payload = data
        if type(data) == 'table' and data.entity then
            payload = {}
            for k, v in pairs(data) do if k ~= 'entity' then payload[k] = v end end
        end

        left, right, accessError = lib.callback.await('vr-inventory:openInventory', false, inv, payload)
    end

    if accessError then return lib.notify({ id = accessError, type = 'error', description = locale(accessError) }) end

    if not left then
        if left == false then return false end
        if invOpen == false then return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') }) end
        if invOpen then return client.closeInventory() end
        return
    end

    if not cache.vehicle then
        if inv == 'player' then
            Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 8.0, 1.0, 2000, 50, 0.0, 0, 0, 0)
        elseif inv ~= 'trunk' then
            Utils.PlayAnim(0, 'pickup_object', 'putdown_low', 5.0, 1.5, 1000, 48, 0.0, 0, 0, 0)
        end
    end

    showInventory(left, right)

    if inv and not currentInventory.coords and inv ~= 'container' and inv ~= 'glovebox' then
        currentInventory.coords = GetEntityCoords(playerPed)
    end

    if inv == 'trunk' then
        SetTimeout(200, function()
            Utils.PlayAnim(0, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 3.0, 3.0, -1, 49, 0.0, 0, 0, 0)

            local entity = data.entity or NetworkGetEntityFromNetworkId(data.netid)
            currentInventory.entity = entity
            currentInventory.door = data.door

            if not currentInventory.door then
                local model = GetEntityModel(entity)
                currentInventory.door = GetVehicleClass(entity) == 12 and { 2, 3 } or (Inventory.Vehicles.Storage and Inventory.Vehicles.Storage[model]) and 4 or 5
            end

            while currentInventory.entity == entity and invOpen and DoesEntityExist(entity) and Inventory.CanAccessTrunk(entity) do Wait(100) end

            if invOpen and currentInventory.entity == entity then client.closeInventory() end
        end)
    end

    return true
end

U.netEvent('openInventory', function(inv, data)
    client.openInventory(inv, data)
end)
exports('openInventory', client.openInventory)

RegisterNetEvent('vr-inventory:forceOpenInventory', function(left, right)
    if source == '' then return end
    if not PlayerData.loaded then return end
    right = right or defaultInventory
    right.ignoreSecurityChecks = true
    showInventory(left, right)
end)

RegisterNetEvent('vr-inventory:viewInventory', function(left, right)
    if source == '' then return end
    if not PlayerData.loaded then return end
    right = right or defaultInventory
    right.ignoreSecurityChecks = true
    right.type = 'inspect'
    showInventory(left, right)
end)

local Animations = InvData('animations')
Animations.anim = Animations.anim or {}
Animations.prop = Animations.prop or {}

lib.callback.register('vr-inventory:usingItem', function(data, noAnim)
    local item = type(data) == 'table' and ItemList[data.name]
    if not item or not usingItem then return end
    if not item.client then return true end

    local cl = item.client
    if type(cl.anim) == 'string' then cl.anim = Animations.anim[cl.anim] end

    if cl.prop then
        if type(cl.prop) == 'string' then
            cl.prop = Animations.prop[cl.prop]
        elseif cl.prop[1] then
            for i = 1, #cl.prop do
                if type(cl.prop[i]) == 'string' then cl.prop[i] = Animations.prop[cl.prop[i]] end
            end
        end
    end

    if not cl.disable then
        cl.disable = { combat = true }
    elseif cl.disable.combat == nil then
        cl.disable.combat = true
    end

    local label = (data.metadata and data.metadata.label) or data.label or item.label
    local success = (not cl.usetime or noAnim or lib.progressBar({
        duration = cl.usetime,
        label = cl.label or locale('using', label),
        useWhileDead = cl.useWhileDead,
        canCancel = cl.cancel,
        disable = cl.disable,
        anim = cl.anim or cl.scenario,
        prop = cl.prop,
    })) and not PlayerData.dead

    if success then
        if cl.notification then lib.notify({ description = cl.notification }) end
        if cl.status and client.setPlayerStatus then client.setPlayerStatus(cl.status) end
        return true
    end
end)

local function canUseItem(isAmmo)
    local ped = cache.ped
    return not usingItem
        and (not isAmmo or currentWeapon)
        and PlayerData.loaded
        and not PlayerData.dead
        and not invBusy
        and not lib.progressActive()
        and not IsPedRagdoll(ped)
        and not IsPedFalling(ped)
        and not IsPedShooting(playerPed)
end

local function useItem(data, cb, noAnim)
    local slotData = PlayerData.inventory[data.slot]

    if not slotData or not canUseItem(data.ammo and true) then
        if currentWeapon then return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') }) end
        return
    end

    if currentWeapon and currentWeapon.timer ~= 0 then
        if not currentWeapon.timer or currentWeapon.timer - GetGameTimer() > 100 then return end
        DisablePlayerFiring(cache.playerId, true)
    end

    if invOpen and data.close then client.closeInventory() end

    usingItem = true
    local result = lib.callback.await('vr-inventory:useItem', 200, data.name, data.slot, slotData.metadata, noAnim)

    if result and cb then
        local ok, err = pcall(cb, result and slotData)
        if not ok and err then print(('^1[vr-inventory] item "%s" callback errored: %s^0'):format(slotData.name, tostring(err))) end
    end

    if result then
        U.fire('usedItem', slotData.name, slotData.slot, next(slotData.metadata or {}) and slotData.metadata)
        TriggerServerEvent('vr-inventory:usedItemInternal', slotData.slot)
    end

    Wait(500)
    usingItem = false
end

InvUseItem = useItem
U.localEvent('item', useItem)
exports('useItem', useItem)

local function useSlot(slot, noAnim)
    local item = PlayerData.inventory[slot]
    if not item then return end

    local data = ItemList[item.name]
    if not data then return end
    if not canUseItem(data.ammo and true) then return end

    if data.component and not currentWeapon then
        return lib.notify({ id = 'weapon_hand_required', type = 'error', description = locale('weapon_hand_required') })
    end

    local durability = item.metadata.durability
    local consume = data.consume
    local label = item.metadata.label or item.label

    if durability and durability <= 100 and consume then
        if durability <= 0 then
            return lib.notify({ type = 'error', description = locale('no_durability', label) })
        elseif consume ~= 0 and consume < 1 and durability < consume * 100 then
            return lib.notify({ type = 'error', description = locale('not_enough_durability', label) })
        end
    end

    data.slot = slot

    if item.metadata.container then
        return client.openInventory('container', item.slot)
    elseif data.client then
        if invOpen and data.close then client.closeInventory() end
        if data.export then
            return data.export(data, { name = item.name, slot = item.slot, metadata = item.metadata })
        elseif data.client.event then
            return TriggerEvent(data.client.event, data, { name = item.name, slot = item.slot, metadata = item.metadata })
        end
    end

    if data.effect then
        data:effect({ name = item.name, slot = item.slot, metadata = item.metadata })
    elseif data.weapon then
        if WeaponWheelEnabled or not LocalPlayer.state.canUseWeapons then return end
        if IsCinematicCamRendering() then SetCinematicModeActive(false) end

        if currentWeapon then
            if not currentWeapon.timer or currentWeapon.timer ~= 0 then return end
            local weaponSlot = currentWeapon.slot
            currentWeapon = Weapon.Disarm(currentWeapon)
            if weaponSlot == data.slot then return end
        end

        GiveWeaponToPed(playerPed, data.hash, 0, false, true)
        SetCurrentPedWeapon(playerPed, data.hash, false)

        if data.hash ~= GetSelectedPedWeapon(playerPed) then
            return lib.notify({ type = 'error', description = locale('cannot_use', data.label) })
        end

        RemoveWeaponFromPed(cache.ped, data.hash)

        useItem(data, function(result)
            if result then
                local sleep
                currentWeapon, sleep = Weapon.Equip(item, data, noAnim)
                if sleep then Wait(sleep) end
            end
        end, noAnim)
    elseif currentWeapon then
        if data.ammo then
            if WeaponWheelEnabled or (currentWeapon.metadata.durability or 0) <= 0 then return end

            local clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
            local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
            local _, maxAmmo = GetMaxAmmo(playerPed, currentWeapon.hash)
            if maxAmmo < clipSize then clipSize = maxAmmo end
            if currentAmmo == clipSize then return end

            useItem(data, function(resp)
                if not resp or not currentWeapon or resp.name ~= currentWeapon.ammo then return end

                local weaponItem = ItemList[currentWeapon.name]
                if currentWeapon.metadata.specialAmmo ~= resp.metadata.type and type(currentWeapon.metadata.specialAmmo) == 'string' or type(resp.metadata.type) == 'string' then
                    local clipKey = ('%s_CLIP'):format(weaponItem.model:gsub('WEAPON_', 'COMPONENT_'))
                    local special = ('%s_%s'):format(clipKey, tostring(resp.metadata.type or currentWeapon.metadata.specialAmmo):upper())
                    local specialHash = joaat(special)

                    if type(resp.metadata.type) == 'string' then
                        if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialHash) then
                            if not DoesWeaponTakeWeaponComponent(currentWeapon.hash, specialHash) then return end
                            if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, joaat(('%s_01'):format(clipKey))) then return end
                            if currentAmmo > 0 then return end
                            currentWeapon.metadata.specialAmmo = resp.metadata.type
                            GiveWeaponComponentToPed(playerPed, currentWeapon.hash, specialHash)
                        end
                    elseif HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialHash) then
                        if currentAmmo > 0 then return end
                        currentWeapon.metadata.specialAmmo = nil
                        RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, specialHash)
                    end
                end

                if maxAmmo > clipSize then clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true) end

                currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
                local missing = clipSize - currentAmmo
                local add = resp.count > missing and missing or resp.count
                local newAmmo = currentAmmo + add
                if newAmmo == currentAmmo then return end

                AddAmmoToPed(playerPed, currentWeapon.hash, add)

                if cache.vehicle then
                    if cache.seat > -1 or IsVehicleStopped(cache.vehicle) then
                        TaskReloadWeapon(playerPed, true)
                    else
                        lib.waitFor(function()
                            RefillAmmoInstantly(playerPed)
                            local _, ammo = GetAmmoInClip(playerPed, currentWeapon.hash)
                            return ammo == newAmmo or nil
                        end, nil, 2000)
                    end
                else
                    Wait(100)
                    MakePedReload(playerPed)
                    SetTimeout(100, function()
                        while IsPedReloading(playerPed) do
                            DisableControlAction(0, 22, true)
                            Wait(0)
                        end
                    end)
                end

                lib.callback.await('vr-inventory:updateWeapon', false, 'load', newAmmo, false, currentWeapon.metadata.specialAmmo)
            end)
        elseif data.component then
            local components = data.client and data.client.component
            if not components then return end

            local componentType = data.type
            local weaponComponents = PlayerData.inventory[currentWeapon.slot] and PlayerData.inventory[currentWeapon.slot].metadata.components or {}

            for i = 1, #weaponComponents do
                local existing = ItemList[weaponComponents[i]]
                if existing and componentType == existing.type then
                    return lib.notify({ id = 'component_slot_occupied', type = 'error', description = locale('component_slot_occupied', componentType) })
                end
            end

            for i = 1, #components do
                local component = components[i]
                if DoesWeaponTakeWeaponComponent(currentWeapon.hash, component) then
                    if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
                        lib.notify({ id = 'component_has', type = 'error', description = locale('component_has', label) })
                    else
                        useItem(data, function(result)
                            if result then
                                local ok = lib.callback.await('vr-inventory:updateWeapon', false, 'component', tostring(result.slot), currentWeapon.slot)
                                if ok then
                                    GiveWeaponComponentToPed(playerPed, currentWeapon.hash, component)
                                    U.fire('updateWeaponComponent', 'added', component, result.name)
                                end
                            end
                        end)
                    end
                    return
                end
            end

            lib.notify({ id = 'component_invalid', type = 'error', description = locale('component_invalid', label) })
        elseif data.allowArmed then
            useItem(data)
        else
            return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
        end
    elseif not data.ammo and not data.component then
        useItem(data)
    end
end

exports('useSlot', useSlot)

local function useButton(id, slot)
    if not PlayerData.loaded or invBusy or lib.progressActive() then return end
    local item = PlayerData.inventory[slot]
    if not item then return end
    local data = ItemList[item.name]
    local buttons = data and data.buttons
    if buttons and buttons[id] and buttons[id].action then buttons[id].action(slot) end
end

local function openNearbyInventory() client.openInventory('player') end
exports('openNearbyInventory', openNearbyInventory)

local function openGlovebox(vehicle)
    if not IsPedInAnyVehicle(playerPed, false) or not NetworkGetEntityIsNetworked(vehicle) then return end
    if IsEntityDead(vehicle) then return end

    local model = GetEntityModel(vehicle)
    local class = GetVehicleClass(vehicle)
    local storage = Inventory.Vehicles.Storage and Inventory.Vehicles.Storage[model]
    local glove = Inventory.Vehicles.glovebox or {}

    if storage == 0 or storage == 2 or (not glove[class] and not (glove.models and glove.models[model])) then return end

    if client.openInventory('glovebox', { netid = NetworkGetNetworkIdFromEntity(vehicle) }) then
        currentInventory.entity = vehicle
    end
end

local function canOpenGlovebox()
    if not cache.vehicle then return false end
    if not client.gloveboxseatrestriction then return true end
    return cache.seat == -1 or cache.seat == 0
end

local registerCommands

registerCommands = function()
    if client.enablestealcommand then RegisterCommand('steal', openNearbyInventory, false) end

    local primary = lib.addKeybind({
        name = 'inv',
        description = locale('open_player_inventory'),
        defaultKey = client.keys[1],
        onPressed = function()
            if invOpen then return client.closeInventory() end
            if canOpenGlovebox() then return openGlovebox(cache.vehicle) end

            local closest = lib.points.getClosestPoint()
            if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
                if closest.inv == 'crafting' then
                    return client.openInventory('crafting', { id = closest.benchid or closest.id, index = closest.index })
                elseif closest.inv and closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
                    return client.openInventory(closest.inv, { id = closest.invId, type = closest.type })
                elseif not closest.inv and closest.invId then
                    return client.openInventory('drop', { id = closest.invId })
                end
            end

            return client.openInventory()
        end,
    })

    lib.addKeybind({
        name = 'inv2',
        description = locale('open_secondary_inventory'),
        defaultKey = client.keys[2],
        onPressed = function(self)
            if primary:getCurrentKey() == self:getCurrentKey() then return end
            if invOpen then return client.closeInventory() end

            if invBusy or not canOpenInventory() then
                return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
            end

            if StashTarget then return client.openInventory('stash', StashTarget) end
            if canOpenGlovebox() then return openGlovebox(cache.vehicle) end

            local entity, entityType = Utils.Raycast(2 | 16)
            if not entity then return end

            if not shared.target and entityType == 3 and Inventory.IsDumpster(GetEntityModel(entity)) then
                return Inventory.OpenDumpster(entity)
            end

            if entityType ~= 2 then return end
            Inventory.OpenTrunk(entity)
        end,
    })

    lib.addKeybind({
        name = 'reloadweapon',
        description = locale('reload_weapon'),
        defaultKey = 'r',
        onPressed = function()
            if not currentWeapon or WeaponWheelEnabled or not canUseItem(true) then return end
            if not currentWeapon.ammo then return end
            if (currentWeapon.metadata.durability or 0) > 0 then
                local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)
                if slotId then useSlot(slotId) end
            else
                lib.notify({ id = 'no_durability', type = 'error', description = locale('no_durability', currentWeapon.label) })
            end
        end,
    })

    lib.addKeybind({
        name = 'hotbar',
        description = locale('disable_hotbar'),
        defaultKey = client.keys[3],
        onPressed = function()
            if WeaponWheelEnabled or not invHotkeys or IsNuiFocused() or lib.progressActive() then return end
            SendNUIMessage({ action = 'hotbar' })
        end,
    })

    for i = 1, 5 do
        lib.addKeybind({
            name = ('hotkey%s'):format(i),
            description = locale('use_hotbar', i),
            defaultKey = tostring(i),
            onPressed = function()
                if invOpen or WeaponWheelEnabled or not invHotkeys or IsNuiFocused() then return end
                useSlot(i)
            end,
        })
    end

    registerCommands = nil
end

function client.closeInventory()
    if not client.interval then return end
    if not invOpen then return end

    invOpen = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Utils.blurOut()
    closeTrunk()
    SendNUIMessage({ action = 'close' })
    SetInterval(client.interval, 200)
    Wait(200)

    if invOpen ~= nil then return end

    TriggerServerEvent('vr-inventory:closeInventory')
    currentInventory = defaultInventory
    invOpen = false
    setState('invOpen', false)
    defaultInventory.coords = nil
end

U.netEvent('closeInventory', function() client.closeInventory() end)
exports('closeInventory', function() client.closeInventory() end)

local function updateInventory(data, weight)
    local changes, itemCount = {}, {}
    local nui = {}

    for i = 1, #data do
        local v = data[i]
        local item = v.item

        if item and (not v.inventory or v.inventory == cache.serverId or v.inventory == 'player') then
            v.inventory = 'player'

            if currentWeapon and currentWeapon.slot == item.slot then
                if item.metadata and item.name == currentWeapon.name then
                    currentWeapon.metadata = item.metadata
                    U.fire('currentWeapon', currentWeapon)
                else
                    currentWeapon = Weapon.Disarm(currentWeapon, true)
                end
            end

            local current = PlayerData.inventory[item.slot]
            if current and current.name then itemCount[current.name] = (itemCount[current.name] or 0) - current.count end
            if item.count then itemCount[item.name] = (itemCount[item.name] or 0) + item.count end

            changes[item.slot] = item.count and item or false
            if not item.count then item.name = nil end
            PlayerData.inventory[item.slot] = item.name and item or nil
        end

        nui[#nui + 1] = v
    end

    SendNUIMessage({ action = 'slots', data = { items = nui, itemCount = itemCount, weight = weight } })

    if weight and weight ~= PlayerData.weight then client.setPlayerData('weight', weight) end

    for name, count in pairs(itemCount) do
        local item = ItemList[name]
        if item and count ~= 0 then
            item.count = (item.count or 0) + count
            U.fire('itemCount', item.name, item.count)
            if count < 0 then
                if item.client and item.client.remove then pcall(item.client.remove, item.count) end
            else
                if item.client and item.client.add then pcall(item.client.add, item.count) end
            end
        end
    end

    client.setPlayerData('inventory', PlayerData.inventory)
    U.fire('updateInventory', changes)
end

RegisterNetEvent('vr-inventory:updateSlots', function(items, weight)
    if source == '' or type(items) ~= 'table' or not next(items) then return end
    if not PlayerData.inventory then return end
    for i = 1, #items do
        if items[i].inventory == cache.serverId then items[i].inventory = 'player' end
    end
    updateInventory(items, weight)
end)

RegisterNetEvent('vr-inventory:inventoryReturned', function(items, weight)
    if source == '' then return end
    if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end
    lib.notify({ description = locale('items_returned') })
    client.closeInventory()

    local list = {}
    for slot in pairs(PlayerData.inventory) do list[#list + 1] = { item = { slot = slot }, inventory = 'player' } end
    if #list > 0 then updateInventory(list, 0) end

    list = {}
    for _, slotData in pairs(items or {}) do list[#list + 1] = { item = slotData, inventory = 'player' } end
    updateInventory(list, weight or 0)
end)

RegisterNetEvent('vr-inventory:inventoryConfiscated', function(message)
    if source == '' then return end
    if message then lib.notify({ description = locale('items_confiscated') }) end
    if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end
    client.closeInventory()

    local list = {}
    for slot in pairs(PlayerData.inventory) do list[#list + 1] = { item = { slot = slot }, inventory = 'player' } end
    updateInventory(list, 0)
end)

local function nearbyDrop(point)
    if point.instance and point.instance ~= currentInstance then return end
    local m = client.dropmarker
    DrawMarker(m.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.scale[1], m.scale[2], m.scale[3], m.colour[1], m.colour[2], m.colour[3], 222, false, false, 0, true, false, false, false)
end

local function onEnterDrop(point)
    if point.instance and point.instance ~= currentInstance then return end
    if point.entity then return end
    local model = point.model or client.dropmodel
    if not IsModelValid(model) and not IsModelInCdimage(model) then model = client.dropmodel end
    lib.requestModel(model)
    local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, true)
    point.entity = entity
end

local function onExitDrop(point)
    if point.entity then
        Utils.DeleteEntity(point.entity)
        point.entity = nil
    end
end

local function createDrop(dropId, data)
    local point = lib.points.new({
        coords = data.coords,
        distance = 16,
        invId = dropId,
        instance = data.instance,
        model = data.model,
    })

    if point.model or client.dropprops then
        point.distance = 30
        point.onEnter = onEnterDrop
        point.onExit = onExitDrop
    else
        point.nearby = nearbyDrop
    end

    client.drops[dropId] = point
end

RegisterNetEvent('vr-inventory:createDrop', function(dropId, data, owner, slot)
    if source == '' then return end
    if client.drops then createDrop(dropId, data) end

    if owner == cache.serverId then
        if currentWeapon and currentWeapon.slot == slot then currentWeapon = Weapon.Disarm(currentWeapon) end

        if invOpen and #(GetEntityCoords(playerPed) - data.coords) <= 1 then
            if not cache.vehicle then
                client.openInventory('drop', dropId)
            else
                SendNUIMessage({ action = 'open', data = { right = rightSummary(currentInventory) } })
            end
        end
    end
end)

RegisterNetEvent('vr-inventory:removeDrop', function(dropId)
    if source == '' or not client.drops then return end
    local point = client.drops[dropId]
    if point then
        client.drops[dropId] = nil
        point:remove()
        if point.entity then Utils.DeleteEntity(point.entity) end
    end
end)

local stateHandlers

local function setStateBagHandlers(bag)
    stateHandlers = {
        AddStateBagChangeHandler('invOpen', bag, function(_, _, value) invOpen = value end),
        AddStateBagChangeHandler('invBusy', bag, function(_, _, value)
            invBusy = value
            if relayed.invBusy ~= (value == true) and value ~= 1 then
                relayed.invBusy = value == true
                TriggerServerEvent('vr-inventory:state', 'invBusy', value == true)
            end
        end),
        AddStateBagChangeHandler('canUseWeapons', bag, function(_, _, value)
            if not value and currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end
        end),
        AddStateBagChangeHandler('instance', bag, function(_, _, value)
            currentInstance = value
            if not client.drops then return end
            for dropId, point in pairs(client.drops) do
                if point.instance then
                    if point.instance ~= value then
                        if point.entity then
                            Utils.DeleteEntity(point.entity)
                            point.entity = nil
                        end
                        point:remove()
                    else
                        createDrop(dropId, point)
                    end
                end
            end
        end),
        AddStateBagChangeHandler('isDead', bag, function(_, _, value)
            client.setPlayerData('dead', value == true)
        end),
        AddStateBagChangeHandler('dead', bag, function(_, _, value)
            client.setPlayerData('dead', value == true)
        end),
        AddStateBagChangeHandler('isHandcuffed', bag, function(_, _, value)
            PlayerData.cuffed = value == true
            if value and invOpen then client.closeInventory() end
        end),
        AddStateBagChangeHandler('invHotkeys', bag, function(_, _, value) invHotkeys = value end),
    }
end

RegisterNetEvent('txcl:heal', function()
    if source == '' then return end
    PlayerData.dead = false
end)

lib.onCache('seat', function(seat)
    if seat and GetCurrentPedVehicleWeapon(cache.ped) then return Utils.WeaponWheel(true) end
    Utils.WeaponWheel(false)
end)

lib.onCache('vehicle', function()
    if invOpen and (not currentInventory.entity or currentInventory.entity == cache.vehicle) then
        return client.closeInventory()
    end
end)

local function buildItemData()
    local out = {}
    for name, v in pairs(ItemList) do
        if name == v.name then
            local buttons
            if v.buttons then
                buttons = {}
                for i = 1, #v.buttons do buttons[i] = { label = v.buttons[i].label, group = v.buttons[i].group } end
            end
            out[name] = {
                label = v.label,
                stack = v.stack,
                close = v.close,
                count = v.count or 0,
                description = v.description,
                buttons = buttons,
                ammoName = v.ammoname,
                image = v.client and v.client.image,
                weapon = v.weapon or nil,
                ammo = v.ammo or nil,
                component = v.component or nil,
                weight = v.weight,
            }
        end
    end
    return out
end

local function uiLocales()
    local out = {}
    for k, v in pairs(lib.getLocales()) do
        if k:find('^ui_') then out[k] = v end
    end
    out['$'] = locale('$')
    out.ammo_type = locale('ammo_type')
    return out
end

local licenseText

RegisterNetEvent('vr-inventory:setPlayerInventory', function(currentDrops, inventory, weight, player)
    if source == '' then return end

    PlayerData = player or {}
    PlayerData.id = cache.playerId
    PlayerData.source = cache.serverId
    PlayerData.maxWeight = shared.playerweight
    PlayerData.groups = PlayerData.groups or {}
    PlayerData.dead = LocalPlayer.state.isDead == true or LocalPlayer.state.dead == true
    PlayerData.cuffed = LocalPlayer.state.isHandcuffed == true

    setmetatable(PlayerData, { __index = function(_, key) if key == 'ped' then return PlayerPedId() end end })

    if not stateHandlers then setStateBagHandlers(('player:%s'):format(cache.serverId)) end

    for _, v in pairs(ItemList) do v.count = 0 end

    local slots = {}
    for _, data in pairs(inventory or {}) do
        slots[data.slot] = data
        local item = ItemList[data.name]
        if item then item.count = (item.count or 0) + data.count end
    end

    for name, item in pairs(ItemList) do
        if name == item.name and item.client and item.client.add and item.count > 0 then pcall(item.client.add, item.count) end
    end

    local phone = ItemList.phone
    if phone and phone.count < 1 and phone.client and phone.client.remove then pcall(phone.client.remove, 0) end

    PlayerData.inventory = slots
    PlayerData.weight = weight or 0
    currentWeapon = nil
    Weapon.ClearAll()

    client.drops = {}
    for dropId, data in pairs(currentDrops or {}) do createDrop(dropId, data) end

    local licensePoint
    local function nearbyLicense(point)
        DrawMarker(2, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 245, 165, 36, 222, false, false, 0, true, false, false, false)
        if point.isClosest and point.currentDistance < 1.2 then
            if licensePoint ~= point then
                licensePoint = point
                lib.showTextUI(point.message, { icon = 'fa-id-card' })
            end
            if IsControlJustReleased(0, 38) then
                lib.callback('vr-inventory:buyLicense', 1000, function(success, message)
                    if success ~= nil and message then
                        lib.notify({
                            id = message,
                            type = success == false and 'error' or 'success',
                            description = locale(message, locale('license', point.type:gsub('^%l', string.upper))),
                        })
                    end
                end, point.invId)
            end
        elseif licensePoint == point then
            licensePoint = nil
            lib.hideTextUI()
        end
    end

    if not licenseText then
        licenseText = true
        for id, data in pairs(InvData('licenses')) do
            lib.points.new({
                coords = data.coords,
                distance = 16,
                inv = 'license',
                type = data.name,
                price = data.price,
                invId = id,
                nearby = nearbyLicense,
                message = Utils.prompt(locale('purchase_license', data.name)),
            })
        end
    end

    local started = GetGameTimer()
    while not client.uiLoaded and GetGameTimer() - started < 15000 do Wait(50) end

    SendNUIMessage({
        action = 'init',
        data = {
            locale = uiLocales(),
            items = buildItemData(),
            player = {
                id = 'player',
                slots = shared.playerslots,
                items = U.values(slots),
                weight = PlayerData.weight,
                maxWeight = shared.playerweight,
            },
            imagepath = client.imagepath,
            keys = client.keys,
        },
    })

    InvFlushMetadata()
    PlayerData.loaded = true

    if not client.disablesetupnotification then lib.notify({ type = 'success', description = locale('inventory_setup') }) end

    Shops.refresh()
    Inventory.Stashes()
    Inventory.Evidence()

    if registerCommands then registerCommands() end

    U.fire('updateInventory', PlayerData.inventory)

    if client.interval then ClearInterval(client.interval) end
    if client.tick then ClearInterval(client.tick) end

    client.interval = SetInterval(function()
        local canSteal = canOpenTarget(playerPed) and true or false
        if canSteal ~= (LocalPlayer.state.canSteal == true) then setState('canSteal', canSteal) end

        if invOpen == false then
            if currentWeapon and IsPedUsingActionMode(playerPed) then SetPedUsingActionMode(playerPed, false, -1, 'DEFAULT_ACTION') end
        elseif invOpen == true then
            if not canOpenInventory() then
                client.closeInventory()
            else
                local playerCoords = GetEntityCoords(playerPed)
                if not currentInventory.ignoreSecurityChecks then
                    local maxDistance = (currentInventory.distance or (currentInventory.type == 'stash' and 4.8) or 1.8) + 0.2

                    if currentInventory.type == 'otherplayer' then
                        local id = GetPlayerFromServerId(currentInventory.id)
                        local ped = id and id ~= -1 and GetPlayerPed(id)
                        local pedCoords = ped and ped ~= 0 and GetEntityCoords(ped)
                        local state = Player(currentInventory.id).state
                        local stealable = state.canSteal or state.isDead or state.dead or state.isHandcuffed
                        if not pedCoords or #(playerCoords - pedCoords) > maxDistance or (not client.hasGroup(shared.police) and not stealable) then
                            client.closeInventory()
                            lib.notify({ id = 'inventory_lost_access', type = 'error', description = locale('inventory_lost_access') })
                        else
                            TaskTurnPedToFaceCoord(playerPed, pedCoords.x, pedCoords.y, pedCoords.z, 50)
                        end
                    elseif currentInventory.coords and (#(playerCoords - currentInventory.coords) > maxDistance or canSteal) then
                        client.closeInventory()
                        lib.notify({ id = 'inventory_lost_access', type = 'error', description = locale('inventory_lost_access') })
                    end
                end
            end
        end

        if client.parachute and GetPedParachuteState(playerPed) ~= -1 then
            Utils.DeleteEntity(client.parachute[1])
            client.parachute = false
        end

        if WeaponWheelEnabled then return end

        local weaponHash = GetSelectedPedWeapon(playerPed)

        if currentWeapon then
            if weaponHash ~= currentWeapon.hash and currentWeapon.timer then
                local item = ItemList[currentWeapon.name]
                if item and (item.count or 0) > 0 then
                    SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
                    SetAmmoInClip(playerPed, currentWeapon.hash, currentWeapon.metadata.ammo or 0)
                    SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
                    weaponHash = GetSelectedPedWeapon(playerPed)
                end
                if weaponHash ~= currentWeapon.hash then currentWeapon = Weapon.Disarm(currentWeapon, true) end
            end
        elseif client.weaponmismatch and not client.ignoreweapons[weaponHash] then
            local group = GetWeapontypeGroup(weaponHash)
            if group ~= 0 and group ~= joaat('GROUP_UNARMED') then Weapon.Disarm(currentWeapon, true) end
        end
    end, 200)

    local playerId = cache.playerId
    local EnableKeys = client.enablekeys

    client.tick = SetInterval(function()
        DisablePlayerVehicleRewards(playerId)

        if invOpen then
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            for i = 1, #EnableKeys do EnableControlAction(0, EnableKeys[i], true) end
            if currentInventory.type == 'drop' or currentInventory.type == 'newdrop' then
                EnableControlAction(0, 30, true)
                EnableControlAction(0, 31, true)
            end
            return
        end

        if invBusy then
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 36, true)
        end

        if usingItem or IsPedCuffed(playerPed) then DisablePlayerFiring(playerId, true) end

        if not WeaponWheelEnabled then
            HudWeaponWheelIgnoreSelection()
            DisableControlAction(0, 37, true)
        end

        if not (currentWeapon and currentWeapon.timer) then return end

        DisableControlAction(0, 80, true)
        DisableControlAction(0, 140, true)

        if (currentWeapon.metadata.durability or 0) <= 0 then
            DisablePlayerFiring(playerId, true)
        elseif client.aimedfiring and not currentWeapon.melee and currentWeapon.group ~= GROUP_PETROLCAN and not IsPlayerFreeAiming(playerId) then
            DisablePlayerFiring(playerId, true)
        end

        local weaponAmmo = currentWeapon.metadata.ammo

        if not invBusy and currentWeapon.timer ~= 0 and currentWeapon.timer < GetGameTimer() then
            currentWeapon.timer = 0

            if weaponAmmo then
                TriggerServerEvent('vr-inventory:updateWeapon', 'ammo', weaponAmmo)
                if client.autoreload and currentWeapon.ammo and GetAmmoInPedWeapon(playerPed, currentWeapon.hash) == 0 then
                    local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)
                    if slotId then CreateThread(function() useSlot(slotId) end) end
                end
            elseif currentWeapon.metadata.durability and currentWeapon.melee then
                TriggerServerEvent('vr-inventory:updateWeapon', 'melee', currentWeapon.melee)
                currentWeapon.melee = 0
            end
        elseif weaponAmmo then
            if IsPedShooting(playerPed) then
                local currentAmmo
                local drain = (ItemList[currentWeapon.name] and ItemList[currentWeapon.name].durability) or 0.05

                if currentWeapon.group == GROUP_PETROLCAN or currentWeapon.group == GROUP_FIREEXTINGUISHER then
                    currentAmmo = weaponAmmo - drain < 0 and 0 or weaponAmmo - drain
                    currentWeapon.metadata.durability = currentAmmo
                    currentWeapon.metadata.ammo = (weaponAmmo < currentAmmo) and 0 or currentAmmo
                    if currentAmmo <= 0 then SetPedInfiniteAmmo(playerPed, false, currentWeapon.hash) end
                else
                    currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
                    if currentAmmo < weaponAmmo then
                        currentWeapon.metadata.ammo = currentAmmo
                        currentWeapon.metadata.durability = (currentWeapon.metadata.durability or 100) - (drain * math.abs(weaponAmmo - currentAmmo))
                    end
                end

                if currentAmmo <= 0 then
                    if cache.vehicle then TaskSwapWeapon(playerPed, true) end
                    currentWeapon.timer = GetGameTimer() + 200
                else
                    currentWeapon.timer = GetGameTimer() + (GetWeaponTimeBetweenShots(currentWeapon.hash) * 1000) + 100
                end
            end
        elseif currentWeapon.throwable then
            if not invBusy and IsControlPressed(0, 24) then
                invBusy = 1
                CreateThread(function()
                    local weapon = currentWeapon
                    while currentWeapon and (not IsPedWeaponReadyToShoot(cache.ped) or IsDisabledControlPressed(0, 24)) and GetSelectedPedWeapon(playerPed) == weapon.hash do Wait(0) end
                    if GetSelectedPedWeapon(playerPed) == weapon.hash then Wait(700) end
                    while IsPedPlantingBomb(playerPed) do Wait(0) end
                    TriggerServerEvent('vr-inventory:updateWeapon', 'throw', nil, weapon.slot)
                    invBusy = false
                    setState('invBusy', false)
                    currentWeapon = nil
                    RemoveWeaponFromPed(playerPed, weapon.hash)
                    U.fire('currentWeapon')
                end)
            end
        elseif currentWeapon.melee and IsControlJustReleased(0, 24) and IsPedPerformingMeleeAction(playerPed) then
            currentWeapon.melee = currentWeapon.melee + 1
            currentWeapon.timer = GetGameTimer() + 200
        end
    end)

    invBusy = false
    invOpen = false
    setState('invBusy', false)
    setState('invOpen', false)
    setState('invHotkeys', true)
    invHotkeys = true
    setState('canUseWeapons', true)
    collectgarbage('collect')
end)

function client.onLogout()
    if not PlayerData.loaded then return end

    if client.parachute then
        Utils.DeleteEntity(client.parachute[1])
        client.parachute = false
    end

    for _, point in pairs(client.drops or {}) do
        if point.entity then Utils.DeleteEntity(point.entity) end
        point:remove()
    end

    for _, v in pairs(ItemList) do v.count = 0 end

    PlayerData.loaded = false
    client.drops = nil

    client.closeInventory()
    Shops.wipe()

    if client.interval then
        ClearInterval(client.interval)
        ClearInterval(client.tick)
        client.interval, client.tick = nil, nil
    end

    currentWeapon = Weapon.Disarm(currentWeapon)
    SendNUIMessage({ action = 'close' })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= shared.resource then return end
    if invOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Utils.blurOut()
    end
    if PlayerData.loaded and client.interval then client.onLogout() end
end)

RegisterNUICallback('uiLoaded', function(_, cb)
    client.uiLoaded = true
    cb(1)
end)

RegisterNUICallback('getItemData', function(name, cb)
    local item = type(name) == 'string' and ItemList[name]
    cb(item and { label = item.label, description = item.description, weight = item.weight } or nil)
end)

RegisterNUICallback('removeComponent', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end

    if not currentWeapon then
        return TriggerServerEvent('vr-inventory:updateWeapon', 'component', { slot = data.slot, component = data.component })
    end

    if data.slot ~= currentWeapon.slot then
        return lib.notify({ id = 'weapon_hand_wrong', type = 'error', description = locale('weapon_hand_wrong') })
    end

    local itemSlot = PlayerData.inventory[currentWeapon.slot]
    local component = ItemList[data.component]
    if not itemSlot or not component or not component.client or not component.client.component then return end

    for _, hash in pairs(component.client.component) do
        if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, hash) then
            for k, v in pairs(itemSlot.metadata.components or {}) do
                if v == data.component then
                    if lib.callback.await('vr-inventory:updateWeapon', false, 'component', k) then
                        RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, hash)
                        U.fire('updateWeaponComponent', 'removed', hash, data.component)
                    end
                    break
                end
            end
        end
    end
end)

RegisterNUICallback('removeAmmo', function(slot, cb)
    cb(1)
    local slotData = PlayerData.inventory[slot]
    if usingItem or not slotData or not slotData.metadata.ammo or slotData.metadata.ammo == 0 then return end
    local ok = lib.callback.await('vr-inventory:removeAmmoFromWeapon', false, slot)
    if ok and currentWeapon and slot == currentWeapon.slot then SetPedAmmo(playerPed, currentWeapon.hash, 0) end
end)

RegisterNUICallback('useItem', function(slot, cb)
    cb(1)
    if type(slot) == 'number' then useSlot(slot) end
end)

local function giveItemToTarget(serverId, slotId, count)
    if type(slotId) ~= 'number' then return end
    if count and type(count) ~= 'number' then return end
    if currentWeapon and slotId == currentWeapon.slot then currentWeapon = Weapon.Disarm(currentWeapon) end

    Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 1.0, 1.0, 2000, 50, 0.0, 0, 0, 0)
    local notification = lib.callback.await('vr-inventory:giveItem', false, slotId, serverId, count or 0)
    if notification then lib.notify({ type = 'error', description = locale(table.unpack(notification)) }) end
end

exports('giveItemToTarget', giveItemToTarget)

local function validGiveTarget(ped, coords)
    if cache.vehicle and GetVehiclePedIsIn(ped, false) == cache.vehicle then return true end
    local entity = Utils.Raycast(1 | 4 | 8 | 16, coords + vec3(0, 0, 0.5), 0.2)
    return entity == ped and IsEntityVisible(ped)
end

RegisterNUICallback('giveItem', function(data, cb)
    cb(1)
    if usingItem or type(data) ~= 'table' then return end

    if client.giveplayerlist then
        local coords = cache.vehicle and GetWorldPositionOfEntityBone(playerPed, 0) or GetEntityCoords(playerPed)
        local nearby = lib.getNearbyPlayers(coords, 3.0)
        if #nearby == 0 then return lib.notify({ type = 'error', description = locale('nobody_nearby') }) end

        if #nearby == 1 then
            local option = nearby[1]
            if not validGiveTarget(option.ped, option.coords) then return end
            return giveItemToTarget(GetPlayerServerId(option.id), data.slot, data.count)
        end

        local list = {}
        for i = 1, #nearby do
            local option = nearby[i]
            if validGiveTarget(option.ped, option.coords) then
                local serverId = GetPlayerServerId(option.id)
                list[#list + 1] = { id = serverId, label = Utils.getPlayerName(serverId), icon = 'user' }
            end
        end
        if #list == 0 then return end

        lib.registerMenu({ id = 'vr-inventory:givePlayerList', title = locale('give_to'), options = list }, function(selected)
            giveItemToTarget(list[selected].id, data.slot, data.count)
        end)
        return lib.showMenu('vr-inventory:givePlayerList')
    end

    if cache.vehicle then
        local seats = GetVehicleMaxNumberOfPassengers(cache.vehicle) - 1
        if seats >= 0 then
            local passenger = GetPedInVehicleSeat(cache.vehicle, cache.seat - 2 * (cache.seat % 2) + 1)
            if passenger ~= 0 and IsEntityVisible(passenger) then
                return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(passenger)), data.slot, data.count)
            end
        end
        return
    end

    local entity = Utils.Raycast(1 | 2 | 4 | 8 | 16, GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.5), 0.2)
    if entity and IsPedAPlayer(entity) and IsEntityVisible(entity) and #(GetEntityCoords(playerPed, true) - GetEntityCoords(entity, true)) < 3.0 then
        return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity)), data.slot, data.count)
    end

    lib.notify({ type = 'error', description = locale('nobody_nearby') })
end)

RegisterNUICallback('useButton', function(data, cb)
    cb(1)
    if type(data) == 'table' then useButton(data.id, data.slot) end
end)

RegisterNUICallback('exit', function(_, cb)
    cb(1)
    client.closeInventory()
end)

lib.callback.register('vr-inventory:startCrafting', function(id, recipeId)
    local bench = CraftingBenches[id]
    local recipe = bench and bench.items[recipeId]
    if not recipe then return false end
    local item = ItemList[recipe.name]

    return lib.progressCircle({
        label = locale('crafting_item', recipe.metadata and recipe.metadata.label or (item and item.label) or recipe.name),
        duration = recipe.duration or 3000,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
    })
end)

local swapActive = false

RegisterNUICallback('swapItems', function(data, cb)
    if swapActive or not invOpen or invBusy or usingItem or type(data) ~= 'table' then return cb(false) end
    swapActive = true

    if data.toType == 'newdrop' then
        if cache.vehicle or IsPedFalling(playerPed) then
            swapActive = false
            return cb(false)
        end

        local coords = GetEntityCoords(playerPed)
        if IsEntityInWater(playerPed) then
            local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, coords.x, coords.y, -200.0, 511, cache.ped, 4)
            local found
            local started = GetGameTimer()
            while GetGameTimer() - started < 1000 do
                Wait(0)
                local status, hit, endCoords = GetShapeTestResult(handle)
                if status ~= 1 then
                    if hit then found = vec3(endCoords.x, endCoords.y, endCoords.z + 1.0) end
                    break
                end
            end
            if not found then
                swapActive = false
                return cb(false)
            end
            data.coords = found
        else
            data.coords = coords
        end
    end

    if currentInstance then data.instance = currentInstance end

    if currentWeapon and data.fromType ~= data.toType then
        if (data.fromType == 'player' and data.fromSlot == currentWeapon.slot) or (data.toType == 'player' and data.toSlot == currentWeapon.slot) then
            currentWeapon = Weapon.Disarm(currentWeapon, true)
        end
    end

    local success, response, weaponSlot = lib.callback.await('vr-inventory:swapItems', false, data)
    swapActive = false
    cb(success or false)

    if success then
        if weaponSlot and currentWeapon then currentWeapon.slot = weaponSlot end
        if type(response) == 'table' and response.items then updateInventory(response.items, response.weight) end
    elseif response then
        if type(response) == 'table' then
            for i = 1, #response do
                if response[i].inventory == cache.serverId then response[i].inventory = 'player' end
            end
            SendNUIMessage({ action = 'slots', data = { items = response } })
        else
            lib.notify({ type = 'error', description = locale(response) })
        end
    end
end)

RegisterNUICallback('buyItem', function(data, cb)
    if type(data) ~= 'table' then return cb(false) end
    local response, result, message = lib.callback.await('vr-inventory:buyItem', 100, data)

    if result then
        updateInventory({ { item = result[2], inventory = 'player' } }, result[4])
        if result[3] then
            SendNUIMessage({ action = 'slots', data = { items = { { item = result[3], inventory = 'shop' } } } })
        end
    end

    if message then lib.notify(message) end
    cb(response or false)
end)

RegisterNUICallback('craftItem', function(data, cb)
    cb(true)
    if type(data) ~= 'table' then return end

    local id, index = currentInventory.id, currentInventory.index
    local count = math.max(1, math.min(tonumber(data.count) or 1, 100))

    for _ = 1, count do
        local success, response = lib.callback.await('vr-inventory:craftItem', 200, id, index, data.fromSlot, data.toSlot)
        if not success then
            if response then lib.notify({ type = 'error', description = locale(response) }) end
            break
        end
    end

    if currentInventory.type ~= 'crafting' then client.openInventory('crafting', { id = id, index = index }) end
end)

lib.callback.register('vr-inventory:getVehicleData', function(netid)
    local entity = NetworkGetEntityFromNetworkId(netid)
    if entity and entity ~= 0 then return GetEntityModel(entity), GetVehicleClass(entity) end
end)
