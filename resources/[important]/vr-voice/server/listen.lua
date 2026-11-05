local listeners = {}
local listening = {}

local function allowedTypes()
    local out = {}
    for t in GetConvar('voice_multiListenTypes', 'dispatch'):gmatch('[^,%s]+') do out[t:lower()] = true end
    return out
end

local function jobOf(source)
    local player = Bridge.player(source)
    local job = player and player.job
    return type(job) == 'table' and job or nil
end

local function mayListen(source)
    local job = jobOf(source)
    if not job or job.onduty ~= true then return false end
    local types = allowedTypes()
    return types[tostring(job.type or ''):lower()] == true or types[tostring(job.name or ''):lower()] == true
end

local function toMembers(channel, name, ...)
    for member in pairs(radioData[channel] or {}) do TriggerClientEvent(name, member, ...) end
end

local function stopListening(source, channel)
    local set = listeners[channel]
    if not set or not set[source] then return end
    set[source] = nil
    if not next(set) then listeners[channel] = nil end
    if listening[source] then listening[source][channel] = nil end
    toMembers(channel, 'vr-voice:removeListener', source)
    TriggerClientEvent('vr-voice:listenRemoved', source, channel)
end

local function startListening(source, channel)
    listeners[channel] = listeners[channel] or {}
    if listeners[channel][source] then return end
    listeners[channel][source] = true
    listening[source] = listening[source] or {}
    listening[source][channel] = true
    toMembers(channel, 'vr-voice:addListener', source)
    TriggerClientEvent('vr-voice:listenSync', source, channel, radioData[channel] or {})
end

function setListenChannels(source, list)
    source = tonumber(source)
    if not source or not voiceData[source] then return false end
    local want = {}
    if type(list) == 'table' and mayListen(source) then
        for i = 1, math.min(#list, 8) do
            local channel = tonumber(list[i])
            if channel and channel > 0 and canJoinChannel(source, channel) then want[channel] = true end
        end
    end
    for channel in pairs(listening[source] or {}) do
        if not want[channel] then stopListening(source, channel) end
    end
    for channel in pairs(want) do startListening(source, channel) end
    local out = {}
    for channel in pairs(listening[source] or {}) do out[#out + 1] = channel end
    table.sort(out)
    return true, out
end
VoiceExport('setListenChannels', setListenChannels)

VoiceExport('getListenChannels', function(source)
    local out = {}
    for channel in pairs(listening[tonumber(source)] or {}) do out[#out + 1] = channel end
    table.sort(out)
    return out
end)

VoiceExport('getListeners', function(channel)
    local out = {}
    for source in pairs(listeners[tonumber(channel)] or {}) do out[#out + 1] = source end
    return out
end)

local baseAdd = addPlayerToRadio
function addPlayerToRadio(source, channel)
    local ok = baseAdd(source, channel)
    if ok then
        TriggerClientEvent('vr-voice:syncListeners', source, listeners[channel] or {})
        for listener in pairs(listeners[channel] or {}) do
            if listener ~= source then TriggerClientEvent('vr-voice:listenJoin', listener, channel, source) end
        end
    end
    return ok
end

local baseRemove = removePlayerFromRadio
function removePlayerFromRadio(source, channel)
    baseRemove(source, channel)
    for listener in pairs(listeners[channel] or {}) do
        if listener ~= source then TriggerClientEvent('vr-voice:listenLeave', listener, channel, source) end
    end
end

RegisterNetEvent('vr-voice:setTalkingOnRadio', function(talking)
    local src = source
    local data = voiceData[src]
    local channel = data and data.radio
    if not channel or channel == 0 then return end
    for listener in pairs(listeners[channel] or {}) do
        if listener ~= src then TriggerClientEvent('vr-voice:setTalkingOnListen', listener, channel, src, talking == true) end
    end
end)

local function recheck(source)
    source = tonumber(source)
    if not source or not listening[source] then return end
    if not mayListen(source) then return setListenChannels(source, {}) end
    for channel in pairs(listening[source]) do
        if not canJoinChannel(source, channel) then stopListening(source, channel) end
    end
end

Bridge.on('jobChanged', function(source) recheck(source) end)
Bridge.on('dutyChanged', function(source) recheck(source) end)
Bridge.on('playerUnloaded', function(source)
    source = tonumber(source)
    if source and listening[source] then setListenChannels(source, {}) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for channel in pairs(listening[src] or {}) do
        local set = listeners[channel]
        if set then
            set[src] = nil
            if not next(set) then listeners[channel] = nil end
            toMembers(channel, 'vr-voice:removeListener', src)
        end
    end
    listening[src] = nil
end)
