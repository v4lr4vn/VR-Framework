TestDrive = { active = {}, cooldown = {} }

local T = Config.TestDrive

function TestDrive.start(info, dealer, model)
    local src = info.src
    if TestDrive.active[src] then return false, 'already_driving' end
    local wait = (TestDrive.cooldown[src] or 0) - os.time()
    if wait > 0 then return false, 'cooldown', { seconds = wait } end
    if not Dealers.sells(dealer, model) then return false, 'not_sold_here' end
    local spot = dealer.testDrive
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - vec3(spot.x, spot.y, spot.z)) < 3.0 then return false, 'spot_blocked' end
    end
    local v = Core.vehicle(model)
    local veh = CreateVehicleServerSetter(joaat(model), v.type or 'automobile', spot.x, spot.y, spot.z, spot.w)
    local deadline = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(25) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'spawn_failed' end
    local plate = ('TEST%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('vr_testdrive', src, true)
    TestDrive.active[src] = { veh = veh, dealer = dealer.id, ends = os.time() + T.seconds, origin = vec3(spot.x, spot.y, spot.z), away = 0, plate = plate }
    TriggerClientEvent('vr-dealership:client:testDrive', src, NetworkGetNetworkIdFromEntity(veh), { seconds = T.seconds, plate = plate })
    return true, { seconds = T.seconds }
end

function TestDrive.finish(src, reason)
    local d = TestDrive.active[src]
    if not d then return end
    TestDrive.active[src] = nil
    TestDrive.cooldown[src] = os.time() + T.cooldownSeconds
    if DoesEntityExist(d.veh) then DeleteEntity(d.veh) end
    local dealer = Dealers.get(d.dealer)
    if GetPlayerName(src) then
        TriggerClientEvent('vr-dealership:client:testDriveEnd', src, dealer and dealer.returnPoint and { x = dealer.returnPoint.x, y = dealer.returnPoint.y, z = dealer.returnPoint.z } or nil, reason)
    end
end

function TestDrive.tick()
    local now = os.time()
    for src, d in pairs(TestDrive.active) do
        if not GetPlayerName(src) or not DoesEntityExist(d.veh) then
            TestDrive.finish(src, 'gone')
        elseif now >= d.ends then
            TestDrive.finish(src, 'time')
        elseif #(GetEntityCoords(d.veh) - d.origin) > T.maxDistance then
            TestDrive.finish(src, 'distance')
        else
            local driver = GetPedInVehicleSeat(d.veh, -1)
            if driver ~= GetPlayerPed(src) then
                d.away = d.away + 1
                if d.away >= T.leaveSeconds then TestDrive.finish(src, 'left') end
            else
                d.away = 0
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    if TestDrive.active[src] then TestDrive.finish(src, 'gone') end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, d in pairs(TestDrive.active) do
        if DoesEntityExist(d.veh) then DeleteEntity(d.veh) end
    end
end)
