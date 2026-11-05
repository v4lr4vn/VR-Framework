local radioChannel = 0
radioListeners = radioListeners or {}
listenData = listenData or {}
local radioNames = {}
local disableRadioAnim = false
local radioAnim = { dict = 'random@arrests', anim = 'generic_radio_enter' }

function isRadioEnabled()
    return radioEnabled and LocalPlayer.state.disableRadio == 0
end

function syncRadioData(radioTable, localPlyRadioName)
    radioData = radioTable
    logger.info('[radio] Syncing radio table.')
    if voiceDebugLevel >= 4 then
        print('-------- RADIO TABLE --------')
        tPrint(radioData)
        print('-----------------------------')
    end
    local isEnabled = isRadioEnabled()
    if isEnabled then handleRadioAndCallInit() end
    sendUIMessage({ radioChannel = radioChannel, radioEnabled = isEnabled })
    if Settings.syncPlayerNames then radioNames[playerServerId] = localPlyRadioName end
end
RegisterNetEvent('vr-voice:syncRadioData', syncRadioData)

function setTalkingOnRadio(plySource, enabled)
    radioData[plySource] = enabled
    VoiceEmit('radioTalking', plySource, enabled == true)
    if not isRadioEnabled() then
        return logger.info('[radio] Ignoring setTalkingOnRadio. radioEnabled: %s disableRadio: %s', radioEnabled, LocalPlayer.state.disableRadio)
    end

    local active = enabled or callData[plySource]
    toggleVoice(plySource, active, 'radio')
    playMicClicks(active)
end
RegisterNetEvent('vr-voice:setTalkingOnRadio', setTalkingOnRadio)

function addPlayerToRadio(plySource, plyRadioName)
    radioData[plySource] = false
    if Settings.syncPlayerNames then radioNames[plySource] = plyRadioName end
    logger.info('[radio] %s joined radio %s %s', plySource, radioChannel, radioPressed and ' while we were talking, adding them to targets' or '')
    if radioPressed then addVoiceTargets(radioData, radioListeners, callData) end
end
RegisterNetEvent('vr-voice:addPlayerToRadio', addPlayerToRadio)

function removePlayerFromRadio(plySource)
    if plySource == playerServerId then
        logger.info('[radio] Left radio %s, cleaning up.', radioChannel)
        for tgt in pairs(radioData) do
            if tgt ~= playerServerId then toggleVoice(tgt, false, 'radio') end
        end
        sendUIMessage({ radioChannel = 0, radioEnabled = radioEnabled })
        radioNames = {}
        radioData = {}
        radioListeners = {}
        addVoiceTargets(callData)
        return
    end
    toggleVoice(plySource, false, 'radio')
    if radioPressed then
        logger.info('[radio] %s left radio %s while we were talking, updating targets.', plySource, radioChannel)
        addVoiceTargets(radioData, radioListeners, callData)
    else
        logger.info('[radio] %s has left radio %s', plySource, radioChannel)
    end
    radioData[plySource] = nil
    if Settings.syncPlayerNames then radioNames[plySource] = nil end
end
RegisterNetEvent('vr-voice:removePlayerFromRadio', removePlayerFromRadio)

RegisterNetEvent('vr-voice:radioChangeRejected', function()
    logger.info('The server rejected your radio change.')
    radioChannel = 0
end)

function setRadioChannel(channel)
    if not Settings.enableRadios then return end
    type_check({ channel, 'number' })
    TriggerServerEvent('vr-voice:setPlayerRadio', channel)
    radioChannel = channel
end

VoiceExport('setRadioChannel', setRadioChannel)
VoiceExport('SetRadioChannel', setRadioChannel)
VoiceExport('removePlayerFromRadio', function() setRadioChannel(0) end)
VoiceExport('addPlayerToRadio', function(radio)
    radio = tonumber(radio)
    if radio then setRadioChannel(radio) end
end)

VoiceExport('toggleRadioAnim', function()
    disableRadioAnim = not disableRadioAnim
    VoiceEmit('toggleRadioAnim', disableRadioAnim)
end)
VoiceExport('setDisableRadioAnim', function(shouldDisable) disableRadioAnim = shouldDisable end)
VoiceExport('getRadioAnimState', function() return disableRadioAnim end)

function isDead()
    return LocalPlayer.state.isDead == true or isTrue(IsPlayerDead(PlayerId()))
end

function isRadioAnimEnabled()
    return Settings.enableRadioAnim
        and not (Settings.disableVehicleRadioAnim and IsPedInAnyVehicle(PlayerPedId(), false))
        and not disableRadioAnim
end

RegisterCommand('+radiotalk', function()
    if not Settings.enableRadios or isDead() or not isRadioEnabled() or radioPressed then return end
    if radioChannel <= 0 then return logger.info('Player tried to talk but was not on a radio channel') end

    logger.info('[radio] Start broadcasting, update targets and notify server.')
    addVoiceTargets(radioData, radioListeners, callData)
    TriggerServerEvent('vr-voice:setTalkingOnRadio', true)
    radioPressed = true
    local playAnim = isRadioAnimEnabled()
    playMicClicks(true)

    local dict, anim = radioAnim.dict, radioAnim.anim
    if playAnim then RequestAnimDict(dict) end

    CreateThread(function()
        VoiceEmit('radioActive', true)
        LocalPlayer.state:set('radioActive', true, false)
        local checkFailed = false
        while radioPressed do
            local ped = PlayerPedId()
            if radioChannel < 0 or isDead() or not isRadioEnabled()
                or (Settings.disableRadioWhenShooting and IsPedShooting(ped)) then
                checkFailed = true
                break
            end
            if playAnim and HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 8.0, 2.0, -1, 50, 2.0, false, false, false)
            end

            SetControlNormal(0, 249, 1.0)
            SetControlNormal(1, 249, 1.0)
            SetControlNormal(2, 249, 1.0)
            Wait(0)
        end
        if checkFailed then
            logger.info('Canceling radio talking as the checks have failed.')
            ExecuteCommand('-radiotalk')
        end
        if playAnim then RemoveAnimDict(dict) end
    end)
end, false)

RegisterCommand('-radiotalk', function()
    if radioChannel <= 0 or not radioPressed then return end
    radioPressed = false
    MumbleClearVoiceTargetPlayers(voiceTarget)
    addVoiceTargets(callData)
    VoiceEmit('radioActive', false)
    LocalPlayer.state:set('radioActive', false, false)
    playMicClicks(false)
    if Settings.enableRadioAnim then StopAnimTask(PlayerPedId(), radioAnim.dict, radioAnim.anim, -4.0) end
    TriggerServerEvent('vr-voice:setTalkingOnRadio', false)
end, false)
Keybinds.add({
    name = 'radiotalk',
    label = 'Talk on the radio',
    description = 'Hold to transmit on your radio channel',
    suggested = GetConvar('voice_defaultRadio', 'CAPITAL'),
    allowInUi = true,
    order = 10,
    onPressed = function() ExecuteCommand('+radiotalk') end,
    onReleased = function() ExecuteCommand('-radiotalk') end,
})

VoiceExport('setRadioTalkAnim', function(dict, anim)
    type_check({ dict, 'string' }, { anim, 'string' })
    if not DoesAnimDictExist(dict) then return error(('Dict: %s did not exist'):format(dict)) end
    radioAnim.dict, radioAnim.anim = dict, anim
end)

RegisterNetEvent('vr-voice:clSetPlayerRadio', function(newChannel)
    if not Settings.enableRadios then return end
    logger.info('[radio] radio set serverside update to radio %s', newChannel)
    radioChannel = newChannel
end)

function handleRadioEnabledChanged(enabled)
    if enabled then
        syncRadioData(radioData, '')
    else
        removePlayerFromRadio(playerServerId)
    end
end

VoiceExport('addRadioDisableBit', function(bit)
    LocalPlayer.state:set('disableRadio', (LocalPlayer.state.disableRadio or 0) | bit, false)
end)
VoiceExport('removeRadioDisableBit', function(bit)
    LocalPlayer.state:set('disableRadio', (LocalPlayer.state.disableRadio or 0) & (~bit), false)
end)
