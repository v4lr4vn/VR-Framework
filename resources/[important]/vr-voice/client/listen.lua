radioListeners = radioListeners or {}
listenData = listenData or {}

local function retarget()
    if not radioPressed then return end
    MumbleClearVoiceTargetPlayers(voiceTarget)
    addVoiceTargets(radioData, radioListeners, callData)
end

RegisterNetEvent('vr-voice:syncListeners', function(list)
    radioListeners = {}
    for key in pairs(type(list) == 'table' and list or {}) do
        local id = tonumber(key)
        if id and id ~= playerServerId then radioListeners[id] = true end
    end
    retarget()
end)

RegisterNetEvent('vr-voice:addListener', function(id)
    id = tonumber(id)
    if not id or id == playerServerId then return end
    radioListeners[id] = true
    retarget()
end)

RegisterNetEvent('vr-voice:removeListener', function(id)
    id = tonumber(id)
    if not id then return end
    radioListeners[id] = nil
    retarget()
end)

local function heardElsewhere(id, except)
    if radioData[id] ~= nil then return true end
    for channel, members in pairs(listenData) do
        if channel ~= except and members[id] ~= nil then return true end
    end
    return false
end

RegisterNetEvent('vr-voice:listenSync', function(channel, members)
    channel = tonumber(channel)
    if not channel then return end
    local list = {}
    for key, talking in pairs(type(members) == 'table' and members or {}) do
        local id = tonumber(key)
        if id and id ~= playerServerId then
            list[id] = talking == true
            if talking == true and isRadioEnabled() then toggleVoice(id, true, 'radio') end
        end
    end
    listenData[channel] = list
    VoiceEmit('listenChanged', channel, list)
end)

RegisterNetEvent('vr-voice:listenRemoved', function(channel)
    channel = tonumber(channel)
    local members = channel and listenData[channel]
    if not members then return end
    listenData[channel] = nil
    for id in pairs(members) do
        if not heardElsewhere(id, channel) then toggleVoice(id, false, 'radio') end
    end
    VoiceEmit('listenChanged', channel, nil)
end)

RegisterNetEvent('vr-voice:listenJoin', function(channel, id)
    channel, id = tonumber(channel), tonumber(id)
    if not channel or not id or not listenData[channel] or id == playerServerId then return end
    listenData[channel][id] = false
    VoiceEmit('listenChanged', channel, listenData[channel])
end)

RegisterNetEvent('vr-voice:listenLeave', function(channel, id)
    channel, id = tonumber(channel), tonumber(id)
    if not channel or not id or not listenData[channel] then return end
    listenData[channel][id] = nil
    if not heardElsewhere(id, channel) then toggleVoice(id, false, 'radio') end
    VoiceEmit('listenChanged', channel, listenData[channel])
end)

RegisterNetEvent('vr-voice:setTalkingOnListen', function(channel, id, talking)
    channel, id = tonumber(channel), tonumber(id)
    if not channel or not id or not listenData[channel] then return end
    talking = talking == true
    listenData[channel][id] = talking
    VoiceEmit('listenTalking', channel, id, talking)
    if not isRadioEnabled() then return end
    toggleVoice(id, talking or callData[id] or radioData[id] == true, 'radio')
    playMicClicks(talking)
end)

VoiceExport('getListenData', function() return listenData end)
VoiceExport('getRadioMembers', function() return radioData end)
VoiceExport('isRadioTalking', function() return radioPressed == true end)
