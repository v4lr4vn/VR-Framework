local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })
local bodyCam, faceCam
local camMode = 'body'
local charPed
local loadScreenShutdown = false
local cachedSkins = {}
local randomModels = { `mp_m_freemode_01`, `mp_f_freemode_01` }
local previewToken = 0
local previewCm

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    return HasModelLoaded(model)
end

local function pedscale() return GetResourceState('vr-pedscale') == 'started' end

-- ---------------------------------------------------------------------------
-- Cameras: a wide shot of the ped, and a close one on the face
-- ---------------------------------------------------------------------------
local function updateFaceCam()
    if not faceCam then return end
    local p = Config.PedCoords
    local feet = p.z - 0.98
    local headZ = feet + ((previewCm or 175) / 100.0) * 0.92
    local rad = math.rad(p.w)
    SetCamCoord(faceCam, p.x - math.sin(rad) * 1.15, p.y + math.cos(rad) * 1.15, headZ + 0.02)
    PointCamAtCoord(faceCam, p.x, p.y, headZ - 0.02)
end

local function setCamMode(mode)
    if not bodyCam or not faceCam then return end
    mode = mode == 'face' and 'face' or 'body'
    if mode == camMode then return end
    camMode = mode
    updateFaceCam()
    if mode == 'face' then
        SetCamActiveWithInterp(faceCam, bodyCam, 650, 1, 1)
    else
        SetCamActiveWithInterp(bodyCam, faceCam, 650, 1, 1)
    end
end

local function destroyCams()
    if bodyCam then SetCamActive(bodyCam, false); DestroyCam(bodyCam, true); bodyCam = nil end
    if faceCam then SetCamActive(faceCam, false); DestroyCam(faceCam, true); faceCam = nil end
end

local function skyCam(enable)
    if enable then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        destroyCams()
        camMode = 'body'
        local c = Config.CamCoords
        bodyCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, c.w, 60.0, false, 0)
        faceCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, c.w, 32.0, false, 0)
        updateFaceCam()
        SetCamActive(bodyCam, true)
        RenderScriptCams(true, false, 1, true, true)
    else
        SetTimecycleModifier('default')
        destroyCams()
        RenderScriptCams(false, false, 1, true, true)
    end
end

-- ---------------------------------------------------------------------------
-- The preview ped
-- ---------------------------------------------------------------------------
local function applyPreviewHeight()
    if pedscale() then
        if charPed and previewCm then
            exports['vr-pedscale']:SetPreview(charPed, previewCm)
        else
            exports['vr-pedscale']:ClearPreview()
        end
    end
    updateFaceCam()
end

local function setPreviewHeight(cm)
    previewCm = tonumber(cm)
    applyPreviewHeight()
end

local function deletePreviewPed()
    if charPed and DoesEntityExist(charPed) then
        SetEntityAsMissionEntity(charPed, true, true)
        DeleteEntity(charPed)
    end
    charPed = nil
    if pedscale() then exports['vr-pedscale']:ClearPreview() end
end

local function playIdle(ped)
    local a = Config.IdleAnim
    if not a or not a.dict or not a.name then return end
    RequestAnimDict(a.dict)
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded(a.dict) and GetGameTimer() < deadline do Wait(0) end
    if HasAnimDictLoaded(a.dict) and DoesEntityExist(ped) then
        TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function nextToken()
    previewToken = previewToken + 1
    return previewToken
end

-- token: pass the one you got from nextToken() if you waited on something before calling,
-- so that a slower, older request can never replace a newer ped.
local function createPreviewPed(model, appearance, token)
    token = token or nextToken()
    if type(model) == 'string' then model = tonumber(model) or joaat(model) end
    if not model or not loadModel(model) then
        model = randomModels[math.random(#randomModels)]
        appearance = nil
        loadModel(model)
    end
    if token ~= previewToken then return end
    deletePreviewPed()
    local ped = CreatePed(2, model, Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 0.98, Config.PedCoords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetPedComponentVariation(ped, 0, 0, 0, 2)
    SetEntityInvincible(ped, true)
    PlaceObjectOnGroundProperly(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if appearance and GetResourceState('vr-clothing') == 'started' then
        exports['vr-clothing']:setPedAppearance(ped, appearance)
    end
    charPed = ped
    applyPreviewHeight()
    playIdle(ped)
end

-- ---------------------------------------------------------------------------
-- Opening and closing the menu
-- ---------------------------------------------------------------------------
local function openCharMenu(open)
    VRCore.Functions.TriggerCallback('vr-multicharacter:server:GetNumberOfCharacters', function(slots, countries)
        SetNuiFocus(open, open)
        SendNUIMessage({
            action = 'open',
            heightLimits = pedscale() and exports['vr-pedscale']:GetLimits() or nil,
            customNationality = Config.customNationality,
            slots = slots,
            enableDeleteButton = Config.EnableDeleteButton,
            minAge = Config.MinAge,
            tagline = Config.Tagline,
            countries = countries,
        })
        skyCam(open)
        if not loadScreenShutdown then
            ShutdownLoadingScreenNui()
            loadScreenShutdown = true
        end
    end)
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    TriggerEvent('vr-multicharacter:client:chooseChar')
end)

local function loadPreviewIpl()
    if not Config.InteriorIpl then return end
    for _, ipl in ipairs(Config.InteriorIplVariants or {}) do
        if IsIplActive(ipl) then return end
    end
    RequestIpl(Config.InteriorIpl)
end

RegisterNetEvent('vr-multicharacter:client:chooseChar', function()
    TriggerEvent('vr-multicharacter:client:spawnReset')
    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    loadPreviewIpl()
    Wait(1000)
    local interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z)
    if interior == 0 then interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z - 18.9) end
    if interior ~= 0 then
        LoadInterior(interior)
        local deadline = GetGameTimer() + 5000
        while not IsInteriorReady(interior) and GetGameTimer() < deadline do Wait(100) end
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityCoords(ped, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z)
    Wait(1500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    openCharMenu(true)
end)

RegisterNetEvent('vr-multicharacter:client:closeNUI', function()
    deletePreviewPed()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    skyCam(false)
end)

RegisterNetEvent('vr-multicharacter:client:createFailed', function(message)
    DoScreenFadeIn(300)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'createFailed', message = message })
end)

-- ---------------------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------------------
RegisterNUICallback('selectCharacter', function(data, cb)
    DoScreenFadeOut(10)
    TriggerEvent('vr-multicharacter:client:chosen', data.cData)
    TriggerServerEvent('vr-multicharacter:server:loadUserData', data.cData)
    openCharMenu(false)
    deletePreviewPed()
    cb('ok')
end)

RegisterNUICallback('cDataPed', function(data, cb)
    local cData = data.cData
    cb('ok')
    local token = nextToken()
    if not cData then
        previewCm = pedscale() and exports['vr-pedscale']:GetLimits().default or nil
        return createPreviewPed(nil, nil, token)
    end
    previewCm = cData.charinfo and tonumber(cData.charinfo.height) or nil

    local cached = cachedSkins[cData.citizenid]
    if not cached then
        local p = promise.new()
        VRCore.Functions.TriggerCallback('vr-multicharacter:server:getSkin', function(model, skin)
            p:resolve({ model = model, skin = skin })
        end, cData.citizenid)
        cached = Citizen.Await(p)
        cachedSkins[cData.citizenid] = cached
    end
    if token ~= previewToken then return end

    local appearance = cached.skin and json.decode(cached.skin)
    createPreviewPed(cached.model or (appearance and appearance.model), appearance, token)
end)

RegisterNUICallback('previewHeight', function(data, cb)
    cb('ok')
    setPreviewHeight(data and data.height)
end)

RegisterNUICallback('previewGender', function(data, cb)
    cb('ok')
    createPreviewPed(tonumber(data and data.gender) == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`)
end)

RegisterNUICallback('camView', function(data, cb)
    cb('ok')
    setCamMode(data and data.view)
end)

RegisterNUICallback('rotate', function(data, cb)
    cb('ok')
    if charPed and DoesEntityExist(charPed) then
        local deg = tonumber(data and data.deg) or 0
        SetEntityHeading(charPed, (GetEntityHeading(charPed) + deg) % 360.0)
    end
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    VRCore.Functions.TriggerCallback('vr-multicharacter:server:setupCharacters', function(characters)
        cachedSkins = {}
        SendNUIMessage({ action = 'characters', characters = characters })
        cb('ok')
    end)
end)

RegisterNUICallback('removeBlur', function(_, cb)
    SetTimecycleModifier('default')
    cb('ok')
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    DoScreenFadeOut(150)
    local g = tonumber(data.gender)
    if g == nil then g = (data.gender == Lang:t('ui.female')) and 1 or 0 end
    data.gender = g
    TriggerServerEvent('vr-multicharacter:server:createCharacter', data)
end)

RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('vr-multicharacter:server:deleteCharacter', data.citizenid)
    deletePreviewPed()
    TriggerEvent('vr-multicharacter:client:chooseChar')
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreviewPed()
    skyCam(false)
    SetNuiFocus(false, false)
end)
