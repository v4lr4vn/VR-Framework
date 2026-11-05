Permissions = {}

local function keysOf(dept)
    local out = {}
    for _, p in ipairs(Perms.list) do
        if p.dept == 'all' or p.dept == dept then out[#out + 1] = p end
    end
    return out
end

local function stored(job)
    local rows = Db.query('SELECT `grade`, `perm`, `allowed` FROM `vr_mdt_permissions` WHERE `job` = ?', { job })
    if not rows then return nil end
    local map = {}
    for _, r in ipairs(rows) do
        local g = tonumber(r.grade)
        map[g] = map[g] or {}
        map[g][r.perm] = r.allowed == true or tonumber(r.allowed) == 1
    end
    return map
end

local function jobInDept(job, dept)
    for _, name in ipairs(Core.jobsOfDept(dept)) do
        if name == job then return true end
    end
    return false
end

function Permissions.matrix(ctx, job)
    local grades = Roster.grades(job)
    local saved = stored(job)
    if not saved then return nil end
    local defaults, effective, gradesOut = {}, {}, {}
    for i, g in ipairs(grades) do
        defaults[i] = Perms.defaults(ctx.dept, g.level, g.isboss, job)
        effective[i] = Core.permsFor(ctx.dept, job, g.level, g.isboss)
        gradesOut[i] = { level = g.level, name = g.name, isboss = g.isboss, mine = ctx.job == job and ctx.grade == g.level, changes = 0 }
    end
    local groups, byName = {}, {}
    for _, p in ipairs(keysOf(ctx.dept)) do
        local cells = {}
        for i, g in ipairs(grades) do
            local default = defaults[i][p.key] == true
            local allowed = effective[i][p.key] == true
            local o = saved[g.level] and saved[g.level][p.key]
            local fits = Perms.allowedFor(ctx.dept, p.key, job)
            local overridden = fits and not g.isboss and o ~= nil and o ~= default
            if overridden then gradesOut[i].changes = gradesOut[i].changes + 1 end
            cells[i] = { allowed = allowed, default = default, overridden = overridden, locked = g.isboss or not fits }
        end
        local group = byName[p.group]
        if not group then
            group = { name = p.group, perms = {} }
            byName[p.group] = group
            groups[#groups + 1] = group
        end
        group.perms[#group.perms + 1] = { key = p.key, label = p.label, cells = cells }
    end
    local jobs = {}
    for _, name in ipairs(Core.jobsOfDept(ctx.dept)) do
        if Core.manages(ctx, name) then jobs[#jobs + 1] = { name = name, label = Bridge.jobs()[name].label or name } end
    end
    return { jobs = jobs, job = job, jobLabel = (Bridge.jobs()[job] or {}).label or job, grades = gradesOut, groups = groups }
end

local function announce(ctx, job, grade)
    Push.where(function(c) return c.job == job and c.grade == grade end, 'session:refresh', { reason = 'permissions' })
    Push.dept(ctx.dept, 'permissions:changed', { job = job, grade = grade }, function(c) return c.src ~= ctx.src and Core.can(c, 'permissions.manage') end)
end

local function pickJob(ctx, value)
    local job = V.str(value, 50)
    if job then return jobInDept(job, ctx.dept) and Core.manages(ctx, job) and job or nil end
    if jobInDept(ctx.job, ctx.dept) then return ctx.job end
    for _, name in ipairs(Core.jobsOfDept(ctx.dept)) do
        if Core.manages(ctx, name) then return name end
    end
    return nil
end

local function targetGrade(ctx, data)
    local job = V.str(data.job, 50)
    local grade = V.int(data.grade, 0, 1000)
    if not job or grade == nil or not jobInDept(job, ctx.dept) or not Core.manages(ctx, job) then return nil end
    local g = Roster.gradeOf(job, grade)
    if not g then return nil end
    return job, grade, g
end

Api.register('permissions.get', 'permissions.manage', function(src, ctx, data)
    local job = pickJob(ctx, data.job)
    if not job then return false, 'bad_request' end
    local m = Permissions.matrix(ctx, job)
    if not m then return false, 'server_error' end
    return true, m
end, { rate = 250 })

Api.register('permissions.set', 'permissions.manage', function(src, ctx, data)
    local job, grade, g = targetGrade(ctx, data)
    local perm = V.str(data.perm, 48)
    local allowed = V.bool(data.allowed)
    if not job or not perm or allowed == nil or not Perms.exists(ctx.dept, perm) then return false, 'bad_request' end
    if not Perms.allowedFor(ctx.dept, perm, job) then return false, 'locked' end
    if g.isboss then return false, 'locked' end
    if perm == 'permissions.manage' and not allowed and job == ctx.job and grade == ctx.grade then return false, 'cant_self' end
    local ok = Db.update('INSERT INTO `vr_mdt_permissions` (`job`, `grade`, `perm`, `allowed`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `allowed` = VALUES(`allowed`)', {
        job, grade, perm, allowed and 1 or 0,
    })
    if ok == nil then return false, 'save_failed' end
    Core.setPermission(job, grade, perm, allowed)
    Audit.log(ctx, 'permissions.set', ('%s:%d'):format(job, grade), { perm = perm, allowed = allowed, rank = g.name })
    announce(ctx, job, grade)
    return true, Permissions.matrix(ctx, job)
end, { rate = 120 })

Api.register('permissions.reset', 'permissions.manage', function(src, ctx, data)
    local job, grade, g = targetGrade(ctx, data)
    if not job then return false, 'bad_request' end
    if g.isboss then return false, 'locked' end
    if job == ctx.job and grade == ctx.grade and not Perms.defaults(ctx.dept, grade, false, job)['permissions.manage'] then return false, 'cant_self' end
    local ok = Db.update('DELETE FROM `vr_mdt_permissions` WHERE `job` = ? AND `grade` = ?', { job, grade })
    if ok == nil then return false, 'save_failed' end
    for _, p in ipairs(keysOf(ctx.dept)) do Core.setPermission(job, grade, p.key, nil) end
    Audit.log(ctx, 'permissions.reset', ('%s:%d'):format(job, grade), { rank = g.name, removed = ok })
    announce(ctx, job, grade)
    return true, Permissions.matrix(ctx, job)
end, { rate = 500 })
