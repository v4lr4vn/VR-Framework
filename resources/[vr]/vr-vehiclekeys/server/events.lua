Bridge.on('playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    Db.onReady(function() Keys.push(src) end)
end)

AddEventHandler('playerDropped', function()
    local info = Core.info(source)
    if info then Keys.shared[info.cid] = nil end
end)

RegisterNetEvent('vr-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not Bridge.isAdmin(src) then return end
    plate = KU.plate(plate)
    local info = Core.info(src)
    if not plate or not info then return end
    Keys.grantTemp(info.cid, plate, Config.Keys.tempMinutes)
    Keys.push(src)
end)

AddEventHandler('vr-garages:server:jobVehicleOut', function(plate, cid, group, model, src)
    src = tonumber(src)
    if not src or not plate then return end
    local info = Core.info(src)
    if not info then return end
    Keys.grantTemp(info.cid, plate, Config.Keys.tempMinutes)
    Keys.push(src)
end)

AddEventHandler('vr-garages:server:jobVehicleReturned', function(plate)
    Keys.pushAll(Keys.clearTemp(plate))
end)

AddEventHandler('vr-garages:server:ownerChanged', function(plate, cid)
    local old = Keys.ownerOf(plate)
    Keys.forget(plate)
    if old then Keys.pushCid(old) end
    if cid then Keys.pushCid(cid) end
end)

AddEventHandler('vr-banking:server:vehicleSeized', function(plate)
    Keys.pushAll(Keys.clearTemp(plate))
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local a, b = Keys.platesOf(entity)
    if a then Keys.pushAll(Keys.clearTemp(a)) end
    if b then Keys.pushAll(Keys.clearTemp(b)) end
end)
