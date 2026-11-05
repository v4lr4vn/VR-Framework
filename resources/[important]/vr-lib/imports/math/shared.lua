function math.toscalars(input, min, max, round)
    local out = {}
    for n in tostring(input):gmatch('-?%d+%.?%d*') do
        local v = tonumber(n)
        if min then v = math.max(min, v) end
        if max then v = math.min(max, v) end
        if round then v = math.floor(v + 0.5) end
        out[#out + 1] = v
    end
    return table.unpack(out)
end

function math.tovector(input, min, max, round)
    local t = type(input)
    if t == 'vector2' or t == 'vector3' or t == 'vector4' then return input end
    local values
    if t == 'table' then
        values = { input.x or input[1], input.y or input[2], input.z or input[3], input.w or input[4] }
        local n = 0
        for i = 1, 4 do if values[i] ~= nil then n = i end end
        values.n = n
    else
        values = table.pack(math.toscalars(input, min, max, round))
    end
    local n = values.n
    if n == 2 then return vector2(values[1], values[2]) end
    if n == 3 then return vector3(values[1], values[2], values[3]) end
    if n >= 4 then return vector4(values[1], values[2], values[3], values[4]) end
    error(('cannot convert %s to a vector'):format(tostring(input)), 2)
end

function math.normaltorotation(input)
    local inputType = type(input)
    if inputType == 'vector3' or inputType == 'table' then
        local pitch = -math.asin(input.y) * 180.0 / math.pi
        local yaw = math.atan(input.x, input.z) * 180.0 / math.pi
        return vector3(pitch, yaw, 0.0)
    end
    error(('expected a vector3 (received %s)'):format(inputType), 2)
end

function math.torgba(input)
    return math.tovector(input, 0, 255, true)
end

function math.hextorgb(input)
    local hex = tostring(input):gsub('^#', '')
    if #hex == 3 then hex = hex:gsub('.', '%0%0') end
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

function math.tohex(n, upper)
    n = math.floor(tonumber(n) or 0)
    local s = ('%x'):format(n)
    return upper and s:upper() or s
end

function math.groupdigits(number, seperator)
    local s = tostring(number)
    local sign, int, frac = s:match('^([%-]?)(%d+)(%.?%d*)$')
    if not int then return s end
    int = int:reverse():gsub('(%d%d%d)', '%1' .. (seperator or ',')):reverse()
    if int:sub(1, 1) == (seperator or ',') then int = int:sub(2) end
    return sign .. int .. frac
end

function math.clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end

function math.round(value, places)
    if type(value) == 'string' then value = tonumber(value) end
    if type(value) ~= 'number' then error(('expected number (received %s)'):format(type(value)), 2) end
    if places then
        if type(places) == 'string' then places = tonumber(places) end
        local mult = 10 ^ places
        return math.floor(value * mult + 0.5) / mult
    end
    return math.floor(value + 0.5)
end

return math
