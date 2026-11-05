local H = {}
local cfg = function() return Config.Jobs.busdriver end

local function routeOf(id)
    for _, r in ipairs(cfg().routes) do
        if r.id == id then return r end
    end
    return nil
end

function H.board(b)
    local options = {}
    for _, r in ipairs(cfg().routes) do
        local daily = r.daily and Progress.dailyDone(b.info.cid, 'busdriver', r.id)
        options[#options + 1] = {
            id = r.id, label = r.label, level = r.level, locked = b.level < r.level or daily == true,
            detail = ('%d stops, $%d%s'):format(#r.stops, r.pay, r.daily and (daily and ', done today' or ', once a day') or ''),
        }
    end
    return { options = options }
end

function H.start(ctx, opts)
    local r = routeOf(opts.option) or cfg().routes[1]
    if ctx.level < r.level then return nil, 'level' end
    if r.daily and Progress.dailyDone(ctx.info.cid, 'busdriver', r.id) then return nil, 'daily_done' end
    ctx.state.route = r
    ctx.state.idx = 1
    ctx.state.phase = 'route'
    ctx.state.arrived = nil
    ctx.state.passengers = 0
    ctx.state.onboard = 0
    ctx.state.board = 0
    ctx.state.alight = 0
    local rec = ctx.spawn(cfg().vehicle.model, cfg().vehicle.coords)
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local stop = s.route.stops[s.idx]
    return {
        phase = s.phase,
        route = s.route.label,
        idx = s.idx,
        of = #s.route.stops,
        stop = stop and { label = stop.label, x = stop.coords.x, y = stop.coords.y, z = stop.coords.z } or nil,
        arrived = s.arrived ~= nil,
        passengers = s.passengers,
        onboard = s.onboard or 0,
        wait = cfg().stopWaitSeconds,
        depot = Civ.vec(cfg().depot.coords),
        pay = s.route.pay,
    }
end

local function speed(veh)
    local ok, v = pcall(GetEntityVelocity, veh)
    if not ok or not v then return 0.0 end
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

H.act = {}

H.act.arrive = function(ctx)
    local s = ctx.state
    if s.phase ~= 'route' or s.arrived then return nil, 'refused' end
    local stop = s.route.stops[s.idx]
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    if Civ.dist(GetEntityCoords(veh), stop.coords) > cfg().stopRange then return nil, 'too_far' end
    if speed(veh) > cfg().stopSpeed then return nil, 'too_fast' end
    s.arrived = GetGameTimer()
    -- Who gets off here and who gets on. Everybody gets off at the end of the line, and nobody gets on.
    local last = s.idx >= #s.route.stops
    local onboard = s.onboard or 0
    local alight = last and onboard or math.floor(onboard * math.random(25, 90) / 100 + 0.5)
    local board = 0
    if not last then
        board = math.random(cfg().passengers[1], cfg().passengers[2])
        board = math.max(0, math.min(board, (cfg().capacity or 14) - (onboard - alight)))
    end
    s.alight, s.board = alight, board
    return { arrived = true, board = board, alight = alight, onboard = onboard }
end

H.act.depart = function(ctx)
    local s = ctx.state
    if s.phase ~= 'route' or not s.arrived then return nil, 'refused' end
    if GetGameTimer() - s.arrived < cfg().stopWaitSeconds * 800 then return nil, 'too_fast' end
    local n = s.board or 0
    local off = s.alight or 0
    s.passengers = s.passengers + n
    s.onboard = math.max(0, (s.onboard or 0) - off) + n
    s.board, s.alight = 0, 0
    s.arrived = nil
    ctx.earn(n * cfg().farePerPassenger, 0)
    if s.idx >= #s.route.stops then
        s.phase = 'return'
        ctx.notify('Route complete. Take the bus back to the depot')
    else
        s.idx = s.idx + 1
    end
    return { passengers = n, alighted = off, onboard = s.onboard }
end

H.act.finish = function(ctx)
    if ctx.state.phase ~= 'return' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, cfg().vehicle.returnRadius * 2) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    local s = ctx.state
    if s.phase ~= 'return' then return {} end
    local crash = 0
    local veh = ctx.vehicle()
    if veh then
        local ok, health = pcall(GetVehicleBodyHealth, veh)
        if ok and health and health < Config.Penalty.crashBelowBodyHealth then
            crash = math.floor((Config.Penalty.crashBelowBodyHealth - health) * Config.Penalty.crashPerCent)
        end
    end
    if s.route.daily then Progress.markDaily(ctx.info.cid, 'busdriver', s.route.id) end
    return { complete = true, bonus = s.route.pay, xp = s.route.xp, crash = crash }
end

Civ.register('busdriver', H)
