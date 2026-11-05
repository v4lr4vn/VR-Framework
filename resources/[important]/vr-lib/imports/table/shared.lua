local pairs, type = pairs, type

local function contains(tbl, value)
    if type(value) ~= 'table' then
        for _, v in pairs(tbl) do
            if v == value then return true end
        end
        return false
    end
    local found = {}
    for _, want in pairs(value) do
        for _, v in pairs(tbl) do
            if v == want then
                found[want] = true
                break
            end
        end
    end
    for _, want in pairs(value) do
        if not found[want] then return false end
    end
    return true
end

local function matches(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do
        if not matches(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function deepclone(tbl, seen)
    if type(tbl) ~= 'table' then return tbl end
    seen = seen or {}
    if seen[tbl] then return seen[tbl] end
    local out = {}
    seen[tbl] = out
    for k, v in pairs(tbl) do
        out[deepclone(k, seen)] = deepclone(v, seen)
    end
    return setmetatable(out, getmetatable(tbl))
end

local function merge(t1, t2, addDuplicateNumbers)
    if addDuplicateNumbers == nil then addDuplicateNumbers = true end
    for k, v2 in pairs(t2) do
        local v1 = t1[k]
        local tv1, tv2 = type(v1), type(v2)
        if tv1 == 'table' and tv2 == 'table' then
            merge(v1, v2, addDuplicateNumbers)
        elseif addDuplicateNumbers and tv1 == 'number' and tv2 == 'number' then
            t1[k] = v1 + v2
        else
            t1[k] = v2
        end
    end
    return t1
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

local function map(tbl, fn)
    local out = {}
    for k, v in pairs(tbl) do out[k] = fn(v, k, tbl) end
    return out
end

local frozen = setmetatable({}, { __mode = 'k' })

local function freeze(tbl)
    local copy = {}
    for k, v in pairs(tbl) do copy[k] = v end
    local proxy = setmetatable({}, {
        __index = copy,
        __newindex = function() error('Attempted to modify a frozen table', 2) end,
        __len = function() return #copy end,
        __pairs = function() return next, copy, nil end,
    })
    frozen[proxy] = true
    return proxy
end

local function isfrozen(tbl)
    return frozen[tbl] == true
end

table.contains = contains
table.matches = matches
table.deepclone = deepclone
table.merge = merge
table.shuffle = shuffle
table.map = map
table.freeze = freeze
table.isfrozen = isfrozen
if not table.wipe then
    table.wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
end

return table
