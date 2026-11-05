InstalledPlates = {}

function LoadVehicles()
    InstalledPlates = {}
    for _, row in ipairs(MySQL.query.await('SELECT `plate`, `installed_by` FROM `vr_djbooth_vehicles`') or {}) do
        InstalledPlates[row.plate] = row.installed_by or ''
    end
end

local function plateOf(veh)
    local p = GetVehicleNumberPlateText(veh)
    if type(p) ~= 'string' then return nil end
    p = p:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if p == '' or #p > 16 then return nil end
    return p
end

local function seatOf(ped, veh)
    for seat = -1, 14 do
        if GetPedInVehicleSeat(veh, seat) == ped then return seat end
    end
end

local function playerVehicle(src, netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= veh then return nil end
    return veh, seatOf(ped, veh)
end

local function allowedSeat(seat)
    for _, s in ipairs(Config.CarStereo.seats) do
        if s == seat then return true end
    end
    return false
end

local function systemVehicle(sys)
    local veh = sys.netId and NetworkGetEntityFromNetworkId(sys.netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
end

function IsInVehicleSeat(src, sys)
    local veh = systemVehicle(sys)
    if not veh then return false end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= veh then return false end
    return allowedSeat(seatOf(ped, veh))
end

function IsDriverOf(src, sys)
    local veh = systemVehicle(sys)
    return veh ~= nil and GetPedInVehicleSeat(veh, -1) == GetPlayerPed(src)
end

local function attach(plate, veh)
    local id = 'v' .. plate
    local sys = Systems[id] or NewSystem(id, 'vehicle', Config.SystemName.vehicle, nil, GetEntityRoutingBucket(veh), Config.DefaultVolume)
    sys.plate = plate
    local netId, bucket = NetworkGetNetworkIdFromEntity(veh), GetEntityRoutingBucket(veh)
    if sys.netId ~= netId or sys.bucket ~= bucket then
        sys.netId, sys.bucket = netId, bucket
        PushSystem(sys)
    end
    sys.missingSince = nil
    Entity(veh).state:set('djStereo', true, true)
    return sys
end

Bridge.useItem(Config.CarStereo.item, function(source)
    TriggerClientEvent('vr-djbooth:client:installStereo', source)
end)

lib.callback.register('vr-djbooth:vehicle:install', function(src, netId)
    if TooFast(src, 'install', 2000) then return false, 'slow_down' end
    local veh, seat = playerVehicle(src, netId)
    if not veh then return false, 'not_in_vehicle' end
    if seat ~= -1 then return false, 'not_driver' end
    local plate = plateOf(veh)
    if not plate then return false, 'bad_request' end
    if InstalledPlates[plate] then return false, 'already_installed' end
    if not Inv:RemoveItem(src, Config.CarStereo.item, 1) then return false, 'no_item' end
    local Player = GetPlayer(src)
    local cid = Player and Player.cid or nil
    InstalledPlates[plate] = cid or ''
    local ok = DbAwait('insert', 'INSERT INTO `vr_djbooth_vehicles` (`plate`, `installed_by`) VALUES (?, ?)', { plate, cid })
    if ok == nil then
        InstalledPlates[plate] = nil
        Inv:AddItem(src, Config.CarStereo.item, 1)
        return false, 'save_failed'
    end
    attach(plate, veh)
    return true
end)

lib.callback.register('vr-djbooth:vehicle:open', function(src, netId)
    if TooFast(src, 'open', 500) then return false, 'slow_down' end
    local veh, seat = playerVehicle(src, netId)
    if not veh then return false, 'not_in_vehicle' end
    local plate = plateOf(veh)
    if not plate or not InstalledPlates[plate] then return false, 'no_stereo' end
    if not allowedSeat(seat) then return false, 'wrong_seat' end
    return true, OpenPanel(src, attach(plate, veh))
end)

local function canUninstall(src, sys)
    if IsAdmin(src) then return true end
    local by = InstalledPlates[sys.plate]
    local Player = GetPlayer(src)
    return by ~= nil and by ~= '' and Player ~= nil and Player.cid == by
end
CanUninstallStereo = canUninstall

function Actions.uninstall(src, sys)
    if sys.kind ~= 'vehicle' then return false, 'not_allowed' end
    if not IsDriverOf(src, sys) then return false, 'not_driver' end
    if not canUninstall(src, sys) then return false, 'not_installer' end
    if not Inv:CanCarryItem(src, Config.CarStereo.item, 1) then return false, 'inventory_full' end
    MySQL.update('DELETE FROM `vr_djbooth_vehicles` WHERE `plate` = ?', { sys.plate })
    InstalledPlates[sys.plate] = nil
    local veh = systemVehicle(sys)
    if veh then Entity(veh).state:set('djStereo', false, true) end
    RemoveSystem(sys)
    Inv:AddItem(src, Config.CarStereo.item, 1)
    return true
end

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for _, sys in pairs(Systems) do
            if sys.kind == 'vehicle' then
                local idle = not sys.now and not next(Viewers[sys.id] or {})
                if not systemVehicle(sys) or idle then
                    sys.missingSince = sys.missingSince or now
                    if now - sys.missingSince > (idle and 120000 or 30000) then RemoveSystem(sys) end
                else
                    sys.missingSince = nil
                end
            end
        end
    end
end)
