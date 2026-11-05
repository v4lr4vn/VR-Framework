local disableUpdates = false
local isListenerEnabled = false
local plyCoords = GetEntityCoords(PlayerPedId())
local localPlayerId = PlayerId()
proximity = MumbleGetTalkerProximity()
currentTargets = {}

local listeners = {}

function orig_addProximityCheck(ply)
    local range = Settings.useNativeAudio and proximity * 3 or proximity
    local distance = #(plyCoords - GetEntityCoords(GetPlayerPed(ply)))
    return distance < range, distance
end

local addProximityCheck = orig_addProximityCheck

VoiceExport('overrideProximityCheck', function(fn)
    addProximityCheck = fn
end)

VoiceExport('resetProximityCheck', function()
    addProximityCheck = orig_addProximityCheck
end)

function addNearbyPlayers()
    if disableUpdates then return end
    plyCoords = GetEntityCoords(PlayerPedId())
    proximity = MumbleGetTalkerProximity()
    currentTargets = {}
    MumbleClearVoiceTargetChannels(voiceTarget)
    if LocalPlayer.state.disableProximity then return end
    MumbleAddVoiceChannelListen(LocalPlayer.state.assignedChannel)
    MumbleAddVoiceTargetChannel(voiceTarget, LocalPlayer.state.assignedChannel)

    for source in pairs(callData) do
        if source ~= playerServerId then
            local channel = MumbleGetVoiceChannelFromServerId(source)
            if channel ~= -1 then MumbleAddVoiceTargetChannel(voiceTarget, channel) end
        end
    end

    local players = GetActivePlayers()
    for i = 1, #players do
        local ply = players[i]
        if addProximityCheck(ply) then
            local channel = MumbleGetVoiceChannelFromServerId(GetPlayerServerId(ply))
            if channel ~= -1 then MumbleAddVoiceTargetChannel(voiceTarget, channel) end
        end
    end
end

function addChannelListener(serverId)
    local channel = MumbleGetVoiceChannelFromServerId(serverId)
    if channel ~= -1 then
        MumbleAddVoiceChannelListen(channel)
        logger.verbose('Adding %s to listen table', serverId)
    end
    listeners[serverId] = channel ~= -1
end

function removeChannelListener(serverId)
    if listeners[serverId] then
        local channel = MumbleGetVoiceChannelFromServerId(serverId)
        if channel ~= -1 then MumbleRemoveVoiceChannelListen(channel) end
        logger.verbose('Removing %s from listen table', serverId)
    end
    listeners[serverId] = nil
end

function setSpectatorMode(enabled)
    logger.info('Setting spectate mode to %s', enabled)
    isListenerEnabled = enabled
    local players = GetActivePlayers()
    for i = 1, #players do
        local serverId = GetPlayerServerId(players[i])
        if serverId ~= playerServerId then
            if enabled then addChannelListener(serverId) else removeChannelListener(serverId) end
        end
    end
    if not enabled then listeners = {} end
end

function tryListeningToFailedListeners()
    for src, isListening in pairs(listeners) do
        if not isListening then addChannelListener(src) end
    end
end

RegisterNetEvent('onPlayerJoining', function(serverId)
    if isListenerEnabled then addChannelListener(serverId) end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
    if isListenerEnabled then removeChannelListener(serverId) end
end)

local listenerOverride = false
VoiceExport('setListenerOverride', function(enabled)
    type_check({ enabled, 'boolean' })
    listenerOverride = enabled
end)

local lastTalkingStatus = false
local lastRadioStatus = false
local voiceState = 'proximity'

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/muteply', 'Mutes the player with the specified id', {
        { name = 'player id', help = 'the player to toggle mute' },
        { name = 'duration', help = '(opt) the duration the mute in seconds (default: 900)' },
    })
    while true do
        while not MumbleIsConnected() or not isInitialized do Wait(100) end

        if Settings.enableUi then
            local talking = isTrue(MumbleIsPlayerTalking(localPlayerId))
            if lastRadioStatus ~= radioPressed or lastTalkingStatus ~= talking then
                lastRadioStatus = radioPressed
                lastTalkingStatus = talking
                sendUIMessage({ usingRadio = lastRadioStatus, talking = lastTalkingStatus })
            end
        end

        if voiceState == 'proximity' then
            addNearbyPlayers()
            local cam = Settings.disableCameraListener and -1 or GetRenderingCam()
            local isSpectating = NetworkIsInSpectatorMode() or cam ~= -1
            if not isListenerEnabled and (isSpectating or listenerOverride) then
                setSpectatorMode(true)
            elseif isListenerEnabled and not isSpectating and not listenerOverride then
                setSpectatorMode(false)
            end
            tryListeningToFailedListeners()
        end

        Wait(Settings.refreshRate)
    end
end)

VoiceExport('setVoiceState', function(newState, channel)
    if newState ~= 'proximity' and newState ~= 'channel' then
        logger.error("Didn't get a proper voice state, expected proximity or channel, got %s", newState)
    end
    voiceState = newState
    if voiceState == 'channel' then
        type_check({ channel, 'number' })
        channel = channel + 65535
        MumbleSetVoiceChannel(channel)
        while MumbleGetVoiceChannelFromServerId(playerServerId) ~= channel do Wait(250) end
        MumbleAddVoiceTargetChannel(voiceTarget, channel)
    elseif voiceState == 'proximity' then
        handleInitialState()
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if type(addProximityCheck) == 'table' then
        local ref = addProximityCheck.__cfx_functionReference
        if ref and ref:find(resource, 1, true) then
            addProximityCheck = orig_addProximityCheck
            logger.warn('Reset proximity check to default, the resource that provided it [%s] stopped', resource)
        end
    end
end)

VoiceExport('addVoiceMode', function(distance, name)
    for i = 1, #Cfg.voiceModes do
        local voiceMode = Cfg.voiceModes[i]
        if voiceMode[2] == name then
            logger.verbose('Already had %s, overwriting instead', name)
            voiceMode[1] = distance
            return
        end
    end
    Cfg.voiceModes[#Cfg.voiceModes + 1] = { distance, name }
end)

VoiceExport('removeVoiceMode', function(name)
    for i = 1, #Cfg.voiceModes do
        if Cfg.voiceModes[i][2] == name then
            table.remove(Cfg.voiceModes, i)
            if mode == i then
                mode = 1
                setProximityState(Cfg.voiceModes[1][1], false)
            end
            return true
        end
    end
    return false
end)
