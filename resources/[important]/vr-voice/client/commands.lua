local wasProximityDisabledFromOverride = false
disableProximityCycle = false

RegisterCommand('setvoiceintent', function(_, args)
    if not Settings.allowSetIntent then return end
    local intent = args[1]
    if intent == 'speech' then
        MumbleSetAudioInputIntent(`speech`)
    elseif intent == 'music' then
        MumbleSetAudioInputIntent(`music`)
    else
        return
    end
    LocalPlayer.state:set('voiceIntent', intent, false)
end)
TriggerEvent('chat:addSuggestion', '/setvoiceintent', 'Sets the players voice intent', {
    { name = 'intent', help = 'speech is default and enables noise suppression & high pass filter, music disables both of these.' },
})

RegisterCommand('vol', function(_, args)
    local volume = tonumber(args[1])
    if not volume then return end
    setVolume(math.max(0, math.min(100, volume)))
end)
TriggerEvent('chat:addSuggestion', '/vol', 'Sets the radio/phone volume', {
    { name = 'volume', help = 'A range between 1-100 on how loud you want them to be' },
})

VoiceExport('setAllowProximityCycleState', function(state)
    type_check({ state, 'boolean' })
    disableProximityCycle = state
end)

function setProximityState(proximityRange, isCustom)
    local voiceModeData = Cfg.voiceModes[mode]
    MumbleSetTalkerProximity(proximityRange + 0.0)
    LocalPlayer.state:set('proximity', {
        index = mode,
        distance = proximityRange,
        mode = isCustom and 'Custom' or voiceModeData[2],
    }, false)

    sendUIMessage({ voiceMode = isCustom and #Cfg.voiceModes or mode - 1 })
end

VoiceExport('overrideProximityRange', function(range, disableCycle)
    type_check({ range, 'number' })
    setProximityState(range, true)
    if disableCycle then
        disableProximityCycle = true
        wasProximityDisabledFromOverride = true
    end
end)

VoiceExport('clearProximityOverride', function()
    setProximityState(Cfg.voiceModes[mode][1], false)
    if wasProximityDisabledFromOverride then disableProximityCycle = false end
end)

RegisterCommand('cycleproximity', function()
    if not Settings.enableProximityCycle or disableProximityCycle then return end
    mode = mode < #Cfg.voiceModes and mode + 1 or 1
    setProximityState(Cfg.voiceModes[mode][1], false)
    VoiceEmit('setTalkingMode', mode)
end, false)
Keybinds.add({
    name = 'cycleproximity',
    label = 'Change voice range',
    description = 'Cycle how far your voice carries',
    suggested = GetConvar('voice_defaultCycle', 'F11'),
    allowInUi = true,
    order = 20,
    onPressed = function() ExecuteCommand('cycleproximity') end,
})

local isSecondaryPttPressed = false
RegisterCommand('+secondary_ptt', function()
    if isSecondaryPttPressed then return end
    isSecondaryPttPressed = true
    CreateThread(function()
        while isSecondaryPttPressed do
            SetControlNormal(0, 249, 1.0)
            SetControlNormal(1, 249, 1.0)
            SetControlNormal(2, 249, 1.0)
            Wait(0)
        end
    end)
end)
RegisterCommand('-secondary_ptt', function()
    isSecondaryPttPressed = false
end)
RegisterKeyMapping('+secondary_ptt', 'A keybind that lets you have a secondary PTT', 'PAD_ANALOGBUTTON', GetConvar('voice_defaultSecondary', 'LUP_INDEX'))
