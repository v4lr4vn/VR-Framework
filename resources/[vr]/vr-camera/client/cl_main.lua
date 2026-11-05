local camera = false
local photo = false
local fov_max = 80.0
local fov_min = 5.0
local zoomspeed = 10.0
local speed_lr = 8.0
local speed_ud = 8.0
local fov = (fov_max+fov_min)*0.5

local cameraprop = nil
local photoprop = nil

local sessionToken = nil

local function HideHUDThisFrame()
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()
    HideHudComponentThisFrame(1)
    HideHudComponentThisFrame(2)
    HideHudComponentThisFrame(3)
    HideHudComponentThisFrame(4)
    HideHudComponentThisFrame(6)
    HideHudComponentThisFrame(7)
    HideHudComponentThisFrame(8)
    HideHudComponentThisFrame(9)
    HideHudComponentThisFrame(13)
    HideHudComponentThisFrame(11)
    HideHudComponentThisFrame(12)
    HideHudComponentThisFrame(15)
    HideHudComponentThisFrame(18)
    HideHudComponentThisFrame(19)
end

local function CheckInputRotation(cam, zoomvalue)
    local rightAxisX = GetDisabledControlNormal(0, 220)
    local rightAxisY = GetDisabledControlNormal(0, 221)
    local rotation = GetCamRot(cam, 2)
    if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
        local new_z = rotation.z + rightAxisX*-1.0*(speed_ud)*(zoomvalue+0.1)
        local new_x = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(speed_lr)*(zoomvalue+0.1)), -89.5)
        SetCamRot(cam, new_x, 0.0, new_z, 2)
        if not IsPedSittingInAnyVehicle(PlayerPedId()) then
            SetEntityHeading(PlayerPedId(), new_z)
        end
    end
end

local function HandleZoom(cam)
    local lPed = PlayerPedId()
    if not IsPedSittingInAnyVehicle(lPed) then
        if IsControlJustPressed(0,241) then
            fov = math.max(fov - zoomspeed, fov_min)
        end
        if IsControlJustPressed(0,242) then
            fov = math.min(fov + zoomspeed, fov_max)
        end
        local current_fov = GetCamFov(cam)
        if math.abs(fov-current_fov) < 0.1 then
            fov = current_fov
        end
        SetCamFov(cam, current_fov + (fov - current_fov)*0.05)
    else
        if IsControlJustPressed(0,17) then
            fov = math.max(fov - zoomspeed, fov_min)
        end
        if IsControlJustPressed(0,16) then
            fov = math.min(fov + zoomspeed, fov_max)
        end
        local current_fov = GetCamFov(cam)
        if math.abs(fov-current_fov) < 0.1 then
            fov = current_fov
        end
        SetCamFov(cam, current_fov + (fov - current_fov)*0.05)
    end
end

local function SharedRequestAnimDict(animDict, cb)
	if not HasAnimDictLoaded(animDict) then
		RequestAnimDict(animDict)

		while not HasAnimDictLoaded(animDict) do
			Citizen.Wait(1)
		end
	end
	if cb ~= nil then
		cb()
	end
end

local function LoadPropDict(model)
    while not HasModelLoaded(GetHashKey(model)) do
        RequestModel(GetHashKey(model))
        Wait(10)
    end
end

local function GetStreetNames()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local streetName, crossingRoad = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
    local streetNameText = GetStreetNameFromHashKey(streetName)
    local crossingRoadText = ""

    if crossingRoad ~= 0 then
        crossingRoadText = GetStreetNameFromHashKey(crossingRoad)
    end

    return streetNameText, crossingRoadText
end

local function SetLocation()
    local streetName, crossingRoad = GetStreetNames()

    if crossingRoad ~= "" then
        SendNUIMessage({action = "SetLocation", location = streetName .. " & " .. crossingRoad})
    else
        SendNUIMessage({action = "SetLocation", location = streetName})
    end
end

local doFlash = false
local function FlashLightEffect()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local lightPos = vector3(pos.x, pos.y, pos.z + 1.1)
    local lightHandle = nil
    CreateThread(function()
        local endTime = GetGameTimer() + 150
        while endTime > GetGameTimer() do
            lightHandle = DrawLightWithRangeAndShadow(lightPos.x, lightPos.y, lightPos.z, 15, 15, 15, 50.0, 10.0, 0.5, true)
            Wait(0)
        end
        if lightHandle ~= nil then
            lightHandle = nil
        end
    end)
end

local exportBusy = false

local function CaptureForExport(session)
    local quality = session.quality
    for _ = 1, 4 do
        local data, done = nil, false
        exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = quality }, function(result)
            data, done = result, true
        end)
        local deadline = GetGameTimer() + 5000
        while not done and GetGameTimer() < deadline do
            HideHUDThisFrame()
            Wait(0)
        end
        if type(data) ~= 'string' then return { ok = false, error = 'no_camera' } end
        if #data * 0.75 <= session.maxBytes then return { ok = true, data = data } end
        quality = quality - 0.15
        if quality < 0.2 then break end
    end
    return { ok = false, error = 'too_large' }
end

local function CameraLoop(session)
    local ped = PlayerPedId()

    SharedRequestAnimDict("amb@world_human_paparazzi@male@base", function()
        TaskPlayAnim(ped, "amb@world_human_paparazzi@male@base", "base", 2.0, 2.0, -1, 1, 0, false, false, false)
    end)

    local x, y, z = table.unpack(GetEntityCoords(ped))

    if not HasModelLoaded("ps_camera") then
        LoadPropDict("ps_camera")
    end

    cameraprop = CreateObject(GetHashKey("ps_camera"), x, y, z + 0.2, true, true, true)
    AttachEntityToEntity(cameraprop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded("ps_camera")

    CreateThread(function()
        local lPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(lPed)
        local tookPhoto = false
        Wait(500)

        SetTimecycleModifier("default")
        SetTimecycleModifierStrength(0.3)

        local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
        AttachCamToEntity(cam, lPed, 0.0, 1.0, 0.8, true)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(lPed), 2)
        SetCamFov(cam, fov)
        RenderScriptCams(true, false, 0, true, false)

        while camera and not IsEntityDead(lPed) and (GetVehiclePedIsIn(lPed) == vehicle) do
            if doFlash then
                SendNUIMessage({action = "toggleFlash", status = true})
            else
                SendNUIMessage({action = "toggleFlash", status = false})
            end
            if IsControlJustPressed(0, 177) then
                camera = false
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                ClearPedTasks(lPed)
                if cameraprop then DeleteEntity(cameraprop) end
            elseif IsControlJustPressed(0, 49) then
                doFlash = not doFlash
            elseif IsControlJustPressed(1, 176) and not tookPhoto then
                if doFlash then
                    FlashLightEffect()
                    Wait(100)
                end
                PlaySoundFrontend(-1, "Camera_Shoot", "Phone_Soundset_Franklin", false)

                if session then
                    tookPhoto = true
                    session.result = CaptureForExport(session)
                    camera = false
                elseif GetResourceState('screenshot-basic') == 'started' then
                    tookPhoto = true
                    local street, crossing = GetStreetNames()
                    local location = crossing ~= '' and (street .. ' & ' .. crossing) or street
                    local token = sessionToken
                    local shotDone = false
                    exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = Config.Quality }, function(data)
                        shotDone = true
                        TriggerLatentServerEvent('vr-camera:server:savePhoto', 200000, token, data, location)
                    end)
                    local deadline = GetGameTimer() + 5000
                    while not shotDone and GetGameTimer() < deadline do
                        HideHUDThisFrame()
                        Wait(0)
                    end
                    camera = false
                end
                ClearTimecycleModifier()
            end

            local zoomvalue = (1.0 / (fov_max - fov_min)) * (fov - fov_min)
            CheckInputRotation(cam, zoomvalue)
            HandleZoom(cam)
            HideHUDThisFrame()
            Wait(0)
        end
        camera = false
        if not session then
            if not tookPhoto then TriggerServerEvent('vr-camera:server:closeCamera') end
            sessionToken = nil
        end
        if cameraprop and DoesEntityExist(cameraprop) then DeleteEntity(cameraprop) end
        cameraprop = nil
        ClearPedTasks(lPed)
        ClearTimecycleModifier()
        fov = (fov_max + fov_min) * 0.5
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        SetNightvision(false)
        SetSeethrough(false)
        SendNUIMessage({action = "hideOverlay"})
        if session then
            session.p:resolve(session.result or { ok = false, error = 'cancelled' })
        end
    end)
end

RegisterNetEvent("vr-camera:client:usePhoto", function(url, location)
    if GetInvokingResource() then return end
    if exportBusy then return end
    photo = not photo

    if photo then
        SetNuiFocus(true, true);
        SendNUIMessage({action = "openPhoto", image = url, location = location})

        local ped = PlayerPedId()
        SharedRequestAnimDict("amb@world_human_tourist_map@male@base", function()
            TaskPlayAnim(ped, "amb@world_human_tourist_map@male@base", "base", 2.0, 2.0, -1, 1, 0, false, false, false)
        end)

        local coords = GetEntityCoords(ped)

        if not HasModelLoaded("prop_cs_planning_photo") then
            LoadPropDict("prop_cs_planning_photo")
        end

        photoprop = CreateObject(`prop_cs_planning_photo`, coords.x, coords.y, coords.z+0.2,  true,  true, true)
        AttachEntityToEntity(photoprop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded("prop_cs_planning_photo")
    end
end)

RegisterNUICallback("close", function(_, cb)
    cb({})
    SetNuiFocus(false, false)
    photo = false

    if photoprop then
        DeleteEntity(photoprop)
    end

    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('vr-camera:client:useCamera', function(token)
    if GetInvokingResource() then return end
    if exportBusy then
        TriggerServerEvent('vr-camera:server:closeCamera')
        return
    end
    if not camera then sessionToken = token end
    camera = not camera

    if camera then
        SendNUIMessage({action = "showOverlay"})

        CameraLoop()
    else
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        if cameraprop then
            DeleteEntity(cameraprop)
        end
        SendNUIMessage({action = "hideOverlay"})
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if cameraprop and DoesEntityExist(cameraprop) then DeleteEntity(cameraprop) end
    if photoprop and DoesEntityExist(photoprop) then DeleteEntity(photoprop) end
    if camera then
        RenderScriptCams(false, false, 0, true, false)
        ClearTimecycleModifier()
    end
end)

exports('TakePhoto', function(opts)
    opts = type(opts) == 'table' and opts or {}
    if camera or photo or exportBusy then return { ok = false, error = 'busy' } end
    if GetResourceState('screenshot-basic') ~= 'started' then return { ok = false, error = 'no_camera' } end
    if IsPedDeadOrDying(PlayerPedId(), true) then return { ok = false, error = 'unavailable' } end

    local quality = tonumber(opts.quality) or Config.Quality
    local session = {
        quality = math.min(math.max(quality, 0.2), 0.95),
        maxBytes = tonumber(opts.maxBytes) or Config.MaxPhotoBytes,
        p = promise.new(),
    }

    exportBusy = true
    camera = true
    SendNUIMessage({ action = 'showOverlay' })
    CameraLoop(session)

    local result = Citizen.Await(session.p)
    exportBusy = false
    return result
end)

exports('IsBusy', function()
    return camera or photo or exportBusy
end)
