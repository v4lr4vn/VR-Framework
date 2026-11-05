local points = {}
local nearby = {}
local closest
local idSeq = 0
local ticking = false

local Point = {}
Point.__index = Point

local function toVec(c)
    if type(c) == 'vector3' then return c end
    if type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' then return vector3(c.x or c[1] or 0.0, c.y or c[2] or 0.0, c.z or c[3] or 0.0) end
    return c
end

local function safe(fn, self)
    local ok, err = pcall(fn, self)
    if not ok then print(('^1[vr-lib] point callback error: %s^0'):format(err)) end
end

function Point:remove()
    if not points[self.id] then return end
    points[self.id] = nil
    if nearby[self.id] then
        nearby[self.id] = nil
        if self.onExit then safe(self.onExit, self) end
    end
    if closest == self then closest = nil end
end

local function tick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(nearby) do
            local coords = GetEntityCoords(PlayerPedId())
            local any = false
            for _, p in pairs(nearby) do
                if p.nearby then
                    any = true
                    p.currentDistance = #(coords - p.coords)
                    safe(p.nearby, p)
                end
            end
            if not any then break end
            Wait(0)
        end
        ticking = false
    end)
end

CreateThread(function()
    while true do
        if next(points) then
            local coords = GetEntityCoords(PlayerPedId())
            local best, bestDistance = nil, math.huge
            for id, p in pairs(points) do
                local distance = #(coords - p.coords)
                p.currentDistance = distance
                if distance <= p.distance then
                    if distance < bestDistance then best, bestDistance = p, distance end
                    if not nearby[id] then
                        nearby[id] = p
                        if p.onEnter then CreateThread(function() safe(p.onEnter, p) end) end
                    end
                elseif nearby[id] then
                    nearby[id] = nil
                    if p.onExit then CreateThread(function() safe(p.onExit, p) end) end
                end
            end
            if closest and closest ~= best then closest.isClosest = false end
            closest = best
            if best then best.isClosest = true end
            if next(nearby) then tick() end
            Wait(300)
        else
            Wait(500)
        end
    end
end)

local function new(...)
    local data = ...
    if type(data) ~= 'table' or (type(data) == 'table' and data.coords == nil and (data.x or data[1])) then
        local coords, distance, extra = ...
        data = type(extra) == 'table' and extra or {}
        data.coords = coords
        data.distance = distance
    end
    idSeq = idSeq + 1
    local self = setmetatable(data, Point)
    self.id = idSeq
    self.coords = toVec(self.coords)
    self.distance = tonumber(self.distance) or 2.0
    self.currentDistance = math.huge
    self.isClosest = false
    points[self.id] = self
    return self
end

return {
    new = new,
    getAllPoints = function() return points end,
    getNearbyPoints = function()
        local out = {}
        for _, p in pairs(nearby) do out[#out + 1] = p end
        return out
    end,
    getClosestPoint = function() return closest end,
}
