Core = {}

local last = {}

function Core.info(src)
    src = tonumber(src)
    if not src then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    local job = p.job or {}
    return {
        src = src,
        cid = p.cid,
        name = p.name or 'Citizen',
        job = job.name or Config.FallbackJob,
        grade = tonumber(job.grade) or 0,
        onduty = job.onduty == true,
    }
end

function Core.notify(src, text, kind)
    if not src or src <= 0 then return print(('[vr-multijob] %s'):format(tostring(text))) end
    Bridge.notify(src, text, kind or 'inform', nil, 'Job menu')
end

function Core.throttle(src, key, seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < seconds * 1000 then return true end
    last[id] = now
    return false
end

function Core.toGrade(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge or n < 0 or n % 1 ~= 0 then return nil end
    return math.floor(n)
end

function Core.def(job, grade)
    if type(job) ~= 'string' then return nil end
    local def = Bridge.jobs()[job]
    if type(def) ~= 'table' or type(def.grades) ~= 'table' then return nil end
    if def.kind == 'gang' or def.type == 'gang' then return nil end
    local g = Core.toGrade(grade)
    if not g then return nil end
    local info = def.grades[g]
    if not info then return nil end
    return def, info, g
end

function Core.person(cid)
    if type(cid) ~= 'string' or cid == '' then return nil end
    local live = Bridge.playerByCid(cid)
    if live then return live end
    if not Bridge.chars or not Bridge.chars.get then return nil end
    local ok, p = pcall(Bridge.chars.get, cid)
    if ok and type(p) == 'table' then return p end
    return nil
end

function Core.setJob(cid, job, grade)
    local src = Bridge.source(cid)
    if src then return Bridge.setJob(src, job, grade) end
    if not Bridge.chars or not Bridge.chars.setJob then return false end
    local ok, done = pcall(Bridge.chars.setJob, cid, job, grade, nil)
    return ok and done ~= false
end

function Core.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

AddEventHandler('playerDropped', function()
    local prefix = ('%s:'):format(source)
    for id in pairs(last) do
        if id:sub(1, #prefix) == prefix then last[id] = nil end
    end
end)
