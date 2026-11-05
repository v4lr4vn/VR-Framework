local H = {}
local cfg = function() return Config.Jobs.hunter end

local function contractOf(id)
    for _, c in ipairs(cfg().contracts) do
        if c.id == id then return c end
    end
    return nil
end

local function met(state)
    for kind, need in pairs(state.contract.needs) do
        if (state.skinned[kind] or 0) < need then return false end
    end
    return true
end

local function inZone(c)
    for _, z in ipairs(cfg().zones) do
        if Civ.dist2(c, z.center) <= z.radius + 30.0 then return true end
    end
    return false
end

function H.board(b)
    local options = {}
    for _, c in ipairs(cfg().contracts) do
        local parts = {}
        for kind, n in pairs(c.needs) do parts[#parts + 1] = ('%d %s'):format(n, cfg().animals[kind].label) end
        table.sort(parts)
        options[#options + 1] = { id = c.id, label = c.label, level = c.level, locked = b.level < c.level, detail = ('%s, $%d'):format(table.concat(parts, ', '), c.pay) }
    end
    return { options = options, extra = { carried = Core.carried(b.info, cfg().prices) } }
end

function H.start(ctx, opts)
    local c = contractOf(opts.option) or cfg().contracts[1]
    if ctx.level < c.level then return nil, 'level' end
    ctx.state.contract = c
    ctx.state.skinned = {}
    ctx.state.total = 0
    local w = cfg().weapon
    ctx.state.gaveWeapon = false
    if w.item and Bridge.inventory.itemExists and Bridge.inventory.itemExists(w.item) and Core.count(ctx.src, w.item) == 0 then
        ctx.state.gaveWeapon = Core.give(ctx.src, w.item, 1) == true
    end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local needs = {}
    for kind, n in pairs(s.contract.needs) do
        needs[#needs + 1] = { kind = kind, label = cfg().animals[kind].label, need = n, have = s.skinned[kind] or 0 }
    end
    table.sort(needs, function(a, b) return a.kind < b.kind end)
    local zones = {}
    for _, z in ipairs(cfg().zones) do zones[#zones + 1] = { label = z.label, x = z.center.x, y = z.center.y, z = z.center.z, r = z.radius } end
    return {
        contract = s.contract.label,
        needs = needs,
        ready = met(s),
        zones = zones,
        weapon = { name = cfg().weapon.name, ammo = cfg().weapon.ammo, item = s.gaveWeapon },
        depot = Civ.vec(cfg().depot.coords),
        pay = s.contract.pay,
    }
end

H.act = {}

H.act.skin = function(ctx, d)
    local s = ctx.state
    local animal = type(d.kind) == 'string' and cfg().animals[d.kind]
    local c = Core.vec(d)
    if not animal or not c then return nil, 'bad_request' end
    if not ctx.near(c, cfg().skinRange + 3.0) then return nil, 'too_far' end
    if not inZone(c) then return nil, 'out_of_zone' end
    if ctx.limit('skin', cfg().minSecondsBetweenSkins * 1000) then return nil, 'slow_down' end
    if s.total >= 40 then return nil, 'enough' end
    local bonus = ctx.level * cfg().levelBonusPerLevel / 100
    local got = {}
    if animal.meat then
        local n = math.floor(Core.between(animal.meatAmount) * (1 + bonus) + 0.5)
        if n > 0 and Core.give(ctx.src, animal.meat, n) then got[#got + 1] = { item = animal.meat, count = n } end
    end
    if animal.pelt and math.random(100) <= animal.peltChance + ctx.level * cfg().levelBonusPerLevel then
        if Core.give(ctx.src, animal.pelt, 1) then got[#got + 1] = { item = animal.pelt, count = 1 } end
    end
    if #got == 0 then return nil, 'full' end
    s.skinned[d.kind] = (s.skinned[d.kind] or 0) + 1
    s.total = s.total + 1
    ctx.member.tasks = ctx.member.tasks + 1
    ctx.xp(25)
    if met(s) then ctx.notify('Contract filled. Take it back to the lodge') end
    return { got = got }
end

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    return { quiet = true }
end

H.act.finish = function(ctx)
    if not met(ctx.state) then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, 40.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    local s = ctx.state
    local w = cfg().weapon
    if s.gaveWeapon and w.item then Core.take(ctx.src, w.item, 1) end
    if met(s) then
        return { complete = true, bonus = s.contract.pay, xp = s.contract.xp }
    end
    return {}
end

function H.sell(info, d)
    local only
    if type(d.items) == 'table' then
        only = {}
        for _, name in ipairs(d.items) do if type(name) == 'string' then only[name] = true end end
    end
    local total, lines = Core.sellAll(info, 'hunter', cfg().prices, only)
    if total <= 0 then return nil, 'nothing' end
    return { total = total, lines = lines }
end

Civ.register('hunter', H)
