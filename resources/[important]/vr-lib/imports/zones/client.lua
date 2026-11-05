local zones = api.__zones
local inside = {}
local ticking = false
local drawing = false

local function safe(fn, self)
    local ok, err = pcall(fn, self)
    if not ok then print(('^1[vr-lib] zone callback error: %s^0'):format(err)) end
end

local function onRemoveExit(self)
    inside[self.id] = nil
    if self.onExit then CreateThread(function() safe(self.onExit, self) end) end
end

local function insideLoop()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while true do
            local any = false
            for _, z in pairs(inside) do
                if z.inside then
                    any = true
                    safe(z.inside, z)
                end
            end
            if not any then break end
            Wait(0)
        end
        ticking = false
    end)
end

local function colour(z)
    local c = z.debugColour or {}
    return c.r or c[1] or 245, c.g or c[2] or 165, c.b or c[3] or 36, c.a or c[4] or 80
end

local function drawBox(z)
    local r, g, b, a = colour(z)
    local h = math.rad(z.heading)
    local c, s = math.cos(h), math.sin(h)
    local hx, hy, hz = z.size.x / 2, z.size.y / 2, z.size.z / 2
    local corners = {}
    for i, sign in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local lx, ly = sign[1] * hx, sign[2] * hy
        corners[i] = { z.coords.x + lx * c - ly * s, z.coords.y + lx * s + ly * c }
    end
    local bottom, top = z.coords.z - hz, z.coords.z + hz
    for i = 1, 4 do
        local p1, p2 = corners[i], corners[i % 4 + 1]
        DrawLine(p1[1], p1[2], bottom, p2[1], p2[2], bottom, r, g, b, 255)
        DrawLine(p1[1], p1[2], top, p2[1], p2[2], top, r, g, b, 255)
        DrawLine(p1[1], p1[2], bottom, p1[1], p1[2], top, r, g, b, 255)
        DrawPoly(p1[1], p1[2], bottom, p2[1], p2[2], bottom, p2[1], p2[2], top, r, g, b, a)
        DrawPoly(p1[1], p1[2], bottom, p2[1], p2[2], top, p1[1], p1[2], top, r, g, b, a)
        DrawPoly(p2[1], p2[2], top, p2[1], p2[2], bottom, p1[1], p1[2], bottom, r, g, b, a)
        DrawPoly(p1[1], p1[2], top, p2[1], p2[2], top, p1[1], p1[2], bottom, r, g, b, a)
    end
end

local function drawPoly(z)
    local r, g, b, a = colour(z)
    local pts = z.points
    for i = 1, #pts do
        local p1, p2 = pts[i], pts[i % #pts + 1]
        DrawLine(p1.x, p1.y, z.minZ, p2.x, p2.y, z.minZ, r, g, b, 255)
        DrawLine(p1.x, p1.y, z.maxZ, p2.x, p2.y, z.maxZ, r, g, b, 255)
        DrawLine(p1.x, p1.y, z.minZ, p1.x, p1.y, z.maxZ, r, g, b, 255)
        DrawPoly(p1.x, p1.y, z.minZ, p2.x, p2.y, z.minZ, p2.x, p2.y, z.maxZ, r, g, b, a)
        DrawPoly(p1.x, p1.y, z.minZ, p2.x, p2.y, z.maxZ, p1.x, p1.y, z.maxZ, r, g, b, a)
        DrawPoly(p2.x, p2.y, z.maxZ, p2.x, p2.y, z.minZ, p1.x, p1.y, z.minZ, r, g, b, a)
        DrawPoly(p1.x, p1.y, z.maxZ, p2.x, p2.y, z.maxZ, p1.x, p1.y, z.minZ, r, g, b, a)
    end
end

local function drawSphere(z)
    local r, g, b, a = colour(z)
    DrawMarker(28, z.coords.x, z.coords.y, z.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, z.radius, z.radius, z.radius, r, g, b, a, false, false, 0, false, nil, nil, false)
end

local function debugLoop()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while true do
            local any = false
            for _, z in pairs(zones) do
                if z.debug then
                    any = true
                    if z.__type == 'box' then drawBox(z) elseif z.__type == 'poly' then drawPoly(z) else drawSphere(z) end
                end
            end
            if not any then break end
            Wait(0)
        end
        drawing = false
    end)
end

CreateThread(function()
    while true do
        if next(zones) then
            local coords = GetEntityCoords(PlayerPedId())
            local debugging = false
            for id, z in pairs(zones) do
                z.__onRemoveExit = onRemoveExit
                z.distance = #(coords - z.coords)
                if z.debug then debugging = true end
                local isIn = z.distance <= z.boundingRadius + 0.5 and z:contains(coords)
                if isIn and not z.insideZone then
                    z.insideZone = true
                    inside[id] = z
                    if z.onEnter then CreateThread(function() safe(z.onEnter, z) end) end
                elseif not isIn and z.insideZone then
                    z.insideZone = false
                    inside[id] = nil
                    if z.onExit then CreateThread(function() safe(z.onExit, z) end) end
                end
            end
            for id in pairs(inside) do
                if not zones[id] then inside[id] = nil end
            end
            if next(inside) then insideLoop() end
            if debugging then debugLoop() end
            Wait(300)
        else
            Wait(500)
        end
    end
end)

return api
