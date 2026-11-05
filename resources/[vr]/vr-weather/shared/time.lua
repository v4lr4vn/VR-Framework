WeatherTime = {}

local DAY = 1440

local function segments(nightStart, nightEnd)
    return nightEnd * 60, nightStart * 60
end

function WeatherTime.rates(dayLength, nightShare, nightStart, nightEnd)
    local realSeconds = math.max(1, dayLength) * 60
    local dayStart, dayEnd = segments(nightStart or 21, nightEnd or 6)
    local dayMinutes = dayEnd - dayStart
    local nightMinutes = DAY - dayMinutes
    nightShare = tonumber(nightShare)
    if not nightShare or nightShare <= 0 or nightShare >= 1 or dayMinutes <= 0 or nightMinutes <= 0 then
        local r = DAY / realSeconds
        return r, r, dayStart, dayEnd
    end
    local dayRate = dayMinutes / ((1 - nightShare) * realSeconds)
    local nightRate = nightMinutes / (nightShare * realSeconds)
    return dayRate, nightRate, dayStart, dayEnd
end

function WeatherTime.wrap(minute)
    minute = minute % DAY
    if minute < 0 then minute = minute + DAY end
    return minute
end

function WeatherTime.advance(minute, seconds, dayLength, nightShare, nightStart, nightEnd)
    local dayRate, nightRate, dayStart, dayEnd = WeatherTime.rates(dayLength, nightShare, nightStart, nightEnd)
    minute = WeatherTime.wrap(minute)
    local guard = 0
    while seconds > 1e-9 and guard < 16 do
        guard = guard + 1
        local isDay = minute >= dayStart and minute < dayEnd
        local rate = isDay and dayRate or nightRate
        local boundary
        if isDay then
            boundary = dayEnd
        elseif minute >= dayEnd then
            boundary = DAY + dayStart
        else
            boundary = dayStart
        end
        local need = (boundary - minute) / rate
        if seconds < need then
            minute = minute + seconds * rate
            seconds = 0
        else
            minute = boundary
            seconds = seconds - need
        end
        minute = WeatherTime.wrap(minute)
    end
    return minute
end

function WeatherTime.split(minute)
    minute = WeatherTime.wrap(minute)
    local h = math.floor(minute / 60)
    local m = math.floor(minute % 60)
    local s = math.floor((minute - math.floor(minute)) * 60)
    return h, m, s
end

function WeatherTime.realSecondsPerGameMinute(minute, dayLength, nightShare, nightStart, nightEnd)
    local dayRate, nightRate, dayStart, dayEnd = WeatherTime.rates(dayLength, nightShare, nightStart, nightEnd)
    minute = WeatherTime.wrap(minute)
    local rate = (minute >= dayStart and minute < dayEnd) and dayRate or nightRate
    return 1 / rate
end

local function lastSunday(year, month)
    local t = os.time({ year = year, month = month + 1, day = 1, hour = 12 }) - 86400
    local d = os.date('!*t', t)
    return d.day - (d.wday - 1)
end

function WeatherTime.ukSummerTime(utc)
    local d = os.date('!*t', utc)
    if d.month < 3 or d.month > 10 then return false end
    if d.month > 3 and d.month < 10 then return true end
    local sunday = lastSunday(d.year, d.month)
    if d.month == 3 then
        return d.day > sunday or (d.day == sunday and d.hour >= 1)
    end
    return d.day < sunday or (d.day == sunday and d.hour < 1)
end

function WeatherTime.realMinute(utc, offsetHours, ukSummerTime)
    utc = utc or os.time()
    local shift = (offsetHours or 0) * 3600
    if ukSummerTime and WeatherTime.ukSummerTime(utc) then shift = shift + 3600 end
    local d = os.date('!*t', utc + shift)
    return d.hour * 60 + d.min + d.sec / 60
end
