local pending = {}
local timers = {}
local resource = GetCurrentResourceName()
local replyEvent = ('__vrl_cbr_%s'):format(resource)
local timeout = GetConvarInt('vr:callbackTimeout', 300000)

RegisterNetEvent(replyEvent, function(key, ...)
    local entry = pending[key]
    if not entry then return end
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

local function trigger(event, delay, cb, ...)
    if type(delay) == 'number' and delay > 0 then
        local now = GetGameTimer()
        if (timers[event] or 0) > now then return false end
        timers[event] = now + delay
    end
    local key = nextKey(event)
    local entry = { cb = type(cb) == 'function' and cb or nil }
    if not entry.cb then entry.promise = promise.new() end
    pending[key] = entry
    TriggerServerEvent(('__vrl_cb_%s'):format(event), resource, key, ...)
    if timeout > 0 then
        SetTimeout(timeout, function()
            if pending[key] == entry then
                pending[key] = nil
                print(('^3[vr-lib] callback %s timed out after %sms^7'):format(event, timeout))
                if entry.promise then entry.promise:resolve({ n = 0 }) end
            end
        end)
    end
    return entry
end

local callback = setmetatable({}, {
    __call = function(_, event, delay, cb, ...)
        trigger(event, delay, cb or function() end, ...)
    end,
})

function callback.await(event, delay, ...)
    local entry = trigger(event, delay, nil, ...)
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
        if type(origin) ~= 'string' or type(key) ~= 'string' then return end
        TriggerServerEvent(('__vrl_cbr_%s'):format(origin), key, respond(pcall(cb, ...)))
    end)
end

return callback
