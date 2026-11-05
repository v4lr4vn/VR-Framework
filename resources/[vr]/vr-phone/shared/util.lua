Phone = Phone or {}

Phone.FoldStates = { cover = true, flex = true, open = true }

-- A yes/no database column: the database layer gives 1/0 or true/false depending on the column, so accept both.
function Phone.flag(v) return v == 1 or v == true end

function Phone.debug(...)
    if Config.Phone.Debug then print('^5[vr-phone]^7', ...) end
end

-- Returns n limited to lo..hi, or nil when n is not a real number.
function Phone.clamp(n, lo, hi)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.max(lo, math.min(hi, n))
end

-- How loud a nearby phone's speaker is for someone `distance` metres away. Full volume right next to it, quieter with
-- distance, and silent at `range`. volume is 0 to 100.
function Phone.speakerVolume(volume, distance, range)
    volume, distance, range = tonumber(volume), tonumber(distance), tonumber(range)
    if not volume or not distance or not range or volume ~= volume or distance ~= distance or range ~= range then return 0 end
    if range <= 0 or distance < 0 or distance >= range then return 0 end
    local left = 1 - distance / range
    return math.max(0, math.min(100, volume)) * left ^ 1.25
end

function Phone.isHex(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

-- Trims a string and cuts it to max characters. Returns nil for empty or non-string input.
function Phone.cut(value, max)
    if type(value) ~= 'string' then return nil end
    local s = value:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    if s == '' then return nil end
    if #s > max then s = s:sub(1, max) end
    return s
end

function Phone.deepMerge(base, patch)
    for k, v in pairs(patch) do
        if type(v) == 'table' and type(base[k]) == 'table' then
            Phone.deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

function Phone.deepCopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Phone.deepCopy(v) end
    return out
end

-- Text for names and messages: control characters out (new lines can stay), trimmed, cut to max.
function Phone.text(value, max, keepLines)
    if type(value) ~= 'string' then return nil end
    -- Everything below space and DEL is dropped. With keepLines, the new line (10) stays.
    local s = value:gsub(keepLines and '[\0-\9\11-\31\127]' or '[\0-\31\127]', '')
    return Phone.cut(s, max)
end

-- A phone number as it is stored. Spaces go, and a plain run of digits gets the dashes of Config.Phone.Number.format.
-- Returns nil when it does not look like a number. (3 to 20 characters: digits, '-', and a leading '+'.)
function Phone.number(raw)
    if type(raw) ~= 'string' then return nil end
    local s = raw:gsub('%s', '')
    if #s < 3 or #s > 20 or not s:match('^%+?[%d%-]+$') then return nil end

    local fmt = Config.Phone.Number and Config.Phone.Number.format
    if fmt and s:match('^%d+$') then
        local want = select(2, fmt:gsub('[%d#]', ''))
        if #s == want then
            local i = 0
            return (fmt:gsub('[%d#]', function() i = i + 1 return s:sub(i, i) end))
        end
    end
    return s
end

-- Both numbers in a fixed order, so a conversation has one key whichever side wrote.
function Phone.pair(a, b)
    if a > b then a, b = b, a end
    return a .. '|' .. b
end

-- ---------------------------------------------------------------- game dates
-- Reminders and the calendar use the game's date. A date is the text 'YYYY-MM-DD'. A stamp counts minutes since 2000-01-01 00:00,
-- so two moments compare with a plain < and >. (web/src/lib/gamedate.js does the same sums on the screen.)

local function leap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- Returns year, month, day, or nil when the text is not a real date between the years 2000 and 2100.
function Phone.parseDate(value)
    if type(value) ~= 'string' then return nil end
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or y < 2000 or y > 2100 or m < 1 or m > 12 or d < 1 then return nil end
    local max = monthDays[m] + ((m == 2 and leap(y)) and 1 or 0)
    if d > max then return nil end
    return y, m, d
end

-- Days since 2000-01-01.
function Phone.dayNumber(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = y // 400
    local yoe = y - era * 400
    local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468 - 10957
end

-- Minutes since 2000-01-01 for a date and a minute of the day. Returns nil for a date that is not real.
function Phone.stamp(date, minute)
    local y, m, d = Phone.parseDate(date)
    if not y then return nil end
    return Phone.dayNumber(y, m, d) * 1440 + (tonumber(minute) or 0)
end
