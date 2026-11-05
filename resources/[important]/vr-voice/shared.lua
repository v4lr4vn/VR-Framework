Cfg = {}
voiceTarget = 1

local isServer = IsDuplicityVersion()
if not isServer then
    playerServerId = GetPlayerServerId(PlayerId())
end

local bridge = GetConvarInt('voice_pmaBridge', 0) == 1

function VoiceExport(name, fn)
    exports(name, fn)
    if bridge then
        AddEventHandler(('__cfx_export_pma-voice_%s'):format(name), function(setCB) setCB(fn) end)
    end
end

function VoiceEmit(name, ...)
    TriggerEvent('vr-voice:' .. name, ...)
    if bridge then TriggerEvent('pma-voice:' .. name, ...) end
end

function VoiceOn(name, fn, isNet)
    local register = isNet and RegisterNetEvent or AddEventHandler
    register('vr-voice:' .. name, fn)
    if bridge then register('pma-voice:' .. name, fn) end
end

if GetConvar('voice_useNativeAudio', 'false') == 'true' then
    Cfg.voiceModes = {
        { 1.5, 'Whisper' },
        { 3.0, 'Normal' },
        { 6.0, 'Shouting' },
    }
else
    Cfg.voiceModes = {
        { 3.0, 'Whisper' },
        { 7.0, 'Normal' },
        { 15.0, 'Shouting' },
    }
end

voiceDebugLevel = GetConvarInt('voice_debugMode', 0)
if isServer then
    CreateThread(function()
        while true do
            Wait(5000)
            voiceDebugLevel = GetConvarInt('voice_debugMode', 0)
        end
    end)
end

logger = {
    log = function(message, ...)
        print(message:format(...))
    end,
    info = function(message, ...)
        if voiceDebugLevel >= 1 then print(('[info] ' .. message):format(...)) end
    end,
    warn = function(message, ...)
        print(('[^1WARNING^7] ' .. message):format(...))
    end,
    error = function(message, ...)
        error(message:format(...))
    end,
    verbose = function(message, ...)
        if voiceDebugLevel >= 4 then print(('[verbose] ' .. message):format(...)) end
    end,
}

function tPrint(tbl, indent)
    indent = indent or 0
    for k, v in pairs(tbl) do
        local prefix = string.rep('  ', indent) .. tostring(k) .. ': '
        if type(v) == 'table' then
            print(prefix)
            tPrint(v, indent + 1)
        else
            print(prefix .. tostring(v))
        end
    end
end

function type_check(...)
    local vars = { ... }
    for i = 1, #vars do
        local var = vars[i]
        local actual = type(var[1])
        local expected, j = {}, 2
        while var[j] ~= nil do
            if var[j] == actual then
                expected = nil
                break
            end
            expected[#expected + 1] = var[j]
            j = j + 1
        end
        if expected then
            error(('Invalid type sent to argument #%s, expected %s, got %s'):format(i, table.concat(expected, '|'), actual))
        end
    end
end

function isTrue(value)
    return value == true or value == 1
end

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-voice'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
