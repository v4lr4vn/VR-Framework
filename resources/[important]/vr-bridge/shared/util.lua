local U = {}
Bridge.util = U

function U.decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, out = pcall(json.decode, value)
    if ok and out ~= nil then return out end
    return fallback
end

function U.callable(v)
    if type(v) == 'function' then return true end
    if type(v) ~= 'table' then return false end
    if type(rawget(v, '__cfx_functionReference')) == 'string' then return true end
    local mt = getmetatable(v)
    return type(mt) == 'table' and type(rawget(mt, '__call')) == 'function'
end

function U.trim(s)
    if type(s) ~= 'string' then return nil end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.fullName(first, last)
    local name = ('%s %s'):format(first or '', last or '')
    name = U.trim(name)
    return name ~= '' and name or 'Unknown'
end

function U.gender(value)
    if value == nil then return nil end
    if type(value) == 'number' then return value == 1 and 1 or 0 end
    local s = tostring(value):lower()
    if s == '1' or s == 'f' or s == 'female' or s == 'woman' then return 1 end
    return 0
end

function U.dob(value)
    if type(value) ~= 'string' or value == '' then return nil end
    local y, m, d = value:match('^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)')
    if y then return ('%04d-%02d-%02d'):format(tonumber(y), tonumber(m), tonumber(d)) end
    local d2, m2, y2 = value:match('^(%d%d?)[-/.](%d%d?)[-/.](%d%d%d%d)')
    if y2 then return ('%04d-%02d-%02d'):format(tonumber(y2), tonumber(m2), tonumber(d2)) end
    return value
end

function U.int(value, fallback)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return math.floor(n)
end

function U.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = U.copy(v) end
    return out
end

function U.like(s)
    return '%' .. tostring(s):gsub('[%%_\\]', '\\%0') .. '%'
end

function U.placeholders(n)
    local t = {}
    for i = 1, n do t[i] = '?' end
    return table.concat(t, ', ')
end

function U.started(name)
    return GetResourceState(name) == 'started'
end

function U.present(name)
    local state = GetResourceState(name)
    return state ~= 'missing' and state ~= 'unknown'
end

function U.waitFor(name, ms)
    if U.started(name) then return true end
    if not U.present(name) then return false end
    local deadline = GetGameTimer() + (ms or 15000)
    while GetGameTimer() < deadline do
        if U.started(name) then return true end
        Wait(100)
    end
    return U.started(name)
end

function U.jobType(name, declared)
    if type(declared) == 'string' and declared ~= '' and declared ~= 'none' then return declared end
    local map = BridgeConfig.jobTypes or {}
    return map[name] or declared or 'none'
end

return U
