local PERMANENT = 2147483647

RegisterNetEvent('vr-adminmenu:server:BanPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:BanPlayer', selectedData) then return end

    local player = GetTargetId(Field(selectedData, "Player"))
    local reason = CleanText(Field(selectedData, "Reason"), Config.MaxReasonLength) or ""
    local time = ToAmount(Field(selectedData, "Duration"))

    if not player then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    if not time or IsAllowedValue('vr-adminmenu:server:BanPlayer', 'Duration', time) == false then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error', 7500)
    end

    if player == src then
        return VRCore.Functions.Notify(src, locale("cant_target_yourself"), 'error', 7500)
    end
    if not CanActOn(src, player) then return end

    local banTime = os.time() + time
    local expire = banTime

    if time >= PERMANENT or banTime > PERMANENT then
        expire = PERMANENT
    end

    local timeTable = os.date('*t', expire)

    local insertId = MySQL.insert.await(
        'INSERT INTO vr_bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            GetPlayerName(player) or 'unknown',
            VRCore.Functions.GetIdentifier(player, 'license'),
            VRCore.Functions.GetIdentifier(player, 'discord') or '',
            VRCore.Functions.GetIdentifier(player, 'ip') or '',
            reason,
            expire,
            GetPlayerName(src) or 'vr-adminmenu',
        }
    )

    if not insertId then
        return VRCore.Functions.Notify(src, locale("ban_failed"), 'error', 7500)
    end

    local targetName = GetPlayerName(player) or tostring(player)

    if expire == PERMANENT then
        DropPlayer(player, locale("banned") .. '\n' .. locale("reason") .. reason .. '\n' .. locale("ban_perm"))
    else
        DropPlayer(player,
            locale("banned") ..
            '\n' ..
            locale("reason") ..
            reason ..
            '\n' ..
            locale("ban_expires") ..
            timeTable['day'] ..
            '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. ('%02d'):format(timeTable['min']))
    end

    local untilText = expire == PERMANENT and locale("permanent") or ('until ' .. os.date('%d/%m/%Y %H:%M', expire))
    VRCore.Functions.Notify(src, locale("playerbanned", targetName, untilText, reason), 'success', 7500)
end)

local function ensureWarnsTable()
    local name = Config.WarnsTable
    if type(name) ~= 'string' or name:find('[^%w_]') then return end
    MySQL.query(([[CREATE TABLE IF NOT EXISTS `%s` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `senderIdentifier` varchar(50) DEFAULT NULL,
        `targetIdentifier` varchar(50) DEFAULT NULL,
        `reason` text DEFAULT NULL,
        `warnId` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(name))
end
CreateThread(ensureWarnsTable)

RegisterNetEvent('vr-adminmenu:server:WarnPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:WarnPlayer', selectedData) then return end

    local targetId, target = GetTargetPlayer(Field(selectedData, "Player"))
    local reason = CleanText(Field(selectedData, "Reason"), Config.MaxReasonLength) or ""
    local sender = VRCore.Functions.GetPlayer(src)

    if not target or not sender then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error')
    end
    if not CanActOn(src, targetId) then return end

    local warnId = 'WARN-' .. math.random(1111, 9999)
    VRCore.Functions.Notify(targetId, locale("warned") .. ", for: " .. locale("reason") .. reason, 'primary', 10000)
    VRCore.Functions.Notify(src, locale("warngiven") .. (GetPlayerName(targetId) or targetId) .. ", for: " .. reason, 'success')
    MySQL.insert(('INSERT INTO `%s` (senderIdentifier, targetIdentifier, reason, warnId) VALUES (?, ?, ?, ?)'):format(Config.WarnsTable),
        {
            sender.PlayerData.license,
            target.PlayerData.license,
            reason,
            warnId
        })
end)

RegisterNetEvent('vr-adminmenu:server:KickPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:KickPlayer', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    local reason = CleanText(Field(selectedData, "Reason"), Config.MaxReasonLength) or ""

    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if target == src then
        return VRCore.Functions.Notify(src, locale("cant_target_yourself"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    DropPlayer(target, locale("kicked") .. '\n' .. locale("reason") .. reason)
end)

local function revive(target)
    TriggerClientEvent(Config.ReviveEvent, target)
end

local function reviveAvailable(src)
    if ResourceUp('ambulance') then return true end
    VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.ambulance)), 'error', 7500)
    return false
end

RegisterNetEvent('vr-adminmenu:server:Revive', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:Revive', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not reviveAvailable(src) then return end

    revive(target)
end)

RegisterNetEvent('vr-adminmenu:server:ReviveAll', function()
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ReviveAll') then return end
    if not reviveAvailable(src) then return end

    revive(-1)
end)

RegisterNetEvent('vr-adminmenu:server:ReviveRadius', function()
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ReviveRadius') then return end
    if not reviveAvailable(src) then return end

    local pos = GetEntityCoords(GetPlayerPed(src))
    local players = VRCore.Functions.GetPlayers()

    for i = 1, #players do
        local target = players[i]
        local targetPos = GetEntityCoords(GetPlayerPed(target))

        if #(pos - targetPos) < 15.0 then
            revive(target)
        end
    end
end)

RegisterNetEvent('vr-adminmenu:server:SetBucket', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SetBucket', selectedData) then return end

    local player = GetTargetId(Field(selectedData, "Player"))
    local bucket = tonumber(Field(selectedData, "Bucket"))

    if not player then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not bucket or bucket < 0 or bucket > 2147483647 or bucket ~= math.floor(bucket) then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error', 7500)
    end
    if not CanActOn(src, player) then return end

    if bucket == GetPlayerRoutingBucket(player) then
        return VRCore.Functions.Notify(src, locale("target_same_bucket", player), 'error', 7500)
    end

    VRCore.Functions.SetPlayerBucket(player, math.floor(bucket))
    VRCore.Functions.Notify(src, locale("bucket_set_for_target", player, math.floor(bucket)), 'success', 7500)
end)

RegisterNetEvent('vr-adminmenu:server:GetBucket', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:GetBucket', selectedData) then return end

    local player = GetTargetId(Field(selectedData, "Player"))
    if not player then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    VRCore.Functions.Notify(src, locale("bucket_get", player, GetPlayerRoutingBucket(player)), 'success', 7500)
end)

local function moneyRequest(src, event, selectedData)
    local amount = ToAmount(Field(selectedData, "Amount"), Config.MaxMoneyAmount)
    local moneyType = Field(selectedData, "Type")

    if not amount then
        VRCore.Functions.Notify(src, locale("invalid_amount", Config.MaxMoneyAmount), 'error', 7500)
        return nil
    end
    if type(moneyType) ~= 'string' or IsAllowedValue(event, "Type", moneyType) == false then
        VRCore.Functions.Notify(src, locale("invalid_money_type"), 'error', 7500)
        return nil
    end

    return amount, moneyType
end

RegisterNetEvent('vr-adminmenu:server:GiveMoney', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:GiveMoney', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    local amount, moneyType = moneyRequest(src, 'vr-adminmenu:server:GiveMoney', selectedData)
    if not amount then return end

    if not Player.Functions.AddMoney(moneyType, amount, 'vr-adminmenu: given by ' .. (GetPlayerName(src) or src)) then
        return VRCore.Functions.Notify(src, locale("invalid_money_type"), 'error', 7500)
    end

    VRCore.Functions.Notify(src,
        locale((moneyType == "crypto" and "give_money_crypto" or "give_money"), amount, FullName(Player)), "success")
end)

RegisterNetEvent('vr-adminmenu:server:GiveMoneyAll', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:GiveMoneyAll', selectedData) then return end

    local amount, moneyType = moneyRequest(src, 'vr-adminmenu:server:GiveMoneyAll', selectedData)
    if not amount then return end

    local reason = 'vr-adminmenu: given to all by ' .. (GetPlayerName(src) or src)
    local players = VRCore.Functions.GetPlayers()
    for i = 1, #players do
        local Player = VRCore.Functions.GetPlayer(players[i])
        if Player then
            Player.Functions.AddMoney(moneyType, amount, reason)
        end
    end

    VRCore.Functions.Notify(src,
        locale((moneyType == "crypto" and "give_money_all_crypto" or "give_money_all"), amount), "success")
end)

RegisterNetEvent('vr-adminmenu:server:TakeMoney', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:TakeMoney', selectedData) then return end

    local target, Player = GetTargetPlayer(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end

    local amount, moneyType = moneyRequest(src, 'vr-adminmenu:server:TakeMoney', selectedData)
    if not amount then return end

    local balance = tonumber(Player.PlayerData.money[moneyType]) or 0
    if balance < amount or not Player.Functions.RemoveMoney(moneyType, amount, 'vr-adminmenu: removed by ' .. (GetPlayerName(src) or src)) then
        return VRCore.Functions.Notify(src, locale("not_enough_money"), "error")
    end

    VRCore.Functions.Notify(src,
        locale((moneyType == "crypto" and "take_money_crypto" or "take_money"), amount .. "$", FullName(Player)), "success")
end)

RegisterNetEvent('vr-adminmenu:server:CuffPlayer', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:CuffPlayer', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not CanActOn(src, target) then return end
    if not ResourceUp('police') then
        return VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.police)), 'error', 7500)
    end

    TriggerClientEvent('vr-adminmenu:client:ToggleCuffs', target)
    VRCore.Functions.Notify(src, locale("toggled_cuffs"), 'success')
end)

RegisterNetEvent('vr-adminmenu:server:ClothingMenu', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ClothingMenu', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if not ResourceUp('clothing') then
        return VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.clothing)), 'error', 7500)
    end

    if target == src then
        TriggerClientEvent("vr-adminmenu:client:CloseUI", src)
    end

    TriggerClientEvent('vr-clothing:client:openClothingShopMenu', target, true)
end)

local PedModels = {}
do
    local list = LoadDataFile('data/ped.lua')
    if type(list) == 'table' then
        for _, v in pairs(list) do
            if v.label then PedModels[v.label] = true end
        end
    end
end

RegisterNetEvent("vr-adminmenu:server:setPed", function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:setPed', selectedData) then return end

    local ped = Field(selectedData, "Ped Models", "label")
    local tsrc = GetTargetId(Field(selectedData, "Player"))

    if not tsrc then
        return VRCore.Functions.Notify(src, locale("not_online"), "error", 5000)
    end
    if type(ped) ~= 'string' or not PedModels[ped] then
        return VRCore.Functions.Notify(src, locale("invalid_ped"), "error", 5000)
    end
    if not CanActOn(src, tsrc) then return end

    TriggerClientEvent("vr-adminmenu:client:setPed", tsrc, ped)
end)
