local H = {}
local cfg = function() return Config.Jobs.newspaper end

local function routeOf(id)
    for _, r in ipairs(cfg().routes) do
        if r.id == id then return r end
    end
    return nil
end

function H.board(b)
    local options = {}
    for _, r in ipairs(cfg().routes) do
        local daily = r.daily and Progress.dailyDone(b.info.cid, 'newspaper', r.id)
        options[#options + 1] = {
            id = r.id, label = r.label, level = r.level, locked = b.level < r.level or daily == true,
            detail = ('%d houses, $%d%s'):format(#r.stops, r.pay, r.daily and (daily and ', done today' or ', once a day') or ''),
        }
    end
    return { options = options }
end

function H.start(ctx, opts)
    local r = routeOf(opts.option) or cfg().routes[1]
    if ctx.level < r.level then return nil, 'level' end
    if r.daily and Progress.dailyDone(ctx.info.cid, 'newspaper', r.id) then return nil, 'daily_done' end
    ctx.state.route = r
    ctx.state.delivered = {}
    ctx.state.count = 0
    ctx.state.phase = 'deliver'
    local spec = cfg().vehicle
    local rec = ctx.spawn(spec.model, spec.coords, { type = 'bike' })
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local stops = {}
    for i, c in ipairs(s.route.stops) do stops[i] = { x = c.x, y = c.y, z = c.z, done = s.delivered[i] == true } end
    return { phase = s.phase, route = s.route.label, stops = stops, count = s.count, total = #stops, depot = Civ.vec(cfg().depot.coords), pay = s.route.pay }
end

H.act = {}

H.act.throw = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'deliver' then return nil, 'refused' end
    local i = math.floor(Core.num(d.i, 1, #s.route.stops) or 0)
    local stop = s.route.stops[i]
    if not stop or s.delivered[i] then return nil, 'gone' end
    if not ctx.near(stop, cfg().throwRange) then return nil, 'too_far' end
    if ctx.limit('throw', 800) then return nil, 'slow_down' end
    s.delivered[i] = true
    s.count = s.count + 1
    ctx.earn(cfg().pricePerPaper, cfg().xpPerPaper)
    if s.count >= #s.route.stops then
        s.phase = 'return'
        ctx.notify('Round finished. Take the bike back to the depot')
    end
    return { count = s.count }
end

H.act.finish = function(ctx)
    if ctx.state.phase ~= 'return' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, cfg().vehicle.returnRadius * 2) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    local s = ctx.state
    if s.phase ~= 'return' then return {} end
    if s.route.daily then Progress.markDaily(ctx.info.cid, 'newspaper', s.route.id) end
    return { complete = true, bonus = s.route.pay, xp = s.route.xp }
end

Civ.register('newspaper', H)
