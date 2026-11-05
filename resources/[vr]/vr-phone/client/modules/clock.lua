-- In-game time, date and weather for the clock and the cover screen.
local Clock = {}
Phone.Clock = Clock

local weatherKinds = {}
for name, kind in pairs({
    CLEAR = 'clear', EXTRASUNNY = 'clear', NEUTRAL = 'clear',
    CLOUDS = 'cloud', OVERCAST = 'cloud', CLEARING = 'cloud',
    RAIN = 'rain', THUNDER = 'storm',
    SMOG = 'fog', FOGGY = 'fog',
    SNOW = 'snow', SNOWLIGHT = 'snow', BLIZZARD = 'snow', XMAS = 'snow',
}) do
    weatherKinds[joaat(name) & 0xFFFFFFFF] = kind
end

local function kindOf(hash) return weatherKinds[hash & 0xFFFFFFFF] or 'clear' end

function Clock.snapshot()
    return {
        h = GetClockHours(),
        m = GetClockMinutes(),
        s = GetClockSeconds(),
        dow = GetClockDayOfWeek(), -- 0 = Sunday
        day = GetClockDayOfMonth(),
        month = GetClockMonth() + 1,
        year = GetClockYear(),
        weather = kindOf(GetPrevWeatherTypeHashName()),
        -- For the Weather app: what the weather turns into next, how windy and how wet it is right now.
        nextWeather = kindOf(GetNextWeatherTypeHashName()),
        wind = math.floor(GetWindSpeed() * 10 + 0.5) / 10, -- metres per second
        rain = math.floor(GetRainLevel() * 100 + 0.5) / 100, -- 0 to 1
    }
end
