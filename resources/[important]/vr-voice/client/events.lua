isInitialized = false

function handleInitialState()
    local voiceModeData = Cfg.voiceModes[mode]
    MumbleSetTalkerProximity(voiceModeData[1] + 0.0)
    MumbleClearVoiceTarget(voiceTarget)
    MumbleSetVoiceTarget(voiceTarget)
    MumbleSetVoiceChannel(LocalPlayer.state.assignedChannel)

    while MumbleGetVoiceChannelFromServerId(playerServerId) ~= LocalPlayer.state.assignedChannel do
        Wait(100)
        MumbleSetVoiceChannel(LocalPlayer.state.assignedChannel)
    end

    isInitialized = true
    MumbleAddVoiceTargetChannel(voiceTarget, LocalPlayer.state.assignedChannel)
    addNearbyPlayers()
end

AddEventHandler('mumbleConnected', function(address, isReconnecting)
    logger.info('Connected to mumble server with address of %s, is this a reconnect %s',
        Settings.hideEndpoints and 'HIDDEN' or address, isReconnecting)
    local voiceModeData = Cfg.voiceModes[mode]
    LocalPlayer.state:set('proximity', { index = mode, distance = voiceModeData[1], mode = voiceModeData[2] }, false)
    handleInitialState()
    logger.info('Finished connection logic')
end)

AddEventHandler('mumbleDisconnected', function(address)
    isInitialized = false
    logger.info('Disconnected from mumble server with address of %s', Settings.hideEndpoints and 'HIDDEN' or address)
end)

VoiceOn('settingsCallback', function(cb)
    cb(Cfg)
end)
