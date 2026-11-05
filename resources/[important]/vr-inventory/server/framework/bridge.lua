local U = InvUtil

local function accountFor(item)
    return item == 'money' and 'cash' or item
end

local function playerInfo(source)
    local p = Bridge.player(source)
    if not p then return nil end
    local identifier = p.cid
    if Bridge.framework == 'ox' and p.charId then identifier = p.charId end
    return {
        source = tonumber(source),
        identifier = identifier,
        cid = p.cid,
        name = p.name,
        sex = p.gender,
        dateofbirth = p.dob,
    }
end

function server.setPlayerData(player)
    return {
        source = player.source,
        name = player.name,
        cid = player.cid,
        groups = Bridge.groups(player.source) or {},
        sex = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

local function pushAccounts(source)
    if Bridge.framework == 'ox' then return end
    local accounts = Inventory.GetAccountItemCounts(source)
    if not accounts then return end
    for item in pairs(accounts) do
        Inventory.SetItem(source, item, math.floor(Bridge.money(source, accountFor(item))))
    end
end

local loading = {}

local function setupPlayer(source)
    local info = playerInfo(source)
    if not info or not info.identifier then return end
    loading[info.source] = true
    local ok, err = pcall(server.setPlayerInventory, info)
    loading[info.source] = nil
    if not ok then print(('^1[vr-inventory] could not load inventory for %s: %s^0'):format(info.source, tostring(err))) end
    pushAccounts(info.source)
end

Bridge.on('playerLoaded', function(source)
    if source then CreateThread(function() setupPlayer(source) end) end
end)

Bridge.on('playerUnloaded', function(source)
    if Inventory(tonumber(source)) then server.playerDropped(source) end
end)

local function refreshGroups(source)
    local inventory = Inventory(tonumber(source))
    if inventory and inventory.player then inventory.player.groups = Bridge.groups(source) or {} end
end

Bridge.on('jobChanged', refreshGroups)
Bridge.on('gangChanged', refreshGroups)

local syncing = {}

Bridge.on('moneyChanged', function(source, account)
    source = tonumber(source)
    if not source or syncing[source] or not Inventory(source) then return end
    local item = account == 'cash' and 'money' or account
    if server.accounts[item] == nil then return end
    Inventory.SetItem(source, item, math.floor(Bridge.money(source, account)))
end)

CreateThread(function()
    while not shared.ready do Wait(50) end
    for _, source in ipairs(Bridge.sources()) do setupPlayer(source) end
end)

function server.UseItem(source, itemName, data)
    local fn = Bridge.usable(itemName)
    if fn then return fn(source, data) end
end

function server.syncInventory(inv)
    if Bridge.framework == 'ox' or loading[inv.id] then return end
    local accounts = Inventory.GetAccountItemCounts(inv)
    if not accounts then return end
    local source = inv.id
    syncing[source] = true
    for item, amount in pairs(accounts) do
        local account = accountFor(item)
        if Bridge.money(source, account) ~= amount then
            Bridge.setMoney(source, account, amount, ('Sync %s with inventory'):format(account))
        end
    end
    syncing[source] = nil
end

local function cidOf(inv)
    return inv and inv.player and inv.player.cid or Bridge.cid(inv and inv.id)
end

function server.hasLicense(inv, license)
    local cid = cidOf(inv)
    if not cid or not Bridge.licences.get then return false end
    local held = Bridge.licences.get(cid) or {}
    return held[license] == true
end

function server.buyLicense(inv, license)
    local cid = cidOf(inv)
    if not cid or not Bridge.licences.set then return end
    if server.hasLicense(inv, license.name) then
        return false, 'already_have'
    elseif Inventory.GetItemCount(inv, 'money') < license.price then
        return false, 'can_not_afford'
    end
    Inventory.RemoveItem(inv, 'money', license.price)
    Bridge.licences.set(cid, license.name, true)
    return true, 'have_purchased'
end

function server.isPlayerBoss(playerId, group, grade)
    local data = Bridge.grade(group, grade)
    return data and data.isboss or false
end

function server.hasGroup(inv, group)
    local groups = inv and inv.player and inv.player.groups
    if not groups then return end

    if type(group) == 'table' then
        for name, required in pairs(group) do
            if type(name) == 'number' then name, required = required, 0 end
            local rank = groups[name]
            if rank then
                if type(required) == 'table' then
                    if U.inArray(required, rank) then return name, rank end
                elseif rank >= (required or 0) then
                    return name, rank
                end
            end
        end
    elseif group then
        local rank = groups[group]
        if rank then return group, rank end
    end
end
