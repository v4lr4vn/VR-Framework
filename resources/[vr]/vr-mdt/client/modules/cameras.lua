local active = nil
local starting = false

local KEY = {
    lookX = 1,
    lookY = 2,
    left = 174,
    right = 175,
    up = 172,
    down = 173,
    prev = 34,
    next = 35,
    zoomIn = 44,
    zoomOut = 38,
    scrollUp = 241,
    scrollDown = 242,
    back = 194,
    esc = 200,
    pause = 199,
    talk = 249,
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function pressed(control)
    return IsDisabledControlPressed(0, control)
end

local function tapped(control)
    return IsDisabledControlJustPressed(0, control)
end

local function blockControls()
    DisableAllControlActions(0)
    DisableControlAction(0, KEY.pause, true)
    DisableControlAction(0, KEY.esc, true)
    EnableControlAction(0, KEY.talk, true)
    HideHudAndRadarThisFrame()
end

local function wantsExit()
    return tapped(KEY.back) or tapped(KEY.esc)
end

local function cleanIds(list, current)
    local out, seen = {}, {}
    if type(list) == 'table' then
        for i = 1, math.min(#list, 200) do
            local id = math.tointeger(tonumber(list[i]))
            if id and id > 0 and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    if not seen[current] then table.insert(out, 1, current) end
    return out
end

local function indexOf(list, id)
    for i, v in ipairs(list) do
        if v == id then return i end
    end
    return 1
end

local function hud(v)
    if not v.cam then return end
    local cfg = Config.Cameras
    Mdt.send({
        type = 'camera',
        show = true,
        mode = v.mode,
        id = v.id,
        label = v.label,
        location = v.location,
        index = v.index,
        count = v.list and #v.list or nil,
        zoom = U.round(cfg.fov.max / (v.fov or cfg.fov.max), 1),
        live = v.live,
        busy = v.busy == true,
    })
end

local function restore(v)
    if v.cam and DoesCamExist(v.cam) then
        SetCamActive(v.cam, false)
        DestroyCam(v.cam, false)
    end
    v.cam = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()
    ClearFocus()
    if IsNewLoadSceneActive() then NewLoadSceneStop() end
    if v.frozen then FreezeEntityPosition(Bridge.cache.ped, false) end
    v.frozen = false
    if not IsScreenFadedIn() then DoScreenFadeIn(250) end
    Mdt.send({ type = 'camera', show = false })
end

local function finish(v)
    restore(v)
    if active == v then active = nil end
    Mdt.showTablet()
end

local function begin(v)
    active = v
    Mdt.hideTablet()
    local ped = Bridge.cache.ped
    if not IsPedInAnyVehicle(ped, false) then
        FreezeEntityPosition(ped, true)
        v.frozen = true
    end
end

local function stillValid(v)
    if active ~= v or v.stop then return false end
    if not Mdt.open then return false end
    if IsPedDeadOrDying(Bridge.cache.ped, true) then return false end
    return true
end

local function loadScene(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    if not NewLoadSceneStartSphere(x, y, z, 60.0, 0) then return end
    local deadline = GetGameTimer() + Config.Cameras.loadTimeout
    while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do Wait(50) end
    NewLoadSceneStop()
end

local function revealWhenLoaded(v, x, y, z)
    CreateThread(function()
        loadScene(x, y, z)
        if active == v and not v.stop then DoScreenFadeIn(250) end
    end)
end

local function applyCctv(v, data)
    v.id = data.id
    v.label = data.label
    v.location = data.location
    v.base = { x = data.x + 0.0, y = data.y + 0.0, z = data.z + 0.0, heading = data.heading + 0.0, pitch = data.pitch + 0.0 }
    v.yaw, v.pitchOffset = 0.0, 0.0
    v.fov = clamp(data.fov + 0.0, Config.Cameras.fov.min, Config.Cameras.fov.max)
    v.index = indexOf(v.list, data.id)
    SetFocusPosAndVel(v.base.x, v.base.y, v.base.z, 0.0, 0.0, 0.0)
    SetCamCoord(v.cam, v.base.x, v.base.y, v.base.z)
    SetCamRot(v.cam, v.base.pitch, 0.0, v.base.heading, 2)
    SetCamFov(v.cam, v.fov)
end

local function switchCamera(v, step)
    if v.busy or #v.list < 2 then return end
    v.busy = true
    local target = v.list[((v.index - 1 + step) % #v.list) + 1]
    CreateThread(function()
        local res = Mdt.request('cameras.view', { id = target })
        if active ~= v or v.stop then return end
        if not res or not res.ok then
            v.busy = false
            Bridge.notify("That camera isn't available.", 'error')
            return
        end
        DoScreenFadeOut(120)
        Wait(140)
        if active ~= v or v.stop then return end
        applyCctv(v, res.data)
        hud(v)
        loadScene(v.base.x, v.base.y, v.base.z)
        if active == v then DoScreenFadeIn(220) end
        v.busy = false
        hud(v)
    end)
end

local function steerCctv(v)
    local cfg = Config.Cameras
    local dt = GetFrameTime()
    local scale = v.fov / cfg.fov.max
    local yaw = v.yaw - GetDisabledControlNormal(0, KEY.lookX) * cfg.mouseSpeed * scale
    local pitch = v.pitchOffset - GetDisabledControlNormal(0, KEY.lookY) * cfg.mouseSpeed * scale
    local step = cfg.keySpeed * dt * scale
    if pressed(KEY.left) then yaw = yaw + step end
    if pressed(KEY.right) then yaw = yaw - step end
    if pressed(KEY.up) then pitch = pitch + step end
    if pressed(KEY.down) then pitch = pitch - step end
    v.yaw = clamp(yaw, -cfg.yawRange, cfg.yawRange)
    v.pitchOffset = clamp(pitch, -cfg.pitchRange, cfg.pitchRange)
    local fov = v.fov
    if tapped(KEY.scrollUp) then fov = fov - cfg.zoomStep end
    if tapped(KEY.scrollDown) then fov = fov + cfg.zoomStep end
    if pressed(KEY.zoomIn) then fov = fov - cfg.zoomSpeed * dt end
    if pressed(KEY.zoomOut) then fov = fov + cfg.zoomSpeed * dt end
    fov = clamp(fov, cfg.fov.min, cfg.fov.max)
    local zoomChanged = math.abs(fov - (v.sentFov or fov)) >= 1.0
    v.fov = fov
    local pitchAbs = clamp(v.base.pitch + v.pitchOffset, -89.0, 89.0)
    SetCamRot(v.cam, pitchAbs, 0.0, v.base.heading + v.yaw, 2)
    SetCamFov(v.cam, v.fov)
    if zoomChanged then
        v.sentFov = fov
        hud(v)
    end
    if tapped(KEY.prev) then switchCamera(v, -1) end
    if tapped(KEY.next) then switchCamera(v, 1) end
end

local function runCctv(data, list)
    local cfg = Config.Cameras
    local v = { mode = 'cctv', list = cleanIds(list, data.id) }
    begin(v)
    local ok, err = pcall(function()
        DoScreenFadeOut(150)
        Wait(170)
        v.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', data.x + 0.0, data.y + 0.0, data.z + 0.0, data.pitch + 0.0, 0.0, data.heading + 0.0, data.fov + 0.0, true, 2)
        RenderScriptCams(true, false, 0, true, true)
        SetTimecycleModifier(cfg.timecycle)
        SetTimecycleModifierStrength(cfg.timecycleStrength)
        applyCctv(v, data)
        v.sentFov = v.fov
        hud(v)
        revealWhenLoaded(v, v.base.x, v.base.y, v.base.z)
        while stillValid(v) do
            blockControls()
            if wantsExit() then break end
            steerCctv(v)
            Wait(0)
        end
    end)
    if not ok then print(('^1[vr-mdt] camera view: %s^0'):format(tostring(err))) end
    v.stop = true
    finish(v)
end

local function followBodycam(v)
    local cfg = Config.Cameras.bodycam
    local player = GetPlayerFromServerId(v.serverId)
    local ped = player ~= -1 and GetPlayerPed(player) or 0
    if ped ~= 0 and DoesEntityExist(ped) then
        local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
        local heading = GetEntityHeading(ped)
        local r = math.rad(heading)
        SetCamCoord(v.cam, head.x - math.sin(r) * cfg.forward, head.y + math.cos(r) * cfg.forward, head.z - cfg.drop)
        SetCamRot(v.cam, cfg.pitch, 0.0, heading, 2)
        if v.focusPed ~= ped then
            SetFocusEntity(ped)
            v.focusPed = ped
        end
        return true
    end
    local c = v.coords
    SetCamCoord(v.cam, c.x + 0.0, c.y + 0.0, c.z + 0.65)
    SetCamRot(v.cam, cfg.pitch, 0.0, (v.heading or 0.0) + 0.0, 2)
    if v.focusPed or v.focusAt ~= c then
        SetFocusPosAndVel(c.x + 0.0, c.y + 0.0, c.z + 0.0, 0.0, 0.0, 0.0)
        v.focusPed = nil
        v.focusAt = c
    end
    return false
end

local function pollBodycam(v)
    CreateThread(function()
        while active == v and not v.stop do
            Wait(v.refresh)
            if active ~= v or v.stop then break end
            local res = Mdt.request('bodycams.pos', { cid = v.cid })
            if active ~= v or v.stop then break end
            if res and res.ok and type(res.data) == 'table' and type(res.data.coords) == 'table' then
                v.coords = res.data.coords
                v.heading = tonumber(res.data.heading) or v.heading
                v.serverId = tonumber(res.data.serverId) or v.serverId
            elseif res and res.error == 'slow_down' then
                Wait(250)
            else
                v.ended = res and res.error or 'unit_unavailable'
                v.stop = true
            end
        end
    end)
end

local function runBodycam(info)
    local cfg = Config.Cameras.bodycam
    local v = {
        mode = 'bodycam',
        cid = info.cid,
        id = info.cid,
        serverId = tonumber(info.serverId) or -1,
        coords = info.coords,
        heading = tonumber(info.heading) or 0.0,
        label = info.callsign or info.name,
        location = info.name,
        fov = cfg.fov,
        refresh = math.max(tonumber(info.refresh) or cfg.refreshMs, 1000),
        live = false,
    }
    begin(v)
    local ok, err = pcall(function()
        DoScreenFadeOut(150)
        Wait(170)
        local c = v.coords
        v.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x + 0.0, c.y + 0.0, c.z + 0.65, cfg.pitch, 0.0, v.heading + 0.0, cfg.fov, true, 2)
        RenderScriptCams(true, false, 0, true, true)
        ShakeCam(v.cam, 'HAND_SHAKE', cfg.shake)
        SetTimecycleModifier(cfg.timecycle)
        SetTimecycleModifierStrength(cfg.timecycleStrength)
        SetFocusPosAndVel(c.x + 0.0, c.y + 0.0, c.z + 0.0, 0.0, 0.0, 0.0)
        v.focusAt = c
        hud(v)
        revealWhenLoaded(v, c.x + 0.0, c.y + 0.0, c.z + 0.0)
        pollBodycam(v)
        while stillValid(v) do
            blockControls()
            if wantsExit() then break end
            local live = followBodycam(v)
            if live ~= v.live then
                v.live = live
                hud(v)
            end
            Wait(0)
        end
    end)
    if not ok then print(('^1[vr-mdt] bodycam view: %s^0'):format(tostring(err))) end
    v.stop = true
    finish(v)
    CreateThread(function() Mdt.request('bodycams.stop', {}) end)
    if v.ended then
        Bridge.notify('The bodycam feed ended.', 'inform')
    end
end

local function launch(fn, payload)
    CreateThread(function()
        starting = false
        fn(payload)
    end)
end

Mdt.callback('viewCamera', function(data)
    if active or starting then return { ok = false, error = 'busy' } end
    local id = math.tointeger(tonumber(data.id))
    if not id or id < 1 then return { ok = false, error = 'bad_request' } end
    starting = true
    local res = Mdt.request('cameras.view', { id = id })
    if not res or not res.ok or type(res.data) ~= 'table' or not Mdt.open then
        starting = false
        return { ok = false, error = res and res.error or 'server_error' }
    end
    local list = data.list
    launch(function(cam) runCctv(cam, list) end, res.data)
    return { ok = true }
end)

Mdt.callback('viewBodycam', function(data)
    if active or starting then return { ok = false, error = 'busy' } end
    if type(data.cid) ~= 'string' then return { ok = false, error = 'bad_request' } end
    starting = true
    local res = Mdt.request('bodycams.start', { cid = data.cid })
    if not res or not res.ok or type(res.data) ~= 'table' or type(res.data.coords) ~= 'table' or not Mdt.open then
        starting = false
        if res and res.ok then CreateThread(function() Mdt.request('bodycams.stop', {}) end) end
        return { ok = false, error = res and res.error or 'server_error' }
    end
    launch(runBodycam, res.data)
    return { ok = true }
end)

Bridge.on('playerUnloaded', function()
    if active then active.stop = true end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not active then return end
    local v = active
    v.stop = true
    active = nil
    restore(v)
end)

local placing = false

-- Same method the heist creator uses: a poller thread casts the ray from the
-- rendered camera and the draw loop just reads the latest answer every frame.
local RAY = { running = false, stamp = 0, distance = 80.0, point = nil, normal = nil, origin = nil }

local function castRay(distance)
    local origin = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local flat = math.abs(math.cos(rx))
    local target = origin + vector3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx)) * distance
    local handle = StartShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, 1 | 2 | 16, PlayerPedId(), 4)
    for _ = 1, 30 do
        local retval, hit, point, normal = GetShapeTestResultIncludingMaterial(handle)
        if retval ~= 1 then
            if hit == 1 and point then return point, normal, origin end
            return nil, nil, origin
        end
        Wait(0)
    end
    return nil, nil, origin
end

local function aimRay(distance)
    RAY.distance, RAY.stamp = distance, GetGameTimer()
    if not RAY.running then
        RAY.running, RAY.point, RAY.normal = true, nil, nil
        CreateThread(function()
            while GetGameTimer() - RAY.stamp < 500 do
                local ok, point, normal, origin = pcall(castRay, RAY.distance)
                if ok then
                    RAY.point, RAY.normal, RAY.origin = point, normal, origin
                else
                    RAY.point, RAY.normal = nil, nil
                    print(('^1[vr-mdt] aim ray failed: %s^0'):format(tostring(point)))
                    Wait(500)
                end
                Wait(0)
            end
            RAY.running, RAY.point, RAY.normal = false, nil, nil
        end)
    end
    return RAY.point, RAY.normal, RAY.origin or GetFinalRenderedCamCoord()
end

local function lookAngles(from, to)
    local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
    local flat = math.sqrt(dx * dx + dy * dy)
    local heading = math.deg(math.atan(-dx, dy)) % 360.0
    local pitch = math.deg(math.atan(dz, math.max(flat, 0.001)))
    return heading, pitch
end

-- Drawn on screen every frame, so it does not depend on any text UI resource.
local function prompt(text)
    SetTextFont(4)
    SetTextScale(0.0, 0.45)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.9)
end

local BLOCKED = { 24, 25, 14, 15, 16, 17, 37, 44, 140, 141, 142, 199, 200, 257, 263, 264 }

local function dot(point, origin, size, r, g, b, a)
    local scale = math.max(size, #(point - origin) * 0.012)
    DrawMarker(28, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, scale, r, g, b, a, false, false, 2, false, nil, nil, false)
end

local function aimCamera()
    local cfg = Config.Cameras
    local range = cfg.aimRange or 80.0
    local mount = nil
    local result = nil
    Mdt.hideTablet()
    SetNuiFocusKeepInput(false)
    Wait(150)
    local deadline = GetGameTimer() + 600
    while IsDisabledControlPressed(0, 24) and GetGameTimer() < deadline do Wait(0) end
    Wait(100)
    local notified = false
    Bridge.notify('Camera placing: aim at the wall or pole and left click', 'inform')
    while true do
        Wait(0)
        DrawRect(0.5, 0.5, 0.0035, 0.0006, 255, 176, 0, 230)
        DrawRect(0.5, 0.5, 0.0006, 0.0035 * 16.0 / 9.0, 255, 176, 0, 230)
        local skipCancel = false
        DisablePlayerFiring(PlayerId(), true)
        for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
        local point, normal, origin = aimRay(range)
        if not mount then
            prompt('Aim at the wall or pole  ~g~[Left click]~w~ place the mount   ~r~[Right click]~w~ cancel')
            if point then
                dot(point, origin, 0.14, 255, 176, 0, 200)
                DrawLine(point.x, point.y, point.z, point.x, point.y, point.z + 1.0, 255, 176, 0, 220)
            elseif not notified then
                notified = true
                Bridge.notify('Aim at a wall or pole within reach', 'inform')
            end
            if IsDisabledControlJustPressed(0, 24) and point then
                mount = point + (normal or vector3(0.0, 0.0, 0.0)) * 0.12
                Wait(150)
            end
        else
            local heading, pitch = 0.0, cfg.pitch.default
            if point then
                heading, pitch = lookAngles(mount, point)
                pitch = clamp(pitch, cfg.pitch.min, cfg.pitch.max)
                DrawLine(mount.x, mount.y, mount.z, point.x, point.y, point.z, 255, 176, 0, 220)
                dot(point, origin, 0.12, 255, 255, 255, 200)
            end
            dot(mount, origin, 0.2, 255, 176, 0, 230)
            prompt(('Aim at what it should watch  ~g~[Left click]~w~ place the camera (tilt %d)   ~r~[Right click]~w~ redo the mount'):format(math.floor(pitch + 0.5)))
            if IsDisabledControlJustPressed(0, 24) and point then
                result = { at = { x = mount.x, y = mount.y, z = mount.z }, heading = heading, pitch = pitch }
                break
            end
            if IsDisabledControlJustPressed(0, 25) then
                mount = nil
                Wait(150)
                skipCancel = true
            end
        end
        if not skipCancel and not mount and IsDisabledControlJustPressed(0, 25) then break end
        if IsDisabledControlJustPressed(0, 200) then break end
        if IsPedDeadOrDying(PlayerPedId(), true) then break end
    end
    Wait(100)
    Mdt.showTablet()
    return result
end

Mdt.preRequest['cameras.add'] = function(data)
    if placing then return nil end
    placing = true
    -- Run the aiming in its own thread (like the heist creator does) and wait for
    -- the answer, so the drawing never depends on the NUI callback it came from.
    local done = promise.new()
    CreateThread(function()
        local ok, aimed = pcall(aimCamera)
        done:resolve({ ok = ok, aimed = aimed })
    end)
    local out = Citizen.Await(done)
    placing = false
    if not out.ok then
        print(('^1[vr-mdt] camera placing failed: %s^0'):format(tostring(out.aimed)))
        Bridge.notify('Camera placing failed, see the F8 console', 'error')
        Mdt.showTablet()
        return nil
    end
    local aimed = out.aimed
    if not aimed then return nil end
    data.at = aimed.at
    data.heading = aimed.heading
    data.pitch = aimed.pitch
    return data
end
