V = {}
U = {}

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function utf8Cut(s, max)
    if #s <= max then return s end
    local cut = s:sub(1, max)
    local i = #cut
    while i > 0 do
        local b = cut:byte(i)
        if b < 0x80 then break end
        if b >= 0xC0 then
            local need = b >= 0xF0 and 4 or b >= 0xE0 and 3 or 2
            if #cut - i + 1 < need then cut = cut:sub(1, i - 1) end
            break
        end
        i = i - 1
    end
    return cut
end

function V.str(v, max, min)
    if type(v) == 'number' then v = tostring(v) end
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    v = utf8Cut(v, max or 255)
    if #v < (min or 1) then return nil end
    return v
end

function V.text(v, max, min)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('\r\n', '\n'):gsub('[%z\1-\8\11\12\14-\31\127]', ''):gsub('\n\n\n+', '\n\n')
    v = v:match('^%s*(.-)%s*$')
    v = utf8Cut(v, max or 4000)
    if #v < (min or 1) then return nil end
    return v
end

function V.int(v, min, max)
    v = tonumber(v)
    if not finite(v) or v ~= math.floor(v) then return nil end
    if (min and v < min) or (max and v > max) then return nil end
    return math.tointeger(v) or v
end

function V.num(v, min, max)
    v = tonumber(v)
    if not finite(v) then return nil end
    if (min and v < min) or (max and v > max) then return nil end
    return v
end

function V.bool(v)
    if v == true or v == false then return v end
    return nil
end

function V.enum(v, set)
    if type(v) ~= 'string' then return nil end
    if set[v] then return v end
    for _, s in ipairs(set) do
        if s == v then return v end
    end
    return nil
end

function V.id(v)
    return V.int(v, 1, 2147483647)
end

function V.cid(v)
    if type(v) ~= 'string' or #v < 1 or #v > 64 or not v:match('^[%w:]+$') then return nil end
    return v
end

function V.plate(v)
    if type(v) ~= 'string' then return nil end
    v = v:upper():match('^%s*(.-)%s*$')
    if #v < 1 or #v > 8 or not v:match('^[%w ]+$') then return nil end
    return v
end

function V.list(v, max, fn)
    if type(v) ~= 'table' then return nil end
    local out = {}
    for i = 1, math.min(#v, max or 50) do
        local x = fn(v[i])
        if x ~= nil then out[#out + 1] = x end
    end
    return out
end

function V.vec(v)
    if type(v) ~= 'table' and type(v) ~= 'vector3' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z or 0)
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return { x = x, y = y, z = z }
end

function V.imageId(v)
    if type(v) ~= 'string' or not v:match('^%x+$') or #v ~= 32 then return nil end
    return v
end

function U.like(s)
    return '%' .. s:gsub('[%%_\\]', '\\%0') .. '%'
end

function U.now()
    return os.time()
end

function U.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = U.copy(v) end
    return out
end

function U.pick(t, keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = t[k] end
    return out
end

function U.round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

function U.decode(s, fallback)
    if type(s) ~= 'string' or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end

function U.vec(c)
    if not c then return nil end
    return { x = U.round(c.x, 2), y = U.round(c.y, 2), z = U.round(c.z, 2) }
end

function U.fullName(charinfo)
    if type(charinfo) ~= 'table' then return 'Unknown' end
    local first, last = charinfo.firstname or '', charinfo.lastname or ''
    local name = (first .. ' ' .. last):match('^%s*(.-)%s*$')
    return name ~= '' and name or 'Unknown'
end
