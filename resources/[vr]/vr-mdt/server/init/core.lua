Core = { tabletOpen = {} }
Api = {}
Push = {}
Audit = {}

local handlers = {}
local lastCall = {}
local permOverrides = {}
local deptByType = {}

for key, d in pairs(Config.Departments) do
    deptByType[d.type] = key
end

Db.schema('permissions', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_permissions` (
        `job` VARCHAR(50) NOT NULL,
        `grade` INT NOT NULL,
        `perm` VARCHAR(48) NOT NULL,
        `allowed` TINYINT(1) NOT NULL,
        PRIMARY KEY (`job`, `grade`, `perm`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

Db.schema('audit', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_audit` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `at` INT UNSIGNED NOT NULL,
        `cid` VARCHAR(64) DEFAULT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `dept` VARCHAR(16) DEFAULT NULL,
        `action` VARCHAR(48) NOT NULL,
        `target` VARCHAR(64) DEFAULT NULL,
        `details` TEXT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `dept_at` (`dept`, `at`),
        KEY `cid` (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

function Core.player(src)
    return Bridge.player(src)
end

function Core.playerByCid(cid)
    return Bridge.playerByCid(cid)
end

function Core.callsign(md)
    local cs = type(md) == 'table' and md.callsign or nil
    if type(cs) ~= 'string' or cs == '' or cs == 'NO CALLSIGN' then return nil end
    return cs
end

function Core.deptOf(job)
    if type(job) ~= 'table' then return nil end
    return deptByType[job.type]
end

function Core.deptType(dept)
    local d = Config.Departments[dept]
    return d and d.type or nil
end

function Core.jobsOfDept(dept)
    local out = {}
    for name, job in pairs(Bridge.jobs()) do
        if job.type and deptByType[job.type] == dept then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function Core.loadPermissions()
    local rows = Db.query('SELECT `job`, `grade`, `perm`, `allowed` FROM `vr_mdt_permissions`') or {}
    local map = {}
    for _, r in ipairs(rows) do
        map[r.job] = map[r.job] or {}
        map[r.job][tonumber(r.grade)] = map[r.job][tonumber(r.grade)] or {}
        map[r.job][tonumber(r.grade)][r.perm] = tonumber(r.allowed) == 1 or r.allowed == true
    end
    permOverrides = map
end

function Core.setPermission(job, grade, perm, allowed)
    permOverrides[job] = permOverrides[job] or {}
    permOverrides[job][grade] = permOverrides[job][grade] or {}
    permOverrides[job][grade][perm] = allowed
end

function Core.permsFor(dept, jobName, grade, isboss)
    local perms = Perms.defaults(dept, grade, isboss, jobName)
    if isboss then return perms end
    local o = permOverrides[jobName] and permOverrides[jobName][grade]
    if o then
        for key, allowed in pairs(o) do
            if Perms.allowedFor(dept, key, jobName) then perms[key] = allowed or nil end
        end
    end
    return perms
end

function Core.pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Core.dispatchSpot(src)
    return DispatchZones.spot(Core.pedCoords(src))
end

function Core.context(src)
    local player = Core.player(src)
    if not player then return nil, 'not_loaded' end
    local job = player.job or {}
    local dept = Core.deptOf(job)
    if not dept then return nil, 'no_access' end
    if Config.RequireDuty and dept ~= 'doj' and not job.onduty then return nil, 'off_duty' end
    local spot = nil
    if dept == 'dispatch' then
        spot = Core.dispatchSpot(src)
        if not spot then return nil, 'not_at_desk' end
    end
    local grade, isboss, gradeName = job.grade or 0, job.isboss == true, job.gradeName
    return {
        src = src,
        cid = player.cid,
        name = player.name,
        callsign = Core.callsign(player.metadata),
        job = job.name,
        jobLabel = job.label,
        grade = grade,
        gradeName = gradeName,
        isboss = isboss,
        dept = dept,
        deptType = Core.deptType(dept),
        perms = Core.permsFor(dept, job.name, grade, isboss),
        console = spot == 'console',
    }
end

function Core.manages(ctx, job)
    if not ctx then return false end
    local d = Config.Departments[ctx.dept]
    if d and d.separateJobs then return job == ctx.job end
    return true
end

function Core.can(ctx, perm)
    if not ctx then return false end
    if perm == nil then return true end
    if type(perm) == 'table' then
        for _, p in ipairs(perm) do
            if ctx.perms[p] then return true end
        end
        return false
    end
    return ctx.perms[perm] == true
end

function Core.notify(src, msg, kind)
    Bridge.notify(src, msg, kind or 'primary')
end

function Core.nameOf(cid)
    return Bridge.chars.name(cid)
end

function Core.onlineInDept(dept)
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local ctx = Core.context(src)
        if ctx and ctx.dept == dept then out[#out + 1] = ctx end
    end
    return out
end

function Core.onlineContexts()
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local ctx = Core.context(src)
        if ctx then out[#out + 1] = ctx end
    end
    return out
end

function Api.register(action, perm, fn, opts)
    handlers[action] = { perm = perm, fn = fn, rate = opts and opts.rate or 150, any = opts and opts.any }
end

function Api.has(action)
    return handlers[action] ~= nil
end

local function tooFast(src, action, ms)
    local now = GetGameTimer()
    local key = src .. ':' .. action
    local last = lastCall[key]
    if last and now - last < ms then return true end
    lastCall[key] = now
    return false
end

function Api.call(src, action, data)
    if type(action) ~= 'string' or #action > 48 then return false, 'bad_request' end
    local h = handlers[action]
    if not h then return false, 'bad_request' end
    if not Db.isReady() then return false, 'not_ready' end
    local ctx, why = Core.context(src)
    if not ctx then return false, why end
    if not Core.can(ctx, h.perm) then return false, 'not_allowed' end
    if ctx.dept == 'dispatch' and Dispatcher and Dispatcher.denied(action) then return false, 'not_allowed' end
    if tooFast(src, action, h.rate) then return false, 'slow_down' end
    if data ~= nil and type(data) ~= 'table' then return false, 'bad_request' end
    local ok, a, b = pcall(h.fn, src, ctx, data or {})
    if not ok then
        print(('^1[vr-mdt] %s failed: %s^0'):format(action, tostring(a)))
        return false, 'server_error'
    end
    return a, b
end

Bridge.callback.register('vr-mdt:req', function(src, action, data)
    local ok, result = Api.call(src, action, data)
    if ok then return { ok = true, data = result } end
    return { ok = false, error = result or 'server_error' }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local prefix = src .. ':'
    for k in pairs(lastCall) do
        if k:sub(1, #prefix) == prefix then lastCall[k] = nil end
    end
end)

function Push.to(src, name, payload)
    TriggerClientEvent('vr-mdt:client:push', src, name, payload)
end

function Push.dept(dept, name, payload, filter)
    for _, ctx in ipairs(Core.onlineInDept(dept)) do
        if not filter or filter(ctx) then Push.to(ctx.src, name, payload) end
    end
end

function Push.where(filter, name, payload)
    for _, ctx in ipairs(Core.onlineContexts()) do
        if filter(ctx) then Push.to(ctx.src, name, payload) end
    end
end

function Audit.log(ctx, action, target, details)
    local cid, name, dept = nil, 'System', nil
    if ctx then cid, name, dept = ctx.cid, ctx.name, ctx.dept end
    local encoded = details ~= nil and json.encode(details) or nil
    if encoded and #encoded > 4000 then encoded = encoded:sub(1, 4000) end
    Db.insert('INSERT INTO `vr_mdt_audit` (`at`, `cid`, `name`, `dept`, `action`, `target`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        U.now(), cid, name, dept, action, target ~= nil and tostring(target):sub(1, 64) or nil, encoded,
    })
end

Api.register('session.get', nil, function(src, ctx)
    local d = Config.Departments[ctx.dept]
    local perms = {}
    for key in pairs(ctx.perms) do perms[#perms + 1] = key end
    table.sort(perms)
    return true, {
        me = { cid = ctx.cid, name = ctx.name, callsign = ctx.callsign, job = ctx.job, jobLabel = ctx.jobLabel, grade = ctx.grade, gradeName = ctx.gradeName, isboss = ctx.isboss, console = ctx.console },
        dept = { id = ctx.dept, label = d.label, short = d.short, type = d.type, color = d.color },
        perms = perms,
        statuses = Config.UnitStatuses,
        map = Config.Map,
        flags = Config.CitizenFlags,
        licences = Config.Licences,
        serverTime = U.now(),
    }
end, { rate = 500 })

Api.register('audit.list', 'permissions.manage', function(src, ctx, data)
    local page = V.int(data.page, 1, 1000) or 1
    local q = V.str(data.q, 48)
    local rows
    if q then
        local like = U.like(q)
        rows = Db.query([[SELECT * FROM `vr_mdt_audit` WHERE `dept` = ? AND (`name` LIKE ? OR `action` LIKE ? OR `target` LIKE ?)
            ORDER BY `id` DESC LIMIT 50 OFFSET ?]], { ctx.dept, like, like, like, (page - 1) * 50 })
    else
        rows = Db.query('SELECT * FROM `vr_mdt_audit` WHERE `dept` = ? ORDER BY `id` DESC LIMIT 50 OFFSET ?', { ctx.dept, (page - 1) * 50 })
    end
    if not rows then return false, 'server_error' end
    for _, r in ipairs(rows) do r.details = U.decode(r.details, nil) end
    return true, rows
end, { rate = 300 })

RegisterNetEvent('vr-mdt:server:tablet', function(open)
    local src = source
    if open == true and Core.context(src) then
        Core.tabletOpen[src] = true
    else
        Core.tabletOpen[src] = nil
    end
    TriggerEvent('vr-mdt:server:tabletChanged', src, Core.tabletOpen[src] == true)
end)

AddEventHandler('playerDropped', function()
    Core.tabletOpen[source] = nil
end)

function Core.exportAs(name, fn, aliases)
    exports(name, fn)
    for _, res in ipairs(aliases or {}) do
        AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
    end
end

Db.ready(function()
    Core.loadPermissions()
end)
