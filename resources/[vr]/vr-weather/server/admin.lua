local S = Weather.state

local function notify(src, text, kind)
    if not src or src <= 0 then
        print(('[vr-weather] %s'):format(text))
        return
    end
    Bridge.notify(src, text, kind or 'inform', nil, 'Weather')
end

local function allowed(src)
    src = tonumber(src)
    if not src or src <= 0 then return true end
    return IsPlayerAceAllowed(src, Config.AdminAce) or Bridge.isAdmin(src)
end

local function fmtClock()
    local h, m = Weather.clock()
    return ('%02d:%02d'):format(h, m)
end

function Weather.adminPayload()
    local seasons = {}
    for key, s in pairs(Config.Seasons.list) do seasons[#seasons + 1] = { key = key, label = s.label } end
    table.sort(seasons, function(a, b) return a.label < b.label end)
    local types = {}
    for i = 1, #WeatherData.types do
        local name = WeatherData.types[i]
        types[i] = { name = name, label = WeatherData.label(name) }
    end
    return {
        time = Weather.timePayload(),
        weather = Weather.weatherPayload(),
        forecast = Weather.forecast(),
        types = types,
        seasons = seasons,
        seasonLabel = WeatherData.season(S.season).label,
        presets = Config.Admin.presets,
        dayLengths = Config.Admin.dayLengthPresets,
        limits = { min = Config.Time.minDayLength, max = Config.Time.maxDayLength },
        units = Config.Weather.units or 'C',
        holiday = S.holiday,
    }
end

local admins = {}

local function pushAdmins()
    local payload
    for src in pairs(admins) do
        if GetPlayerName(src) then
            payload = payload or Weather.adminPayload()
            TriggerClientEvent('vr-weather:client:adminState', src, payload)
        else
            admins[src] = nil
        end
    end
end

AddEventHandler('vr-weather:server:changed', function() pushAdmins() end)

local function openAdmin(src)
    if not allowed(src) then return end
    admins[src] = true
    TriggerClientEvent('vr-weather:client:openAdmin', src, Weather.adminPayload())
end

RegisterNetEvent('vr-weather:server:adminClosed', function()
    admins[source] = nil
end)

AddEventHandler('playerDropped', function()
    admins[source] = nil
end)

local actions = {}

function actions.weather(v)
    local ok = Weather.setWeather(v)
    return ok, ok and ('Weather set to %s'):format(WeatherData.label(S.weather)) or 'Unknown weather type'
end

function actions.time(v)
    if type(v) ~= 'table' then return false, 'Bad time' end
    if Weather.isRealTime() then return false, 'Real time mode is on, the clock follows the real world' end
    local ok = Weather.setTime(v.hour, v.minute)
    return ok, ok and ('Time set to %s'):format(fmtClock()) or 'Bad time'
end

function actions.freezeTime(v)
    Weather.setFreezeTime(v == true)
    return true, S.freezeTime and 'Time frozen' or 'Time running'
end

function actions.freezeWeather(v)
    Weather.setFreezeWeather(v == true)
    return true, S.freezeWeather and 'Weather frozen' or 'Weather running'
end

function actions.blackout(v)
    Weather.setBlackout(v == true)
    return true, S.blackout and 'Blackout on' or 'Blackout off'
end

function actions.dynamic(v)
    Weather.setDynamic(v == true)
    return true, S.dynamic and 'Dynamic weather on' or 'Dynamic weather off'
end

function actions.dayLength(v)
    local ok, len = Weather.setDayLength(v)
    return ok, ok and ('One in-game day now lasts %d real minutes'):format(len) or 'Bad day length'
end

function actions.skip()
    local w = Weather.nextStage()
    return true, ('Skipped to %s'):format(WeatherData.label(w))
end

function actions.reroll()
    S.queue = {}
    Weather.setWeather(S.weather)
    return true, 'Forecast rebuilt'
end

RegisterNetEvent('vr-weather:server:admin', function(name, value)
    local src = source
    if not allowed(src) then return end
    local fn = actions[name]
    if type(name) ~= 'string' or not fn then return end
    local ok, msg = fn(value)
    if msg then notify(src, msg, ok and 'success' or 'error') end
    admins[src] = true
    pushAdmins()
end)

local function tempText(c)
    if (Config.Weather.units or 'C') == 'F' then return ('%d°F'):format(WeatherData.toF(c)) end
    return ('%d°C'):format(c)
end

local function sendForecast(src)
    local f = Weather.forecast()
    if not src or src <= 0 then
        for _, x in ipairs(f) do print(('[vr-weather] %s in %ds (%s)'):format(x.weather, x.startsIn, tempText(x.temp))) end
        return
    end
    local text = ('%s, %s'):format(f[1].label, tempText(f[1].temp))
    if f[2] then text = text .. (' · next %s in %d min'):format(f[2].label, math.max(1, math.floor(f[2].startsIn / 60))) end
    notify(src, text, 'inform')
end

local function onOff(arg, current)
    if arg == nil then return not current end
    arg = tostring(arg):lower()
    return arg == 'on' or arg == 'true' or arg == '1' or arg == 'yes'
end

RegisterCommand('weather', function(src, args)
    if not args[1] then
        if src > 0 then return openAdmin(src) end
        return notify(src, ('%s, season %s'):format(S.weather, S.season))
    end
    local ok, msg = actions.weather(args[1])
    notify(src, msg, ok and 'success' or 'error')
end, true)

RegisterCommand('time', function(src, args)
    if not args[1] then return notify(src, ('It is %s'):format(fmtClock())) end
    local ok, msg = actions.time({ hour = tonumber(args[1]), minute = tonumber(args[2]) or 0 })
    notify(src, msg, ok and 'success' or 'error')
end, true)

RegisterCommand('freezetime', function(src, args)
    local _, msg = actions.freezeTime(onOff(args[1], S.freezeTime))
    notify(src, msg, 'success')
end, true)

RegisterCommand('freezeweather', function(src, args)
    local _, msg = actions.freezeWeather(onOff(args[1], S.freezeWeather))
    notify(src, msg, 'success')
end, true)

RegisterCommand('blackout', function(src, args)
    local _, msg = actions.blackout(onOff(args[1], S.blackout))
    notify(src, msg, 'success')
end, true)

RegisterCommand('dynamicweather', function(src, args)
    local _, msg = actions.dynamic(onOff(args[1], S.dynamic))
    notify(src, msg, 'success')
end, true)

RegisterCommand('daylength', function(src, args)
    if not args[1] then return notify(src, ('One in-game day lasts %d real minutes'):format(S.dayLength)) end
    local ok, msg = actions.dayLength(args[1])
    notify(src, msg, ok and 'success' or 'error')
end, true)

for name, hour in pairs({ morning = 7, noon = 12, evening = 18, night = 23 }) do
    RegisterCommand(name, function(src)
        local ok, msg = actions.time({ hour = hour, minute = 0 })
        notify(src, msg, ok and 'success' or 'error')
    end, true)
end

RegisterCommand('forecast', function(src)
    sendForecast(src)
end, false)
