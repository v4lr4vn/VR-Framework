local function sendTo(targets, eventName, payload)
    for _, id in ipairs(targets) do
        TriggerClientEvent(eventName, id, payload)
    end
end

RegisterNetEvent('vr-policejob:server:sendStatusNotification', function(data)
    local src = source
    if type(data) ~= 'table' or not hasJob(src, Config.AccessToMenu) then return end

    local index = Security.int(data.status, 1, #Config.StatusCodes)
    local entry = index and Config.StatusCodes[index]
    local adam = Security.int(data.adam, 0, 999)
    if not entry or not adam then return notify(src, locale('invalid_input'), 'error') end
    if not Security.cooldown('status', src, Config.Security.statusCooldown) then
        return notify(src, locale('action_cooldown'), 'error')
    end

    sendTo(getOnDutyPlayers(policeJobList()), 'vr-policejob:client:sendStatusNotification', {
        adam = adam,
        status = entry.code,
        location = Security.text(data.location, 100, true) or locale('unknown_location'),
    })

    if entry.alert then sendOfficerAlert(src, entry.alert) end
end)

RegisterNetEvent('vr-policejob:server:callMeeting', function(data)
    local src = source
    if type(data) ~= 'table' or not hasJob(src, Config.AccessToMenu) then return end
    if getPlayerJobGrade(src) < Config.MettingMenuGrade then
        return Security.flag(src, 'callMeeting below the meeting grade')
    end

    local reason = Security.text(data.reason, Config.Meeting.maxLength)
    local radio = Security.int(data.radio, 1, 999)
    if not reason or not radio then return notify(src, locale('invalid_input'), 'error') end
    if not Security.cooldown('meeting', src, Config.Security.meetingCooldown) then
        return notify(src, locale('action_cooldown'), 'error')
    end

    sendTo(getOnDutyPlayers(policeJobList()), 'vr-policejob:client:callMeeting', {
        reason = reason,
        radio = radio,
    })
end)

RegisterNetEvent('vr-policejob:server:broadcastMsg', function(data)
    local src = source
    if type(data) ~= 'table' or not hasJob(src, Config.AccessToMenu) then return end

    local reason = Security.text(data.reason, Config.Broadcast.maxLength)
    if not reason then return notify(src, locale('invalid_input'), 'error') end
    if not Security.cooldown('broadcast', src, Config.Security.broadcastCooldown) then
        return notify(src, locale('action_cooldown'), 'error')
    end

    sendTo(getOnDutyPlayers(policeJobList(Config.Broadcast.jobs)), 'vr-policejob:client:broadcastMsg', {
        reason = reason,
    })
end)
