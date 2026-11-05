local NAMES = {
    jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
    sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6,
}
local RANGES = { { 0, 59 }, { 0, 23 }, { 1, 31 }, { 1, 12 }, { 0, 6 } }

local function num(s)
    return tonumber(s) or NAMES[tostring(s):lower()]
end

local function field(spec, lo, hi)
    local set = {}
    for part in tostring(spec):gmatch('[^,]+') do
        local range, step = part:match('^([^/]+)/?(%d*)$')
        step = tonumber(step) or 1
        local a, b
        if range == '*' then
            a, b = lo, hi
        elseif range:find('-') then
            local x, y = range:match('^(%w+)-(%w+)$')
            a, b = num(x), num(y)
        else
            a = num(range)
            b = (tonumber(step) and part:find('/')) and hi or a
        end
        if not a or not b then error(('invalid cron field %s'):format(part), 3) end
        for v = a, b, step do
            if v >= lo and v <= hi then set[v] = true end
        end
    end
    return set
end

local function parse(expression)
    local parts = {}
    for p in expression:gmatch('%S+') do parts[#parts + 1] = p end
    if #parts ~= 5 then error(('cron expression must have 5 fields (%s)'):format(expression), 3) end
    local out = {}
    for i = 1, 5 do out[i] = field(parts[i], RANGES[i][1], RANGES[i][2]) end
    if out[5][7] then out[5][0] = true end
    return out
end

local function matches(spec, t)
    return spec[1][t.min] and spec[2][t.hour] and spec[3][t.day] and spec[4][t.month] and spec[5][(t.wday - 1)]
end

local Task = {}
Task.__index = Task

function Task:stop()
    self.isActive = false
end

function Task:run()
    local ok, err = pcall(self.job, self, os.date('*t'))
    if not ok then print(('^1[vr-lib] cron job %s failed: %s^0'):format(self.expression, err)) end
end

local function new(expression, job, options)
    local self = setmetatable({ expression = expression, job = job, spec = parse(expression), isActive = true, options = options or {} }, Task)
    CreateThread(function()
        local last
        while self.isActive do
            local t = os.date('*t')
            local stamp = os.time(t) // 60
            if stamp ~= last and matches(self.spec, t) then
                last = stamp
                self:run()
            end
            Wait(((60 - t.sec) * 1000) + 50)
        end
    end)
    return self
end

return { new = new }
