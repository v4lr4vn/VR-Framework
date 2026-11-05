Roster = {}

local STATUSES = { 'active', 'loa', 'suspended' }
local HOUR = 3600

Db.schema('roster', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_roster` (
        `cid` VARCHAR(64) NOT NULL,
        `dept` VARCHAR(16) NOT NULL,
        `badge` VARCHAR(16) DEFAULT NULL,
        `divisions` LONGTEXT DEFAULT NULL,
        `notes` TEXT DEFAULT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'active',
        `hired_at` INT UNSIGNED DEFAULT NULL,
        `fired_at` INT UNSIGNED DEFAULT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        `updated_by` VARCHAR(64) DEFAULT NULL,
        PRIMARY KEY (`cid`),
        KEY `dept_status` (`dept`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function gradeOf(job, level)
    if level == nil then return nil end
    return Bridge.grade(job, level)
end
Roster.gradeOf = gradeOf

function Roster.grades(job)
    return Bridge.grades(job)
end

local function jobInDept(job, dept)
    for _, name in ipairs(Core.jobsOfDept(dept)) do
        if name == job then return true end
    end
    return false
end

local function callsignOf(md)
    local cs = type(md) == 'table' and md.callsign or nil
    if type(cs) ~= 'string' or cs == '' or cs == 'NO CALLSIGN' then return nil end
    return cs
end

local function decodeList(s)
    local v = U.decode(s, {})
    local out = {}
    if type(v) ~= 'table' then return out end
    for _, x in ipairs(v) do
        if type(x) == 'string' then out[#out + 1] = x end
    end
    return out
end

local function encodeList(list)
    if #list == 0 then return '[]' end
    return json.encode(list)
end

local function rowFor(cid)
    return Db.single('SELECT * FROM `vr_mdt_roster` WHERE `cid` = ? LIMIT 1', { cid })
end

local function rowsFor(cids)
    local map = {}
    if #cids == 0 then return map end
    local marks = {}
    for i = 1, #cids do marks[i] = '?' end
    local rows = Db.query(('SELECT * FROM `vr_mdt_roster` WHERE `cid` IN (%s)'):format(table.concat(marks, ',')), cids) or {}
    for _, r in ipairs(rows) do map[r.cid] = r end
    return map
end

local function currentRow(row, dept)
    if row and row.dept == dept and row.status ~= 'former' then return row end
    return nil
end

local function personFromPlayer(p)
    local job = p.job or {}
    return {
        cid = p.cid,
        name = p.name,
        job = job.name,
        jobLabel = job.label,
        jobType = job.type,
        grade = tonumber(job.grade) or 0,
        gradeName = job.gradeName,
        callsign = callsignOf(p.metadata),
        online = true,
        onduty = job.onduty == true,
    }
end

local function lookup(cid)
    local p = Core.playerByCid(cid)
    if p then return personFromPlayer(p) end
    local person = People.get(cid)
    if not person then return nil end
    person.callsign = callsignOf(person.metadata)
    person.metadata = nil
    person.online = false
    person.onduty = false
    return person
end

local function build(person, row, dept)
    local cur = currentRow(row, dept)
    local g = gradeOf(person.job, person.grade)
    return {
        cid = person.cid,
        name = person.name,
        callsign = person.callsign,
        badge = cur and cur.badge or nil,
        job = person.job,
        jobLabel = person.jobLabel,
        grade = tonumber(person.grade) or 0,
        gradeName = person.gradeName or (g and g.name) or nil,
        isboss = g ~= nil and g.isboss == true,
        status = cur and cur.status or 'active',
        divisions = cur and decodeList(cur.divisions) or {},
        online = person.online == true,
        onduty = person.onduty == true,
        hiredAt = cur and tonumber(cur.hired_at) or nil,
    }
end

function Roster.member(cid, dept)
    cid = V.cid(cid)
    if not cid then return nil end
    local person = lookup(cid)
    if not person then return nil end
    local actual = Core.deptOf({ type = person.jobType })
    if not actual or (dept and actual ~= dept) then return nil end
    return build(person, rowFor(cid), actual)
end

function Roster.divisions(cid)
    local m = Roster.member(cid)
    return m and m.divisions or {}
end

function Roster.isMember(cid, dept)
    return Roster.member(cid, dept) ~= nil
end

local function matches(person, q)
    if not q then return true end
    local hay = ('%s %s %s'):format(person.name or '', person.callsign or '', person.cid or ''):lower()
    return hay:find(q:lower(), 1, true) ~= nil
end

local function collect(dept, q)
    local list, seen = {}, {}
    for _, person in ipairs(People.staff(dept, q)) do
        if not seen[person.cid] then
            seen[person.cid] = true
            list[#list + 1] = person
        end
    end
    for _, src in ipairs(GetPlayers()) do
        local p = Core.player(tonumber(src))
        if p and not seen[p.cid] and Core.deptOf(p.job) == dept then
            local person = personFromPlayer(p)
            if matches(person, q) then
                seen[person.cid] = true
                list[#list + 1] = person
            end
        end
    end
    if q then
        local rows = Db.query("SELECT `cid` FROM `vr_mdt_roster` WHERE `dept` = ? AND `status` <> 'former' AND `badge` LIKE ? LIMIT 20", { dept, U.like(q) }) or {}
        for _, r in ipairs(rows) do
            if not seen[r.cid] then
                local person = lookup(r.cid)
                if person and Core.deptOf({ type = person.jobType }) == dept then
                    seen[person.cid] = true
                    list[#list + 1] = person
                end
            end
        end
    end
    return list
end

function Roster.list(dept, q)
    local people = collect(dept, q)
    local cids = {}
    for i, p in ipairs(people) do cids[i] = p.cid end
    local rows = rowsFor(cids)
    local hours = Duty.hours(dept, 7)
    local last = Duty.lastSeen(dept)
    local now = U.now()
    local out = {}
    for _, person in ipairs(people) do
        local m = build(person, rows[person.cid], dept)
        m.hours7 = U.round((hours[m.cid] or 0) / HOUR, 1)
        m.lastSeen = m.onduty and now or last[m.cid]
        out[#out + 1] = m
    end
    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    while #out > 250 do table.remove(out) end
    return out
end

local function outranks(ctx, member)
    if not Core.manages(ctx, member.job) then return false end
    if ctx.isboss then return true end
    return (member.grade or 0) < ctx.grade
end
Roster.outranks = outranks

local function mayEdit(ctx, member, selfOk)
    if member.cid == ctx.cid then
        if selfOk == true or ctx.isboss then return true end
        return false, 'cant_self'
    end
    if outranks(ctx, member) then return true end
    return false, 'outranked'
end

local function changed(ctx, cid)
    Push.dept(ctx.dept, 'roster:changed', { cid = cid }, function(c) return Core.can(c, 'roster.view') end)
end
Roster.changed = changed

local function tell(cid, msg)
    local p = Core.playerByCid(cid)
    if p then Core.notify(p.source, msg, 'primary') end
end

local function multijob(fn, ...)
    if GetResourceState('vr-multijob') ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function()
        local res = exports['vr-multijob']
        return res[fn](res, table.unpack(args, 1, args.n))
    end)
    if not ok then
        print(('^3[vr-mdt] vr-multijob %s failed: %s^0'):format(fn, tostring(res)))
        return nil
    end
    return res
end

local function setJob(cid, job, grade, keepDuty)
    local onduty
    if keepDuty then
        local current = Core.playerByCid(cid) or Bridge.chars.get(cid)
        if current and current.job then onduty = current.job.onduty == true end
    end
    if not Bridge.chars.setJob(cid, job, grade, onduty) then return false end
    local p = Core.playerByCid(cid)
    if p then
        Bridge.save(p.source)
        Duty.sync(p.source)
    end
    return true
end

local function writeCallsign(cid, value)
    if not Bridge.chars.setMeta(cid, 'callsign', value) then return false end
    local p = Core.playerByCid(cid)
    if p then Bridge.save(p.source) end
    return true
end

local function callsignTaken(dept, callsign, exceptCid)
    for _, src in ipairs(GetPlayers()) do
        local p = Core.player(tonumber(src))
        if p and p.cid ~= exceptCid and Core.deptOf(p.job) == dept then
            local cs = callsignOf(p.metadata)
            if cs and cs:upper() == callsign then return true end
        end
    end
    local found = Bridge.chars.findByMeta and Bridge.chars.findByMeta('callsign', callsign, Core.jobsOfDept(dept))
    if not found then return nil end
    for _, cid in ipairs(found) do
        if cid ~= exceptCid and not Core.playerByCid(cid) then return true end
    end
    return false
end

local function cleanCallsign(v)
    local s = V.str(v, 64, 2)
    if not s or #s > 16 then return nil end
    s = s:upper()
    if not s:match('^[%w%- ]+$') then return nil end
    return s
end

local function cleanBadge(v)
    local s = V.str(v, 64)
    if not s or #s > 12 then return nil end
    s = s:upper()
    if not s:match('^[%w%-]+$') then return nil end
    return s
end

local function cleanDivisions(dept, list)
    if type(list) ~= 'table' then return nil end
    local allowed, order = {}, {}
    for i, d in ipairs(Config.Roster.divisions[dept] or {}) do
        allowed[d:lower()] = d
        order[d] = i
    end
    local count = #list
    if count > (Config.Roster.maxDivisions or 8) then return nil end
    for k in pairs(list) do
        if type(k) ~= 'number' or k < 1 or k > count then return nil end
    end
    local out, seen = {}, {}
    for i = 1, count do
        local v = V.str(list[i], 32)
        local canon = v and allowed[v:lower()]
        if not canon then return nil end
        if not seen[canon] then
            seen[canon] = true
            out[#out + 1] = canon
        end
    end
    table.sort(out, function(a, b) return order[a] < order[b] end)
    return out
end
Roster.cleanDivisions = cleanDivisions

local function ensureRow(cid, dept, actor)
    local row = rowFor(cid)
    local now = U.now()
    if not row then
        local ok = Db.insert([[INSERT INTO `vr_mdt_roster` (`cid`, `dept`, `divisions`, `status`, `updated_at`, `updated_by`) VALUES (?, ?, '[]', 'active', ?, ?)]], { cid, dept, now, actor })
        return ok ~= nil
    end
    if row.dept ~= dept or row.status == 'former' then
        local notes = row.dept == dept and row.notes or nil
        return Db.update([[UPDATE `vr_mdt_roster` SET `dept` = ?, `badge` = NULL, `divisions` = '[]', `notes` = ?, `status` = 'active', `hired_at` = NULL, `fired_at` = NULL,
            `updated_at` = ?, `updated_by` = ? WHERE `cid` = ?]], { dept, notes, now, actor, cid }) ~= nil
    end
    return true
end

local function setField(ctx, cid, column, value)
    if not ensureRow(cid, ctx.dept, ctx.cid) then return false end
    return Db.update(('UPDATE `vr_mdt_roster` SET `%s` = ?, `updated_at` = ?, `updated_by` = ? WHERE `cid` = ?'):format(column), { value, U.now(), ctx.cid, cid }) ~= nil
end

function Roster.setDivisions(ctx, cid, list)
    return setField(ctx, cid, 'divisions', encodeList(list))
end

local function hireRow(cid, dept, actor)
    local now = U.now()
    local row = rowFor(cid)
    local notes = row and row.dept == dept and row.notes or nil
    local divisions = cleanDivisions(dept, Config.Roster.hireDivisions and Config.Roster.hireDivisions[dept] or {}) or {}
    return Db.update([[INSERT INTO `vr_mdt_roster` (`cid`, `dept`, `badge`, `divisions`, `notes`, `status`, `hired_at`, `fired_at`, `updated_at`, `updated_by`)
        VALUES (?, ?, NULL, ?, ?, 'active', ?, NULL, ?, ?)
        ON DUPLICATE KEY UPDATE `dept` = VALUES(`dept`), `badge` = NULL, `divisions` = VALUES(`divisions`), `notes` = VALUES(`notes`), `status` = 'active',
        `hired_at` = VALUES(`hired_at`), `fired_at` = NULL, `updated_at` = VALUES(`updated_at`), `updated_by` = VALUES(`updated_by`)]],
        { cid, dept, encodeList(divisions), notes, now, now, actor }) ~= nil
end

local function fireRow(cid, dept, actor)
    local now = U.now()
    return Db.update([[INSERT INTO `vr_mdt_roster` (`cid`, `dept`, `divisions`, `status`, `fired_at`, `updated_at`, `updated_by`)
        VALUES (?, ?, '[]', 'former', ?, ?, ?)
        ON DUPLICATE KEY UPDATE `dept` = VALUES(`dept`), `status` = 'former', `fired_at` = VALUES(`fired_at`), `updated_at` = VALUES(`updated_at`), `updated_by` = VALUES(`updated_by`)]],
        { cid, dept, now, now, actor }) ~= nil
end

local function target(ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return nil, 'bad_request' end
    local m = Roster.member(cid, ctx.dept)
    if not m then return nil, 'not_found' end
    return m
end

local function detail(ctx, m)
    local row = rowFor(m.cid)
    local cur = currentRow(row, ctx.dept)
    m.hours7 = U.round(Duty.secondsFor(m.cid, ctx.dept, 7) / HOUR, 1)
    m.hours30 = U.round(Duty.secondsFor(m.cid, ctx.dept, 30) / HOUR, 1)
    m.sessions = Duty.sessions(m.cid, ctx.dept, Config.Roster.sessionsShown or 20)
    local lastEnd
    for _, s in ipairs(m.sessions) do
        if s.running then lastEnd = U.now() break end
        lastEnd = math.max(lastEnd or 0, s.endedAt or 0)
    end
    m.lastSeen = m.onduty and U.now() or lastEnd
    local manage = Core.can(ctx, 'roster.manage')
    m.notes = manage and cur and cur.notes or nil
    m.can = {
        identity = manage and (mayEdit(ctx, m, true)),
        edit = manage and (mayEdit(ctx, m, false)),
        rank = manage and m.cid ~= ctx.cid and outranks(ctx, m),
        fire = manage and m.cid ~= ctx.cid and outranks(ctx, m),
    }
    m.updatedAt = cur and tonumber(cur.updated_at) or nil
    return m
end

Api.register('roster.list', 'roster.view', function(src, ctx, data)
    local q = V.str(data.q, 48)
    return true, Roster.list(ctx.dept, q)
end, { rate = 400 })

Api.register('roster.meta', 'roster.view', function(src, ctx)
    local jobs = {}
    for _, name in ipairs(Core.jobsOfDept(ctx.dept)) do
        local info = Bridge.jobs()[name] or {}
        jobs[#jobs + 1] = { name = name, label = info.label or name, grades = Roster.grades(name), hire = Core.manages(ctx, name) }
    end
    return true, {
        divisions = Config.Roster.divisions[ctx.dept] or {},
        statuses = STATUSES,
        jobs = jobs,
        maxDivisions = Config.Roster.maxDivisions or 8,
        hireDivisions = cleanDivisions(ctx.dept, Config.Roster.hireDivisions and Config.Roster.hireDivisions[ctx.dept] or {}) or {},
        traineeDivision = ctx.dept == 'police' and Config.Fto.traineeDivision or nil,
    }
end, { rate = 300 })

Api.register('roster.get', 'roster.view', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    return true, detail(ctx, m)
end, { rate = 150 })

Api.register('roster.setCallsign', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local clear = data.callsign == '' or data.callsign == false
    local callsign = not clear and cleanCallsign(data.callsign) or nil
    if not clear and not callsign then return false, 'bad_request' end
    if callsign == 'NO CALLSIGN' then clear, callsign = true, nil end
    local allowed, why = mayEdit(ctx, m, true)
    if not allowed then return false, why end
    if callsign and callsign == (m.callsign or ''):upper() then return true, detail(ctx, m) end
    if callsign then
        local taken = callsignTaken(ctx.dept, callsign, m.cid)
        if taken == nil then return false, 'save_failed' end
        if taken then return false, 'callsign_taken' end
    end
    if not writeCallsign(m.cid, callsign or 'NO CALLSIGN') then return false, 'save_failed' end
    Audit.log(ctx, 'roster.callsign', m.cid, { from = m.callsign, to = callsign })
    if callsign then tell(m.cid, ('Your callsign is now %s.'):format(callsign)) end
    changed(ctx, m.cid)
    return true, detail(ctx, Roster.member(m.cid, ctx.dept))
end, { rate = 400 })

Api.register('roster.setGrade', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local grade = V.int(data.grade, 0, 1000)
    if grade == nil or not gradeOf(m.job, grade) then return false, 'bad_request' end
    if m.cid == ctx.cid then return false, 'cant_self' end
    if not outranks(ctx, m) or (not ctx.isboss and grade >= ctx.grade) then return false, 'outranked' end
    if grade == m.grade then return true, detail(ctx, m) end
    if not setJob(m.cid, m.job, grade, true) then return false, 'save_failed' end
    multijob('AddJob', m.cid, m.job, grade)
    local after = Roster.member(m.cid, ctx.dept) or m
    Audit.log(ctx, 'roster.grade', m.cid, { job = m.job, from = m.grade, to = grade, rank = after.gradeName })
    tell(m.cid, ('Your rank is now %s.'):format(after.gradeName or tostring(grade)))
    changed(ctx, m.cid)
    return true, detail(ctx, after)
end, { rate = 500 })

Api.register('roster.hire', 'roster.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local job = V.str(data.job, 50)
    local grade = V.int(data.grade, 0, 1000)
    if not cid or not job or grade == nil then return false, 'bad_request' end
    if not jobInDept(job, ctx.dept) or not gradeOf(job, grade) then return false, 'bad_request' end
    if not Core.manages(ctx, job) or (not ctx.isboss and grade >= ctx.grade) then return false, 'outranked' end
    local person = lookup(cid)
    if not person then return false, 'not_found' end
    if Core.deptOf({ type = person.jobType }) == ctx.dept then return false, 'already_member' end
    if not setJob(cid, job, grade, false) then return false, 'save_failed' end
    multijob('AddJob', cid, job, grade)
    hireRow(cid, ctx.dept, ctx.cid)
    local m = Roster.member(cid, ctx.dept)
    Audit.log(ctx, 'roster.hire', cid, { name = person.name, job = job, grade = grade, rank = m and m.gradeName or nil, from = person.job })
    tell(cid, ('You were hired by the %s.'):format(Config.Departments[ctx.dept].label))
    changed(ctx, cid)
    if not m then return true, { cid = cid, name = person.name } end
    return true, detail(ctx, m)
end, { rate = 1000 })

Api.register('roster.fire', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local reason = V.str(data.reason, 200, 3)
    if not reason then return false, 'bad_request' end
    if m.cid == ctx.cid then return false, 'cant_self' end
    if not outranks(ctx, m) then return false, 'outranked' end
    if not setJob(m.cid, 'unemployed', 0, false) then return false, 'save_failed' end
    multijob('RemoveJob', m.cid, m.job)
    Duty.stop(m.cid)
    fireRow(m.cid, ctx.dept, ctx.cid)
    Audit.log(ctx, 'roster.fire', m.cid, { name = m.name, job = m.job, grade = m.grade, rank = m.gradeName, reason = reason })
    tell(m.cid, ('You were let go from the %s.'):format(Config.Departments[ctx.dept].label))
    changed(ctx, m.cid)
    return true, { cid = m.cid }
end, { rate = 1000 })

Api.register('roster.divisions', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local list = cleanDivisions(ctx.dept, data.divisions)
    if not list then return false, 'bad_request' end
    local allowed, why = mayEdit(ctx, m, false)
    if not allowed then return false, why end
    if not Roster.setDivisions(ctx, m.cid, list) then return false, 'save_failed' end
    Audit.log(ctx, 'roster.divisions', m.cid, { from = m.divisions, to = list })
    changed(ctx, m.cid)
    return true, detail(ctx, Roster.member(m.cid, ctx.dept))
end, { rate = 400 })

Api.register('roster.notes', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    if type(data.notes) ~= 'string' then return false, 'bad_request' end
    local notes = V.text(data.notes, 2000)
    local allowed, why = mayEdit(ctx, m, false)
    if not allowed then return false, why end
    if not setField(ctx, m.cid, 'notes', notes) then return false, 'save_failed' end
    Audit.log(ctx, 'roster.notes', m.cid, { length = notes and #notes or 0 })
    changed(ctx, m.cid)
    return true, detail(ctx, Roster.member(m.cid, ctx.dept))
end, { rate = 400 })

Api.register('roster.status', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local status = V.enum(data.status, STATUSES)
    if not status then return false, 'bad_request' end
    local allowed, why = mayEdit(ctx, m, false)
    if not allowed then return false, why end
    if status == m.status then return true, detail(ctx, m) end
    if not setField(ctx, m.cid, 'status', status) then return false, 'save_failed' end
    Audit.log(ctx, 'roster.status', m.cid, { from = m.status, to = status })
    changed(ctx, m.cid)
    return true, detail(ctx, Roster.member(m.cid, ctx.dept))
end, { rate = 400 })

Api.register('roster.badge', 'roster.manage', function(src, ctx, data)
    local m, err = target(ctx, data)
    if not m then return false, err end
    local clear = data.badge == '' or data.badge == false
    local badge = not clear and cleanBadge(data.badge) or nil
    if not clear and not badge then return false, 'bad_request' end
    local allowed, why = mayEdit(ctx, m, true)
    if not allowed then return false, why end
    if badge then
        local rows = Db.query("SELECT `cid` FROM `vr_mdt_roster` WHERE `dept` = ? AND `status` <> 'former' AND `badge` = ? AND `cid` <> ?", { ctx.dept, badge, m.cid })
        if not rows then return false, 'save_failed' end
        for _, r in ipairs(rows) do
            if Roster.isMember(r.cid, ctx.dept) then return false, 'badge_taken' end
        end
    end
    if not setField(ctx, m.cid, 'badge', badge) then return false, 'save_failed' end
    Audit.log(ctx, 'roster.badge', m.cid, { from = m.badge, to = badge })
    changed(ctx, m.cid)
    return true, detail(ctx, Roster.member(m.cid, ctx.dept))
end, { rate = 400 })
