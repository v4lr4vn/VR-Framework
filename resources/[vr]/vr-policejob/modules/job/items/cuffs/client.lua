if not Config.CanBreakCuffs then return end

exports('breakCuffs', function(data, slot)
    if not player.cuffed then
        return utils.showNotification(locale('not_cuffed'), 'error')
    end

    CreateThread(function()
        local success = lib.skillCheck({ 'easy', 'easy', "medium", 'easy', "medium", "hard" }, { 'w', 'a', 's', 'd' })
        if not player.cuffed then return end
        TriggerServerEvent('vr-policejob:server:breakCuffs', success == true)
    end)
end)
