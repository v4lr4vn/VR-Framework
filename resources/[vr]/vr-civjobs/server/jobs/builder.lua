local H = {}
local cfg = function() return Config.Jobs.builder end

local function percent(state)
    local done = 0
    for _, t in ipairs(state.tasks) do
        if t.done then done = done + 1 end
    end
    return done, #state.tasks
end

local function worth(state)
    return cfg().onePercentWorth * 100 / #state.tasks
end

function H.board()
    local out = {}
    for i, s in ipairs(cfg().sites) do out[#out + 1] = { id = tostring(i), label = s.label, detail = ('%d jobs'):format(#s.tasks), level = 1 } end
    return { options = out }
end

function H.start(ctx, opts)
    local site = cfg().sites[tonumber(opts.option) or 1] or cfg().sites[1]
    local tasks = {}
    for i, t in ipairs(site.tasks) do
        tasks[i] = { type = t.type, label = t.label, from = t.from, to = t.to, at = t.at, done = false, holder = nil }
    end
    ctx.state.site = site.label
    ctx.state.tasks = tasks
    ctx.state.phase = 'build'
    return true
end

local function pt(v)
    return v and Civ.vec(v) or nil
end

function H.view(ctx)
    local s = ctx.state
    local tasks = {}
    for i, t in ipairs(s.tasks) do
        tasks[i] = { type = t.type, label = t.label, from = pt(t.from), to = pt(t.to), at = pt(t.at), done = t.done, holder = t.holder }
    end
    local done, total = percent(s)
    return {
        phase = s.phase,
        site = s.site,
        tasks = tasks,
        done = done,
        total = total,
        percent = math.floor(done / total * 100),
        carry = ctx.member and ctx.member.carry or false,
        carryTask = ctx.member and ctx.member.carryTask or nil,
        depot = Civ.vec(cfg().depot.coords),
        work = cfg().work,
    }
end

function H.left(sess, src)
    local m = sess.members[src]
    if m and m.carryTask then
        local t = sess.state.tasks[m.carryTask]
        if t and not t.done then t.holder = nil end
        m.carry, m.carryTask = false, nil
    end
end

H.act = {}

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    ctx.begin('work')
    return { quiet = true }
end

local function task(ctx, d)
    local i = math.floor(Core.num(d.i, 1, #ctx.state.tasks) or 0)
    local t = ctx.state.tasks[i]
    if not t or t.done or ctx.state.phase ~= 'build' then return nil end
    return t, i
end

H.act.pick = function(ctx, d)
    local t, i = task(ctx, d)
    if not t or t.type ~= 'carry' or t.holder or ctx.member.carry then return nil, 'refused' end
    if not ctx.near(t.from, cfg().carryRange) then return nil, 'too_far' end
    if ctx.limit('pick', 500) then return nil, 'slow_down' end
    t.holder = ctx.src
    ctx.member.carry, ctx.member.carryTask = true, i
    return { i = i }
end

local function complete(ctx)
    local s = ctx.state
    local done, total = percent(s)
    if done >= total then
        s.phase = 'complete'
        ctx.notify('The build is finished. Report back to the foreman')
    end
end

H.act.place = function(ctx, d)
    local t, i = task(ctx, d)
    if not t or t.type ~= 'carry' or t.holder ~= ctx.src then return nil, 'refused' end
    if not ctx.near(t.to, cfg().carryRange) then return nil, 'too_far' end
    t.done, t.holder = true, nil
    ctx.member.carry, ctx.member.carryTask = false, nil
    ctx.earn(worth(ctx.state), math.floor(cfg().xpFull / #ctx.state.tasks))
    complete(ctx)
    return { i = i }
end

H.act.work = function(ctx, d)
    local t, i = task(ctx, d)
    local w = t and cfg().work[t.type]
    if not t or not w then return nil, 'refused' end
    if not ctx.near(t.at, cfg().workRange) then return nil, 'too_far' end
    local since = ctx.since('work')
    ctx.clear('work')
    if not since or since < w.seconds * 800 then return nil, 'too_fast' end
    t.done = true
    ctx.earn(worth(ctx.state), math.floor(cfg().xpFull / #ctx.state.tasks))
    complete(ctx)
    return { i = i }
end

H.act.finish = function(ctx)
    if ctx.state.phase ~= 'complete' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, 60.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    if ctx.state.phase == 'complete' then
        return { complete = true, bonus = cfg().completionBonus }
    end
    return { penalty = cfg().penaltyIncomplete }
end

Civ.register('builder', H)
