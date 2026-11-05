return function(coords, maxDistance)
    maxDistance = maxDistance or 2.0
    local out = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        local vcoords = GetEntityCoords(vehicle)
        if #(coords - vcoords) < maxDistance then
            out[#out + 1] = { vehicle = vehicle, coords = vcoords }
        end
    end
    return out
end
