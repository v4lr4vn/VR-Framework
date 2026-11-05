Design = { clone = nil, real = nil, netId = nil }

function Design.open(real)
    if Design.clone or not real or not DoesEntityExist(real) then return end
    if IsPedInAnyVehicle(cache.ped, false) then return Mech.notify(Mech.errorText('in_vehicle'), 'error') end
    local netId = NetworkGetNetworkIdFromEntity(real)
    local res = Mech.api('design.open', { netId = netId })
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    local model = GetEntityModel(real)
    if not lib.requestModel(model, 5000) then return Mech.notify(Mech.errorText('failed'), 'error') end
    local c, rot = GetEntityCoords(real), GetEntityRotation(real, 2)
    local clone = CreateVehicle(model, c.x, c.y, c.z, GetEntityHeading(real), false, false)
    SetModelAsNoLongerNeeded(model)
    if not clone or clone == 0 then return Mech.notify(Mech.errorText('failed'), 'error') end
    SetEntityCollision(clone, false, false)
    FreezeEntityPosition(clone, true)
    SetEntityCoordsNoOffset(clone, c.x, c.y, c.z, false, false, false)
    SetEntityRotation(clone, rot.x, rot.y, rot.z, 2, true)
    SetEntityInvincible(clone, true)
    SetVehicleDoorsLocked(clone, 2)
    local props = lib.getVehicleProperties(real) or {}
    lib.setVehicleProperties(clone, props)
    SetVehicleDirtLevel(clone, GetVehicleDirtLevel(real))
    Design.clone, Design.real, Design.netId = clone, real, netId
    CreateThread(function()
        while Design.clone do
            if Design.real and DoesEntityExist(Design.real) then SetEntityLocallyInvisible(Design.real) end
            Wait(0)
        end
    end)
    Mech.netId = netId
    local d = Tuning.beginDesign(clone, real, props, res.data)
    Mech.show('tune', d)
    Cam.start(clone)
end

function Design.close()
    if not Design.clone then return end
    Cam.stop()
    if DoesEntityExist(Design.clone) then DeleteEntity(Design.clone) end
    Design.clone, Design.real, Design.netId = nil, nil, nil
    Tuning.reset()
end

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Design.close() end
end)
