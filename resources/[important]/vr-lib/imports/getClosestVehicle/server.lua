return function(coords, maxDistance)
    maxDistance = maxDistance or 2.0
    local closest, closestCoords
    for _, vehicle in ipairs(GetAllVehicles()) do
        local vcoords = GetEntityCoords(vehicle)
        local distance = #(coords - vcoords)
        if distance < maxDistance then
            maxDistance = distance
            closest, closestCoords = vehicle, vcoords
        end
    end
    return closest, closestCoords
end
