local raycast = {}

local function result(handle)
    while true do
        local retval, hit, endCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResultIncludingMaterial(handle)
        if retval ~= 1 then
            return hit, entityHit, endCoords, surfaceNormal, materialHash
        end
        Wait(0)
    end
end

function raycast.fromCoords(coords, destination, flags, ignore)
    local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, flags or 511, cache.ped, ignore or 4)
    return result(handle)
end

local function direction(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

function raycast.getForwardVector()
    return direction(GetFinalRenderedCamRot(2))
end

function raycast.cam(flags, ignore, distance)
    local origin = GetFinalRenderedCamCoord()
    local dest = origin + raycast.getForwardVector() * (distance or 10)
    local handle = StartShapeTestLosProbe(origin.x, origin.y, origin.z, dest.x, dest.y, dest.z, flags or 511, cache.ped, ignore or 4)
    return result(handle)
end

raycast.fromCamera = raycast.cam

return raycast
