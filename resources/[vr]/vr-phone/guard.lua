local expected = 'vr-phone'
local current = GetCurrentResourceName()
if current ~= expected then
    local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
    print(message)
    if IsDuplicityVersion() then
        CreateThread(function() StopResource(current) end)
    end
    error(message, 0)
end
