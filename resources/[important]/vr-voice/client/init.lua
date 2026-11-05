AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    logger.info('Starting script initialization')

    local kvp = GetResourceKvpString('vr-voice_enableMicClicks')
    if kvp == 'true' or kvp == 'false' then
        micClicks = kvp == 'true'
    else
        if kvp then logger.warn('Mic click preference was corrupted, resetting it.') end
        SetResourceKvp('vr-voice_enableMicClicks', 'true')
        micClicks = true
    end

    sendUIMessage({
        uiEnabled = Settings.enableUi,
        voiceModes = json.encode(Cfg.voiceModes),
        voiceMode = mode - 1,
    })

    local radioChannel = LocalPlayer.state.radioChannel or 0
    local callChannel = LocalPlayer.state.callChannel or 0
    if radioChannel ~= 0 then setRadioChannel(radioChannel) end
    if callChannel ~= 0 then setCallChannel(callChannel) end
    if not LocalPlayer.state.disableRadio then LocalPlayer.state:set('disableRadio', 0, false) end

    logger.info('Script initialization finished.')
end)
