local function parse(v)
    local out = {}
    for n in tostring(v or ''):gmatch('%d+') do out[#out + 1] = tonumber(n) end
    return out
end

return function(resource, minimumVersion, printMessage)
    local state = GetResourceState(resource)
    if state ~= 'started' and state ~= 'starting' then
        local msg = ('^1%s requires %s to be started.^0'):format(GetCurrentResourceName(), resource)
        if printMessage then print(msg) end
        return false, msg
    end
    if not minimumVersion then return true end
    local raw = GetResourceMetadata(resource, 'version', 0)
    local current = parse(raw)
    local want = parse(minimumVersion)
    for i = 1, math.max(#current, #want) do
        local a, b = current[i] or 0, want[i] or 0
        if a ~= b then
            if a < b then
                local msg = ('^1%s requires version %s of %s (current %s).^0'):format(GetCurrentResourceName(), minimumVersion, resource, raw or 'unknown')
                if printMessage then print(msg) end
                return false, msg
            end
            break
        end
    end
    return true
end
