TargetUtils = {}
local utils = TargetUtils

local itemCounts = {}
local cached = Bridge.inventoryName == 'ox'

setmetatable(itemCounts, {
    __index = function(self, name)
        local count = Bridge.inventory.count(name)
        if cached then rawset(self, name, count) end
        return count
    end,
})

Bridge.on('itemCount', function(name, count)
    if cached then rawset(itemCounts, name, tonumber(count) or 0) end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == Bridge.inventoryResource then
        for k in pairs(itemCounts) do rawset(itemCounts, k, nil) end
    end
end)

function utils.getItems()
    return itemCounts
end

function utils.hasPlayerGotItems(filter, hasAny)
    if Bridge.inventoryName == 'none' then return true end
    local kind = type(filter)
    if kind == 'string' then
        return (itemCounts[filter] or 0) > 0
    end
    if kind ~= 'table' then return true end
    if filter[1] ~= nil then
        for i = 1, #filter do
            local has = (itemCounts[filter[i]] or 0) > 0
            if hasAny and has then return true end
            if not hasAny and not has then return false end
        end
    else
        for name, amount in pairs(filter) do
            local has = (itemCounts[name] or 0) >= (tonumber(amount) or 1)
            if hasAny and has then return true end
            if not hasAny and not has then return false end
        end
    end
    return not hasAny
end

function utils.hasPlayerGotGroup(filter)
    if Bridge.framework == 'none' then return true end
    return Bridge.hasGroup(filter) ~= false
end

local currentZones, previousZones = {}, {}
local drawZones, drawN = {}, 0

function utils.getNearbyZones(coords)
    local nearby = lib.zones.getNearbyZones()
    local n = 0
    drawN = 0
    previousZones, currentZones = currentZones, previousZones
    for k in pairs(currentZones) do currentZones[k] = nil end
    for i = 1, #nearby do
        local zone = nearby[i]
        if zone.options then
            local contains = zone:contains(coords)
            if contains then
                n = n + 1
                currentZones[n] = zone
            end
            if drawN < TargetConfig.sprites and zone.drawSprite ~= false and (contains or (zone.distance or 99) < 7) then
                drawN = drawN + 1
                drawZones[drawN] = zone
                zone.__hover = contains
            end
        end
    end
    if n ~= #previousZones then return currentZones, true end
    for i = 1, n do
        local found = false
        for j = 1, #previousZones do
            if previousZones[j] == currentZones[i] then
                found = true
                break
            end
        end
        if not found then return currentZones, true end
    end
    return currentZones, false
end

function utils.drawZoneSprites(dict, texture)
    if drawN == 0 then return end
    local w = 0.02
    local h = w * GetAspectRatio(false)
    for i = 1, drawN do
        local zone = drawZones[i]
        local c = zone.__hover and TargetConfig.spriteHover or TargetConfig.spriteColour
        SetDrawOrigin(zone.coords.x, zone.coords.y, zone.coords.z)
        DrawSprite(dict, texture, 0, 0, w, h, 0, c[1], c[2], c[3], c[4])
    end
    ClearDrawOrigin()
end

function utils.warn(msg)
    print(('^3[vr-target] %s^7'):format(msg))
end
