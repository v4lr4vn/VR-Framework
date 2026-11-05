return function(eventName, targetIds, ...)
    local payload = msgpack.pack_args(...)
    local len = #payload
    if type(targetIds) ~= 'table' then
        TriggerClientEventInternal(eventName, targetIds, payload, len)
        return
    end
    for i = 1, #targetIds do
        TriggerClientEventInternal(eventName, targetIds[i], payload, len)
    end
end
