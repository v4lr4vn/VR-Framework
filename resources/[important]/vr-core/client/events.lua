local VRCore    = VRCore
local Config    = VRCore.Config
local Shared    = VRCore.Shared
local Functions = VRCore.Functions
local Resources = Config.Resources

local function applyPvp(enabled)
    SetCanAttackFriendly(PlayerPedId(), enabled, false)
    NetworkSetFriendlyFireOption(enabled)
end

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
    ShutdownLoadingScreenNui()
    LocalPlayer.state:set('isLoggedIn', true, false)
    if Config.Server.PVP then applyPvp(true) end
end)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('isLoggedIn', false, false)
end)

RegisterNetEvent('VRCore:Client:PvpHasToggled', applyPvp)

RegisterNetEvent('VRCore:Client:OnPlayerUpdated', function(key, val, sub)
    local pd = VRCore.PlayerData
    if key == 'all' then
        VRCore.PlayerData = val
        CoreEmit('Player:SetPlayerData', val)
        CoreEmit('Client:OnJobUpdate', val.job)
        CoreEmit('Client:OnGangUpdate', val.gang)
        return
    end
    if not key or not pd then return end

    if sub then
        pd[key] = pd[key] or {}
        pd[key][sub] = val
        if key == 'metadata' and (sub == 'hunger' or sub == 'thirst') then
            TriggerEvent('hud:client:UpdateNeeds', pd.metadata.hunger, pd.metadata.thirst)
        end
    else
        pd[key] = val
        if key == 'job' then CoreEmit('Client:OnJobUpdate', val) end
        if key == 'gang' then CoreEmit('Client:OnGangUpdate', val) end
    end
    CoreEmit('Player:SetPlayerData', pd)
end)

RegisterNetEvent('VRCore:Client:OnMoneyChange', function(moneytype, amount, operation, _, money)
    local pd = VRCore.PlayerData
    local before = pd.money and pd.money[moneytype] or 0
    if money then pd.money = money end
    local shown, isMinus = amount, operation == 'remove'
    if operation == 'set' then
        local diff = amount - before
        shown, isMinus = math.abs(diff), diff < 0
    end

    CoreEmit('Player:SetPlayerData', pd)
    TriggerEvent('hud:client:OnMoneyChange', moneytype, shown, isMinus)
end)

CoreOnNet('Notify', function(text, notifyType, length, icon)
    Functions.Notify(text, notifyType, length, icon)
end)

RegisterNUICallback('getNotifyConfig', function(_, cb)
    cb(Config.Notify)
end)

CoreOnNet('Command:TeleportToPlayer', function(coords)
    SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, coords.z)
end)

CoreOnNet('Command:TeleportToCoords', function(x, y, z, h)
    local ped = PlayerPedId()
    SetPedCoordsKeepVehicle(ped, x, y, z)
    SetEntityHeading(ped, h or GetEntityHeading(ped))
end)

CoreOnNet('Command:GoToMarker', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return Functions.Notify(Lang:t('error.no_waypoint'), 'error', 5000) end

    DoScreenFadeOut(650)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local frozen = vehicle > 0 and vehicle or ped
    local target = GetBlipInfoIdCoord(blip)
    local oldCoords = GetEntityCoords(ped)
    local x, y = target.x, target.y
    FreezeEntityPosition(frozen, true)

    local found, groundZ = false, 0.0
    for i = 950.0, 0.0, -25.0 do
        local z = (i % 2 ~= 0) and (950.0 - i) or i
        local started = GetGameTimer()
        NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
        while IsNetworkLoadingScene() and GetGameTimer() - started < 1000 do Wait(0) end
        NewLoadSceneStop()
        SetPedCoordsKeepVehicle(ped, x, y, z)
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - started < 1000 do
            RequestCollisionAtCoord(x, y, z)
            Wait(0)
        end
        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then break end
        Wait(0)
    end

    if found then
        SetPedCoordsKeepVehicle(ped, x, y, groundZ)
    else
        SetPedCoordsKeepVehicle(ped, oldCoords.x, oldCoords.y, oldCoords.z - 1.0)
    end
    FreezeEntityPosition(frozen, false)
    DoScreenFadeIn(650)
    Functions.Notify(Lang:t(found and 'success.teleported_waypoint' or 'error.tp_error'), found and 'success' or 'error', 5000)
end)

CoreOnNet('Command:SpawnVehicle', function(vehName)
    local ped = PlayerPedId()
    local hash = joaat(vehName)
    if not IsModelInCdimage(hash) or not Functions.LoadModel(hash) then return end

    local current = GetVehiclePedIsUsing(ped)
    if current ~= 0 then Functions.DeleteVehicle(current) end

    local coords = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetModelAsNoLongerNeeded(hash)
    TriggerEvent('vehiclekeys:client:SetOwner', Functions.GetPlate(vehicle))
end)

CoreOnNet('Command:DeleteVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsUsing(ped)
    if veh ~= 0 then return Functions.DeleteVehicle(veh) end
    local coords = GetEntityCoords(ped)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(v)) <= 5.0 then Functions.DeleteVehicle(v) end
    end
end)

local function draw3DText(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local scale = 200 / (GetGameplayCamFov() * #(GetGameplayCamCoord() - coords))
    SetTextScale(1.0, 0.5 * scale)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextProportional(true)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CoreOnNet('Command:ShowMe3D', function(senderId, msg)
    local sender = GetPlayerFromServerId(senderId)
    if sender == -1 then return end
    CreateThread(function()
        local untilTime = GetGameTimer() + 5000
        while GetGameTimer() < untilTime do
            draw3DText(GetEntityCoords(GetPlayerPed(sender)), msg)
            Wait(0)
        end
    end)
end)

RegisterNetEvent('VRCore:Client:VehicleInfo', function(info)
    local vehicle = info.vehicle
    local plate = Functions.GetPlate(vehicle)
    local hasKeys = true
    if Resources.vehiclekeys and GetResourceState(Resources.vehiclekeys) == 'started' then
        hasKeys = exports[Resources.vehiclekeys]:HasKeys(plate)
    end
    CoreEmit('Client:' .. info.event .. 'Vehicle', {
        vehicle = vehicle,
        seat = info.seat,
        name = info.name,
        plate = plate,
        driver = GetPedInVehicleSeat(vehicle, -1),
        inseat = GetPedInVehicleSeat(vehicle, info.seat),
        haskeys = hasKeys,
    })
end)

RegisterNetEvent('VRCore:Client:OnSharedUpdate', function(ns, key, value)
    Shared[ns][key] = value
    CoreEmit('Client:UpdateObject')
end)

RegisterNetEvent('VRCore:Client:OnSharedUpdateMultiple', function(ns, values)
    local t = Shared[ns]
    for key, value in pairs(values) do t[key] = value end
    CoreEmit('Client:UpdateObject')
end)

RegisterNetEvent('VRCore:Client:SharedSync', function(delta)
    for ns, entries in pairs(delta) do
        local t = Shared[ns]
        if t then
            for key, value in pairs(entries) do t[key] = value or nil end
        end
    end
    CoreEmit('Client:UpdateObject')
end)
