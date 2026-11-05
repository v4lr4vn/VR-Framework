return function(coords, maxDistance, ignore)
    maxDistance = maxDistance or 2.0
    local closestId, closestPed, closestCoords
    for _, src in ipairs(GetPlayers()) do
        local id = tonumber(src)
        if id ~= ignore then
            local ped = GetPlayerPed(src)
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
