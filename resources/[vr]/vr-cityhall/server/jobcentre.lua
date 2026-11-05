Jobs = {}

local lastTake = {}

local function multi()
    return GetResourceState('vr-multijob') == 'started'
end

local function held(cid)
    if not multi() then return nil end
    local ok, jobs = pcall(function() return exports['vr-multijob']:GetJobs(cid) end)
    if ok and type(jobs) == 'table' then return jobs end
    return nil
end

local function find(job)
    for _, j in ipairs(Config.JobCentre.jobs) do
        if j.job == job then return j end
    end
    return nil
end

local function gradeInfo(job, grade)
    local def = Bridge.jobs()[job]
    if not def then return nil end
    return def, def.grades[tonumber(grade) or 0]
end

local function listedHeld(info)
    local jobs = held(info.cid) or {}
    if info.job and info.job ~= Config.JobCentre.fallbackJob and jobs[info.job] == nil then jobs[info.job] = info.grade end
    return jobs
end

function Jobs.list(info)
    local cfg = Config.JobCentre
    local out = { enabled = cfg.enabled, jobs = {}, maxJobs = cfg.maxJobs, canQuit = cfg.allowQuit }
    if not cfg.enabled then return out end
    local mine = listedHeld(info)
    local count = 0
    for _ in pairs(mine) do count = count + 1 end
    out.count = count
    for _, j in ipairs(cfg.jobs) do
        local def, g = gradeInfo(j.job, j.grade)
        if def and g then
            out.jobs[#out.jobs + 1] = {
                job = j.job,
                label = def.label or j.job,
                grade = tonumber(j.grade) or 0,
                gradeLabel = g.name,
                salary = g.payment,
                description = j.description,
                icon = j.icon or 'fa-briefcase',
                current = info.job == j.job,
                held = mine[j.job] ~= nil,
            }
        end
    end
    return out
end

function Jobs.take(info, job)
    local cfg = Config.JobCentre
    if not cfg.enabled then return false, 'disabled' end
    local j = type(job) == 'string' and find(job) or nil
    if not j then return false, 'bad_request' end
    local def, g = gradeInfo(j.job, j.grade)
    if not def or not g then return false, 'no_such_job' end
    if info.job == j.job then return false, 'already' end
    local wait = (lastTake[info.cid] or 0) + cfg.cooldownSeconds - os.time()
    if wait > 0 then return false, 'cooldown', { wait = wait } end
    local mine = listedHeld(info)
    local count = 0
    for _ in pairs(mine) do count = count + 1 end
    if mine[j.job] == nil and count >= cfg.maxJobs then return false, 'job_limit' end
    local grade = tonumber(j.grade) or 0
    if mine[j.job] ~= nil and multi() then grade = tonumber(mine[j.job]) or grade end
    if multi() then pcall(function() exports['vr-multijob']:AddJob(info.cid, j.job, grade) end) end
    if not Bridge.setJob(info.src, j.job, grade) then return false, 'failed' end
    lastTake[info.cid] = os.time()
    return true, nil, { job = j.job, label = def.label or j.job, grade = grade }
end

function Jobs.quit(info, job)
    local cfg = Config.JobCentre
    if not cfg.enabled or not cfg.allowQuit then return false, 'disabled' end
    local j = type(job) == 'string' and find(job) or nil
    if not j then return false, 'bad_request' end
    local mine = listedHeld(info)
    if mine[j.job] == nil then return false, 'not_held' end
    local def = Bridge.jobs()[j.job]
    local label = def and def.label or j.job
    if multi() then
        local ok, done = pcall(function() return exports['vr-multijob']:RemoveJob(info.cid, j.job) end)
        if ok and done == true then return true, nil, { job = j.job, label = label } end
    end
    if info.job ~= j.job then return false, 'not_held' end
    if not Bridge.setJob(info.src, cfg.fallbackJob, 0) then return false, 'failed' end
    return true, nil, { job = j.job, label = label }
end
