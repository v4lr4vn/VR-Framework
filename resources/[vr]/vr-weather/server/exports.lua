local S = Weather.state

local api = {}

function api.getWeather() return S.weather end
function api.getWeatherState() return S.weather end
function api.setWeather(name) return Weather.setWeather(name) end
function api.setTime(hour, minute) return Weather.setTime(hour, minute) end
function api.getTime() return Weather.clock() end
function api.setBlackout(value) return Weather.setBlackout(value) end
function api.getBlackoutState() return S.blackout end
function api.setTimeFreeze(value) return Weather.setFreezeTime(value) end
function api.getTimeFreezeState() return S.freezeTime end
function api.setWeatherFreeze(value) return Weather.setFreezeWeather(value) end
function api.getWeatherFreezeState() return S.freezeWeather end
function api.setDynamicWeather(value) return Weather.setDynamic(value) end
function api.getDynamicWeather() return S.dynamic end
function api.nextWeatherStage() return Weather.nextStage() end
function api.getSeason() return S.season, WeatherData.season(S.season).label end
function api.getForecast() return Weather.forecast() end
function api.getTemperature() return Weather.temperature() end
function api.setDayLength(minutes) return Weather.setDayLength(minutes) end
function api.getDayLength() return S.dayLength end

for name, fn in pairs(api) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_qb-weathersync_%s'):format(name), function(cb) cb(fn) end)
    AddEventHandler(('__cfx_export_vr-weathersync_%s'):format(name), function(cb) cb(fn) end)
end

local function trusted(src)
    src = tonumber(src)
    if not src or src <= 0 then return true end
    return IsPlayerAceAllowed(src, Config.AdminAce) or Bridge.isAdmin(src)
end

RegisterNetEvent('qb-weathersync:server:setWeather', function(name)
    if trusted(source) then Weather.setWeather(name) end
end)

RegisterNetEvent('qb-weathersync:server:setTime', function(hour, minute)
    if trusted(source) then Weather.setTime(hour, minute) end
end)

RegisterNetEvent('qb-weathersync:server:toggleBlackout', function(state)
    if not trusted(source) then return end
    if type(state) == 'boolean' then Weather.setBlackout(state) else Weather.setBlackout(not S.blackout) end
end)

RegisterNetEvent('qb-weathersync:server:toggleFreezeTime', function(state)
    if not trusted(source) then return end
    if type(state) == 'boolean' then Weather.setFreezeTime(state) else Weather.setFreezeTime(not S.freezeTime) end
end)

RegisterNetEvent('qb-weathersync:server:toggleDynamicWeather', function(state)
    if not trusted(source) then return end
    if type(state) == 'boolean' then Weather.setDynamic(state) else Weather.setDynamic(not S.dynamic) end
end)
