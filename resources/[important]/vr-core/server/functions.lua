local VRCore = VRCore
local Config = VRCore.Config
local Resources = Config.Resources

VRCore.Functions      = {}
VRCore.Player_Buckets = {}
VRCore.Entity_Buckets = {}
VRCore.UsableItems    = {}
VRCore.Players            = {}
VRCore.PlayersByCitizenId = {}
VRCore.PlayersByLicense   = {}

local Functions = VRCore.Functions
local Players   = VRCore.Players

function ResourceUp(name)
    return name and GetResourceState(name) == 'started'
end

local logResource = Resources.logs
local logEvent    = logResource and (logResource .. ':server:CreateLog')
local logEnabled  = ResourceUp(logResource)
AddEventHandler('onResourceStart', function(res) if res == logResource then logEnabled = true end end)
AddEventHandler('onResourceStop', function(res) if res == logResource then logEnabled = false end end)

function CoreLog(category, title, color, tagEveryone, fmt, ...)
    if not logEnabled then return end
    TriggerEvent(logEvent, category, title, color, select('#', ...) > 0 and fmt:format(...) or fmt, tagEveryone)
end

local function toVec3(coords)
    if type(coords) == 'table' then return vector3(coords.x, coords.y, coords.z) end
    return coords
end

function Functions.GetCoords(entity)
    local c = GetEntityCoords(entity, false)
    return vector4(c.x, c.y, c.z, GetEntityHeading(entity))
end

function Functions.GetIdentifier(source, idtype)
    if GetConvarInt('sv_fxdkMode', 0) == 1 then return 'license:fxdk' end
    return GetPlayerIdentifierByType(source, idtype or 'license')
end

function Functions.GetSource(identifier)
    local player = VRCore.PlayersByLicense[identifier]
    if player then return player.PlayerData.source end
    for src in pairs(Players) do
        local ids = GetPlayerIdentifiers(src)
        for i = 1, #ids do
            if ids[i] == identifier then return src end
        end
    end
    return 0
end

function Functions.GetPlayer(source)
    local id = tonumber(source)
    if id then return Players[id] end
    return Players[Functions.GetSource(source)]
end

function Functions.GetPlayerByCitizenId(citizenid)
    return VRCore.PlayersByCitizenId[citizenid]
end

function Functions.GetOfflinePlayerByCitizenId(citizenid)
    return VRCore.Player.GetOfflinePlayer(citizenid)
end

function Functions.GetPlayerByLicense(license)
    return VRCore.Player.GetPlayerByLicense(license)
end

function Functions.GetPlayerByCharInfo(property, value)
    if value == nil then return nil end
    for _, player in pairs(Players) do
        if player.PlayerData.charinfo[property] == value then return player end
    end
end

function Functions.GetPlayerByPhone(number)
    return Functions.GetPlayerByCharInfo('phone', number)
end

function Functions.GetPlayerByAccount(account)
    return Functions.GetPlayerByCharInfo('account', account)
end

function Functions.GetPlayers()
    local sources, n = {}, 0
    for src in pairs(Players) do
        n = n + 1
        sources[n] = src
    end
    return sources
end

function Functions.GetVRPlayers()
    return Players
end

function Functions.GetPlayersByJob(job, checkOnDuty)
    local players, count = {}, 0
    for src, player in pairs(Players) do
        local j = player.PlayerData.job
        if (j.name == job or j.type == job) and (not checkOnDuty or j.onduty) then
            count = count + 1
            players[count] = src
        end
    end
    return players, count
end

function Functions.GetPlayersOnDuty(job)
    return Functions.GetPlayersByJob(job, true)
end

function Functions.GetDutyCount(job)
    local _, count = Functions.GetPlayersByJob(job, true)
    return count
end

local function closest(pool, coords, ignore)
    local best, bestDist = -1, -1
    for i = 1, #pool do
        local entity = pool[i]
        if entity ~= ignore then
            local dist = #(GetEntityCoords(entity) - coords)
            if bestDist == -1 or dist < bestDist then best, bestDist = entity, dist end
        end
    end
    return best, bestDist
end

function Functions.GetClosestPlayer(source, coords)
    local ped = GetPlayerPed(source)
    coords = toVec3(coords) or GetEntityCoords(ped)
    local best, bestDist = -1, -1
    local players = GetPlayers()
    for i = 1, #players do
        local otherPed = GetPlayerPed(players[i])
        if otherPed ~= ped then
            local dist = #(GetEntityCoords(otherPed) - coords)
            if bestDist == -1 or dist < bestDist then best, bestDist = tonumber(players[i]), dist end
        end
    end
    return best, bestDist
end

function Functions.GetClosestObject(source, coords)
    return closest(GetAllObjects(), toVec3(coords) or GetEntityCoords(GetPlayerPed(source)))
end

function Functions.GetClosestVehicle(source, coords)
    return closest(GetAllVehicles(), toVec3(coords) or GetEntityCoords(GetPlayerPed(source)))
end

function Functions.GetClosestPed(source, coords)
    local ped = GetPlayerPed(source)
    return closest(GetAllPeds(), toVec3(coords) or GetEntityCoords(ped), ped)
end

function Functions.GetBucketObjects()
    return VRCore.Player_Buckets, VRCore.Entity_Buckets
end

function Functions.SetPlayerBucket(source, bucket)
    if not source or not bucket then return false end
    Player(source).state:set('instance', bucket, true)
    SetPlayerRoutingBucket(source, bucket)
    VRCore.Player_Buckets[Functions.GetIdentifier(source, 'license')] = { id = source, bucket = bucket }
    return true
end

function Functions.SetEntityBucket(entity, bucket)
    if not entity or not bucket then return false end
    SetEntityRoutingBucket(entity, bucket)
    VRCore.Entity_Buckets[entity] = { id = entity, bucket = bucket }
    return true
end

local function inBucket(list, bucket)
    local result = {}
    for _, v in pairs(list) do
        if v.bucket == bucket then result[#result + 1] = v.id end
    end
    return result
end

function Functions.GetPlayersInBucket(bucket) return inBucket(VRCore.Player_Buckets, bucket) end
function Functions.GetEntitiesInBucket(bucket) return inBucket(VRCore.Entity_Buckets, bucket) end

local function waitFor(check, timeout)
    local deadline = GetGameTimer() + timeout
    while not check() and GetGameTimer() < deadline do Wait(0) end
    return check()
end

local function spawnParams(source, model, coords)
    model = type(model) == 'string' and joaat(model) or model
    coords = coords or GetEntityCoords(GetPlayerPed(source))
    return model, coords, coords.w or 0.0
end

function Functions.SpawnVehicle(source, model, coords, warp)
    local ped = GetPlayerPed(source)
    local hash, pos, heading = spawnParams(source, model, coords)
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, heading, true, true)
    waitFor(function() return DoesEntityExist(veh) end, 5000)
    if warp then
        waitFor(function()
            TaskWarpPedIntoVehicle(ped, veh, -1)
            return GetVehiclePedIsIn(ped, false) == veh
        end, 2000)
    end
    waitFor(function() return NetworkGetEntityOwner(veh) == source end, 5000)
    return veh
end

function Functions.CreateVehicle(source, model, vehtype, coords, warp)
    local hash, pos, heading = spawnParams(source, model, coords)
    if not vehtype then
        local info = VRCore.Shared.VehicleHashes[hash]
        vehtype = info and info.type or 'automobile'
    end
    local veh = CreateVehicleServerSetter(hash, vehtype, pos.x, pos.y, pos.z, heading)
    waitFor(function() return DoesEntityExist(veh) end, 5000)
    if warp then TaskWarpPedIntoVehicle(GetPlayerPed(source), veh, -1) end
    return veh
end

function Functions.CreateAutomobile(source, model, coords, warp)
    return Functions.CreateVehicle(source, model, nil, coords, warp)
end

local pendingClient, nextClientId = {}, 0

function Functions.TriggerClientCallback(name, source, ...)
    if not source then return end
    local args = table.pack(...)
    local cb, first = nil, 1
    if VRCore.Shared.IsFunction(args[1]) then cb, first = args[1], 2 end

    nextClientId = nextClientId + 1
    local id, p = nextClientId, promise.new()
    pendingClient[id] = { p = p, cb = cb, src = tonumber(source) }
    TriggerClientEvent('VRCore:Client:TriggerClientCallback', source, name, id, table.unpack(args, first, args.n))

    SetTimeout(Config.CallbackTimeout, function()
        if not pendingClient[id] then return end
        pendingClient[id] = nil
        if Config.Debug then VRCore.ShowError(GetCurrentResourceName(), ('client callback %s timed out (id %s)'):format(name, source)) end
        p:resolve({ n = 0 })
    end)

    if not cb then
        local r = Citizen.Await(p)
        return table.unpack(r, 1, r.n)
    end
end

RegisterNetEvent('VRCore:Server:TriggerClientCallback', function(id, ...)
    local entry = pendingClient[id]
    if not entry or entry.src ~= source then return end
    pendingClient[id] = nil
    entry.p:resolve(table.pack(...))
    if entry.cb then entry.cb(...) end
end)

local callbackOwner = {}

function Functions.CreateCallback(name, cb)
    VRCore.ServerCallbacks[name] = cb
    callbackOwner[name] = GetInvokingResource()
end

RegisterNetEvent('VRCore:Server:TriggerCallback', function(name, id, ...)
    local src = source
    local handler = VRCore.ServerCallbacks[name]
    if not handler then
        if Config.Debug then VRCore.ShowError(GetCurrentResourceName(), ('unknown server callback "%s" from %s'):format(tostring(name), src)) end
        return TriggerClientEvent('VRCore:Client:TriggerCallback', src, id)
    end
    handler(src, function(...) TriggerClientEvent('VRCore:Client:TriggerCallback', src, id, ...) end, ...)
end)

function Functions.CreateUseableItem(item, data)
    local fn
    if VRCore.Shared.IsFunction(data) then
        fn = data
    elseif type(data) == 'table' then
        fn = VRCore.Shared.IsFunction(data.cb) and data.cb or VRCore.Shared.IsFunction(data.callback) and data.callback or nil
    end
    if fn then VRCore.UsableItems[item] = { func = fn, resource = GetInvokingResource() } end
end

function Functions.CanUseItem(item)
    return VRCore.UsableItems[item]
end

IsSlotInventory = Resources.inventory == 'vr-inventory'

local function slotCount(source, name)
    return exports[Resources.inventory]:Search(source, 'count', name) or 0
end

function Functions.UseItem(source, item)
    if IsSlotInventory or not ResourceUp(Resources.inventory) then return end
    exports[Resources.inventory]:UseItem(source, item)
end

function Functions.HasItem(source, items, amount)
    if not ResourceUp(Resources.inventory) then return false end
    if not IsSlotInventory then return exports[Resources.inventory]:HasItem(source, items, amount) end
    amount = tonumber(amount) or 1
    if type(items) == 'string' then return slotCount(source, items) >= amount end
    if type(items) ~= 'table' then return false end
    for k, v in pairs(items) do
        local name, need = k, tonumber(v) or amount
        if type(k) == 'number' then name, need = v, amount end
        if slotCount(source, name) < need then return false end
    end
    return true
end

function Functions.GetGroups(source)
    local player = Players[tonumber(source)]
    return VRCore.Shared.GetGroupsFromData(player and player.PlayerData)
end

function Functions.HasGroup(source, filter)
    local player = Players[tonumber(source)]
    if not player then return end
    return VRCore.Shared.MatchGroup(VRCore.Shared.GetGroupsFromData(player.PlayerData), filter)
end

AddEventHandler('onResourceStop', function(res)
    for name, item in pairs(VRCore.UsableItems) do
        if item.resource == res then VRCore.UsableItems[name] = nil end
    end
    for name, owner in pairs(callbackOwner) do
        if owner == res then
            VRCore.ServerCallbacks[name] = nil
            callbackOwner[name] = nil
        end
    end
end)

function Functions.Kick(source, reason, setKickReason, deferrals)
    reason = ('\n%s\n🔸 Check our Discord for further information: %s'):format(reason, Config.Server.Discord)
    if setKickReason then setKickReason(reason) end
    if deferrals then
        deferrals.done(reason)
        return
    end
    if source then DropPlayer(source, reason) end
end

function Functions.IsWhitelisted(source)
    if not Config.Server.Whitelist then return true end
    return Functions.HasPermission(source, Config.Server.WhitelistPermission)
end

function Functions.AddPermission(source, permission)
    if IsPlayerAceAllowed(source, permission) then return end
    ExecuteCommand(('add_principal player.%s vrcore.%s'):format(source, permission))
    VRCore.Commands.Refresh(source)
end

function Functions.RemovePermission(source, permission)
    local list = permission and { permission } or Config.Server.Permissions
    local changed = false
    for i = 1, #list do
        if IsPlayerAceAllowed(source, list[i]) then
            ExecuteCommand(('remove_principal player.%s vrcore.%s'):format(source, list[i]))
            changed = true
        end
    end
    if changed then VRCore.Commands.Refresh(source) end
end

function Functions.HasPermission(source, permission)
    if type(permission) == 'string' then return IsPlayerAceAllowed(source, permission) end
    if type(permission) == 'table' then
        for _, perm in pairs(permission) do
            if IsPlayerAceAllowed(source, perm) then return true end
        end
    end
    return false
end

function Functions.GetPermission(source)
    local perms = {}
    for _, perm in ipairs(Config.Server.Permissions) do
        if IsPlayerAceAllowed(source, perm) then perms[perm] = true end
    end
    return perms
end

function Functions.IsOptin(source)
    if not Functions.HasPermission(source, 'admin') then return false end
    local player = Functions.GetPlayer(source)
    return player and player.PlayerData.optin or false
end

function Functions.ToggleOptin(source)
    if not Functions.HasPermission(source, 'admin') then return end
    local player = Functions.GetPlayer(source)
    if not player then return end
    player.Functions.SetPlayerData('optin', not player.PlayerData.optin)
end

function Functions.IsPlayerBanned(source)
    local license = Functions.GetIdentifier(source, 'license')
    local ban = MySQL.single.await('SELECT id, reason, expire FROM vr_bans WHERE license = ? LIMIT 1', { license })
    if not ban then return false end
    local expire = tonumber(ban.expire) or 0
    if os.time() < expire then
        local t = os.date('*t', expire)
        return true, ('You have been banned from the server:\n%s\nYour ban expires %d/%d/%d %d:%02d\n')
            :format(ban.reason or 'No reason given', t.day, t.month, t.year, t.hour, t.min)
    end
    MySQL.query('DELETE FROM vr_bans WHERE id = ?', { ban.id })
    return false
end

function Functions.IsLicenseInUse(license)
    local players = GetPlayers()
    for i = 1, #players do
        if Functions.GetIdentifier(players[i], 'license') == license then return true end
    end
    return false
end

function Functions.Notify(source, text, notifyType, length)
    TriggerClientEvent('VRCore:Notify', source, text, notifyType, length)
end
