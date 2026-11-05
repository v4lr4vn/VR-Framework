return function(coords, maxDistance)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local peds = GetGamePool('CPed')
    local closest, closestCoords
    for i = 1, #peds do
        local ped = peds[i]
        if not IsPedAPlayer(ped) then
            local pcoords = GetEntityCoords(ped)
            local distance = #(coords - pcoords)
            if distance < maxDistance then
                maxDistance = distance
                closest, closestCoords = ped, pcoords
            end
        end
    end
    return closest, closestCoords
end
