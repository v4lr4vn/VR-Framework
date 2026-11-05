Store = {}

local cache = {}

local function normalize(data)
    local jobs = {}
    if type(data) == 'table' then
        for job, grade in pairs(data) do
            local g = Core.toGrade(grade)
            if type(job) == 'string' and g then jobs[job] = g end
        end
    end
    return jobs
end

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function Store.read(cid)
    if cache[cid] then
        if Bridge.playerByCid(cid) then return copy(cache[cid]) end
        cache[cid] = nil
    end
    Db.await()
    local row = MySQL.single.await('SELECT jobdata FROM vr_multijobs WHERE citizenid = ? LIMIT 1', { cid })
    if not row then return nil end
    local ok, data = pcall(json.decode, row.jobdata or '[]')
    local jobs = normalize(ok and data or nil)
    if Bridge.playerByCid(cid) then cache[cid] = copy(jobs) end
    return jobs
end

function Store.save(cid, jobs)
    Db.await()
    jobs = normalize(jobs)
    MySQL.query.await('INSERT INTO vr_multijobs (citizenid, jobdata) VALUES (?, ?) ON DUPLICATE KEY UPDATE jobdata = VALUES(jobdata)', { cid, json.encode(jobs) })
    if cache[cid] or Bridge.playerByCid(cid) then cache[cid] = copy(jobs) end
end

function Store.wipe(cid)
    Db.await()
    cache[cid] = nil
    MySQL.query.await('DELETE FROM vr_multijobs WHERE citizenid = ?', { cid })
end

function Store.get(cid)
    if type(cid) ~= 'string' or cid == '' then return {} end
    local jobs = Store.read(cid)
    if jobs then return jobs end
    jobs = {}
    local person = Core.person(cid)
    local job = person and person.job
    if job and not Config.IgnoredJobs[job.name] and Core.def(job.name, job.grade) then
        jobs[job.name] = Core.toGrade(job.grade)
        Store.save(cid, jobs)
    end
    return jobs
end
