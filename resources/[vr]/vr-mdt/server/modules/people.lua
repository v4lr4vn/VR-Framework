People = {}

local SEARCH_PERMS = { 'records.view', 'patients.view', 'roster.manage', 'court.view', 'ia.view', 'fto.view', 'reports.create', 'medreports.create' }

local function toPerson(c)
    if not c then return nil end
    local job = c.job or {}
    return {
        cid = c.cid,
        name = c.name,
        dob = c.dob,
        phone = c.phone,
        gender = c.gender,
        nationality = c.nationality,
        job = job.name,
        jobLabel = job.label,
        jobType = job.type,
        grade = job.grade,
        gradeName = job.gradeName,
        metadata = c.metadata or {},
        online = c.online == true,
        src = c.source,
        onduty = c.online == true and job.onduty == true or nil,
    }
end
People.fromChar = toPerson

function People.search(q, limit)
    q = V.str(q, 48, 2)
    if not q then return {} end
    limit = V.int(limit, 1, 50) or 20
    local out = {}
    for _, c in ipairs(Bridge.chars.search(q, limit) or {}) do
        local person = toPerson(c)
        person.metadata = nil
        out[#out + 1] = person
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function People.get(cid)
    cid = V.cid(cid)
    if not cid then return nil end
    return toPerson(Bridge.chars.get(cid))
end

function People.many(cids)
    local out = {}
    for cid, c in pairs(Bridge.chars.many(cids) or {}) do out[cid] = toPerson(c) end
    return out
end

function People.exists(cid)
    return Bridge.chars.exists(cid) == true
end

function People.public(person)
    if not person then return nil end
    return {
        cid = person.cid, name = person.name, dob = person.dob, phone = person.phone, gender = person.gender,
        nationality = person.nationality, job = person.job, jobLabel = person.jobLabel, gradeName = person.gradeName, online = person.online,
    }
end

function People.staff(dept, q)
    local jobs = Core.jobsOfDept(dept)
    if #jobs == 0 then return {} end
    q = V.str(q, 48)
    local out = {}
    local needle = q and q:lower() or nil
    for _, c in ipairs(Bridge.chars.byJobs(jobs, nil, 500) or {}) do
        local person = toPerson(c)
        person.callsign = Core.callsign(person.metadata)
        person.metadata = nil
        local hay = ('%s %s'):format(person.name, person.callsign or ''):lower()
        if Core.deptOf({ type = person.jobType }) == dept and (not needle or hay:find(needle, 1, true)) then
            out[#out + 1] = person
        end
    end
    table.sort(out, function(a, b) return (a.grade or 0) > (b.grade or 0) or ((a.grade or 0) == (b.grade or 0) and a.name < b.name) end)
    if #out > 200 then
        for i = #out, 201, -1 do out[i] = nil end
    end
    return out
end

Api.register('people.search', SEARCH_PERMS, function(src, ctx, data)
    return true, People.search(data.q, data.limit)
end, { rate = 250 })

Api.register('people.staff', nil, function(src, ctx, data)
    local dept = V.enum(data.dept, Config.Departments) or ctx.dept
    if dept ~= ctx.dept and not Core.can(ctx, { 'ia.view', 'court.view' }) then return false, 'not_allowed' end
    return true, People.staff(dept, data.q)
end, { rate = 300 })
