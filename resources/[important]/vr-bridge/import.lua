if Bridge and Bridge.ready then return Bridge end

local RESOURCE = 'vr-bridge'
local side = IsDuplicityVersion() and 'server' or 'client'
local loaded = {}

local function include(path)
    local cached = loaded[path]
    if cached ~= nil then return cached end
    local code = LoadResourceFile(RESOURCE, path)
    if not code then error(('[vr-bridge] missing file %s'):format(path), 2) end
    local fn, err = load(code, ('@@%s/%s'):format(RESOURCE, path))
    if not fn then error(('[vr-bridge] %s'):format(err), 2) end
    local result = fn()
    if result == nil then result = true end
    loaded[path] = result
    return result
end

Bridge = {
    side = side,
    resource = GetCurrentResourceName(),
    include = include,
}

include('config.lua')
include('shared/util.lua')
include('shared/detect.lua')
include('shared/events.lua')
include('shared/callback.lua')
include(side .. '/main.lua')

Bridge.ready = true
return Bridge
