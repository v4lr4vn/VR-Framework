local mutedPlayers = {}

local volumes = {
    radio = GetConvarInt('voice_defaultRadioVolume', 60) / 100,
    call = GetConvarInt('voice_defaultCallVolume', 60) / 100,
    click_on = GetConvarInt('voice_onClickVolume', 10) / 100,
    click_off = GetConvarInt('voice_offClickVolume', 3) / 100,
}

radioEnabled, radioPressed, mode = true, false, GetConvarInt('voice_defaultVoiceMode', 2)
radioData = {}
callData = {}
submixIndicies = {}

function setVolume(volume, volumeType)
    type_check({ volume, 'number' })
    local fraction = volume / 100
    if volumeType then
        if not volumes[volumeType] then error(('setVolume got a invalid volume type %s'):format(volumeType)) end
        LocalPlayer.state:set(volumeType, volume, false)
        volumes[volumeType] = fraction
        resyncVolume(volumeType, fraction)
    else
        for vType in pairs(volumes) do
            volumes[vType] = fraction
            LocalPlayer.state:set(vType, volume, false)
        end
        resyncVolume('all', fraction)
    end
end

VoiceExport('setRadioVolume', function(vol) setVolume(vol, 'radio') end)
VoiceExport('getRadioVolume', function() return volumes.radio * 100 end)
VoiceExport('setCallVolume', function(vol) setVolume(vol, 'call') end)
VoiceExport('getCallVolume', function() return volumes.call * 100 end)
VoiceExport('setMicClickOnVolume', function(vol) setVolume(vol, 'click_on') end)
VoiceExport('getMicClickOnVolume', function() return volumes.click_on * 100 end)
VoiceExport('setMicClickOffVolume', function(vol) setVolume(vol, 'click_off') end)
VoiceExport('getMicClickOffVolume', function() return volumes.click_off * 100 end)

local radioEffectId = CreateAudioSubmix('Radio')
SetAudioSubmixEffectRadioFx(radioEffectId, 0)
SetAudioSubmixEffectParamInt(radioEffectId, 0, GetHashKey('default'), 1)
SetAudioSubmixOutputVolumes(radioEffectId, 0, 1.0, 0.25, 0.0, 0.0, 1.0, 1.0)
AddAudioSubmixOutput(radioEffectId, 0)
submixIndicies.radio = radioEffectId

local callEffectId = CreateAudioSubmix('Call')
SetAudioSubmixOutputVolumes(callEffectId, 1, 0.10, 0.50, 0.0, 0.0, 1.0, 1.0)
AddAudioSubmixOutput(callEffectId, 1)
submixIndicies.call = callEffectId

VoiceExport('registerCustomSubmix', function(callback)
    local submixTable = callback()
    type_check({ submixTable, 'table' })
    local submixName, submixId = submixTable[1], submixTable[2]
    type_check({ submixName, 'string' }, { submixId, 'number' })
    logger.info('Creating submix %s with submixId %s', submixName, submixId)
    submixIndicies[submixName] = submixId
end)
VoiceEmit('registerCustomSubmixes')

VoiceExport('setEffectSubmix', function(type, effectId)
    type_check({ type, 'string' }, { effectId, 'number' })
    if submixIndicies[type] then submixIndicies[type] = effectId end
end)

function restoreDefaultSubmix(plyServerId)
    local submix = Player(plyServerId).state.submix
    local effect = submixIndicies[submix]
    MumbleSetSubmixForServerId(plyServerId, (submix and effect) or -1)
end

local disableSubmixReset = {}

function toggleVoice(plySource, enabled, moduleType)
    if mutedPlayers[plySource] then return end
    logger.verbose('[main] Updating %s to talking: %s with submix %s', plySource, enabled, moduleType)
    local distance = currentTargets[plySource]
    if enabled and (not distance or distance > 4.0) then
        MumbleSetVolumeOverrideByServerId(plySource, volumes[moduleType] or -1.0)
        if Settings.enableSubmix then
            if moduleType then
                disableSubmixReset[plySource] = true
                if submixIndicies[moduleType] then MumbleSetSubmixForServerId(plySource, submixIndicies[moduleType]) end
            else
                restoreDefaultSubmix(plySource)
            end
        end
    elseif not enabled then
        if Settings.enableSubmix then
            disableSubmixReset[plySource] = nil
            SetTimeout(250, function()
                if not disableSubmixReset[plySource] then restoreDefaultSubmix(plySource) end
            end)
        end
        MumbleSetVolumeOverrideByServerId(plySource, -1.0)
    end
end

local function updateVolumes(voiceTable, override)
    for serverId, talking in pairs(voiceTable) do
        if serverId ~= playerServerId then
            MumbleSetVolumeOverrideByServerId(serverId, talking and override or -1.0)
        end
    end
end

function resyncVolume(volumeType, newVolume)
    if volumeType == 'all' then
        resyncVolume('radio', newVolume)
        resyncVolume('call', newVolume)
    elseif volumeType == 'radio' then
        updateVolumes(radioData, newVolume)
    elseif volumeType == 'call' then
        updateVolumes(callData, newVolume)
    end
end

function addVoiceTargets(...)
    local added = { [playerServerId] = true }
    local targets = { ... }
    for i = 1, #targets do
        for id in pairs(targets[i]) do
            if not added[id] then
                logger.verbose('[main] Adding %s as a voice target', id)
                added[id] = true
                MumbleAddVoiceTargetPlayerByServerId(voiceTarget, id)
            end
        end
    end
end

function playMicClicks(clickType)
    if micClicks ~= true then return logger.verbose('Not playing mic clicks because client has them disabled') end
    sendUIMessage({
        sound = clickType and 'audio_on' or 'audio_off',
        volume = clickType and volumes.click_on or volumes.click_off,
    })
end

VoiceExport('isPlayerMuted', function(source) return mutedPlayers[source] end)
VoiceExport('getMutedPlayers', function() return mutedPlayers end)

function toggleMutePlayer(source)
    if mutedPlayers[source] then
        mutedPlayers[source] = nil
        MumbleSetVolumeOverrideByServerId(source, -1.0)
    else
        mutedPlayers[source] = true
        MumbleSetVolumeOverrideByServerId(source, 0.0)
    end
end
VoiceExport('toggleMutePlayer', toggleMutePlayer)

function setVoiceProperty(type, value)
    if type == 'radioEnabled' then
        radioEnabled = value
        handleRadioEnabledChanged(value)
        sendUIMessage({ radioEnabled = value })
    elseif type == 'micClicks' then
        micClicks = value == true or value == 'true'
        SetResourceKvp('vr-voice_enableMicClicks', tostring(micClicks))
    end
end
VoiceExport('setVoiceProperty', setVoiceProperty)
VoiceExport('SetMumbleProperty', setVoiceProperty)
VoiceExport('SetTokoProperty', setVoiceProperty)

function handleRadioAndCallInit()
    for tgt, enabled in pairs(radioData) do
        if tgt ~= playerServerId then toggleVoice(tgt, enabled, 'radio') end
    end
    for tgt in pairs(callData) do
        if tgt ~= playerServerId then toggleVoice(tgt, true, 'call') end
    end
end
