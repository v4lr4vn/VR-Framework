local KVP = 'vr-weather:state'
local T = Config.Time
local W = Config.Weather
local real = T.realTime or {}

local S = {
    minute = (T.startHour or 9) * 60 + (T.startMinute or 0),
    weather = WeatherData.normalise(W.start) or 'CLEAR',
    blackout = false,
    freezeTime = false,
    freezeWeather = false,
    dynamic = W.dynamic ~= false,
    dayLength = T.dayLengthMinutes or 150,
    queue = {},
    stageEnds = 0,
    season = 'summer',
    holiday = nil,
}

Weather = { state = S }

local timeSeq, weatherSeq = 0, 0
local dirty = false

local function clampDayLength(v)
    v = math.floor(tonumber(v) or S.dayLength)
    return math.max(T.minDayLength or 20, math.min(T.maxDayLength or 1440, v))
end

local function stageSeconds()
    local mn, mx = W.stageMinutes.min or 20, W.stageMinutes.max or 40
    if mx < mn then mx = mn end
    return math.random(mn * 60, mx * 60)
end

local function monthNow()
    return tonumber(os.date('%m')) or 1
end

local function holidayWeather()
    if not (Config.Holidays and Config.Holidays.enabled) then return nil end
    return WeatherData.normalise(Config.Holidays.days[os.date('%m-%d')])
end

local function groundSnow()
    local season = WeatherData.season(S.season)
    return Config.SnowWeathers[S.weather] == true and (season.groundSnow == true or S.weather == 'XMAS')
end

function Weather.isRealTime()
    return real.enabled == true
end

function Weather.timePayload()
    local realMode = Weather.isRealTime()
    return {
        minute = S.minute,
        freeze = S.freezeTime and not realMode,
        dayLength = realMode and 1440 or S.dayLength,
        nightShare = realMode and 0 or T.nightShare,
        ns = T.nightStartHour or 21,
        ne = T.nightEndHour or 6,
        real = realMode,
        seq = timeSeq,
    }
end

function Weather.temperature()
    return WeatherData.temperature(S.season, S.weather, S.minute)
end

function Weather.weatherPayload()
    return {
        weather = S.weather,
        label = WeatherData.label(S.weather),
        blackout = S.blackout,
        freeze = S.freezeWeather,
        dynamic = S.dynamic,
        season = S.season,
        snow = groundSnow(),
        transition = W.transitionSeconds or 45,
        temp = Weather.temperature(),
        seq = weatherSeq,
    }
end

function Weather.publishTime()
    timeSeq = timeSeq + 1
    GlobalState.vrTime = Weather.timePayload()
end

function Weather.publishWeather()
    weatherSeq = weatherSeq + 1
    GlobalState.vrWeather = Weather.weatherPayload()
    TriggerEvent('vr-weather:server:changed', S.weather, S.season)
end

function Weather.save()
    dirty = false
    SetResourceKvp(KVP, json.encode({
        minute = S.minute,
        weather = S.weather,
        blackout = S.blackout,
        freezeTime = S.freezeTime,
        freezeWeather = S.freezeWeather,
        dynamic = S.dynamic,
        dynamicConfig = W.dynamic ~= false,
        dayLength = S.dayLength,
        dayLengthConfig = T.dayLengthMinutes,
        queue = S.queue,
        stageLeft = math.max(0, S.stageEnds - os.time()),
        season = S.season,
    }))
end

local function markDirty()
    dirty = true
end

local function fillQueue()
    local cap = math.max(1, W.forecastStages or 6)
    while #S.queue > cap do table.remove(S.queue) end
    while #S.queue < cap do
        local last = S.queue[#S.queue]
        local from = last and last.weather or S.weather
        S.queue[#S.queue + 1] = { weather = WeatherData.next(from, S.season), seconds = stageSeconds() }
    end
end

local function rebuildQueue()
    S.queue = {}
    fillQueue()
end

local function load()
    local raw = GetResourceKvpString(KVP)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end
    if tonumber(data.minute) then S.minute = WeatherTime.wrap(tonumber(data.minute)) end
    S.weather = WeatherData.normalise(data.weather) or S.weather
    S.blackout = data.blackout == true
    S.freezeTime = data.freezeTime == true
    S.freezeWeather = data.freezeWeather == true
    if data.dynamicConfig == (W.dynamic ~= false) and type(data.dynamic) == 'boolean' then S.dynamic = data.dynamic end
    if tonumber(data.dayLength) and data.dayLengthConfig == T.dayLengthMinutes then S.dayLength = clampDayLength(data.dayLength) end
    if type(data.queue) == 'table' then
        for i = 1, #data.queue do
            local q = data.queue[i]
            local name = type(q) == 'table' and WeatherData.normalise(q.weather)
            if name and tonumber(q.seconds) then S.queue[#S.queue + 1] = { weather = name, seconds = math.floor(tonumber(q.seconds)) } end
        end
    end
    if tonumber(data.stageLeft) then S.stageEnds = os.time() + math.floor(tonumber(data.stageLeft)) end
    if type(data.season) == 'string' then S.season = data.season end
end

function Weather.setWeather(name, keepQueue)
    name = WeatherData.normalise(name)
    if not name then return false end
    local changed = name ~= S.weather
    S.weather = name
    S.stageEnds = os.time() + stageSeconds()
    if not keepQueue then rebuildQueue() end
    Weather.publishWeather()
    markDirty()
    return true, changed
end

function Weather.nextStage()
    local holiday = holidayWeather()
    if holiday then
        S.holiday = holiday
        if S.weather ~= holiday then
            S.weather = holiday
            Weather.publishWeather()
        end
        S.stageEnds = os.time() + stageSeconds()
        markDirty()
        return S.weather
    end
    S.holiday = nil
    local nxt = table.remove(S.queue, 1)
    if not nxt then nxt = { weather = WeatherData.next(S.weather, S.season), seconds = stageSeconds() } end
    S.weather = nxt.weather
    S.stageEnds = os.time() + (nxt.seconds or stageSeconds())
    fillQueue()
    Weather.publishWeather()
    markDirty()
    return S.weather
end

function Weather.setTime(hour, minute)
    hour, minute = tonumber(hour), tonumber(minute) or 0
    if not hour or hour < 0 or hour > 23 or minute < 0 or minute > 59 then return false end
    if Weather.isRealTime() then return false end
    S.minute = math.floor(hour) * 60 + math.floor(minute)
    Weather.publishTime()
    markDirty()
    return true
end

function Weather.setBlackout(value)
    S.blackout = value == true
    Weather.publishWeather()
    markDirty()
    return true
end

function Weather.setFreezeTime(value)
    S.freezeTime = value == true
    Weather.publishTime()
    markDirty()
    return true
end

function Weather.setFreezeWeather(value)
    S.freezeWeather = value == true
    if not S.freezeWeather and S.stageEnds < os.time() then S.stageEnds = os.time() + stageSeconds() end
    Weather.publishWeather()
    markDirty()
    return true
end

function Weather.setDynamic(value)
    S.dynamic = value == true
    if S.dynamic then
        S.stageEnds = os.time() + stageSeconds()
        if #S.queue == 0 then fillQueue() end
    end
    Weather.publishWeather()
    markDirty()
    return true
end

function Weather.setDayLength(minutes)
    minutes = tonumber(minutes)
    if not minutes then return false end
    S.dayLength = clampDayLength(minutes)
    Weather.publishTime()
    markDirty()
    return true, S.dayLength
end

function Weather.setSeason(key)
    if not Config.Seasons.list[key] then return false end
    if key == S.season then return true end
    S.season = key
    rebuildQueue()
    Weather.publishWeather()
    markDirty()
    return true
end

function Weather.forecast()
    local now = os.time()
    local out = {}
    local at = math.max(0, S.stageEnds - now)
    local running = S.dynamic and not S.freezeWeather
    out[1] = { weather = S.weather, label = WeatherData.label(S.weather), startsIn = 0, endsIn = running and at or nil, temp = Weather.temperature(), current = true }
    if not running then return out end
    local realMode = Weather.isRealTime()
    local p = Weather.timePayload()
    for i = 1, #S.queue do
        local q = S.queue[i]
        local minute = S.minute
        if not p.freeze then minute = WeatherTime.advance(S.minute, at, p.dayLength, p.nightShare, p.ns, p.ne) end
        if realMode then minute = WeatherTime.realMinute(now + at, real.utcOffsetHours, real.ukSummerTime) end
        out[#out + 1] = {
            weather = q.weather,
            label = WeatherData.label(q.weather),
            startsIn = at,
            endsIn = at + q.seconds,
            temp = WeatherData.temperature(S.season, q.weather, minute),
        }
        at = at + q.seconds
    end
    return out
end

function Weather.clock()
    local h, m = WeatherTime.split(S.minute)
    return h, m
end

local function updateSeason()
    local key = WeatherData.seasonFor(monthNow())
    if key ~= S.season then Weather.setSeason(key) end
end

CreateThread(function()
    load()
    S.season = WeatherData.seasonFor(monthNow())
    if Weather.isRealTime() then S.minute = WeatherTime.realMinute(os.time(), real.utcOffsetHours, real.ukSummerTime) end
    if #S.queue == 0 then fillQueue() end
    if S.stageEnds <= os.time() then S.stageEnds = os.time() + stageSeconds() end
    local holiday = holidayWeather()
    if holiday and S.dynamic and not S.freezeWeather then
        S.weather = holiday
        S.holiday = holiday
    end
    Weather.publishTime()
    Weather.publishWeather()
    Weather.save()
    local last = GetGameTimer()
    local ticks = 0
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local dt = (now - last) / 1000
        last = now
        ticks = ticks + 1
        if Weather.isRealTime() then
            S.minute = WeatherTime.realMinute(os.time(), real.utcOffsetHours, real.ukSummerTime)
        elseif not S.freezeTime then
            S.minute = WeatherTime.advance(S.minute, dt, S.dayLength, T.nightShare, T.nightStartHour, T.nightEndHour)
        end
        if S.dynamic and not S.freezeWeather and os.time() >= S.stageEnds then
            Weather.nextStage()
        end
        if ticks % 30 == 0 then Weather.publishTime() end
        if ticks % 60 == 0 then
            updateSeason()
            markDirty()
        end
        if dirty and ticks % 10 == 0 then Weather.save() end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Weather.save() end
end)
