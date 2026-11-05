local resource = Bridge.resource
local isServer = Bridge.side == 'server'
local requestEvent = '__vrb_cb_req:%s'
local replyEvent = ('__vrb_cb_res:%s'):format(resource)
local pending = {}
local nextId = 0
local registered = {}

local cb = {}
Bridge.callback = cb

local function finish(id, ok, ...)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    if ok then p:resolve(table.pack(...)) else p:resolve(false) end
end

local function newRequest()
    nextId = nextId + 1
    if nextId > 2147483000 then nextId = 1 end
    local p = promise.new()
    pending[nextId] = p
    return nextId, p
end

local function awaitReply(id, p, timeout)
    local ms = tonumber(timeout) or BridgeConfig.callbackTimeout or 10000
    SetTimeout(ms, function()
        if pending[id] == p then
            pending[id] = nil
            p:resolve(false)
        end
    end)
    local result = Citizen.Await(p)
    if not result then return nil end
    return table.unpack(result, 1, result.n)
end

if isServer then
    RegisterNetEvent(replyEvent, function(id, ok, ...)
        local p = pending[id]
        if not p or p.target ~= source then return end
        finish(id, ok, ...)
    end)

    function cb.register(name, fn)
        if registered[name] then error(('[vr-bridge] callback %s registered twice'):format(name), 2) end
        registered[name] = true
        RegisterNetEvent(requestEvent:format(name), function(id, replyTo, ...)
            local src = source
            if type(id) ~= 'number' or type(replyTo) ~= 'string' or #replyTo > 64 then return end
            local res = table.pack(pcall(fn, src, ...))
            if not res[1] then
                print(('^1[vr-bridge] callback %s failed: %s^0'):format(name, tostring(res[2])))
                return TriggerClientEvent(('__vrb_cb_res:%s'):format(replyTo), src, id, false)
            end
            TriggerClientEvent(('__vrb_cb_res:%s'):format(replyTo), src, id, true, table.unpack(res, 2, res.n))
        end)
    end

    function cb.await(name, target, timeout, ...)
        local id, p = newRequest()
        p.target = target
        TriggerClientEvent(requestEvent:format(name), target, id, resource, ...)
        return awaitReply(id, p, timeout)
    end
else
    RegisterNetEvent(replyEvent, function(id, ok, ...)
        finish(id, ok, ...)
    end)

    function cb.register(name, fn)
        if registered[name] then error(('[vr-bridge] callback %s registered twice'):format(name), 2) end
        registered[name] = true
        RegisterNetEvent(requestEvent:format(name), function(id, replyTo, ...)
            if type(id) ~= 'number' or type(replyTo) ~= 'string' then return end
            local res = table.pack(pcall(fn, ...))
            if not res[1] then
                print(('^1[vr-bridge] callback %s failed: %s^0'):format(name, tostring(res[2])))
                return TriggerServerEvent(('__vrb_cb_res:%s'):format(replyTo), id, false)
            end
            TriggerServerEvent(('__vrb_cb_res:%s'):format(replyTo), id, true, table.unpack(res, 2, res.n))
        end)
    end

    function cb.await(name, timeout, ...)
        local id, p = newRequest()
        TriggerServerEvent(requestEvent:format(name), id, resource, ...)
        return awaitReply(id, p, timeout)
    end
end

return true
