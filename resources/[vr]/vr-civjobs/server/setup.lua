local overrides = {}
local loaded = false

local function admin(src)
    if src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

local function fail(code) return { ok = false, error = code } end

local function view(job)
    local def = Config.Jobs[job]
    local fields = Setup.describe(job)
    for _, d in ipairs(fields) do
        local f = Setup.field(job, d.id)
        d.value = Setup.value(f)
        d.custom = overrides[job] ~= nil and overrides[job][d.id] ~= nil
    end
    return { id = job, label = def.label, icon = def.icon, fields = fields }
end

local function overview()
    local out = {}
    for id, def in pairs(Config.Jobs) do
        local changed = 0
        for _ in pairs(overrides[id] or {}) do changed = changed + 1 end
        out[#out + 1] = { id = id, label = def.label, icon = def.icon, changed = changed, fields = #(Setup.jobs[id] or {}) }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function broadcast(to)
    TriggerClientEvent('vr-civjobs:client:setup', to or -1, overrides)
end

local function save(job, id, j)
    overrides[job] = overrides[job] or {}
    if j == nil then
        overrides[job][id] = nil
        if next(overrides[job]) == nil then overrides[job] = nil end
        Setup.reset(job, id)
        MySQL.query('DELETE FROM vr_civjobs_setup WHERE job = ? AND field = ?', { job, id })
    else
        overrides[job][id] = j
        Setup.apply(job, id, j)
        MySQL.query('INSERT INTO vr_civjobs_setup (job, field, value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)', { job, id, json.encode(j) })
    end
    broadcast()
end

local function here(src)
    local p = Bridge.coords(src)
    if not p then return nil end
    local ped = GetPlayerPed(src)
    local h = ped and ped ~= 0 and GetEntityHeading(ped) or 0.0
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, w = h + 0.0 }
end

local function newItem(f, pos, data)
    local spec = f.item
    local item = { x = pos.x, y = pos.y, z = pos.z }
    if spec.pos == 'vec4' then item.w = pos.w end
    if spec.rkey then
        local r = tonumber(data.r) or spec.defaultR or 50.0
        item.r = math.max(2.0, math.min(1500.0, r))
    end
    if spec.headingKey then item.heading = pos.w end
    for _, e in ipairs(spec.extra or {}) do
        local v = data[e.key]
        if v == nil then v = e.default end
        item[e.key] = v
    end
    return item
end

local handlers = {}

handlers.open = function(src, d)
    local jobs = overview()
    local out = { jobs = jobs }
    local id = type(d.job) == 'string' and Config.Jobs[d.job] and d.job or nil
    if id then out.job = view(id) end
    return { ok = true, data = out }
end

handlers.job = function(src, d)
    if type(d.job) ~= 'string' or not Config.Jobs[d.job] then return fail('bad_job') end
    return { ok = true, data = { job = view(d.job), jobs = overview() } }
end

local function target(d)
    if type(d.job) ~= 'string' or not Config.Jobs[d.job] then return nil, 'bad_job' end
    local f = type(d.field) == 'string' and Setup.field(d.job, d.field)
    if not f then return nil, 'bad_field' end
    return f
end

local function done(job)
    return { ok = true, data = { job = view(job), jobs = overview() } }
end

handlers.set = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    local j
    if f.kind == 'number' then
        j = tonumber(d.value)
    elseif f.kind == 'vec3' or f.kind == 'vec4' then
        local p = here(src)
        if not p then return fail('no_position') end
        j = { x = p.x, y = p.y, z = p.z }
        if f.kind == 'vec4' then j.w = p.w end
    else
        return fail('bad_field')
    end
    if j == nil or not Setup.valid(f, j) then return fail('bad_value') end
    save(f.job, f.id, j)
    return done(f.job)
end

handlers.add = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    if f.kind ~= 'list' then return fail('bad_field') end
    local p = here(src)
    if not p then return fail('no_position') end
    local list = Setup.value(f) or {}
    if #list >= (f.max or 40) then return fail('list_full') end
    list[#list + 1] = newItem(f, p, type(d.data) == 'table' and d.data or {})
    if not Setup.valid(f, list) then return fail('bad_value') end
    save(f.job, f.id, list)
    return done(f.job)
end

handlers.update = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    if f.kind ~= 'list' or type(d.patch) ~= 'table' then return fail('bad_field') end
    local list = Setup.value(f) or {}
    local i = math.floor(tonumber(d.index) or 0)
    local item = list[i]
    if not item then return fail('bad_index') end
    if f.item.rkey and d.patch.r ~= nil then item.r = tonumber(d.patch.r) end
    for _, e in ipairs(f.item.extra or {}) do
        local v = d.patch[e.key]
        if v ~= nil then
            if e.type == 'number' then v = tonumber(v) end
            item[e.key] = v
        end
    end
    if not Setup.valid(f, list) then return fail('bad_value') end
    save(f.job, f.id, list)
    return done(f.job)
end

handlers.move = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    if f.kind ~= 'list' then return fail('bad_field') end
    local p = here(src)
    if not p then return fail('no_position') end
    local list = Setup.value(f) or {}
    local i = math.floor(tonumber(d.index) or 0)
    local item = list[i]
    if not item then return fail('bad_index') end
    item.x, item.y, item.z = p.x, p.y, p.z
    if f.item.pos == 'vec4' then item.w = p.w end
    if f.item.headingKey then item.heading = p.w end
    save(f.job, f.id, list)
    return done(f.job)
end

handlers.remove = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    if f.kind ~= 'list' then return fail('bad_field') end
    local list = Setup.value(f) or {}
    local i = math.floor(tonumber(d.index) or 0)
    if not list[i] then return fail('bad_index') end
    if #list <= (f.min or 0) then return fail('list_min') end
    table.remove(list, i)
    save(f.job, f.id, list)
    return done(f.job)
end

handlers.reset = function(src, d)
    local f, err = target(d)
    if not f then return fail(err) end
    save(f.job, f.id, nil)
    return done(f.job)
end

handlers.resetJob = function(src, d)
    if type(d.job) ~= 'string' or not Config.Jobs[d.job] then return fail('bad_job') end
    for _, f in ipairs(Setup.jobs[d.job] or {}) do
        if overrides[d.job] and overrides[d.job][f.id] ~= nil then save(d.job, f.id, nil) end
    end
    return done(d.job)
end

local limits = { open = 300, job = 150, set = 200, add = 200, update = 120, move = 200, remove = 200, reset = 200, resetJob = 500 }

lib.callback.register('vr-civjobs:setup', function(src, action, data)
    if not admin(src) then return fail('not_admin') end
    if not loaded then return fail('not_ready') end
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if Core.throttle(src, 'setup:' .. action, limits[action] or 200) then return fail('slow_down') end
    local ok, res = pcall(h, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[vr-civjobs] setup %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end)

lib.callback.register('vr-civjobs:setupGet', function()
    if not loaded then return nil end
    return overrides
end)

Db.onReady(function()
    local rows = MySQL.query.await('SELECT job, field, value FROM vr_civjobs_setup') or {}
    for _, r in ipairs(rows) do
        local ok, j = pcall(json.decode, r.value)
        local f = ok and Config.Jobs[r.job] and Setup.field(r.job, r.field)
        if f and Setup.valid(f, j) then
            overrides[r.job] = overrides[r.job] or {}
            overrides[r.job][r.field] = j
            Setup.apply(r.job, r.field, j)
        end
    end
    loaded = true
    broadcast()
end)

Bridge.on('playerLoaded', function(src)
    if loaded then broadcast(src) end
end)
