local levels = { error = 1, warn = 2, info = 3, verbose = 4, debug = 5 }
local prefixes = { '^1[ERROR]', '^3[WARN]', '^7[INFO]', '^4[VERBOSE]', '^6[DEBUG]' }
local resource = GetCurrentResourceName()

local function current()
    local value = GetConvar(('vr:printlevel:%s'):format(resource), GetConvar(('ox:printlevel:%s'):format(resource), GetConvar('vr:printlevel', GetConvar('ox:printlevel', 'info'))))
    return levels[value] or levels.info
end

local function out(lvl, ...)
    if lvl > current() then return end
    local n = select('#', ...)
    local args = { ... }
    for i = 1, n do
        local v = args[i]
        args[i] = type(v) == 'table' and json.encode(v, { indent = true }) or tostring(v)
    end
    print(('%s %s^7'):format(prefixes[lvl], table.concat(args, '\t', 1, n)))
end

local printer = {}
for name, lvl in pairs(levels) do
    printer[name] = function(...) out(lvl, ...) end
end

return printer
