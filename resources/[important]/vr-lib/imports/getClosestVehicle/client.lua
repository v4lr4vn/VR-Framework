return function(coords, maxDistance, includePlayerVehicle)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local vehicles = GetGamePool('CVehicle')
    local closest, closestCoords
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if not cache.vehicle or vehicle ~= cache.vehicle or includePlayerVehicle then
            local vcoords = GetEntityCoords(vehicle)
            local distance = #(coords - vcoords)
            if distance < maxDistance then
                maxDistance = distance
                closest, closestCoords = vehicle, vcoords
            end
        end
    end
    return closest, closestCoords
end
