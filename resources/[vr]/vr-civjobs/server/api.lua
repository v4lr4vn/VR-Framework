Api = {}

local handlers = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end

Api.ok, Api.fail = ok, fail

local function board(info, jobId)
    local def = Config.Jobs[jobId]
    local H = Civ.jobs[jobId]
    if not def or not H or Config.Disabled[jobId] then return nil end
    local prog = Progress.get(info.cid, jobId)
    local level, into, need = Civ.levelOf(prog.xp)
    local sess = Session.of(info.src)
    local out = {
        job = jobId,
        label = def.label,
        icon = def.icon,
        description = def.description,
        crew = def.crew or 0,
        level = level,
        xp = into,
        xpNext = need,
        done = prog.done,
        earned = prog.earned,
        mult = Civ.round(Civ.mult(level), 2),
        qualified = Core.qualifies(info, def),
        needsJob = Core.defined(def) and def.job or nil,
        active = sess and sess.job == jobId and Session.view(sess, info.src) or nil,
        busyWith = sess and sess.job ~= jobId and sess.def.label or nil,
    }
    if H.board then
        local done, res = pcall(H.board, { info = info, prog = prog, level = level, def = def })
        if done and type(res) == 'table' then out.options = res.options; out.extra = res.extra end
    end
    return out
end

handlers.open = function(info, d)
    local b = type(d.job) == 'string' and board(info, d.job)
    if not b then return fail('bad_job') end
    return ok(b)
end

handlers.start = function(info, d)
    if type(d.job) ~= 'string' then return fail('bad_job') end
    local sess, err = Session.start(info, d.job, { option = d.option })
    if not sess then return fail(err) end
    return ok(board(info, d.job))
end

handlers.stop = function(info)
    local sess = Session.of(info.src)
    if not sess then return fail('no_session') end
    if sess.host == info.src then
        Session.close(sess, 'quit', info.src)
    else
        Session.leave(info.src, 'left')
    end
    return ok(true)
end

handlers['crew.invite'] = function(info, d)
    local done, err = Session.invite(info.src, d.target)
    if not done then return fail(err) end
    return ok(true)
end

handlers['crew.accept'] = function(info)
    local sess, err = Session.accept(info.src)
    if not sess then return fail(err) end
    return ok(Session.view(sess, info.src))
end

handlers['crew.decline'] = function(info)
    Session.decline(info.src)
    return ok(true)
end

handlers['crew.kick'] = function(info, d)
    local done, err = Session.kick(info.src, d.target)
    if not done then return fail(err) end
    return ok(true)
end

handlers['crew.nearby'] = function(info)
    local sess = Session.of(info.src)
    if not sess or sess.host ~= info.src then return fail('not_host') end
    local me = Bridge.coords(info.src)
    local out = {}
    if me then
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            if src and src ~= info.src and not Session.byMember[src] then
                local c = Bridge.coords(src)
                local other = Core.info(src)
                if c and other and Civ.dist(me, c) <= Config.Crew.range and Core.qualifies(other, sess.def) then
                    out[#out + 1] = { src = src, name = other.name }
                end
            end
        end
    end
    return ok(out)
end

handlers.act = function(info, d)
    if type(d.kind) ~= 'string' then return fail('bad_request') end
    local res, err = Session.act(info.src, d.kind, d.data)
    if not res then return fail(err) end
    return ok(res)
end

handlers.state = function(info)
    local sess = Session.of(info.src)
    if not sess then return ok(nil) end
    return ok(Session.view(sess, info.src))
end

handlers.sell = function(info, d)
    local jobId = type(d.job) == 'string' and d.job or nil
    local H = jobId and Civ.jobs[jobId]
    if not H or not H.sell then return fail('bad_request') end
    local def = Config.Jobs[jobId]
    if not Core.near(info.src, def.depot.coords, 12.0) then return fail('too_far') end
    local res, err = H.sell(info, d)
    if not res then return fail(err or 'refused') end
    return ok(res)
end

handlers.shop = function(info, d)
    local jobId = type(d.job) == 'string' and d.job or nil
    local H = jobId and Civ.jobs[jobId]
    if not H or not H.shop then return fail('bad_request') end
    local def = Config.Jobs[jobId]
    if not Core.near(info.src, def.depot.coords, 12.0) then return fail('too_far') end
    local res, err = H.shop(info, d)
    if not res then return fail(err or 'refused') end
    return ok(res)
end

local LIMITS = { act = 120, open = 250, start = 1500, stop = 800, state = 300, sell = 800, shop = 500 }

function Api.handle(src, action, data)
    if not Db.ready then return fail('not_ready') end
    local info = Core.info(src)
    if not info then return fail('no_character') end
    local fn = type(action) == 'string' and handlers[action] or nil
    if not fn then return fail('bad_request') end
    local limit = LIMITS[action] or 300
    if Core.throttle(src, 'api:' .. action, limit) then return fail('slow_down') end
    Progress.bind(src, info.cid)
    local done, res = pcall(fn, info, type(data) == 'table' and data or {})
    if not done then
        print(('^1[vr-civjobs] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end

lib.callback.register('vr-civjobs:api', function(src, action, data)
    return Api.handle(src, action, data)
end)
