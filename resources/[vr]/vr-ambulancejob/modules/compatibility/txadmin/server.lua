AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
    if GetInvokingResource() ~= "monitor" then return end
    if type(eventData) ~= "table" then return end

    local target = tonumber(eventData.id)
    if not target then return end

    local function heal(id)
        if IsPlayerDead(id) then
            RevivePlayer(id)
        else
            HealPlayer(id)
        end
    end

    if target == -1 then
        local players = Framework.getPlayers()
        for i = 1, #players do heal(players[i]) end
    else
        heal(target)
    end
end)
