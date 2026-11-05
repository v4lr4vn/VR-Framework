if not _VERSION:find('5.4') then
    error('Lua 5.4 must be enabled in the resource manifest!', 2)
end

local resourceName = GetCurrentResourceName()
local VRLIB = 'vr-lib'

if resourceName == VRLIB then return end

if lib and lib.name == VRLIB then
    error(("Cannot load vr-lib more than once.\n\tRemove any duplicate entries from '@%s/fxmanifest.lua'"):format(resourceName))
end

if GetResourceState(VRLIB) ~= 'started' then
    error('^1vr-lib must be started before this resource.^0', 0)
end

local export = exports[VRLIB]
local context = IsDuplicityVersion() and 'server' or 'client'

if msgpack and msgpack.setoption then msgpack.setoption('ignore_invalid', true) end

function noop() end

local UI_FUNCS = {
    notify = 'notify', showTextUI = true, hideTextUI = true, isTextUIOpen = true,
    progressBar = true, progressCircle = true, progressActive = true, cancelProgress = true,
    registerContext = true, showContext = true, hideContext = true, getOpenContextMenu = true,
    registerMenu = true, showMenu = true, hideMenu = true, setMenuOptions = true, getOpenMenu = true,
    inputDialog = true, closeInputDialog = true, alertDialog = true, closeAlertDialog = true,
    skillCheck = true, skillCheckActive = true, cancelSkillCheck = true,
    addRadialItem = true, removeRadialItem = true, clearRadialItems = true, registerRadial = true,
    showRadial = true, showRadialMenu = true, hideRadial = true, disableRadial = true, getCurrentRadialId = true,
    setClipboard = true,
}

local function loadModule(self, module)
    local dir = ('imports/%s'):format(module)
    local chunk = LoadResourceFile(VRLIB, ('%s/%s.lua'):format(dir, context))
    local shared = LoadResourceFile(VRLIB, ('%s/shared.lua'):format(dir))

    if shared then
        chunk = chunk and ('%s\n%s'):format(shared, chunk) or shared
    end

    if not chunk then return nil end

    local fn, err = load(chunk, ('@@vr-lib/%s/%s.lua'):format(dir, context))

    if not fn or err then
        return error(('\n^1Error importing module (%s): %s^0'):format(dir, err), 3)
    end

    local result = fn()
    self[module] = result or noop
    return self[module]
end

local function call(self, index, ...)
    local module = rawget(self, index)

    if not module then
        self[index] = noop
        module = loadModule(self, index)

        if not module then
            local method

            if context == 'client' and UI_FUNCS[index] then
                method = function(...)
                    return exports['vr-ui'][index](nil, ...)
                end
            else
                method = function(...)
                    return export[index](nil, ...)
                end
            end

            self[index] = method
            return method
        end
    end

    return module
end

local lib = setmetatable({
    name = VRLIB,
    context = context,
}, {
    __index = call,
    __call = call,
})

local intervals = {}

function SetInterval(callback, interval, ...)
    interval = interval or 0

    if type(interval) ~= 'number' then
        return error(('Interval must be a number. Received %s'):format(json.encode(interval)))
    end

    local cbType = type(callback)

    if cbType == 'number' and intervals[callback] then
        intervals[callback] = interval or 0
        return
    end

    if cbType ~= 'function' then
        return error(('Callback must be a function. Received %s'):format(cbType))
    end

    local args, id = { ... }, nil

    Citizen.CreateThreadNow(function(ref)
        id = ref
        intervals[id] = interval or 0
        repeat
            local wait = intervals[id]
            Wait(wait)
            if intervals[id] < 0 then break end
            callback(table.unpack(args))
        until false
        intervals[id] = nil
    end)

    return id
end

function ClearInterval(id)
    if type(id) ~= 'number' then
        return error(('Interval id must be a number. Received %s'):format(json.encode(id)))
    end

    if not intervals[id] then
        return error(('No interval exists with id %s'):format(id))
    end

    intervals[id] = -1
end

local cacheEvents = {}
local liveKeys = {}

local cache = setmetatable({ game = GetGameName and GetGameName() or 'fivem', resource = resourceName }, {
    __index = function(self, key)
        if liveKeys[key] then return liveKeys[key]() end

        cacheEvents[key] = {}

        AddEventHandler(('vr-lib:cache:%s'):format(key), function(value)
            local oldValue = rawget(self, key)
            local events = cacheEvents[key]

            for i = 1, #events do
                Citizen.CreateThreadNow(function()
                    events[i](value, oldValue)
                end)
            end

            rawset(self, key, value)
        end)

        local value = export:cache(key)
        if value == nil then value = false end
        return rawset(self, key, value)[key]
    end,

    __call = function(self, key, func, timeout)
        local value = rawget(self, key)

        if value == nil then
            value = func()
            rawset(self, key, value)

            if timeout then
                SetTimeout(timeout, function() rawset(self, key, nil) end)
            end
        end

        return value
    end,
})

if context == 'client' then
    liveKeys.coords = function()
        return GetEntityCoords(cache.ped)
    end
end

function lib.onCache(key, cb)
    if not cacheEvents[key] then
        getmetatable(cache).__index(cache, key)
    end

    table.insert(cacheEvents[key], cb)
end

_ENV.lib = lib
_ENV.cache = cache
_ENV.require = lib.require

local localeStub
localeStub = function(...)
    local init = lib.locale
    if type(init) == 'function' and init ~= noop then init() end
    if _ENV.locale == localeStub then return (...) end
    return _ENV.locale(...)
end
_ENV.locale = localeStub

if context == 'client' then
    cache.playerId = PlayerId()
    cache.serverId = GetPlayerServerId(cache.playerId)
else
    function lib.notify(playerId, data)
        TriggerClientEvent('vr-ui:notify', playerId, data)
    end

    function GetActivePlayers()
        local playerNum = GetNumPlayerIndices()
        local players = {}

        for i = 1, playerNum do
            players[i] = tonumber(GetPlayerFromIndex(i - 1))
        end

        return players
    end
end

for _, key in ipairs({ 'vr_lib', 'ox_lib' }) do
    for i = 1, GetNumResourceMetadata(cache.resource, key) do
        local name = GetResourceMetadata(cache.resource, key, i - 1)

        if name and not rawget(lib, name) then
            local module = loadModule(lib, name)
            if type(module) == 'function' then pcall(module) end
        end
    end
end
