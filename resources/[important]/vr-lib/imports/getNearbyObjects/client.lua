return function(coords, maxDistance)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local objects = GetGamePool('CObject')
    local out = {}
    for i = 1, #objects do
        local object = objects[i]
        local ocoords = GetEntityCoords(object)
        if #(coords - ocoords) < maxDistance then
            out[#out + 1] = { object = object, coords = ocoords }
        end
    end
    return out
end
