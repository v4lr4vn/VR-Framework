return function(coords, maxDistance, ignore)
    maxDistance = maxDistance or 2.0
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        local id = tonumber(src)
        if id ~= ignore then
            local ped = GetPlayerPed(src)
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
