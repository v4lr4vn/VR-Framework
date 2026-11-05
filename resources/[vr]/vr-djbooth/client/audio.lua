local BySystem = {}
local indexDirty = true

function SpeakersChanged() indexDirty = true end

local function bySystem()
    if indexDirty then
        indexDirty = false
        BySystem = {}
        for _, sp in pairs(Speakers) do
            if sp.system then
                local list = BySystem[sp.system]
                if not list then list = {}; BySystem[sp.system] = list end
                list[#list + 1] = sp
            end
        end
    end
    return BySystem
end

local function vehicleIsOpen(veh)
    local model = GetEntityModel(veh)
    if IsThisModelABike(model) or IsThisModelAQuadbike(model) or IsThisModelABicycle(model) or IsThisModelABoat(model) then return true end
    if not AreAllVehicleWindowsIntact(veh) then return true end
    for door = 0, 5 do
        if GetVehicleDoorAngleRatio(veh, door) > 0.05 then return true end
    end
    if IsVehicleAConvertible(veh, false) and GetConvertibleRoofState(veh) ~= 0 then return true end
    return false
end

local function occlusion(listenerInterior, listenerRoom, speakerInterior, speakerEntity)
    if listenerInterior ~= speakerInterior then return 2 end
    if listenerInterior ~= 0 and speakerEntity and listenerRoom ~= 0 then
        local room = GetRoomKeyFromEntity(speakerEntity)
        if room ~= 0 and room ~= listenerRoom then return 1 end
    end
    return 0
end

local wasAudible = false

CreateThread(function()
    while true do
        local playing = false
        for _, sys in pairs(Systems) do
            if sys.now then playing = true break end
        end

        if not playing then
            if wasAudible then
                SendNUIMessage({ action = 'tick', s = {} })
                wasAudible = false
            end
            Wait(500)
        else
            Wait(100)
            local ped = cache.ped
            local cam = GetFinalRenderedCamCoord()
            local rot = GetFinalRenderedCamRot(2)
            local h, p = math.rad(rot.z), math.rad(rot.x)
            local fwd = { -math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p) }
            local here = GetEntityCoords(ped)
            local myInterior = GetInteriorFromEntity(ped)
            local myRoom = myInterior ~= 0 and GetRoomKeyFromEntity(ped) or 0
            local myVehicle = cache.vehicle or 0
            local bucket = MyBucket()

            local out, any = {}, false
            local index = bySystem()
            for id, sys in pairs(Systems) do
                if sys.now and (sys.bucket or 0) == bucket then
                    local list = {}
                    if sys.kind == 'vehicle' then
                        local veh = sys.netId and NetworkDoesNetworkIdExist(sys.netId) and NetworkGetEntityFromNetworkId(sys.netId) or 0
                        if veh ~= 0 and DoesEntityExist(veh) then
                            local c = GetEntityCoords(veh)
                            local r = sys.range or Config.CarStereo.radius
                            if veh == myVehicle then
                                list[1] = { id = 'veh', x = cam.x, y = cam.y, z = cam.z, r = r, o = 0 }
                            elseif #(here - c) < r + 5.0 then
                                local o = vehicleIsOpen(veh) and (myInterior ~= 0 and 2 or 0) or 3
                                list[1] = { id = 'veh', x = c.x, y = c.y, z = c.z + 0.4, r = r, o = o }
                            end
                        end
                    else
                        for _, sp in ipairs(index[id] or {}) do
                            if (sp.bucket or 0) == bucket then
                                local info = SpeakerInfo(sp)
                                local r = sys.range or (info and info.radius) or 20.0
                                local pos = vector3(sp.x, sp.y, sp.z)
                                if #(here - pos) < r + 5.0 then
                                    local sInterior = sp.interior or GetInteriorAtCoords(sp.x, sp.y, sp.z)
                                    list[#list + 1] = {
                                        id = sp.id, x = sp.x, y = sp.y, z = sp.z + 0.3, r = r,
                                        o = occlusion(myInterior, myRoom, sInterior, sp.entity),
                                    }
                                end
                            end
                        end
                    end
                    if #list > 0 then
                        out[id] = list
                        any = true
                    end
                end
            end

            if any or wasAudible then
                SendNUIMessage({ action = 'tick', l = { p = { cam.x, cam.y, cam.z }, f = fwd }, s = out })
            end
            wasAudible = any
        end
    end
end)
