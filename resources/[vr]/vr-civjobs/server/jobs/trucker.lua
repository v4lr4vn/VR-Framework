local H = {}
local cfg = function() return Config.Jobs.trucker end

local function contractOf(id)
    for _, c in ipairs(cfg().contracts) do
        if c.id == id then return c end
    end
    return nil
end

local function distance(c)
    return Civ.dist2(cfg().depot.coords, c.to)
end

local function rate(level)
    return cfg().perHundredMetres * cfg().perHundredGrowth ^ (level - 1)
end

local function payFor(c, level, illegal)
    local amount = c.base + distance(c) / 100 * rate(level)
    if illegal then amount = amount * cfg().illegalMultiplier end
    return math.floor(amount)
end

function H.board(b)
    local options = {}
    for _, c in ipairs(cfg().contracts) do
        options[#options + 1] = {
            id = c.id, label = c.label, level = c.level, locked = b.level < c.level,
            detail = ('%s, %.1f km, about $%d'):format(c.cargo, distance(c) / 1000, payFor(c, b.level, false)),
        }
    end
    return { options = options }
end

function H.start(ctx, opts)
    local c = contractOf(opts.option) or cfg().contracts[1]
    if ctx.level < c.level then return nil, 'level' end
    local spec = cfg().vehicle
    local cab = ctx.spawn(spec.cab, spec.coords)
    if not cab then return nil, 'no_vehicle' end
    local rad = math.rad(spec.coords.w)
    local back = vec4(spec.coords.x + math.sin(rad) * 11.0, spec.coords.y - math.cos(rad) * 11.0, spec.coords.z, spec.coords.w)
    local tr = ctx.spawn(c.trailer, back, { type = 'trailer', trailer = true })
    if not tr then return nil, 'no_vehicle' end
    ctx.state.contract = c
    ctx.state.illegal = math.random(100) <= cfg().illegalChance
    ctx.state.phase = 'deliver'
    ctx.state.payout = payFor(c, ctx.level, ctx.state.illegal)
    if ctx.state.illegal and math.random(100) <= cfg().policeAlertChance then
        Core.alert(ctx.src, 'Suspicious haulage', 'A heavy goods vehicle is carrying questionable cargo')
    end
    return true
end

function H.view(ctx)
    local s = ctx.state
    return {
        phase = s.phase,
        contract = s.contract.label,
        cargo = s.contract.cargo,
        illegal = s.illegal,
        payout = s.payout,
        to = Civ.vec(s.contract.to),
        depot = Civ.vec(cfg().depot.coords),
        km = Civ.round(distance(s.contract) / 1000, 1),
    }
end

H.act = {}

H.act.deliver = function(ctx)
    local s = ctx.state
    if s.phase ~= 'deliver' then return nil, 'refused' end
    local c = s.contract
    if not ctx.near(c.to, cfg().deliverRange) then return nil, 'too_far' end
    local tr = ctx.vehicle(2)
    if not tr or Civ.dist(GetEntityCoords(tr), c.to) > cfg().deliverRange + 15.0 then return nil, 'trailer_far' end
    local xp = math.floor(distance(c) / 100 * cfg().xpPerHundredMetres)
    ctx.pay(payFor(c, ctx.level, s.illegal), xp, 'Haulage: ' .. c.label)
    s.phase = 'return'
    DeleteEntity(tr)
    ctx.sess.vehicles[2].entity = nil
    ctx.notify('Delivered. Bring the cab back to the depot for your bonus')
    return { delivered = true }
end

H.act.finish = function(ctx)
    if ctx.state.phase ~= 'return' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, cfg().vehicle.returnRadius * 2) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    if ctx.state.phase == 'return' then
        return { complete = true, bonus = ctx.returned and cfg().returnBonus or 0 }
    end
    return {}
end

Civ.register('trucker', H)
