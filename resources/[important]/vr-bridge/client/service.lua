local code = LoadResourceFile(GetCurrentResourceName(), 'import.lua')
local Hub = load(code, ('@@%s/import.lua'):format(GetCurrentResourceName()))()

exports('info', function() return Hub.info() end)
exports('playerData', function() return Hub.playerData() end)
exports('loggedIn', function() return Hub.loggedIn() end)

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-bridge'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
