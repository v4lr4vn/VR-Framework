return function(coords, maxDistance)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local objects = GetGamePool('CObject')
    local closest, closestCoords
    for i = 1, #objects do
        local object = objects[i]
        local ocoords = GetEntityCoords(object)
        local distance = #(coords - ocoords)
        if distance < maxDistance then
            maxDistance = distance
            closest, closestCoords = object, ocoords
        end
    end
    return closest, closestCoords
end
