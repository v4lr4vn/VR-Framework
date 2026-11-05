return function(coords, maxDistance, includePlayer)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local players = GetActivePlayers()
    local closestId, closestPed, closestCoords
    for i = 1, #players do
        local id = players[i]
        if id ~= cache.playerId or includePlayer then
            local ped = GetPlayerPed(id)
            if ped and ped ~= 0 then
                local pcoords = GetEntityCoords(ped)
                local distance = #(coords - pcoords)
                if distance < maxDistance then
                    maxDistance = distance
                    closestId, closestPed, closestCoords = id, ped, pcoords
                end
            end
        end
    end
    return closestId, closestPed, closestCoords
end
