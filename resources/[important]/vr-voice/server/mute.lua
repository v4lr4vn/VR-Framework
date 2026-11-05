local muteTimers = {}

RegisterCommand('muteply', function(source, args)
    local target = tonumber(args[1])
    local duration = tonumber(args[2])
    if not duration or duration <= 0 then duration = 900 end
    if not target or not isValidPlayer(target) then return end

    local muted = not isTrue(MumbleIsPlayerMuted(target))
    Player(target).state.muted = muted
    MumbleSetPlayerMuted(target, muted)
    VoiceEmit('playerMuted', target, source, muted, duration)

    if muteTimers[target] then
        muteTimers[target] = nil
        return
    end

    local token = {}
    muteTimers[target] = token
    SetTimeout(math.floor(duration * 1000), function()
        if muteTimers[target] ~= token then return end
        muteTimers[target] = nil
        MumbleSetPlayerMuted(target, not muted)
        Player(target).state.muted = not muted
    end)
end, true)

AddEventHandler('playerDropped', function()
    muteTimers[source] = nil
end)
