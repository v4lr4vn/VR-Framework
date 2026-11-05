UIConfig = {
    notify = {
        position = 'top-right',
        offsetX = 24,
        offsetY = 24,
        width = 340,
        maxVisible = 3,
        duration = 5000,
    },
    textui = { position = 'left-center' },
    progress = { position = 'bottom', cancelKey = 'x', propLimit = 2 },
    context = { position = 'right' },
    menu = { position = 'top-left' },
    radial = { key = 'z', x = 0.24, y = 0.24 },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-ui'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
