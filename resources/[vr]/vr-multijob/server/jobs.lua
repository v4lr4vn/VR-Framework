Jobs = {}

local warned = {}

local function current(cid)
    local p = Core.person(cid)
    if not p or not p.job then return nil end
    return p.job.name, tonumber(p.job.grade) or 0, p
end

function Jobs.add(cid, job, grade)
    if type(cid) ~= 'string' or cid == '' then return false end
    local def, _, g = Core.def(job, grade)
    if not def or Config.IgnoredJobs[job] then return false end
    local jobs = Store.get(cid)
    for ignored in pairs(Config.IgnoredJobs) do jobs[ignored] = nil end
    jobs[job] = g
    Store.save(cid, jobs)
    return true
end

function Jobs.setRank(cid, job, grade)
    if type(cid) ~= 'string' then return false end
    local def, _, g = Core.def(job, grade)
    if not def then return false end
    if not Core.person(cid) then return false end
    local jobs = Store.get(cid)
    if jobs[job] == nil then return false end
    jobs[job] = g
    Store.save(cid, jobs)
    local active = current(cid)
    if active == job then Core.setJob(cid, job, g) end
    return true
end

local function successor(jobs)
    local names = {}
    for name in pairs(jobs) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        if Core.def(name, jobs[name]) then return name, jobs[name] end
    end
    return nil
end

function Jobs.remove(cid, job)
    if type(cid) ~= 'string' or type(job) ~= 'string' then return false end
    local active, _, person = current(cid)
    if not person then return false end
    local jobs = Store.get(cid)
    local wasActive = active == job
    if jobs[job] == nil and not wasActive then return false end
    jobs[job] = nil
    Store.save(cid, jobs)
    if wasActive then
        local nextJob, nextGrade = successor(jobs)
        Core.setJob(cid, nextJob or Config.FallbackJob, nextJob and nextGrade or 0)
    end
    return true
end

function Jobs.onDutyCounts()
    local out = {}
    for _, p in ipairs(Bridge.players()) do
        local j = p.job
        if j and j.name and j.onduty then out[j.name] = (out[j.name] or 0) + 1 end
    end
    return out
end


-- A job is whitelisted when it is in Config.WhitelistJobs, when the script that made it says so
-- (restaurants do), or when it has a job type such as leo, ems or doj (Config.WhitelistByType).
function Jobs.isWhitelisted(name, def)
    if Config.WhitelistJobs[name] == true then return true end
    if type(def) ~= 'table' then return false end
    if def.whitelisted == true then return true end
    if Config.WhitelistByType and type(def.type) == 'string' and def.type ~= '' and def.type ~= 'none' and not Config.OpenJobTypes[def.type] then return true end
    return false
end

function Jobs.snapshot(info)
    local jobs = Store.get(info.cid)
    local counts = Jobs.onDutyCounts()
    local list = {}
    for name, grade in pairs(jobs) do
        local def, g = Core.def(name, grade)
        if not def then
            local key = info.cid .. ':' .. name
            if not warned[key] then
                warned[key] = true
                print(("^3[vr-multijob] The job '%s' (grade %s) of %s is not in your framework's jobs. Remove it from vr_multijobs or add the job back.^0"):format(name, tostring(grade), info.cid))
            end
        else
            list[#list + 1] = {
                name = name,
                label = def.label or name,
                grade = grade,
                gradeLabel = g.name,
                -- A job made by another script (a restaurant, say) can show its own pay and flags.
                salary = g.display or g.payment or 0,
                description = Config.Descriptions[name] or def.description,
                icon = Config.FontAwesomeIcons[name] or def.icon,
                whitelist = Jobs.isWhitelisted(name, def),
                active = counts[name] or 0,
                current = info.job == name,
                onduty = info.job == name and info.onduty or false,
                canDuty = Config.DenyDuty[name] ~= true,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.whitelist ~= b.whitelist then return a.whitelist end
        return a.label < b.label
    end)
    local cur = Bridge.jobs()[info.job]
    return {
        jobs = list,
        current = { name = info.job, label = cur and cur.label or info.job, onduty = info.onduty, listed = jobs[info.job] ~= nil },
        max = Config.MaxJobs,
        canLeave = Config.AllowSelfRemove == true,
        fallback = Config.FallbackJob,
        hint = Config.Hint,
    }
end

function Jobs.select(info, job)
    if type(job) ~= 'string' then return false, 'bad_request' end
    if job == Config.FallbackJob then
        if info.job == job then return false, 'already' end
        if not Core.def(job, 0) then return false, 'no_job' end
        if not Bridge.setJob(info.src, job, 0) then return false, 'failed' end
        return true, nil, { job = job, label = Bridge.jobs()[job].label or job }
    end
    local jobs = Store.get(info.cid)
    local grade = jobs[job]
    if grade == nil then return false, 'not_held' end
    local def = Core.def(job, grade)
    if not def then return false, 'no_job' end
    if info.job == job and info.grade == grade then return false, 'already' end
    if not Bridge.setJob(info.src, job, grade) then return false, 'failed' end
    return true, nil, { job = job, label = def.label or job }
end

function Jobs.leave(info, job)
    if type(job) ~= 'string' then return false, 'bad_request' end
    if not Config.AllowSelfRemove then return false, 'no_leave' end
    local jobs = Store.get(info.cid)
    if jobs[job] == nil then return false, 'not_held' end
    local def = Bridge.jobs()[job]
    if not Jobs.remove(info.cid, job) then return false, 'failed' end
    return true, nil, { job = job, label = def and def.label or job }
end

function Jobs.duty(info)
    if Config.DenyDuty[info.job] then return false, 'deny_duty' end
    if info.job == Config.FallbackJob then return false, 'no_duty' end
    local want = not info.onduty
    if not Bridge.setDuty(info.src, want) then return false, 'failed' end
    return true, nil, { onduty = want }
end

Bridge.on('jobChanged', function(src, job)
    src = tonumber(src)
    if not src or type(job) ~= 'table' or not job.name then return end
    if Config.IgnoredJobs[job.name] then return end
    local info = Core.info(src)
    if not info then return end
    local def, _, g = Core.def(job.name, job.grade)
    if not def then return end
    local jobs = Store.get(info.cid)
    local held = jobs[job.name]
    if held == g then return end
    if held == nil then
        local limit = Config.MaxJobs
        if Bridge.isAdmin(src) then limit = math.huge end
        if Core.count(jobs) >= limit then
            Core.notify(src, 'Your job menu is full, so this job was not added. Leave a job to make room.', 'error')
            return
        end
    end
    Jobs.add(info.cid, job.name, g)
end)
