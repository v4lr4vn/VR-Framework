local pending = {}
local resource = GetCurrentResourceName()
local replyEvent = ('__vrl_cbr_%s'):format(resource)
local timeout = GetConvarInt('vr:callbackTimeout', 300000)

RegisterNetEvent(replyEvent, function(key, ...)
    local src = source
    local entry = pending[key]
    if not entry or entry.target ~= src then return end
    pending[key] = nil
    if entry.cb then
        entry.cb(...)
    else
        entry.promise:resolve(table.pack(...))
    end
end)

local function nextKey(event)
    local key
    repeat
        key = ('%s:%s:%s'):format(event, math.random(0, 1000000), GetGameTimer())
    until not pending[key]
    return key
end

local function trigger(event, playerId, cb, ...)
    playerId = tonumber(playerId)
    if not playerId or not DoesPlayerExist(tostring(playerId)) then
        return nil
    end
    local key = nextKey(event)
    local entry = { target = playerId, cb = type(cb) == 'function' and cb or nil }
    if not entry.cb then entry.promise = promise.new() end
    pending[key] = entry
    TriggerClientEvent(('__vrl_cb_%s'):format(event), playerId, resource, key, ...)
    if timeout > 0 then
        SetTimeout(timeout, function()
            if pending[key] == entry then
                pending[key] = nil
                print(('^3[vr-lib] callback %s to %s timed out after %sms^7'):format(event, playerId, timeout))
                if entry.promise then entry.promise:resolve({ n = 0 }) end
            end
        end)
    end
    return entry
end

AddEventHandler('playerDropped', function()
    local src = source
    for key, entry in pairs(pending) do
        if entry.target == src then
            pending[key] = nil
            if entry.promise then entry.promise:resolve({ n = 0 }) end
        end
    end
end)

local callback = setmetatable({}, {
    __call = function(_, event, playerId, cb, ...)
        trigger(event, playerId, cb or function() end, ...)
    end,
})

function callback.await(event, playerId, ...)
    local entry = trigger(event, playerId, nil, ...)
    if not entry then return nil end
    local result = Citizen.Await(entry.promise)
    return table.unpack(result, 1, result.n)
end

local function respond(ok, ...)
    if not ok then
        print(('^1[vr-lib] callback error: %s^0'):format((...)))
        return
    end
    return ...
end

function callback.register(name, cb)
    RegisterNetEvent(('__vrl_cb_%s'):format(name), function(origin, key, ...)
        local src = source
        if type(origin) ~= 'string' or #origin > 64 or type(key) ~= 'string' or #key > 160 then return end
        TriggerClientEvent(('__vrl_cbr_%s'):format(origin), src, key, respond(pcall(cb, src, ...)))
    end)
end

return callback
