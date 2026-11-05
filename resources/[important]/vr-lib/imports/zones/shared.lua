local Zone = {}
Zone.__index = Zone

local zones = {}
local idSeq = 0

local function toVec(c)
    if c == nil then return nil end
    if type(c) == 'vector3' then return c end
    if type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' then return vector3((c.x or c[1] or 0.0) + 0.0, (c.y or c[2] or 0.0) + 0.0, (c.z or c[3] or 0.0) + 0.0) end
    return c
end

local function heading(rot)
    if type(rot) == 'number' then return rot end
    if type(rot) == 'vector3' or (type(rot) == 'table' and rot.z) then return rot.z or 0.0 end
    return 0.0
end

local function inPolygon(points, x, y)
    local inside = false
    local n = #points
    local j = n
    for i = 1, n do
        local pi, pj = points[i], points[j]
        if ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / ((pj.y - pi.y) ~= 0 and (pj.y - pi.y) or 1e-9) + pi.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function Zone:contains(coords)
    coords = toVec(coords)
    if not coords then return false end
    if self.__type == 'sphere' then
        return #(coords - self.coords) <= self.radius
    elseif self.__type == 'box' then
        local d = coords - self.coords
        local h = -math.rad(self.heading)
        local c, s = math.cos(h), math.sin(h)
        local lx = d.x * c - d.y * s
        local ly = d.x * s + d.y * c
        return math.abs(lx) <= self.size.x / 2 and math.abs(ly) <= self.size.y / 2 and math.abs(d.z) <= self.size.z / 2
    else
        if coords.z < self.minZ or coords.z > self.maxZ then return false end
        return inPolygon(self.points, coords.x, coords.y)
    end
end

function Zone:remove()
    if not zones[self.id] then return end
    zones[self.id] = nil
    if self.insideZone then
        self.insideZone = false
        if self.onExit and self.__onRemoveExit then self.__onRemoveExit(self) end
    end
end

function Zone:setDebug(state, colour)
    self.debug = state == true
    if colour then self.debugColour = colour end
end

local function register(self, kind)
    idSeq = idSeq + 1
    self.id = idSeq
    self.__type = kind
    self.insideZone = false
    self.distance = math.huge
    self.debugColour = self.debugColour or { r = 245, g = 165, b = 36, a = 80 }
    zones[self.id] = self
    return self
end

local function sphere(data)
    local self = setmetatable(data, Zone)
    self.coords = toVec(self.coords)
    self.radius = (tonumber(self.radius) or 2.0) + 0.0
    self.boundingRadius = self.radius
    return register(self, 'sphere')
end

local function box(data)
    local self = setmetatable(data, Zone)
    self.coords = toVec(self.coords)
    self.size = toVec(self.size) or vector3(2.0, 2.0, 2.0)
    self.heading = (heading(self.rotation) or 0.0) + 0.0
    self.boundingRadius = math.sqrt((self.size.x / 2) ^ 2 + (self.size.y / 2) ^ 2 + (self.size.z / 2) ^ 2)
    return register(self, 'box')
end

local function poly(data)
    local self = setmetatable(data, Zone)
    local pts = {}
    local sumX, sumY, sumZ = 0.0, 0.0, 0.0
    for i = 1, #(self.points or {}) do
        local p = toVec(self.points[i])
        pts[i] = p
        sumX, sumY, sumZ = sumX + p.x, sumY + p.y, sumZ + p.z
    end
    if #pts < 3 then error('poly zone requires at least 3 points', 2) end
    self.points = pts
    local n = #pts
    local z = sumZ / n
    self.thickness = (tonumber(self.thickness) or 4.0) + 0.0
    self.minZ = z - self.thickness / 2
    self.maxZ = z + self.thickness / 2
    self.coords = vector3(sumX / n, sumY / n, z)
    local r = 0.0
    for i = 1, n do
        local dx, dy = pts[i].x - self.coords.x, pts[i].y - self.coords.y
        r = math.max(r, math.sqrt(dx * dx + dy * dy))
    end
    self.boundingRadius = math.sqrt(r * r + (self.thickness / 2) ^ 2)
    return register(self, 'poly')
end

local api = {
    sphere = sphere,
    box = box,
    poly = poly,
    getAllZones = function() return zones end,
    getCurrentZones = function()
        local out = {}
        for _, z in pairs(zones) do
            if z.insideZone then out[#out + 1] = z end
        end
        return out
    end,
    getNearbyZones = function()
        local out = {}
        for _, z in pairs(zones) do
            if z.distance <= z.boundingRadius + 25.0 then out[#out + 1] = z end
        end
        return out
    end,
    __zones = zones,
}
