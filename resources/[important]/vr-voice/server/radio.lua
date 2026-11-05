local msgpack_pack_args = msgpack.pack_args
local radioChecks = {}

local function enabled() return GetConvarInt('voice_enableRadios', 1) == 1 end

local restricted = {}

local function parseRestrictions(value)
    local out = {}
    for part in tostring(value):gmatch('[^;]+') do
        local lo, hi, types = part:match('^%s*([%d%.]+)%s*%-%s*([%d%.]+)%s*:%s*(.-)%s*$')
        lo, hi = tonumber(lo), tonumber(hi)
        if lo and hi and types then
            local allowed = {}
            for t in types:gmatch('[^,%s]+') do allowed[t:lower()] = true end
            out[#out + 1] = { lo = lo, hi = hi, types = allowed }
        end
    end
    return out
end

restricted = parseRestrictions(GetConvar('voice_restrictedRadio', '1-10:leo,ems,dispatch'))

local function jobOf(source)
    local player = Bridge.player(source)
    local job = player and player.job
    return type(job) == 'table' and job or nil
end

local function restrictionFor(radioChannel)
    for i = 1, #restricted do
        local r = restricted[i]
        if radioChannel >= r.lo and radioChannel < r.hi + 1 then return r end
    end
end

local function allowedOn(source, radioChannel)
    local r = restrictionFor(radioChannel)
    if not r then return true end
    local job = jobOf(source)
    if not job or job.onduty ~= true then return false end
    return r.types[tostring(job.type or ''):lower()] == true or r.types[tostring(job.name or ''):lower()] == true
end

function canJoinChannel(source, radioChannel)
    local check = radioChecks[radioChannel]
    if check then return check(source) end
    return allowedOn(source, radioChannel)
end

local function recheck(source)
    source = tonumber(source)
    local data = source and voiceData[source]
    if not data or not data.radio or data.radio == 0 then return end
    if radioChecks[data.radio] or allowedOn(source, data.radio) then return end
    removePlayerFromRadio(source, data.radio)
    Player(source).state.radioChannel = 0
    TriggerClientEvent('vr-voice:clSetPlayerRadio', source, 0)
    TriggerClientEvent('vr-voice:radioChangeRejected', source)
end

Bridge.on('jobChanged', function(source) recheck(source) end)
Bridge.on('dutyChanged', function(source) recheck(source) end)
Bridge.on('playerUnloaded', function(source) recheck(source) end)

function addChannelCheck(channel, cb)
    if type(channel) ~= 'number' then error(("'channel' expected 'number' got '%s'"):format(type(channel))) end
    if type(cb) ~= 'table' or not cb.__cfx_functionReference then error(("'cb' expected 'function' got '%s'"):format(type(cb))) end
    radioChecks[channel] = cb
    logger.info('%s added a check to channel %s', GetInvokingResource(), channel)
end
VoiceExport('addChannelCheck', addChannelCheck)

function removeChannelCheck(channel)
    if type(channel) ~= 'number' then error(("'channel' expected 'number' got '%s'"):format(type(channel))) end
    radioChecks[channel] = nil
    logger.info('%s removed check for channel %s', GetInvokingResource(), channel)
end
VoiceExport('removeChannelCheck', removeChannelCheck)

local function radioNameGetter_orig(source)
    return GetPlayerName(source)
end
local radioNameGetter = radioNameGetter_orig

local function triggerEventForRadioChannel(eventName, radioTbl, ...)
    local payload = msgpack_pack_args(...)
    local len = payload:len()
    for player in pairs(radioTbl) do
        TriggerClientEventInternal(eventName, player, payload, len)
    end
end

function overrideRadioNameGetter(_, cb)
    if type(cb) == 'table' and not cb.__cfx_functionReference then
        error(("'cb' expected 'function' got '%s'"):format(type(cb)))
    end
    radioNameGetter = cb
    logger.info('%s overrode the radio name getter', GetInvokingResource())
end
VoiceExport('overrideRadioNameGetter', overrideRadioNameGetter)

function addPlayerToRadio(source, radioChannel)
    if not canJoinChannel(source, radioChannel) then
        TriggerClientEvent('vr-voice:radioChangeRejected', source)
        TriggerClientEvent('vr-voice:removePlayerFromRadio', source, source)
        return false
    end
    logger.verbose('[radio] Added %s to radio %s', source, radioChannel)
    radioData[radioChannel] = radioData[radioChannel] or {}
    local syncNames = GetConvarInt('voice_syncPlayerNames', 0) == 1
    local plyName = radioNameGetter(source)
    triggerEventForRadioChannel('vr-voice:addPlayerToRadio', radioData[radioChannel], source, plyName)
    voiceData[source] = voiceData[source] or defaultTable(source)
    voiceData[source].radio = radioChannel
    radioData[radioChannel][source] = false
    TriggerClientEvent('vr-voice:syncRadioData', source, radioData[radioChannel], syncNames and plyName)
    return true
end

function removePlayerFromRadio(source, radioChannel)
    logger.verbose('[radio] Removed %s from radio %s', source, radioChannel)
    local channel = radioData[radioChannel]
    if channel then
        triggerEventForRadioChannel('vr-voice:removePlayerFromRadio', channel, source)
        channel[source] = nil
        if not next(channel) then radioData[radioChannel] = nil end
    end
    voiceData[source] = voiceData[source] or defaultTable(source)
    voiceData[source].radio = 0
end

function setPlayerRadio(source, newChannel)
    if not enabled() then return end
    voiceData[source] = voiceData[source] or defaultTable(source)
    local isResource = GetInvokingResource()
    local plyVoice = voiceData[source]
    local radioChannel = tonumber(newChannel)
    if not radioChannel then
        if isResource then error(("'radioChannel' expected 'number', got: %s"):format(type(newChannel))) end
        return logger.warn("%s sent a invalid radio, 'radioChannel' expected 'number', got: %s", source, type(newChannel))
    end

    if isResource then TriggerClientEvent('vr-voice:clSetPlayerRadio', source, radioChannel) end

    if radioChannel ~= 0 then
        if plyVoice.radio > 0 then removePlayerFromRadio(source, plyVoice.radio) end
        local wasAdded = addPlayerToRadio(source, radioChannel)
        Player(source).state.radioChannel = wasAdded and radioChannel or 0
    else
        removePlayerFromRadio(source, plyVoice.radio)
        Player(source).state.radioChannel = 0
    end
end
VoiceExport('setPlayerRadio', setPlayerRadio)

VoiceOn('setPlayerRadio', function(radioChannel)
    setPlayerRadio(source, radioChannel)
end, true)

function setTalkingOnRadio(talking)
    if not enabled() then return end
    local src = source
    voiceData[src] = voiceData[src] or defaultTable(src)
    local plyVoice = voiceData[src]
    local radioTbl = radioData[plyVoice.radio]
    if radioTbl then
        talking = talking == true
        radioTbl[src] = talking
        logger.verbose('[radio] Set %s to talking: %s on radio %s', src, talking, plyVoice.radio)
        triggerEventForRadioChannel('vr-voice:setTalkingOnRadio', radioTbl, src, talking)
    end
end
RegisterNetEvent('vr-voice:setTalkingOnRadio', setTalkingOnRadio)

AddEventHandler('onResourceStop', function(resource)
    for channel, ref in pairs(radioChecks) do
        local fnRef = ref.__cfx_functionReference
        if fnRef and fnRef:find(resource, 1, true) then
            radioChecks[channel] = nil
            logger.warn('Channel %s had its radio check removed because the resource that gave the checks stopped', channel)
        end
    end
    if type(radioNameGetter) == 'table' then
        local fnRef = radioNameGetter.__cfx_functionReference
        if fnRef and fnRef:find(resource, 1, true) then
            radioNameGetter = radioNameGetter_orig
            logger.warn('Radio name getter is resetting to default because the resource that gave the cb got turned off')
        end
    end
end)
