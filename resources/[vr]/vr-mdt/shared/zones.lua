DispatchZones = {}

local function num(v) return tonumber(v) or 0.0 end

function DispatchZones.inPoly(x, y, points)
    local inside = false
    local n = #points
    local j = n
    for i = 1, n do
        local a, b = points[i], points[j]
        local ay, by = num(a.y), num(b.y)
        if (ay > y) ~= (by > y) then
            local ax, bx = num(a.x), num(b.x)
            if x < (bx - ax) * (y - ay) / (by - ay) + ax then inside = not inside end
        end
        j = i
    end
    return inside
end

function DispatchZones.inside(coords, zone)
    if type(zone) ~= 'table' or not coords then return false end
    if type(zone.points) == 'table' and #zone.points >= 3 then
        local z = coords.z or 0.0
        if zone.minZ and z < zone.minZ then return false end
        if zone.maxZ and z > zone.maxZ then return false end
        return DispatchZones.inPoly(coords.x, coords.y, zone.points)
    end
    local c = zone.coords
    if not c then return false end
    local dx, dy, dz = coords.x - num(c.x), coords.y - num(c.y), (coords.z or 0.0) - num(c.z)
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= (zone.radius or 2.0)
end

function DispatchZones.find(coords, list)
    for _, zone in ipairs(list or {}) do
        if DispatchZones.inside(coords, zone) then return zone end
    end
end

function DispatchZones.nearDesk(coords, list, range)
    for _, desk in ipairs(list or {}) do
        local c = desk.coords
        if c then
            local dx, dy, dz = coords.x - num(c.x), coords.y - num(c.y), (coords.z or 0.0) - num(c.z)
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= (desk.radius or 1.2) + (range or 0.0) then return desk end
        end
    end
end

function DispatchZones.spot(coords)
    local d = Config.Dispatcher or {}
    if not coords then return nil end
    if DispatchZones.nearDesk(coords, d.computers, d.computerRange or 2.5) then return 'console' end
    if DispatchZones.find(coords, d.zones) then return 'zone' end
    return nil
end

function DispatchZones.inZone(coords)
    local d = Config.Dispatcher or {}
    return coords ~= nil and DispatchZones.find(coords, d.zones) ~= nil
end
