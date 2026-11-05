Cam = {}

local cam, target, yaw, pitch, dist = nil, nil, 0.0, 12.0, 6.0

function Cam.place()
    if not cam or not target or not DoesEntityExist(target) then return end
    local c = GetEntityCoords(target)
    local ry, rp = math.rad(yaw), math.rad(pitch)
    local px = c.x + math.sin(ry) * math.cos(rp) * dist
    local py = c.y - math.cos(ry) * math.cos(rp) * dist
    local pz = c.z + 0.4 + math.sin(rp) * dist
    local shift = dist * 0.22
    SetCamCoord(cam, px, py, pz)
    PointCamAtCoord(cam, c.x + math.cos(ry) * shift, c.y + math.sin(ry) * shift, c.z + 0.2)
end

function Cam.start(veh)
    if not veh or not DoesEntityExist(veh) then return end
    target = veh
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local sx, sy, sz = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
    dist = math.max(4.5, math.sqrt(sx * sx + sy * sy + sz * sz) * 1.05 + 1.0)
    yaw = GetEntityHeading(veh) + 140.0
    pitch = 14.0
    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(cam, 50.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 600, true, true)
    end
    Cam.place()
end

function Cam.move(dx, dy, dz)
    if not cam then return end
    yaw = (yaw + (tonumber(dx) or 0) * 0.35) % 360
    pitch = math.max(-4.0, math.min(55.0, pitch + (tonumber(dy) or 0) * 0.2))
    dist = math.max(3.0, math.min(14.0, dist + (tonumber(dz) or 0)))
    Cam.place()
end

function Cam.active()
    return cam ~= nil
end

function Cam.stop()
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
    end
    cam, target = nil, nil
end

RegisterNUICallback('cam', function(d, cb)
    cb(true)
    if type(d) == 'table' then Cam.move(d.dx, d.dy, d.dz) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Cam.stop() end
end)
