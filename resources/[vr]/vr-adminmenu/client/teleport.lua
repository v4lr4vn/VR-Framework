local lastCoords

local function teleport(x, y, z)
    if cache.vehicle then
        return SetPedCoordsKeepVehicle(cache.ped, x, y, z)
    end

    SetEntityCoords(cache.ped, x, y, z, false, false, false, false)
end

RegisterNetEvent('vr-adminmenu:client:TeleportToPlayer', function(coords)
    lastCoords = GetEntityCoords(cache.ped)
    SetPedCoordsKeepVehicle(cache.ped, coords.x, coords.y, coords.z)
end)

RegisterNetEvent('vr-adminmenu:client:TeleportToCoords', function(data, selectedData)
    local coordsStr = type(selectedData) == 'table' and selectedData["Coords"] and selectedData["Coords"].value
    if type(coordsStr) ~= 'string' then return end
    local x, y, z, heading

    x, y, z, heading = coordsStr:match("(-?%d+%.?%d*),%s*(-?%d+%.?%d*),?%s*(-?%d*%.?%d*),?%s*(-?%d*%.?%d*)")

    if not x or not y then
        x, y, z, heading = coordsStr:match("(-?%d+%.?%d*)%s+(-?%d+%.?%d*)%s*(-?%d*%.?%d*)%s*(-?%d*%.?%d*)")
    end

    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z) or 0
    heading = tonumber(heading) or 0

    if x and y then
        lastCoords = GetEntityCoords(cache.ped)
        if heading and heading ~= 0 then
            SetEntityHeading(cache.ped, heading)
        end
        SetPedCoordsKeepVehicle(cache.ped, x, y, z)
    end
end)

RegisterNetEvent('vr-adminmenu:client:TeleportToLocation', function(data, selectedData)
    local coords = type(selectedData) == 'table' and selectedData["Location"] and selectedData["Location"].value
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then return end
    if not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then return end

    lastCoords = GetEntityCoords(cache.ped)
    SetPedCoordsKeepVehicle(cache.ped, coords.x, coords.y, coords.z)
end)

RegisterNetEvent('vr-adminmenu:client:TeleportBack', function(data)
    if lastCoords then
        local coords = GetEntityCoords(cache.ped)
        teleport(lastCoords.x, lastCoords.y, lastCoords.z)
        lastCoords = coords
    end
end)
