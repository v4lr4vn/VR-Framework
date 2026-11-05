local callChannel = 0

local function retarget()
    MumbleClearVoiceTargetPlayers(voiceTarget)
    addVoiceTargets((radioPressed and isRadioEnabled()) and radioData or {}, callData)
end

RegisterNetEvent('vr-voice:syncCallData', function(callTable)
    callData = callTable
    handleRadioAndCallInit()
end)

RegisterNetEvent('vr-voice:addPlayerToCall', function(plySource)
    toggleVoice(plySource, true, 'call')
    callData[plySource] = true
end)

RegisterNetEvent('vr-voice:removePlayerFromCall', function(plySource)
    if plySource == playerServerId then
        for tgt in pairs(callData) do
            if tgt ~= playerServerId then toggleVoice(tgt, false, 'call') end
        end
        callData = {}
        retarget()
        return
    end
    callData[plySource] = nil
    toggleVoice(plySource, radioData[plySource], 'call')
    if isTrue(MumbleIsPlayerTalking(PlayerId())) then retarget() end
end)

function setCallChannel(channel)
    if not Settings.enableCalls then return end
    TriggerServerEvent('vr-voice:setPlayerCall', channel)
    callChannel = channel
    sendUIMessage({ callInfo = channel })
end

VoiceExport('setCallChannel', setCallChannel)
VoiceExport('SetCallChannel', setCallChannel)
VoiceExport('addPlayerToCall', function(call)
    call = tonumber(call)
    if call then setCallChannel(call) end
end)
VoiceExport('removePlayerFromCall', function() setCallChannel(0) end)

RegisterNetEvent('vr-voice:clSetPlayerCall', function(newChannel)
    if not Settings.enableCalls then return end
    callChannel = newChannel
    sendUIMessage({ callInfo = newChannel })
end)
