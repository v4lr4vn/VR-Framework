return function(coords, maxDistance, includePlayer)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local players = GetActivePlayers()
    local out = {}
    for i = 1, #players do
        local id = players[i]
        if id ~= cache.playerId or includePlayer then
            local ped = GetPlayerPed(id)
            if ped and ped ~= 0 then
                local pcoords = GetEntityCoords(ped)
                if #(coords - pcoords) < maxDistance then
                    out[#out + 1] = { id = id, ped = ped, coords = pcoords }
                end
            end
        end
    end
    return out
end
