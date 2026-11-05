local HEAD_BONE = 31086

local shooting = false

local function frame(ped, fov)
    local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
    local forward = GetEntityForwardVector(ped)
    local pos = vector3(head.x + forward.x * 1.2, head.y + forward.y * 1.2, head.z + 0.03)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov or 38.0, false, 2)
    PointCamAtCoord(cam, head.x, head.y, head.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    return cam
end

local function unframe(cam)
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end
end

local function hideHudWhileShooting()
    CreateThread(function()
        while shooting do
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        end
    end)
end

local function countdown(seconds)
    for n = seconds, 1, -1 do
        Bridge.textUI.show(('Mugshot in %d  [Backspace] Cancel'):format(n))
        local untilAt = GetGameTimer() + 1000
        while GetGameTimer() < untilAt do
            if IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) or IsPedDeadOrDying(Bridge.cache.ped, true) then
                Bridge.textUI.hide()
                return false
            end
            Wait(0)
        end
    end
    Bridge.textUI.hide()
    Wait(120)
    return true
end

local function targetPed(serverId)
    local player = GetPlayerFromServerId(serverId)
    if not player or player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

function Mdt.captureMugshot(data)
    if shooting then return { ok = false, error = 'slow_down' } end
    if type(data.cid) ~= 'string' then return { ok = false, error = 'bad_request' } end
    local target = Mdt.request('mugshots.target', { cid = data.cid })
    if type(target) ~= 'table' or not target.ok then return { ok = false, error = type(target) == 'table' and target.error or 'server_error' } end
    local ped = targetPed(target.data.src)
    if not ped then return { ok = false, error = 'not_nearby' } end
    local cam
    shooting = true
    local id, err, url = Mdt.captureAndUpload('mugshot', function()
        Mdt.hideTablet()
        hideHudWhileShooting()
        cam = frame(ped, target.data.fov)
        return countdown(target.data.countdown or 3)
    end, function()
        unframe(cam)
        cam = nil
        shooting = false
        Mdt.showTablet()
    end)
    shooting = false
    if not id then return { ok = false, error = err } end
    return { ok = true, data = { id = id, url = url } }
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not shooting then return end
    shooting = false
    RenderScriptCams(false, false, 0, true, true)
    Bridge.textUI.hide()
end)
