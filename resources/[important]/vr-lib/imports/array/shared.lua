local Array = lib.class('Array')

function Array:constructor(...)
    local n = select('#', ...)
    local args = { ... }
    for i = 1, n do self[i] = args[i] end
end

function Array.__newindex(self, key, value)
    if type(key) ~= 'number' then error(('Cannot insert non-number key into array (%s)'):format(tostring(key)), 2) end
    rawset(self, key, value)
end

function Array.isArray(tbl)
    if type(tbl) ~= 'table' then return false end
    if getmetatable(tbl) == Array then return true end
    local n = 0
    for k in pairs(tbl) do
        if type(k) ~= 'number' then return false end
        n = n + 1
    end
    return n == #tbl
end

function Array:from(iter)
    local out = Array:new()
    if type(iter) == 'table' then
        for i = 1, #iter do out[i] = iter[i] end
    elseif type(iter) == 'string' then
        for i = 1, #iter do out[i] = iter:sub(i, i) end
    elseif type(iter) == 'function' then
        local i = 0
        for v in iter do
            i = i + 1
            out[i] = v
        end
    end
    return out
end

function Array:at(index)
    if index < 0 then index = #self + index + 1 end
    return self[index]
end

function Array:merge(...)
    local out = Array:from(self)
    local n = #out
    for _, t in ipairs({ ... }) do
        for i = 1, #t do
            n = n + 1
            out[n] = t[i]
        end
    end
    return out
end

function Array:every(fn)
    for i = 1, #self do if not fn(self[i], i) then return false end end
    return true
end

function Array:some(fn)
    for i = 1, #self do if fn(self[i], i) then return true end end
    return false
end

function Array:fill(value, start, finish)
    for i = start or 1, finish or #self do self[i] = value end
    return self
end

function Array:filter(fn)
    local out, n = Array:new(), 0
    for i = 1, #self do
        if fn(self[i], i) then
            n = n + 1
            out[n] = self[i]
        end
    end
    return out
end

function Array:find(fn, last)
    if last then
        for i = #self, 1, -1 do if fn(self[i], i) then return self[i] end end
    else
        for i = 1, #self do if fn(self[i], i) then return self[i] end end
    end
end

function Array:findIndex(fn, last)
    if last then
        for i = #self, 1, -1 do if fn(self[i], i) then return i end end
    else
        for i = 1, #self do if fn(self[i], i) then return i end end
    end
end

function Array:indexOf(value, last)
    return self:findIndex(function(v) return v == value end, last)
end

function Array:forEach(fn)
    for i = 1, #self do fn(self[i], i) end
end

function Array:includes(value, from)
    for i = from or 1, #self do if self[i] == value then return true end end
    return false
end

function Array:join(sep)
    local parts = {}
    for i = 1, #self do parts[i] = tostring(self[i]) end
    return table.concat(parts, sep or ',')
end

function Array:map(fn)
    local out = Array:new()
    for i = 1, #self do out[i] = fn(self[i], i) end
    return out
end

function Array:pop()
    return table.remove(self)
end

function Array:push(...)
    local n = #self
    for _, v in ipairs({ ... }) do
        n = n + 1
        self[n] = v
    end
    return n
end

function Array:reduce(fn, initial, reverse)
    local acc = initial
    local a, b, step = 1, #self, 1
    if reverse then a, b, step = #self, 1, -1 end
    if acc == nil then
        acc = self[a]
        a = a + step
    end
    for i = a, b, step do acc = fn(acc, self[i], i) end
    return acc
end

function Array:reverse()
    local n = #self
    for i = 1, math.floor(n / 2) do self[i], self[n - i + 1] = self[n - i + 1], self[i] end
    return self
end

function Array:shift()
    return table.remove(self, 1)
end

function Array:slice(start, finish)
    local n = #self
    start = start or 1
    finish = finish or n
    if start < 0 then start = n + start + 1 end
    if finish < 0 then finish = n + finish + 1 end
    local out, j = Array:new(), 0
    for i = start, finish do
        j = j + 1
        out[j] = self[i]
    end
    return out
end

function Array:toReversed()
    return Array:from(self):reverse()
end

function Array:unshift(...)
    local args = { ... }
    for i = #args, 1, -1 do table.insert(self, 1, args[i]) end
    return #self
end

return Array
