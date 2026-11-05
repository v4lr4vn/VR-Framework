local function clearKeep()
    local keep = Config.ClearInventoryKeep
    if type(keep) == 'table' and #keep == 0 then return nil end
    return keep
end

RegisterNetEvent('vr-adminmenu:server:ClearInventory', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ClearInventory', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    exports['vr-inventory']:ClearInventory(target, clearKeep())

    VRCore.Functions.Notify(src, locale("invcleared", FullName(Player)), 'success', 7500)
end)

RegisterNetEvent('vr-adminmenu:server:ClearInventoryOffline', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ClearInventoryOffline', selectedData) then return end

    local citizenId = CleanText(Field(selectedData, "Citizen ID"), 50)
    if not citizenId or citizenId == '' then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error', 7500)
    end

    local Player = VRCore.Functions.GetPlayerByCitizenId(citizenId)

    if Player then
        if not CanActOn(src, Player.PlayerData.source) then return end
        exports['vr-inventory']:ClearInventory(Player.PlayerData.source, clearKeep())
        VRCore.Functions.Notify(src, locale("invcleared", FullName(Player)), 'success', 7500)
        return
    end

    local exists = MySQL.scalar.await('SELECT 1 FROM vr_players WHERE citizenid = ? LIMIT 1', { citizenId })
    if not exists then
        return VRCore.Functions.Notify(src, locale("player_not_found"), 'error', 7500)
    end

    MySQL.update.await("UPDATE vr_players SET inventory = '[]' WHERE citizenid = ?", { citizenId })
    VRCore.Functions.Notify(src, locale("invcleared", citizenId), 'success', 7500)
end)

RegisterNetEvent('vr-adminmenu:server:OpenInv', function(target)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:openInventory') then return end

    target = GetTargetId(target)
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    exports['vr-inventory']:forceOpenInventory(src, 'player', target)
end)

RegisterNetEvent('vr-adminmenu:server:OpenStash', function(stash)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:openStash') then return end

    stash = CleanText(stash, 100)
    if not stash or stash == '' then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error', 7500)
    end

    if not exports['vr-inventory']:forceOpenInventory(src, 'stash', stash) then
        VRCore.Functions.Notify(src, locale("stash_not_found"), 'error', 7500)
    end
end)

local function findVehicleByPlate(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) and Trim(GetVehicleNumberPlateText(veh) or ''):upper() == plate then
            return veh
        end
    end
end

RegisterNetEvent('vr-adminmenu:server:OpenTrunk', function(plate)
    local src = source
    if not Authorize(src, 'vr-adminmenu:client:openTrunk') then return end

    plate = CleanPlate(plate)
    if not plate then
        return VRCore.Functions.Notify(src, locale("plate_invalid"), 'error', 7500)
    end

    local vehicle = findVehicleByPlate(plate)
    if not vehicle then
        return VRCore.Functions.Notify(src, locale("vehicle_not_found"), 'error', 7500)
    end

    exports['vr-inventory']:forceOpenInventory(src, 'trunk', { netid = NetworkGetNetworkIdFromEntity(vehicle) })
end)

local function getItem(name)
    if type(name) ~= 'string' or name == '' or #name > 100 then return nil end
    local ok, item = pcall(function() return exports['vr-inventory']:Items(name) end)
    return ok and item or nil
end

local function checkItemRequest(src, selectedData)
    local itemName = Field(selectedData, "Item")
    local item = getItem(itemName)
    if not item then
        VRCore.Functions.Notify(src, locale("invalid_item"), 'error', 7500)
        return nil
    end

    local amount = ToAmount(Field(selectedData, "Amount"), Config.MaxItemAmount)
    if not amount then
        VRCore.Functions.Notify(src, locale("invalid_amount", Config.MaxItemAmount), 'error', 7500)
        return nil
    end

    if Config.MoneyItems[itemName] and not Authorize(src, 'vr-adminmenu:server:GiveMoney', nil, true) then
        VRCore.Functions.Notify(src, locale("no_perms"), 'error', 7500)
        return nil
    end

    return itemName, amount, item.label or itemName
end

RegisterNetEvent('vr-adminmenu:server:GiveItem', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:GiveItem', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    local item, amount, label = checkItemRequest(src, selectedData)
    if not item then return end

    local success, response = exports['vr-inventory']:AddItem(target, item, amount)
    if not success then
        return VRCore.Functions.Notify(src, locale("give_item_failed", tostring(response or 'error')), 'error', 7500)
    end

    VRCore.Functions.Notify(src, locale("give_item", amount .. " " .. label, FullName(Player)), "success", 7500)
end)

RegisterNetEvent('vr-adminmenu:server:GiveItemAll', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:GiveItemAll', selectedData) then return end

    local item, amount, label = checkItemRequest(src, selectedData)
    if not item then return end

    local players = VRCore.Functions.GetPlayers()
    for i = 1, #players do
        exports['vr-inventory']:AddItem(players[i], item, amount)
    end

    VRCore.Functions.Notify(src, locale("give_item_all", amount .. " " .. label), "success", 7500)
end)
