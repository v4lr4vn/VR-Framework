local dict = {}
local path = GetResourceMetadata(cache.resource, 'locales_path', 0) or 'locales'

local function flatten(source, target, prefix)
    for key, value in pairs(source) do
        local full = prefix and (prefix .. '.' .. key) or key
        if type(value) == 'table' then
            flatten(value, target, full)
        else
            target[full] = value
        end
    end
    return target
end

function locale(str, ...)
    local lstr = dict[str]
    if lstr then
        if ... then return lstr:format(...) end
        return lstr
    end
    return str
end

function lib.getLocales()
    return dict
end

function lib.getLocaleKey()
    return GetConvar('vr:locale', GetConvar('ox:locale', 'en'))
end

local function read(key)
    local data = LoadResourceFile(cache.resource, ('%s/%s.json'):format(path, key))
    if not data then return nil end
    local ok, decoded = pcall(json.decode, data)
    if not ok or type(decoded) ~= 'table' then
        print(('^3[vr-lib] could not parse %s/%s.json in %s^7'):format(path, key, cache.resource))
        return nil
    end
    return decoded
end

local function merge(a, b)
    for k, v in pairs(b) do
        if type(v) == 'table' and type(a[k]) == 'table' then merge(a[k], v) else a[k] = v end
    end
    return a
end

function lib.locale(key)
    local lang = key or lib.getLocaleKey()
    local locales = read('en') or {}
    if lang ~= 'en' then
        local extra = read(lang)
        if extra then merge(locales, extra) end
    end
    for k in pairs(dict) do dict[k] = nil end
    local flat = flatten(locales, {})
    for k, v in pairs(flat) do
        if type(v) == 'string' then
            v = v:gsub('%${([^}]+)}', function(ref)
                local other = flat[ref]
                if type(other) == 'string' then return other end
                return nil
            end)
        end
        dict[k] = v
    end
end

function lib.getLocale(resource, key)
    local value = exports[resource]:getLocale(key)
    dict[key] = value
    return value
end

exports('getLocale', function(key)
    return dict[key]
end)

AddEventHandler('vr-lib:setLocale', function(key)
    lib.locale(key)
end)

AddEventHandler('ox_lib:setLocale', function(key)
    lib.locale(key)
end)

return lib.locale
