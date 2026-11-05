return function(coords, maxDistance, includePlayerVehicle)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local vehicles = GetGamePool('CVehicle')
    local out = {}
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if not cache.vehicle or vehicle ~= cache.vehicle or includePlayerVehicle then
            local vcoords = GetEntityCoords(vehicle)
            if #(coords - vcoords) < maxDistance then
                out[#out + 1] = { vehicle = vehicle, coords = vcoords }
            end
        end
    end
    return out
end
