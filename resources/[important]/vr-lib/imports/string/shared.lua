local chars = {
    A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    a = 'abcdefghijklmnopqrstuvwxyz',
    ['1'] = '0123456789',
    ['.'] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
}

local function pick(set)
    local i = math.random(#set)
    return set:sub(i, i)
end

function string.random(pattern, length)
    pattern = tostring(pattern or '.')
    local out = {}
    local i = 1
    while i <= #pattern do
        local c = pattern:sub(i, i)
        if c == '^' then
            i = i + 1
            out[#out + 1] = pattern:sub(i, i)
        elseif chars[c] then
            out[#out + 1] = pick(chars[c])
        else
            out[#out + 1] = c
        end
        i = i + 1
    end
    local s = table.concat(out)
    if length and #s < length then
        local last = pattern:sub(-1)
        local set = chars[last] or chars['.']
        while #s < length do s = s .. pick(set) end
    end
    return s
end

return string
