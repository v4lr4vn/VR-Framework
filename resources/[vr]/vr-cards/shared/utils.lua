CU = {}

function CU.money(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-' or '') .. s
end

function CU.pick(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then return nil end
    local keys = {}
    for k in pairs(weights) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local r = math.random() * total
    for _, k in ipairs(keys) do
        r = r - weights[k]
        if r <= 0 then return k end
    end
    return keys[#keys]
end
