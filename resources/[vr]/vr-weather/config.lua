Config = {}

Config.AdminAce = 'command.weather'

Config.Time = {
    dayLengthMinutes = 150,
    nightShare = 0.3,
    nightStartHour = 21,
    nightEndHour = 6,
    startHour = 9,
    startMinute = 0,
    minDayLength = 20,
    maxDayLength = 1440,
    realTime = {
        enabled = false,
        utcOffsetHours = 0,
        ukSummerTime = true,
    },
}

Config.Weather = {
    dynamic = true,
    start = 'CLEAR',
    stageMinutes = { min = 25, max = 50 },
    transitionSeconds = 45,
    forecastStages = 6,
    units = 'C',
}

Config.Labels = {
    EXTRASUNNY = 'Sunny',
    CLEAR = 'Clear',
    NEUTRAL = 'Mild',
    SMOG = 'Smog',
    FOGGY = 'Fog',
    CLOUDS = 'Cloudy',
    OVERCAST = 'Overcast',
    CLEARING = 'Clearing',
    RAIN = 'Rain',
    THUNDER = 'Thunderstorm',
    SNOWLIGHT = 'Light snow',
    SNOW = 'Snow',
    BLIZZARD = 'Blizzard',
    XMAS = 'Deep snow',
    HALLOWEEN = 'Halloween',
}

Config.Transitions = {
    EXTRASUNNY = { 'EXTRASUNNY', 'CLEAR', 'SMOG' },
    CLEAR = { 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'SMOG', 'FOGGY', 'SNOWLIGHT' },
    NEUTRAL = { 'CLEAR', 'CLOUDS' },
    SMOG = { 'CLEAR', 'CLOUDS', 'EXTRASUNNY', 'FOGGY' },
    FOGGY = { 'CLEAR', 'CLOUDS', 'SMOG', 'OVERCAST' },
    CLOUDS = { 'CLOUDS', 'CLEAR', 'OVERCAST', 'FOGGY', 'CLEARING', 'SNOWLIGHT' },
    OVERCAST = { 'OVERCAST', 'CLOUDS', 'RAIN', 'CLEARING', 'THUNDER', 'SNOWLIGHT', 'SNOW', 'FOGGY' },
    RAIN = { 'RAIN', 'CLEARING', 'THUNDER', 'OVERCAST' },
    THUNDER = { 'RAIN', 'CLEARING' },
    CLEARING = { 'CLEAR', 'CLOUDS', 'OVERCAST', 'EXTRASUNNY' },
    SNOWLIGHT = { 'SNOWLIGHT', 'SNOW', 'CLOUDS', 'OVERCAST', 'XMAS', 'CLEAR' },
    SNOW = { 'SNOW', 'SNOWLIGHT', 'BLIZZARD', 'XMAS', 'OVERCAST' },
    BLIZZARD = { 'SNOW', 'SNOWLIGHT' },
    XMAS = { 'XMAS', 'SNOWLIGHT', 'SNOW', 'CLOUDS', 'CLEAR' },
    HALLOWEEN = { 'CLEAR', 'CLOUDS', 'FOGGY' },
}

Config.Seasons = {
    byMonth = { 'winter', 'winter', 'spring', 'spring', 'spring', 'summer', 'summer', 'summer', 'autumn', 'autumn', 'autumn', 'winter' },
    list = {
        winter = {
            label = 'Winter',
            groundSnow = true,
            temperature = { -3, 7 },
            weights = { CLEAR = 10, EXTRASUNNY = 2, CLOUDS = 18, OVERCAST = 18, FOGGY = 10, CLEARING = 4, RAIN = 6, SNOWLIGHT = 14, SNOW = 9, BLIZZARD = 3, XMAS = 6 },
        },
        spring = {
            label = 'Spring',
            groundSnow = false,
            temperature = { 6, 16 },
            weights = { CLEAR = 22, EXTRASUNNY = 10, CLOUDS = 20, OVERCAST = 12, FOGGY = 6, CLEARING = 10, RAIN = 14, THUNDER = 4, SMOG = 2 },
        },
        summer = {
            label = 'Summer',
            groundSnow = false,
            temperature = { 15, 29 },
            weights = { EXTRASUNNY = 30, CLEAR = 30, CLOUDS = 12, SMOG = 6, CLEARING = 5, OVERCAST = 5, RAIN = 6, THUNDER = 4, FOGGY = 2 },
        },
        autumn = {
            label = 'Autumn',
            groundSnow = false,
            temperature = { 5, 15 },
            weights = { CLEAR = 14, EXTRASUNNY = 4, CLOUDS = 22, OVERCAST = 18, FOGGY = 12, CLEARING = 8, RAIN = 16, THUNDER = 5, SMOG = 1 },
        },
    },
}

Config.WeatherTemperature = {
    EXTRASUNNY = 2, CLEAR = 1, NEUTRAL = 0, SMOG = 1, FOGGY = -1, CLOUDS = -1, OVERCAST = -2, CLEARING = -1,
    RAIN = -3, THUNDER = -4, SNOWLIGHT = -3, SNOW = -5, BLIZZARD = -8, XMAS = -6, HALLOWEEN = -2,
}

Config.SnowWeathers = { SNOWLIGHT = true, SNOW = true, BLIZZARD = true, XMAS = true }

Config.Holidays = {
    enabled = true,
    days = {
        ['10-31'] = 'HALLOWEEN',
        ['12-25'] = 'XMAS',
    },
}

Config.Admin = {
    presets = {
        { label = 'Morning', hour = 7, minute = 0 },
        { label = 'Noon', hour = 12, minute = 0 },
        { label = 'Evening', hour = 18, minute = 30 },
        { label = 'Night', hour = 23, minute = 0 },
    },
    dayLengthPresets = { 48, 90, 120, 150, 180, 1440 },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-weather'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
