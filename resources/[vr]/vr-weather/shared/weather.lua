WeatherData = {}

WeatherData.types = {
    'EXTRASUNNY', 'CLEAR', 'NEUTRAL', 'SMOG', 'FOGGY', 'CLOUDS', 'OVERCAST', 'CLEARING',
    'RAIN', 'THUNDER', 'SNOWLIGHT', 'SNOW', 'BLIZZARD', 'XMAS', 'HALLOWEEN',
}

WeatherData.valid = {}
for i = 1, #WeatherData.types do WeatherData.valid[WeatherData.types[i]] = true end

function WeatherData.normalise(name)
    if type(name) ~= 'string' then return nil end
    name = name:upper():gsub('%s', '')
    if WeatherData.valid[name] then return name end
    return nil
end

function WeatherData.label(name)
    return Config.Labels[name] or name
end

function WeatherData.seasonFor(month)
    month = tonumber(month) or 1
    return Config.Seasons.byMonth[month] or 'summer'
end

function WeatherData.season(key)
    return Config.Seasons.list[key] or Config.Seasons.list.summer
end

local function weighted(weights, allow, random)
    local total, pool = 0, {}
    for i = 1, #WeatherData.types do
        local name = WeatherData.types[i]
        local w = weights[name]
        if w and w > 0 and (not allow or allow[name]) then
            total = total + w
            pool[#pool + 1] = { name, w }
        end
    end
    if total <= 0 then return nil end
    local roll = random() * total
    for i = 1, #pool do
        roll = roll - pool[i][2]
        if roll <= 0 then return pool[i][1] end
    end
    return pool[#pool][1]
end

function WeatherData.next(current, seasonKey, random)
    random = random or math.random
    local season = WeatherData.season(seasonKey)
    local options = Config.Transitions[current]
    if options then
        local allow = {}
        for i = 1, #options do allow[options[i]] = true end
        local pick = weighted(season.weights, allow, random)
        if pick then return pick end
    end
    return weighted(season.weights, nil, random) or 'CLEAR'
end

function WeatherData.temperature(seasonKey, weather, minute)
    local season = WeatherData.season(seasonKey)
    local lo, hi = season.temperature[1], season.temperature[2]
    local hour = (tonumber(minute) or 720) / 60
    local curve = (math.cos((hour - 15) / 24 * 2 * math.pi) + 1) / 2
    local t = lo + (hi - lo) * curve + (Config.WeatherTemperature[weather] or 0)
    return math.floor(t + 0.5)
end

function WeatherData.toF(c)
    return math.floor(c * 9 / 5 + 32 + 0.5)
end
