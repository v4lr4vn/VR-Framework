local nativeRequire = type(require) == 'function' and require or nil
local loaded = {}
local loading = {}
local resource = GetCurrentResourceName()

package = package or {}
package.loaded = package.loaded or {}

local function split(modname)
    if type(modname) ~= 'string' or modname == '' then
        error(('module name must be a non-empty string (received %s)'):format(type(modname)), 3)
    end
    local res, path = resource, modname
    if modname:sub(1, 1) == '@' then
        local sep = modname:find('[./]', 2)
        if not sep then error(('invalid module path %s'):format(modname), 3) end
        res = modname:sub(2, sep - 1)
        path = modname:sub(sep + 1)
    end
    path = path:gsub('%.lua$', '')
    if not path:find('/') then path = path:gsub('%.', '/') end
    return res, path
end

local function read(res, path, ext)
    local candidates = { path .. ext, path .. '/init' .. ext }
    for i = 1, #candidates do
        local file = LoadResourceFile(res, candidates[i])
        if file then return file, candidates[i] end
    end
    return nil
end

local function require(modname)
    if type(modname) ~= 'string' then error('module name must be a string', 2) end
    local key = modname
    if loaded[key] ~= nil then return loaded[key] end
    if package.loaded[key] ~= nil then return package.loaded[key] end
    if loading[key] then error(('circular require of module %s'):format(modname), 2) end
    local res, path = split(modname)
    local chunk, file = read(res, path, '.lua')
    if not chunk and nativeRequire and modname:sub(1, 1) ~= '@' then
        local ok, mod = pcall(nativeRequire, modname)
        if ok and mod ~= nil then
            loaded[key] = mod
            package.loaded[key] = mod
            return mod
        end
    end
    if not chunk then
        error(("module '%s' not found (looked for @%s/%s.lua and @%s/%s/init.lua)"):format(modname, res, path, res, path), 2)
    end
    local fn, err = load(chunk, ('@@%s/%s'):format(res, file))
    if not fn then error(('error loading module %s: %s'):format(modname, err), 2) end
    loading[key] = true
    local ok, result = pcall(fn, modname)
    loading[key] = nil
    if not ok then error(result, 2) end
    if result == nil then result = true end
    loaded[key] = result
    package.loaded[key] = result
    return result
end

local function loadFile(filePath, env)
    local res, path = split(filePath)
    local chunk, file = read(res, path, '.lua')
    if not chunk then error(("file '%s' not found in @%s"):format(path .. '.lua', res), 2) end
    local fn, err = load(chunk, ('@@%s/%s'):format(res, file), 't', env or _ENV)
    if not fn then error(('error loading %s: %s'):format(filePath, err), 2) end
    return fn()
end

local function loadJson(filePath)
    local res, path = split(filePath)
    path = path:gsub('%.json$', '')
    local data = LoadResourceFile(res, path .. '.json')
    if not data then error(("json file '%s.json' not found in @%s"):format(path, res), 2) end
    return json.decode(data)
end

rawset(lib, 'load', loadFile)
rawset(lib, 'loadJson', loadJson)

return require
