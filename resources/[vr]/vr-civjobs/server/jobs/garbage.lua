local H = {}
local cfg = function() return Config.Jobs.garbage end

local bagSet
local function bags()
    if not bagSet then
        bagSet = {}
        for _, name in ipairs(cfg().bagModels) do bagSet[joaat(name)] = true end
    end
    return bagSet
end

local function routeOf(id)
    for _, r in ipairs(cfg().routes) do
        if r.id == id then return r end
    end
    return nil
end

local function newStop(state)
    state.need = Core.between(cfg().bagsPerStop)
    state.taken = {}
    state.collected = 0
    state.thrown = 0
    state.scanned = false
end

local function key(x, y)
    return ('%d:%d'):format(math.floor(x * 2), math.floor(y * 2))
end

local function nextStop(sess, notify)
    local s = sess.state
    if s.idx >= #s.stops then
        s.phase = 'return'
        notify('Round done. Bring the truck back to the depot')
    else
        s.idx = s.idx + 1
        newStop(s)
        notify('Next stop marked on your map')
    end
end

function H.board(b)
    local options = {}
    for _, r in ipairs(cfg().routes) do
        options[#options + 1] = { id = r.id, label = r.label, detail = ('%d stops'):format(r.stops), level = r.level, locked = b.level < r.level }
    end
    return { options = options }
end

function H.start(ctx, opts)
    local route = routeOf(opts.option) or cfg().routes[1]
    if ctx.level < route.level then return nil, 'level' end
    local pool = Civ.shuffle(cfg().stops)
    local stops = {}
    for i = 1, math.min(route.stops, #pool) do stops[i] = pool[i] end
    ctx.state.route = route.id
    ctx.state.stops = stops
    ctx.state.idx = 1
    ctx.state.phase = 'collect'
    ctx.state.total = 0
    newStop(ctx.state)
    local rec = ctx.spawn(cfg().vehicle.model, cfg().vehicle.coords)
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local stop = s.stops[s.idx]
    local taken = {}
    for _, t in pairs(s.taken) do taken[#taken + 1] = { x = t.x, y = t.y, z = t.z, model = t.model } end
    return {
        phase = s.phase,
        idx = s.idx,
        of = #s.stops,
        stop = stop and Civ.vec(stop) or nil,
        radius = cfg().stopRadius,
        need = s.need,
        collected = s.collected,
        taken = taken,
        scanned = s.scanned,
        thrown = s.thrown,
        total = s.total,
        carry = ctx.member and ctx.member.carry or false,
        depot = Civ.vec(cfg().depot.coords),
    }
end

function H.left(sess, src)
    local m = sess.members[src]
    local s = sess.state
    if m and m.carry and s.phase == 'collect' then
        m.carry = false
        s.collected = math.max(s.thrown, s.collected - 1)
        s.need = math.max(s.thrown, math.min(s.need, s.collected))
        if s.thrown >= s.need and s.thrown > 0 then
            nextStop(sess, function() end)
        end
    end
end

H.act = {}

H.act.scan = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'collect' or s.scanned then return { quiet = true } end
    local stop = s.stops[s.idx]
    if not ctx.near(stop, cfg().stopRadius + 10.0) then return nil, 'too_far' end
    local count = math.floor(Core.num(d.count, 0, 40) or 0)
    s.scanned = true
    if count <= 0 then
        ctx.notify('There is nothing to collect here. Moving on')
        nextStop(ctx.sess, ctx.notify)
        return { skipped = true }
    end
    s.need = math.min(s.need, count)
    return { need = s.need }
end

H.act.pickup = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'collect' or ctx.member.carry then return nil, 'refused' end
    local stop = s.stops[s.idx]
    local c = Core.vec(d)
    local model = math.floor(tonumber(d.model) or 0)
    if not c or not bags()[model] then return nil, 'bad_request' end
    if Civ.dist2(c, stop) > cfg().stopRadius + 2.0 then return nil, 'out_of_zone' end
    if not ctx.near(c, cfg().pickupRange + 2.5) then return nil, 'too_far' end
    local k = key(c.x, c.y)
    if s.taken[k] then return nil, 'taken' end
    if s.collected >= s.need then return nil, 'enough' end
    if ctx.limit('pickup', 500) then return nil, 'slow_down' end
    s.taken[k] = { x = c.x, y = c.y, z = c.z, model = model, src = ctx.src }
    s.collected = s.collected + 1
    ctx.member.carry = true
    return { key = k }
end

H.act.throw = function(ctx)
    local s = ctx.state
    if s.phase ~= 'collect' or not ctx.member.carry then return nil, 'refused' end
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    local p = ctx.pos()
    if not p or Civ.dist(p, GetEntityCoords(veh)) > cfg().throwRange then return nil, 'too_far' end
    if ctx.limit('throw', 500) then return nil, 'slow_down' end
    ctx.member.carry = false
    s.thrown = s.thrown + 1
    s.total = s.total + 1
    ctx.earn(cfg().pricePerBag, cfg().xpPerBag)
    if s.thrown >= s.need then nextStop(ctx.sess, ctx.notify) end
    return { total = s.total }
end

H.act.finish = function(ctx)
    local s = ctx.state
    if s.phase ~= 'return' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, 60.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    local s = ctx.state
    if s.phase == 'return' then
        return { complete = true, bonus = cfg().completionBonus, xp = cfg().xpCompletion }
    end
    return {}
end

Civ.register('garbage', H)
