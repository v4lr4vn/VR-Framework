return function(coords, maxDistance)
    coords = coords or GetEntityCoords(cache.ped)
    maxDistance = maxDistance or 2.0
    local peds = GetGamePool('CPed')
    local out = {}
    for i = 1, #peds do
        local ped = peds[i]
        if not IsPedAPlayer(ped) then
            local pcoords = GetEntityCoords(ped)
            if #(coords - pcoords) < maxDistance then
                out[#out + 1] = { ped = ped, coords = pcoords }
            end
        end
    end
    return out
end
