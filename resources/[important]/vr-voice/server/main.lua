voiceData = {}
radioData = {}
callData = {}

local mappedChannels = {}
local function firstFreeChannel()
    for i = 1, 2048 do
        if not mappedChannels[i] then return i end
    end
    return 0
end

function handleStateBagInitilization(source)
    local plyState = Player(source).state
    if not plyState.vrVoiceInit then
        plyState:set('radio', GetConvarInt('voice_defaultRadioVolume', 30), true)
        plyState:set('call', GetConvarInt('voice_defaultCallVolume', 60), true)
        plyState:set('submix', nil, true)
        plyState:set('proximity', {}, true)
        plyState:set('callChannel', 0, true)
        plyState:set('radioChannel', 0, true)
        plyState:set('voiceIntent', 'speech', true)
        plyState:set('vrVoiceInit', true, false)
    end

    local assignedChannel = firstFreeChannel()
    plyState:set('assignedChannel', assignedChannel, true)
    if assignedChannel ~= 0 then
        mappedChannels[assignedChannel] = source
        logger.verbose('[reuse] Assigned %s to channel %s', source, assignedChannel)
    else
        logger.error('[reuse] Failed to find a free channel for %s', source)
    end
end

function defaultTable(source)
    handleStateBagInitilization(source)
    return { radio = 0, call = 0, lastRadio = 0, lastCall = 0 }
end

CreateThread(function()
    for _, id in ipairs(GetPlayers()) do
        local ply = tonumber(id)
        voiceData[ply] = defaultTable(ply)
    end

    Wait(5000)

    local nativeAudio = GetConvar('voice_useNativeAudio', 'not-set')
    local audio3d = GetConvar('voice_use3dAudio', 'not-set')
    local audio2d = GetConvar('voice_use2dAudio', 'not-set')
    if nativeAudio == 'not-set' and audio3d == 'not-set' and audio2d == 'not-set' then
        SetConvarReplicated('voice_useNativeAudio', 'true')
        logger.info('No voice mod detected, defaulting to \'setr voice_useNativeAudio true\'')
    elseif GetConvar('voice_useSendingRangeOnly', 'not-set') == 'true' then
        logger.warn("It's recommended to have 'voice_useSendingRangeOnly' set to false ('setr voice_useSendingRangeOnly false').")
    end

    local radioVolume = GetConvarInt('voice_defaultRadioVolume', 30)
    local callVolume = GetConvarInt('voice_defaultCallVolume', 60)
    if radioVolume <= 1 or callVolume <= 1 then
        SetConvarReplicated('voice_defaultRadioVolume', '30')
        SetConvarReplicated('voice_defaultCallVolume', '60')
        logger.warn('`voice_defaultRadioVolume` / `voice_defaultCallVolume` must be whole numbers 2-100 (e.g. 30, not 0.3). Reset to 30 / 60 - please fix server.cfg.')
    end
end)

AddEventHandler('playerJoining', function()
    if not voiceData[source] then voiceData[source] = defaultTable(source) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local mappedChannel = Player(src).state.assignedChannel
    local plyData = voiceData[src]
    if plyData then
        if plyData.radio ~= 0 then removePlayerFromRadio(src, plyData.radio) end
        if plyData.call ~= 0 then removePlayerFromCall(src, plyData.call) end
        voiceData[src] = nil
    end
    if mappedChannel then
        mappedChannels[mappedChannel] = nil
        logger.verbose('[reuse] Unassigned %s from channel %s', src, mappedChannel)
    end
end)

if GetConvarInt('voice_externalDisallowJoin', 0) == 1 then
    AddEventHandler('playerConnecting', function(_, _, deferrals)
        deferrals.defer()
        Wait(0)
        deferrals.done('This server is not accepting connections.')
    end)
end

function isValidPlayer(source)
    return voiceData[source]
end
VoiceExport('isValidPlayer', isValidPlayer)

function getPlayersInRadioChannel(channel)
    return radioData[channel] or {}
end
VoiceExport('getPlayersInRadioChannel', getPlayersInRadioChannel)
VoiceExport('GetPlayersInRadioChannel', getPlayersInRadioChannel)
