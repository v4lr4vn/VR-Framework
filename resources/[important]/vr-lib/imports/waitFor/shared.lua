return function(cb, errMessage, timeout)
    local value = cb()
    if value ~= nil then return value end
    if timeout ~= false and type(timeout) ~= 'number' then timeout = 1000 end
    local start = GetGameTimer()
    while value == nil do
        Wait(0)
        if timeout then
            local elapsed = GetGameTimer() - start
            if elapsed > timeout then
                return error(('%s (waited %.1fms)'):format(errMessage or 'failed to resolve callback', elapsed), 2)
            end
        end
        value = cb()
    end
    return value
end
