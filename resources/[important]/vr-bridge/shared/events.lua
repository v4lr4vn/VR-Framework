local handlers = {}

function Bridge.on(name, fn)
    if type(fn) ~= 'function' then return end
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = fn
end

function Bridge.emit(name, ...)
    local list = handlers[name]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then print(('^1[vr-bridge] %s handler failed in %s: %s^0'):format(name, Bridge.resource, tostring(err))) end
    end
end

return true
