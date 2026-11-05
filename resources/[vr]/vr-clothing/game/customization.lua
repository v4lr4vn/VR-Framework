local Logger = require("modules.utility.shared.logger")
local Bridge = require("game.bridge")

local bridgeToggle = nil
local playerAppearance = nil
local config = nil
local isCameraInterpolating = nil
local currentCameraKey = nil
local activeCamera = nil
local savedCoords = nil
local savedHeading = nil
local onExitCallback = nil

local function getAppearance()
    if not playerAppearance then
        Logger.debugf("[game] [customization] [getAppearance] variable `playerAppearance` was nil, calling getPedAppearance")
        playerAppearance = client.getPedAppearance(cache.ped)
    end
    return playerAppearance
end
client.getAppearance = getAppearance

function client.getConfig()
    return config
end

local function setCamera(cameraKey)
    if isCameraInterpolating then
        return Logger.infof("[game] [customization] [setCamera] returning since isCameraInterpolating is true, key: (%s)", cameraKey)
    end

    if cameraKey ~= "current" then
        currentCameraKey = cameraKey
    end

    local fromOffset, toOffset = table.unpack(constants.CAMERAS[currentCameraKey])
    local direction = bridgeToggle and -1 or 1

    if not activeCamera then
        local from = GetOffsetFromEntityInWorldCoords(cache.ped, fromOffset.x, fromOffset.y, fromOffset.z)
        local to = GetOffsetFromEntityInWorldCoords(cache.ped, toOffset.x, toOffset.y, toOffset.z)

        activeCamera = CreateCameraWithParams(
            "DEFAULT_SCRIPTED_CAMERA",
            from.x, from.y, from.z,
            0.0, 0.0, 0.0,
            49.0,
            false, 0
        )
        PointCamAtCoord(activeCamera, to.x, to.y, to.z)
        SetCamActive(activeCamera, true)
        return
    end

    local from = GetOffsetFromEntityInWorldCoords(cache.ped, fromOffset.x * direction, fromOffset.y * direction, fromOffset.z * direction)
    local to = GetOffsetFromEntityInWorldCoords(cache.ped, toOffset.x, toOffset.y, toOffset.z)

    local newCam = CreateCameraWithParams("DEFAULT_SCRIPTED_CAMERA", from.x, from.y, from.z, 0.0, 0.0, 0.0, 49.0, false, 0)
    PointCamAtCoord(newCam, to.x, to.y, to.z)
    SetCamActiveWithInterp(newCam, activeCamera, 1000, 1, 1)

    isCameraInterpolating = true

    CreateThread(function()
        repeat
            Wait(500)
        until not IsCamInterpolating(activeCamera) and IsCamActive(newCam)

        DestroyCam(activeCamera, false)
        activeCamera = newCam
        isCameraInterpolating = false
    end)
end
client.setCamera = setCamera

function client.rotateCamera(direction)
    if isCameraInterpolating then return end

    local fromOffset, toOffset = table.unpack(constants.CAMERAS[currentCameraKey])
    local offset = constants.OFFSETS[currentCameraKey]

    local leftRight = (direction == "left") and 1 or -1
    local flip = bridgeToggle and -1 or 1

    local from = GetOffsetFromEntityInWorldCoords(
        cache.ped,
        (fromOffset.x + offset.x) * leftRight * flip,
        (fromOffset.y + offset.y) * flip,
        fromOffset.z
    )

    local to = GetOffsetFromEntityInWorldCoords(cache.ped, toOffset.x, toOffset.y, toOffset.z)

    local newCam = CreateCameraWithParams("DEFAULT_SCRIPTED_CAMERA", from.x, from.y, from.z, 0.0, 0.0, 0.0, 49.0, false, 0)
    PointCamAtCoord(newCam, to.x, to.y, to.z)
    SetCamActiveWithInterp(newCam, activeCamera, 1000, 1, 1)

    isCameraInterpolating = true
    CreateThread(function()
        repeat
            Wait(500)
        until not IsCamInterpolating(activeCamera) and IsCamActive(newCam)

        DestroyCam(activeCamera, false)
        activeCamera = newCam
        isCameraInterpolating = false
    end)
end

function client.pedTurn(ped, headingOffset)
    bridgeToggle = not bridgeToggle
    local seq = OpenSequenceTask()
    if seq then
        TaskGoStraightToCoord(0, savedCoords.x, savedCoords.y, savedCoords.z, 8.0, -1, GetEntityHeading(ped) - headingOffset, 0.1)
        TaskStandStill(0, -1)
        CloseSequenceTask(seq)
        ClearPedTasks(ped)
        TaskPerformSequence(ped, seq)
        ClearSequenceTask(seq)
    end
end

function client.wearClothes(appearance, slot)
    local slotData = constants.DATA_CLOTHES[slot]
    local components = slotData.components[client.getPedDecorationType()]
    local props = slotData.props[client.getPedDecorationType()]

    for _, comp in ipairs(components) do
        for _, current in ipairs(appearance.components) do
            if current.component_id == comp[1] then
                SetPedComponentVariation(cache.ped, comp[1], current.drawable, current.texture, 2)
            end
        end
    end

    for _, prop in ipairs(props) do
        for _, current in ipairs(appearance.props) do
            if current.prop_id == prop[1] then
                SetPedPropIndex(cache.ped, prop[1], current.drawable, current.texture, true)
            end
        end
    end
end

function client.removeClothes(slot)
    local slotData = constants.DATA_CLOTHES[slot]
    local components = slotData.components[client.getPedDecorationType()]
    local props = slotData.props[client.getPedDecorationType()]

    for _, comp in ipairs(components) do
        SetPedComponentVariation(cache.ped, comp[1], comp[2], 0, 2)
    end

    for _, prop in ipairs(props) do
        ClearPedProp(cache.ped, prop[1])
    end
end

function client.getHeading()
    return savedHeading
end

function client.startPlayerCustomization(callback, settings)
    repeat Wait(0) until IsScreenFadedIn()
    repeat Wait(0) until not IsPlayerTeleportActive()
    repeat Wait(0) until not IsPlayerSwitchInProgress()

    playerAppearance = client.getPedAppearance(cache.ped)
    savedCoords = GetEntityCoords(cache.ped, true)
    savedHeading = GetEntityHeading(cache.ped)

    BackupPlayerStats()
    onExitCallback = callback
    config = settings or {}
    Logger.info("(customization) config value: ", config)
    Logger.info("(customization) settings value: ", settings)
    bridgeToggle = false
    isCameraInterpolating = false

    setCamera("default")
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    RenderScriptCams(true, true, 250, true, true)
    SetEntityInvincible(cache.ped, Config.InvincibleDuringCustomization)
    TaskStandStill(cache.ped, -1)

    lib.hideTextUI()
    if Config.HideRadar then DisplayRadar(false) end

    Bridge.onCustomizationStart()
    Logger.info("(customization) About to call syncCharacterAppearanceStateAndSettingsState with config: ", config)
    Interface:syncCharacterAppearanceStateAndSettingsState(config)
    Interface:toggle(true, true)
end

function client.exitPlayerCustomization(data)
    RenderScriptCams(false, true, 250, true, true)
    DestroyCam(activeCamera, false)

    if Config.HideRadar then DisplayRadar(true) end

    ClearPedTasksImmediately(cache.ped)
    SetEntityInvincible(cache.ped, false)
    Interface:toggle(false, true)

    if not data then
        client.setPlayerAppearance(getAppearance())
    else
        client.setPedTattoos(cache.ped, data.tattoos)
    end

    RestorePlayerStats()
    Bridge.onCustomizationExit()

    if onExitCallback then onExitCallback(data) end

    onExitCallback = nil
    config = nil
    playerAppearance = nil
    savedCoords = nil
    activeCamera = nil
    currentCameraKey = nil
    bridgeToggle = nil
    isCameraInterpolating = nil
end

AddEventHandler("onResourceStop", function(resName)
    if resName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

exports("startPlayerCustomization", client.startPlayerCustomization)
