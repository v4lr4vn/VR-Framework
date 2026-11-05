local H = {}
local cfg = function() return Config.Jobs.taxi end

local function rate(level)
    return cfg().perHundredMetres * cfg().perHundredGrowth ^ (level - 1)
end

-- What a fare is worth to this driver, tip not included.
local function worth(ctx, f)
    local c = cfg()
    local fare = math.max(c.minimumFare, f.distance / 100 * rate(ctx.level))
    if f.illegal then fare = fare * c.illegalMultiplier end
    return fare * Civ.mult(ctx.level)
end

local function nextDelay()
    return Core.between(cfg().callDelay) * 1000
end

local function newFare(ctx)
    local c = cfg()
    local p = ctx.pos() or c.depot.coords
    local spots = {}
    for i, s in ipairs(c.spots) do spots[i] = { c = s, d = Civ.dist2(p, s), i = i } end
    table.sort(spots, function(a, b) return a.d < b.d end)
    local pool = {}
    for i = 1, math.min(6, #spots) do
        if spots[i].i ~= ctx.state.lastPickup and spots[i].d > 40.0 then pool[#pool + 1] = spots[i] end
    end
    if #pool == 0 then pool = { spots[1] } end
    local from = Civ.pick(pool)
    local options = {}
    for i, s in ipairs(c.spots) do
        local d = Civ.dist2(from.c, s)
        if i ~= from.i and d >= c.minFareDistance and d <= c.maxFareDistance then options[#options + 1] = { c = s, d = d } end
    end
    if #options == 0 then
        for i, s in ipairs(c.spots) do
            if i ~= from.i then options[#options + 1] = { c = s, d = Civ.dist2(from.c, s) } end
        end
    end
    local to = Civ.pick(options)
    ctx.state.lastPickup = from.i
    return {
        phase = 'pickup',
        from = from.c,
        to = to.c,
        distance = to.d,
        illegal = math.random(100) <= c.illegalChance,
        model = Civ.pick(c.passengers),
    }
end

function H.start(ctx)
    ctx.state.fare = nil
    ctx.state.completed = 0
    ctx.state.earned = 0
    ctx.state.last = nil
    ctx.state.nextCall = GetGameTimer() + nextDelay()
    local rec = ctx.spawn(cfg().vehicle.model, cfg().vehicle.coords)
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local f = s.fare
    return {
        completed = s.completed,
        earned = s.earned or 0,
        last = s.last,
        fare = f and { phase = f.phase, from = Civ.vec(f.from), to = Civ.vec(f.to), distance = math.floor(f.distance), illegal = f.illegal, model = f.model, estimate = math.floor(worth(ctx, f)) } or nil,
        waiting = f == nil,
    }
end

H.act = {}

H.act.call = function(ctx)
    local s = ctx.state
    if s.fare then return { quiet = true, fare = true } end
    local now = GetGameTimer()
    if now < s.nextCall then return { quiet = true, wait = math.ceil((s.nextCall - now) / 1000) } end
    s.fare = newFare(ctx)
    return { fare = true }
end

H.act.pickup = function(ctx)
    local f = ctx.state.fare
    if not f or f.phase ~= 'pickup' then return nil, 'refused' end
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    if Civ.dist(GetEntityCoords(veh), f.from) > cfg().pickupRange then return nil, 'too_far' end
    if not ctx.near(GetEntityCoords(veh), 12.0) then return nil, 'too_far' end
    f.phase = 'ride'
    f.startedAt = GetGameTimer()
    if f.illegal and math.random(100) <= cfg().policeAlertChance then
        Core.alert(ctx.src, 'Suspicious fare', 'A taxi picked up a passenger acting nervously')
    end
    return { phase = f.phase }
end

H.act.drop = function(ctx)
    local s = ctx.state
    local f = s.fare
    if not f or f.phase ~= 'ride' then return nil, 'refused' end
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    if Civ.dist(GetEntityCoords(veh), f.to) > cfg().dropRange then return nil, 'too_far' end
    -- worth() includes the level bonus because it is only for showing the driver an estimate. ctx.pay adds the bonus itself, so pay from the plain fare.
    local plain = math.max(cfg().minimumFare, f.distance / 100 * rate(ctx.level))
    if f.illegal then plain = plain * cfg().illegalMultiplier end
    local tip = 0
    if math.random(100) <= cfg().tipChance then tip = plain * cfg().tipPercent / 100 end
    local xp = math.floor(f.distance / 100 * cfg().xpPerHundredMetres)
    local paid = ctx.pay(plain + tip, xp, 'Taxi fare')
    s.completed = s.completed + 1
    s.earned = (s.earned or 0) + paid
    s.last = paid
    s.fare = nil
    s.nextCall = GetGameTimer() + nextDelay()
    return { paid = paid, tip = math.floor(tip * Civ.mult(ctx.level)), earned = s.earned }
end

H.act.cancel = function(ctx)
    local s = ctx.state
    if not s.fare then return nil, 'refused' end
    s.fare = nil
    s.nextCall = GetGameTimer() + nextDelay()
    return { cancelled = true }
end

-- Fares are paid to the bank as each one is finished, so there is nothing left to pay when the shift ends.
function H.finish(ctx)
    local s = ctx.state
    local earned = s.earned or 0
    ctx.notify(('You earned $%d from %d fare%s this shift'):format(earned, s.completed or 0, (s.completed or 0) == 1 and '' or 's'), earned > 0 and 'success' or 'inform')
    return { complete = true }
end

Civ.register('taxi', H)
