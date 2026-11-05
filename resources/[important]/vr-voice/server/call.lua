local function enabled() return GetConvarInt('voice_enableCalls', 1) == 1 end

function removePlayerFromCall(source, callChannel)
    logger.verbose('[call] Removed %s from call %s', source, callChannel)
    local channel = callData[callChannel]
    if channel then
        for player in pairs(channel) do
            TriggerClientEvent('vr-voice:removePlayerFromCall', player, source)
        end
        channel[source] = nil
        if not next(channel) then callData[callChannel] = nil end
    end
    voiceData[source] = voiceData[source] or defaultTable(source)
    voiceData[source].call = 0
end

function addPlayerToCall(source, callChannel)
    logger.verbose('[call] Added %s to call %s', source, callChannel)
    callData[callChannel] = callData[callChannel] or {}
    for player in pairs(callData[callChannel]) do
        if player ~= source then TriggerClientEvent('vr-voice:addPlayerToCall', player, source) end
    end
    callData[callChannel][source] = true
    voiceData[source] = voiceData[source] or defaultTable(source)
    voiceData[source].call = callChannel
    TriggerClientEvent('vr-voice:syncCallData', source, callData[callChannel])
end

function setPlayerCall(source, newChannel)
    if not enabled() then return end
    voiceData[source] = voiceData[source] or defaultTable(source)
    local isResource = GetInvokingResource()
    local plyVoice = voiceData[source]
    local callChannel = tonumber(newChannel)
    if not callChannel then
        if isResource then error(("'callChannel' expected 'number', got: %s"):format(type(newChannel))) end
        return logger.warn("%s sent a invalid call, 'callChannel' expected 'number', got: %s", source, type(newChannel))
    end
    if isResource then TriggerClientEvent('vr-voice:clSetPlayerCall', source, callChannel) end

    Player(source).state.callChannel = callChannel

    if callChannel ~= 0 and plyVoice.call == 0 then
        addPlayerToCall(source, callChannel)
    elseif callChannel == 0 then
        removePlayerFromCall(source, plyVoice.call)
    elseif plyVoice.call > 0 then
        removePlayerFromCall(source, plyVoice.call)
        addPlayerToCall(source, callChannel)
    end
end
VoiceExport('setPlayerCall', setPlayerCall)

VoiceOn('setPlayerCall', function(callChannel)
    setPlayerCall(source, callChannel)
end, true)
