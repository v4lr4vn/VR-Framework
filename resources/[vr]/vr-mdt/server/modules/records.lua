Records = {}

function Records.placeholders(n)
    return ('?'):rep(n, ', ')
end

function Records.isList(t)
    if type(t) ~= 'table' then return false end
    for k in pairs(t) do
        if math.type(k) ~= 'integer' or k < 1 then return false end
    end
    return true
end

function Records.cleanFlags(list, options)
    if not Records.isList(list) or #list > #options then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local flag = V.enum(list[i], options)
        if not flag then return nil end
        if not seen[flag] then
            seen[flag] = true
            out[#out + 1] = flag
        end
    end
    return out
end

function Records.flagDiff(before, after)
    local had, has = {}, {}
    for _, f in ipairs(before or {}) do had[f] = true end
    for _, f in ipairs(after or {}) do has[f] = true end
    local added, removed = {}, {}
    for _, f in ipairs(after or {}) do
        if not had[f] then added[#added + 1] = f end
    end
    for _, f in ipairs(before or {}) do
        if not has[f] then removed[#removed + 1] = f end
    end
    return added, removed
end

function Records.notes(v)
    if type(v) ~= 'string' then return nil end
    if not v:find('%S') then return '' end
    return V.text(v, 4000)
end

function Records.flagsOf(raw)
    local list = U.decode(raw, {})
    if not Records.isList(list) then return {} end
    local out = {}
    for _, f in ipairs(list) do
        if type(f) == 'string' then out[#out + 1] = f end
    end
    return out
end

function Records.optional(fn, ...)
    if type(fn) ~= 'function' then return {} end
    local ok, res = pcall(fn, ...)
    if ok and type(res) == 'table' then return res end
    if not ok then print(('^1[vr-mdt] records: %s^0'):format(tostring(res))) end
    return {}
end

function Records.serial(v)
    v = V.str(v, 32, 4)
    if not v or not v:match('^[%w%-]+$') then return nil end
    return v:upper()
end

function Records.vehicleLabel(model)
    if type(model) ~= 'string' then return nil end
    local label = Bridge.vehicles.label and (Bridge.vehicles.label(model) or Bridge.vehicles.label(model:lower()))
    return label or model
end

function Records.ownerNames(cids)
    local names = {}
    for cid, c in pairs(Bridge.chars.many(cids) or {}) do names[cid] = c.name end
    return names
end
