-- The Camera app. While it is open the phone screen is only a viewfinder over the game. The mouse turns the viewfinder
-- (the back camera looks around from the player's eyes, the front camera circles the player's head) and these keys do the rest
-- (the screen shows the key hints):
--   Enter or left mouse   take a photo        R   switch between the back and the front camera
--   mouse wheel           zoom                T   timer (off, 3 s, 10 s)
--   Backspace or Esc      close the camera
--
-- Pictures come from the screenshot-basic resource, which captures the game without the phone on top of it.
local State = Phone.State
local Camera = {}
Phone.Camera = Camera

local FOV_MIN, FOV_MAX = 18.0, 70.0
local HEAD = 31086 -- SKEL_Head

local cam, front, fov = nil, false, 50.0
local timerIndex = 0
local counting = false

-- While a scripted camera is on screen the game's own camera stops listening to the mouse, so the viewfinder turns itself.
-- rear: where the back camera looks.  orbit: where the selfie camera sits around the head (both in degrees).
local rear = { yaw = 0.0, pitch = 0.0 }
local orbit = { yaw = 0.0, pitch = 8.0 }
local lastLook = 0
local walk = { moving = false, at = 0, yaw = 0.0 }

local function cfg() return Config.Phone.Media or {} end

-- Front camera settings (see Config.Phone.Media.selfie).
local function selfie()
    local c = cfg().selfie or {}
    return c.distance or 0.62, c.aimHeight or -0.06, c.startPitch or 3.0
end

local function screenshotReady()
    local res = cfg().screenshotResource
    return res and GetResourceState(res) == 'started'
end

local function destroyCam()
    if cam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
    ClearFocus()
end

-- The direction a heading and a pitch point in.
local function direction(yaw, pitch)
    local y, p = math.rad(yaw), math.rad(pitch)
    return vec3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
end

local function headPos(ped)
    return GetPedBoneCoords(ped, HEAD, 0.0, 0.0, 0.0)
end

local function makeCam()
    if cam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
    local ped = PlayerPedId()
    local at = headPos(ped)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', at.x, at.y, at.z, 0.0, 0.0, 0.0, front and 52.0 or fov, true, 2)
    SetCamNearClip(cam, 0.08)
    SetCamUseShallowDofMode(cam, false)
    SetCamDofStrength(cam, 0.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- Walking with the back camera. The game's own walk controls follow its own camera, which the viewfinder does not turn,
-- so the keys are read here and the player is sent the way the viewfinder points: W goes where the lens looks,
-- A and D go left and right of it, S comes back towards it. Shift runs.
local function steer(ped)
    local lr = GetDisabledControlNormal(0, 30)   -- MOVE_LR  (right is positive)
    local ud = GetDisabledControlNormal(0, 31)   -- MOVE_UD  (forward is negative)
    if IsDisabledControlPressed(0, 32) then ud = -1.0 end
    if IsDisabledControlPressed(0, 33) then ud = 1.0 end
    if IsDisabledControlPressed(0, 34) then lr = -1.0 end
    if IsDisabledControlPressed(0, 35) then lr = 1.0 end
    local power = math.sqrt(lr * lr + ud * ud)
    if power < 0.2 or IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedClimbing(ped) or IsPedJumping(ped) then
        if walk.moving then
            walk.moving = false
            ClearPedTasks(ped)
            -- Putting the phone back in the hand after the walk task ends.
            if Phone.Prop and Phone.Prop.refresh then Phone.Prop.refresh() end
        end
        return
    end

    local yaw = math.rad(rear.yaw)
    local fx, fy = -math.sin(yaw), math.cos(yaw)
    local rx, ry = math.cos(yaw), math.sin(yaw)
    local dx, dy = fx * -ud + rx * lr, fy * -ud + ry * lr
    local len = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / len, dy / len
    local heading = math.deg(math.atan(-dx, dy)) % 360.0   -- GTA headings: 0 faces +y, turning left is positive

    local now = GetGameTimer()
    local changed = math.abs(((heading - walk.yaw + 540.0) % 360.0) - 180.0) > 12.0
    if not walk.moving or changed or now - walk.at > 350 then
        walk.moving, walk.at, walk.yaw = true, now, heading
        local speed = IsDisabledControlPressed(0, 21) and 2.0 or (power > 0.6 and 1.0 or 0.6)
        local at = GetEntityCoords(ped) + vec3(dx, dy, 0.0) * 4.0
        TaskGoStraightToCoord(ped, at.x, at.y, at.z, speed, -1, heading, 0.0)
    end
end

-- Runs every frame while the camera is on: places the camera and turns it with the mouse (or the right stick).
local function follow()
    if not cam then return end
    local ped = PlayerPedId()
    local head = headPos(ped)
    local look = GetDisabledControlNormal(0, 1) * -7.0   -- LOOK_LR
    local pitch = GetDisabledControlNormal(0, 2) * -7.0  -- LOOK_UD
    local inVehicle = IsPedInAnyVehicle(ped, false)

    -- The player's own view never shows the phone in the hand.
    local phone = Phone.Prop and Phone.Prop.entity()
    if phone then SetEntityLocallyInvisible(phone) end

    if front then
        orbit.yaw = (orbit.yaw + look) % 360.0
        orbit.pitch = math.max(-20.0, math.min(40.0, orbit.pitch + pitch))
        local distance, aim = selfie()
        local from = head + direction(orbit.yaw, orbit.pitch) * distance
        SetCamCoord(cam, from.x, from.y, from.z)
        PointCamAtCoord(cam, head.x, head.y, head.z + aim)
        SetCamFov(cam, 52.0)
        SetFocusPosAndVel(from.x, from.y, from.z, 0.0, 0.0, 0.0)

        if not inVehicle then
            -- Face the camera, with the arm held out towards it, and look into the lens.
            local heading = GetEntityHeading(ped)
            local diff = ((orbit.yaw - heading + 540.0) % 360.0) - 180.0
            SetEntityHeading(ped, (heading + diff * 0.25) % 360.0)
        end
        local now = GetGameTimer()
        if now - lastLook > 400 then
            lastLook = now
            TaskLookAtCoord(ped, from.x, from.y, from.z, 1500, 0, 2)
        end
    else
        rear.yaw = (rear.yaw + look) % 360.0
        rear.pitch = math.max(-80.0, math.min(80.0, rear.pitch + pitch))
        -- A little in front of the face, so the head and hair are not in the picture.
        local from = head + direction(rear.yaw, rear.pitch) * 0.22
        SetCamCoord(cam, from.x, from.y, from.z)
        SetCamRot(cam, rear.pitch, 0.0, rear.yaw, 2)
        SetCamFov(cam, fov)
        SetFocusPosAndVel(from.x, from.y, from.z, 0.0, 0.0, 0.0)
        if not inVehicle then
            SetGameplayCamRawYaw(rear.yaw)
            steer(ped)
        end
    end
    OverrideLodscaleThisFrame(1.0)
end

local function timerSeconds()
    local list = cfg().timerSeconds or { 3, 10 }
    return timerIndex > 0 and list[timerIndex] or 0
end

local function shoot()
    if counting or not State.camera then return end
    counting = true
    local wait = timerSeconds()
    for left = wait, 1, -1 do
        send('cameraCount', left)
        Wait(1000)
        if not State.camera then
            counting = false
            return
        end
    end
    send('cameraCount', 0)
    -- The viewfinder hides for a moment so nothing of the phone can end up in the picture.
    send('cameraHide', true)
    Wait(150)
    local res = cfg().screenshotResource
    local done = false
    local ok = pcall(function()
        exports[res]:requestScreenshot({ encoding = 'jpg', quality = 0.9 }, function(data)
            done = true
            send('cameraHide', false)
            if type(data) == 'string' and data ~= '' then send('cameraShot', data) else send('cameraFail', 'capture') end
        end)
    end)
    if not ok then
        send('cameraHide', false)
        send('cameraFail', 'capture')
    else
        -- Do not wait forever for a picture that never comes.
        local waited = 0
        while not done and waited < 5000 do
            Wait(50)
            waited = waited + 50
        end
        if not done then
            send('cameraHide', false)
            send('cameraFail', 'capture')
        end
    end
    counting = false
end

-- The controls. The keys and the on-screen buttons both end up here.
function Camera.shoot()
    if State.camera then CreateThread(shoot) end
end

function Camera.flip()
    if not State.camera then return false end
    front = not front
    local ped = PlayerPedId()
    if front then
        local _, _, startPitch = selfie()
        orbit.yaw, orbit.pitch = GetEntityHeading(ped), startPitch
        lastLook = 0
    else
        TaskClearLookAt(ped)
        walk.moving = false
        rear.yaw, rear.pitch = GetEntityHeading(ped), 0.0
    end
    if Phone.Prop then Phone.Prop.selfie(front) end
    makeCam()
    send('cameraSide', front)
    return front
end

function Camera.cycleTimer()
    local list = cfg().timerSeconds or { 3, 10 }
    timerIndex = (timerIndex + 1) % (#list + 1)
    local seconds = timerSeconds()
    send('cameraTimer', seconds)
    return seconds
end

function Camera.zoomBy(step)
    if front or not State.camera then return end
    fov = math.max(FOV_MIN, math.min(FOV_MAX, fov + step))
    send('cameraZoom', math.floor((FOV_MAX - fov) / (FOV_MAX - FOV_MIN) * 100))
end

local function loop()
    CreateThread(function()
        while State.camera do
            -- The game keeps the mouse while the camera is on, so keys do the work.
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 14, true)  -- weapon wheel next / previous
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 45, true)  -- reload
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 1, true)   -- the mouse turns the viewfinder, not the player's camera
            DisableControlAction(0, 2, true)
            if front then
                -- A selfie is taken standing still: the player faces the camera.
                for _, control in ipairs({ 21, 22, 23, 30, 31, 32, 33, 34, 35, 36 }) do DisableControlAction(0, control, true) end
            elseif not IsPedInAnyVehicle(PlayerPedId(), false) then
                -- The back camera steers the player itself (see steer), so the game's own walking is switched off.
                for _, control in ipairs({ 30, 31, 32, 33, 34, 35 }) do DisableControlAction(0, control, true) end
            end

            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 191) then
                Camera.shoot()
            end
            if IsDisabledControlJustPressed(0, 45) then Camera.flip() end
            if IsControlJustPressed(0, 245) then Camera.cycleTimer() end
            if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 241) then Camera.zoomBy(-3.0) end
            if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 242) then Camera.zoomBy(3.0) end
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                send('cameraExit', true)
            end
            follow()
            Wait(0)
        end
    end)
end

-- The Camera app opened. Returns { ok = true } or { ok = false, reason = ... }.
function Camera.start()
    if State.camera then return { ok = true } end
    if not screenshotReady() then return { ok = false, reason = 'no_screenshot' } end
    State.camera = true
    front, fov, timerIndex, counting = false, math.max(FOV_MIN, math.min(FOV_MAX, GetGameplayCamFov())), 0, false
    -- Start looking where the player was looking.
    local rot = GetGameplayCamRot(2)
    rear.yaw, rear.pitch = rot.z % 360.0, math.max(-80.0, math.min(80.0, rot.x))
    makeCam()
    follow()
    -- No cursor while the camera is on: the mouse turns the camera.
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    loop()
    return { ok = true, side = 'back', zoom = math.floor((FOV_MAX - fov) / (FOV_MAX - FOV_MIN) * 100) }
end

function Camera.stop()
    if not State.camera then return end
    State.camera = false
    counting = false
    destroyCam()
    local ped = PlayerPedId()
    TaskClearLookAt(ped)
    if walk.moving then
        walk.moving = false
        ClearPedTasks(ped)
        if Phone.Prop and Phone.Prop.refresh then Phone.Prop.refresh() end
    end
    if front then
        front = false
        if State.open and Phone.Prop then Phone.Prop.selfie(false) end
    end
    -- The player's own camera carries on from where the viewfinder was pointing.
    SetGameplayCamRawYaw(rear.yaw)
    SetGameplayCamRawPitch(rear.pitch)
    if State.open then Phone.applyFocus() end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then destroyCam() end
end)

-- Splits a photo into pieces the server accepts, sends them, and returns the server's answer.
-- picture = { data, thumb, width, height } (data and thumb are JPEG data URIs).
local PART = 24000

function Camera.upload(picture)
    local whole = picture.data .. '\n' .. picture.thumb
    local total = math.ceil(#whole / PART)
    local id = ('%x%x'):format(GetGameTimer(), math.random(0, 0xFFFF))
    local begin = lib.callback.await('vr-phone:media:begin', false, { id = id, total = total })
    if type(begin) ~= 'table' or not begin.ok then return begin or { ok = false, reason = 'timeout' } end
    for i = 1, total do
        local part = whole:sub((i - 1) * PART + 1, i * PART)
        local r = lib.callback.await('vr-phone:media:part', false, { id = id, index = i, part = part })
        if type(r) ~= 'table' or not r.ok then return r or { ok = false, reason = 'timeout' } end
    end
    return lib.callback.await('vr-phone:media:save', false, { id = id, width = picture.width, height = picture.height }) or { ok = false, reason = 'timeout' }
end
