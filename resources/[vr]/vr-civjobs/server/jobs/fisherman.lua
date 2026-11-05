local H = {}
local cfg = function() return Config.Jobs.fisherman end

local function contractOf(id)
    for _, c in ipairs(cfg().contracts) do
        if c.id == id then return c end
    end
    return nil
end

local function met(state)
    if not state.contract then return false end
    for kind, need in pairs(state.contract.needs) do
        if (state.caught[kind] or 0) < need then return false end
    end
    return true
end

local function spotAt(p)
    for _, s in ipairs(cfg().spots) do
        if Civ.dist2(p, s.center) <= s.radius then return s end
    end
    return nil
end

function H.board(b)
    local options = { { id = 'free', label = 'Free fishing', detail = 'No contract, just sell what you catch', level = 1 } }
    for _, c in ipairs(cfg().contracts) do
        local parts = {}
        for kind, n in pairs(c.needs) do parts[#parts + 1] = ('%d %s'):format(n, cfg().fish[kind].label) end
        table.sort(parts)
        options[#options + 1] = { id = c.id, label = c.label, level = c.level, locked = b.level < c.level, detail = ('%s, $%d'):format(table.concat(parts, ', '), c.pay) }
    end
    local prices = {}
    for _, f in pairs(cfg().fish) do prices[f.item] = f.price end
    return { options = options, extra = { carried = Core.carried(b.info, prices), bait = cfg().bait, baitCount = Core.count(b.info.src, cfg().bait.item) } }
end

function H.start(ctx, opts)
    local c = contractOf(opts.option)
    if c and ctx.level < c.level then return nil, 'level' end
    ctx.state.contract = c
    ctx.state.caught = {}
    ctx.state.cast = nil
    ctx.state.total = 0
    return true
end

function H.view(ctx)
    local s = ctx.state
    local needs
    if s.contract then
        needs = {}
        for kind, n in pairs(s.contract.needs) do
            needs[#needs + 1] = { kind = kind, label = cfg().fish[kind].label, need = n, have = s.caught[kind] or 0 }
        end
        table.sort(needs, function(a, b) return a.kind < b.kind end)
    end
    local spots = {}
    for _, p in ipairs(cfg().spots) do spots[#spots + 1] = { label = p.label, water = p.water, x = p.center.x, y = p.center.y, z = p.center.z, r = p.radius } end
    return {
        contract = s.contract and s.contract.label or nil,
        needs = needs,
        ready = met(s),
        total = s.total,
        spots = spots,
        casting = s.cast ~= nil,
        baitCount = Core.count(ctx.src, cfg().bait.item),
        depot = Civ.vec(cfg().depot.coords),
        pay = s.contract and s.contract.pay or nil,
    }
end

H.act = {}

H.act.cast = function(ctx)
    local s = ctx.state
    if s.cast then return nil, 'refused' end
    local p = ctx.pos()
    local spot = p and spotAt(p)
    if not spot then return nil, 'no_water' end
    if ctx.limit('cast', cfg().castCooldownSeconds * 1000) then return nil, 'slow_down' end
    local baited = false
    if Core.count(ctx.src, cfg().bait.item) >= cfg().bait.perCast and Core.take(ctx.src, cfg().bait.item, cfg().bait.perCast) then baited = true end
    local wait = Core.between(cfg().biteSeconds) - ctx.level * cfg().biteReductionPerLevel
    wait = math.max(2, wait)
    s.cast = { spot = spot, baited = baited, at = GetGameTimer(), wait = wait * 1000 }
    return { wait = wait, baited = baited, quiet = true }
end

H.act.reel = function(ctx, d)
    local s = ctx.state
    local cast = s.cast
    if not cast then return nil, 'refused' end
    s.cast = nil
    if GetGameTimer() - cast.at < cast.wait * 0.8 then return nil, 'too_fast' end
    if d.success ~= true then return { lost = true } end
    local list = {}
    for key, f in pairs(cfg().fish) do
        for _, w in ipairs(f.water) do
            if w == cast.spot.water then list[#list + 1] = { key = key, weight = f.weight, f = f } break end
        end
    end
    if #list == 0 then return { lost = true } end
    local pick = Core.weighted(list)
    local amount = 1
    local c = cfg()
    local crit = math.random(100) <= c.baseCrit + ctx.level * c.critChancePerLevel + (cast.baited and c.bait.bonus / 5 or 0)
    if crit then amount = amount * 2 end
    if math.random(100) <= c.baseExtraCatch + ctx.level * c.extraCatchPerLevel + (cast.baited and c.bait.bonus / 2 or 0) then amount = amount + 1 end
    if not Core.give(ctx.src, pick.f.item, amount) then return nil, 'full' end
    s.caught[pick.key] = (s.caught[pick.key] or 0) + amount
    s.total = s.total + amount
    ctx.member.tasks = ctx.member.tasks + 1
    ctx.xp(c.xpPerCatch * amount)
    if met(s) then ctx.notify('Contract filled. Take your catch to the market') end
    return { fish = pick.key, label = pick.f.label, amount = amount, crit = crit }
end

H.act.stopcast = function(ctx)
    ctx.state.cast = nil
    return { quiet = true }
end

H.act.finish = function(ctx)
    if not met(ctx.state) then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, 40.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    local s = ctx.state
    if s.contract and met(s) then
        return { complete = true, bonus = s.contract.pay, xp = s.contract.xp }
    end
    return {}
end

function H.sell(info, d)
    local prices = {}
    for _, f in pairs(cfg().fish) do prices[f.item] = f.price end
    local only
    if type(d.items) == 'table' then
        only = {}
        for _, name in ipairs(d.items) do if type(name) == 'string' then only[name] = true end end
    end
    local total, lines = Core.sellAll(info, 'fisherman', prices, only)
    if total <= 0 then return nil, 'nothing' end
    return { total = total, lines = lines }
end

function H.shop(info, d)
    local n = math.floor(Core.num(d.count, 1, 50) or 0)
    if n < 1 then return nil, 'bad_request' end
    local cost = n * cfg().bait.price
    if not Bridge.pay(info.src, cost, 'Fishing bait') then return nil, 'no_money' end
    if not Core.give(info.src, cfg().bait.item, n) then
        Bridge.addMoney(info.src, Config.Account, cost, 'Fishing bait refund')
        return nil, 'full'
    end
    return { count = n, cost = cost }
end

Civ.register('fisherman', H)
