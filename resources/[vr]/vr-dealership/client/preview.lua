Preview = {}

local veh, cam, heading, dealerId, dist, angle = nil, nil, 0.0, nil, 6.0, 35.0

local function place()
    if not veh or not cam then return end
    local c = GetEntityCoords(veh)
    local rad = math.rad(heading + angle)
    SetCamCoord(cam, c.x + math.sin(rad) * dist, c.y - math.cos(rad) * dist, c.z + 1.1)
    PointCamAtCoord(cam, c.x, c.y, c.z + 0.35)
end

function Preview.active()
    return veh ~= nil
end

function Preview.start(id, model, color)
    local def = (GlobalState.vrDealers or {})[id]
    if not def or not def.preview or type(model) ~= 'string' then return false end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 8000) then return false end
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    dealerId = id
    Dealer.hideDisplay(id, true)
    local p = def.preview
    veh = CreateVehicle(hash, p.x, p.y, p.z, p.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'PREVIEW')
    if tonumber(color) then SetVehicleColours(veh, tonumber(color), tonumber(color)) end
    heading = p.w
    local mn, mx = GetModelDimensions(hash)
    local size = #(vec3(mx.x, mx.y, mx.z) - vec3(mn.x, mn.y, mn.z))
    dist = math.max(4.5, size * 1.05 + 1.0)
    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(cam, 50.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
    end
    place()
    return true
end

function Preview.rotate(dx)
    if not veh then return end
    heading = (heading + (tonumber(dx) or 0)) % 360
    SetEntityHeading(veh, heading)
    place()
end

function Preview.zoom(dz)
    if not veh then return end
    dist = math.max(3.0, math.min(16.0, dist + (tonumber(dz) or 0)))
    place()
end

function Preview.color(c)
    if veh and tonumber(c) then SetVehicleColours(veh, tonumber(c), tonumber(c)) end
end

function Preview.stop()
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    veh = nil
    if dealerId then Dealer.hideDisplay(dealerId, false) end
    dealerId = nil
end

RegisterNUICallback('preview', function(d, cb)
    cb(Preview.start(Dealer.current, type(d) == 'table' and d.model, type(d) == 'table' and d.color) == true)
end)

RegisterNUICallback('previewRotate', function(d, cb)
    cb(true)
    if type(d) == 'table' then
        if d.dx then Preview.rotate(d.dx) end
        if d.dz then Preview.zoom(d.dz) end
    end
end)

RegisterNUICallback('previewColor', function(d, cb)
    cb(true)
    if type(d) == 'table' then Preview.color(d.color) end
end)

RegisterNUICallback('previewEnd', function(_, cb)
    cb(true)
    Preview.stop()
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Preview.stop() end
end)
