local T = GlobalState.vrTime
local Wx = GlobalState.vrWeather
local base = { minute = 720, at = GetGameTimer() }
local synced = true
local applied = nil
local settleAt = nil
local lastMsPerMinute = nil
local snowOn = false
local override = { weather = 'CLEAR', hour = 18, minute = 0 }

WeatherClient = {}

local function onTime(value)
    if type(value) ~= 'table' then return end
    T = value
    base.minute = tonumber(value.minute) or base.minute
    base.at = GetGameTimer()
end

function WeatherClient.minute()
    if not T then return base.minute end
    if T.freeze then return base.minute end
    local dt = (GetGameTimer() - base.at) / 1000
    return WeatherTime.advance(base.minute, dt, T.dayLength, T.nightShare, T.ns, T.ne)
end

local function setSnow(on)
    if on == snowOn then return end
    snowOn = on
    SetForceVehicleTrails(on)
    SetForcePedFootstepsTracks(on)
    if ForceSnowPass then ForceSnowPass(on) end
end

local function settle(name)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(name)
    SetWeatherTypeNow(name)
    SetWeatherTypeNowPersist(name)
end

local function applyWeather(name, instant)
    if not name then return end
    if instant or not applied then
        settle(name)
        settleAt = nil
    else
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypeOverTime(name, (Wx and Wx.transition or 45) + 0.0)
        settleAt = GetGameTimer() + ((Wx and Wx.transition or 45) * 1000)
    end
    applied = name
end

local function onWeather(value)
    if type(value) ~= 'table' then return end
    Wx = value
    if not synced then return end
    if value.weather ~= applied then applyWeather(value.weather, false) end
    SetArtificialLightsState(value.blackout == true)
    SetArtificialLightsStateAffectsVehicles(false)
    setSnow(value.snow == true)
end

AddStateBagChangeHandler('vrTime', 'global', function(_, _, value) onTime(value) end)
AddStateBagChangeHandler('vrWeather', 'global', function(_, _, value) onWeather(value) end)

local function setSynced(value)
    value = value ~= false
    if value == synced then return end
    synced = value
    applied = nil
    if synced then
        if Wx then onWeather(Wx) end
    else
        settle(override.weather)
        applied = override.weather
        SetArtificialLightsState(false)
        setSnow(false)
    end
end

WeatherClient.setSynced = setSynced

CreateThread(function()
    if T then onTime(T) end
    if Wx then onWeather(Wx) end
    while true do
        if synced then
            local minute = WeatherClient.minute()
            local h, m, s = WeatherTime.split(minute)
            NetworkOverrideClockTime(h, m, s)
            if T and NetworkOverrideClockMillisecondsPerGameMinute then
                local ms = T.freeze and 0 or math.floor(WeatherTime.realSecondsPerGameMinute(minute, T.dayLength, T.nightShare, T.ns, T.ne) * 1000)
                if ms ~= lastMsPerMinute and ms > 0 then
                    lastMsPerMinute = ms
                    NetworkOverrideClockMillisecondsPerGameMinute(ms)
                end
            end
        else
            NetworkOverrideClockTime(override.hour, override.minute, 0)
        end
        Wait(250)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if synced then
            if settleAt and GetGameTimer() >= settleAt then
                settleAt = nil
                if applied then settle(applied) end
            elseif not settleAt and Wx and Wx.weather then
                if applied ~= Wx.weather then
                    applyWeather(Wx.weather, false)
                end
            end
            if Wx then SetArtificialLightsState(Wx.blackout == true) end
        else
            settle(override.weather)
        end
    end
end)

RegisterNetEvent('vr-weather:client:DisableSync', function(weather, hour, minute)
    override.weather = WeatherData.normalise(weather) or 'CLEAR'
    override.hour = tonumber(hour) or 18
    override.minute = tonumber(minute) or 0
    setSynced(false)
end)

RegisterNetEvent('vr-weather:client:EnableSync', function()
    setSynced(true)
end)

RegisterNetEvent('qb-weathersync:client:DisableSync', function()
    override.weather, override.hour, override.minute = 'CLEAR', 18, 0
    setSynced(false)
end)

RegisterNetEvent('qb-weathersync:client:EnableSync', function()
    setSynced(true)
end)

local api = {}
function api.getWeather() return Wx and Wx.weather or applied end
function api.getTime() local h, m = WeatherTime.split(WeatherClient.minute()) return h, m end
function api.getSeason() return Wx and Wx.season end
function api.getTemperature() return Wx and Wx.temp end
function api.isBlackout() return Wx and Wx.blackout == true end
function api.isSynced() return synced end
function api.setSynced(value) setSynced(value) return synced end

for name, fn in pairs(api) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_qb-weathersync_%s'):format(name), function(cb) cb(fn) end)
end
