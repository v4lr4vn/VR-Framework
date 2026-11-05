InvUtil = {}
local U = InvUtil

InvExports = {}

do
    local raw = exports
    exports = setmetatable({}, {
        __index = function(_, key) return raw[key] end,
        __call = function(_, name, fn)
            InvExports[name] = fn
            return raw(name, fn)
        end,
    })
end

function U.trim(value)
    if type(value) ~= 'string' then return value end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.split(value, sep)
    local out = {}
    if type(value) ~= 'string' then return out end
    for part in (value .. sep):gmatch('(.-)' .. sep:gsub('%p', '%%%0')) do out[#out + 1] = part end
    return out
end

function U.tableType(tbl)
    if type(tbl) ~= 'table' then return nil end
    local n = 0
    local array = true
    for k in pairs(tbl) do
        n = n + 1
        if type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then array = false end
    end
    if n == 0 then return 'empty' end
    if array and n == #tbl then return 'array' end
    if array then return 'hash' end
    return 'hash'
end

function U.clone(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = v end
    return out
end

function U.deepclone(tbl, seen)
    if type(tbl) ~= 'table' then return tbl end
    seen = seen or {}
    if seen[tbl] then return seen[tbl] end
    local out = {}
    seen[tbl] = out
    for k, v in pairs(tbl) do out[U.deepclone(k, seen)] = U.deepclone(v, seen) end
    return out
end

function U.matches(a, b)
    if a == b then return true end
    local ta, tb = type(a), type(b)
    if ta ~= 'table' or tb ~= 'table' then
        if ta == 'number' and tb == 'number' then return a == b end
        return false
    end
    for k, v in pairs(a) do
        if not U.matches(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function U.contains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    if type(value) ~= 'table' then
        for _, v in pairs(tbl) do
            if v == value then return true end
        end
        return false
    end
    for k, v in pairs(value) do
        if type(v) == 'table' then
            if not U.matches(tbl[k], v) then return false end
        elseif tbl[k] ~= v then
            return false
        end
    end
    return true
end

function U.inArray(tbl, value)
    if type(tbl) ~= 'table' then return false end
    for i = 1, #tbl do
        if tbl[i] == value then return true end
    end
    return false
end

function U.count(tbl)
    local n = 0
    if type(tbl) == 'table' then for _ in pairs(tbl) do n = n + 1 end end
    return n
end

function U.wipe(tbl)
    for k in pairs(tbl) do tbl[k] = nil end
    return tbl
end

function U.values(tbl)
    local out = {}
    if type(tbl) ~= 'table' then return out end
    for _, v in pairs(tbl) do out[#out + 1] = v end
    table.sort(out, function(a, b)
        local sa = type(a) == 'table' and tonumber(a.slot) or 0
        local sb = type(b) == 'table' and tonumber(b.slot) or 0
        return sa < sb
    end)
    return out
end

function U.callable(fn)
    local t = type(fn)
    if t == 'function' then return true end
    if t == 'table' then
        local mt = getmetatable(fn)
        return mt ~= nil and mt.__call ~= nil
    end
    return false
end

function U.round(n)
    return math.floor(n + 0.5)
end

function U.groupDigits(number)
    local s = tostring(math.floor(tonumber(number) or 0))
    local sign, digits = s:match('^(-?)(%d+)$')
    if not digits then return s end
    local out = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if out:sub(1, 1) == ',' then out = out:sub(2) end
    return sign .. out
end

function U.isInt(n)
    return type(n) == 'number' and n == n and n % 1 == 0
end

function U.slotIn(n, max)
    return U.isInt(n) and n >= 1 and n <= (max or math.huge)
end

function U.itemName(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    if name:sub(1, 7) == 'weapon_' then name = name:upper() end
    return name
end

function U.toVec3(c)
    local t = type(c)
    if t == 'vector3' then return c end
    if t == 'vector4' then return vector3(c.x, c.y, c.z) end
    if t == 'table' then
        local x, y, z = c.x or c[1], c.y or c[2], c.z or c[3]
        if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    return c
end

function U.isVec3(c)
    local t = type(c)
    if t == 'vector3' or t == 'vector4' then return true end
    return t == 'table' and type(c.x) == 'number' and type(c.y) == 'number' and type(c.z) == 'number'
end

function U.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local events = {}

function U.event(name)
    local cached = events[name]
    if cached then return cached end
    cached = { 'vr-inventory:' .. name }
    if shared.compat then cached[2] = 'ox_inventory:' .. name end
    events[name] = cached
    return cached
end

function U.fire(name, ...)
    local list = U.event(name)
    for i = 1, #list do TriggerEvent(list[i], ...) end
end

function U.netEvent(name, fn)
    local list = U.event(name)
    for i = 1, #list do RegisterNetEvent(list[i], fn) end
end

function U.localEvent(name, fn)
    local list = U.event(name)
    for i = 1, #list do AddEventHandler(list[i], fn) end
end
