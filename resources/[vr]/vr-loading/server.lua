-- Hands the player's name to the loading screen (window.nuiHandoverData.name).
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.handover({
        name = GetPlayerName(src) or 'Visitor',
    })
end)
