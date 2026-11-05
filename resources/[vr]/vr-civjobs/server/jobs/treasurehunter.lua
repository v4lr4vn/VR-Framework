local H = {}
local cfg = function() return Config.Jobs.treasurehunter end

local function luckWeights(list, level)
    local top = 0
    for _, e in ipairs(list) do top = math.max(top, e.weight) end
    local luck = level * cfg().levelLuckPerLevel / 100
    local out = {}
    for i, e in ipairs(list) do
        out[i] = { entry = e, weight = e.weight * (1 + luck * (1 - e.weight / top) * 4) }
    end
    return out
end

local function roll(list, level)
    local weighted = luckWeights(list, level)
    local pick = Core.weighted(weighted)
    return pick.entry
end

local function randomIn(center, radius)
    local a = math.random() * math.pi * 2
    local r = math.sqrt(math.random()) * radius * 0.9
    return center.x + math.cos(a) * r, center.y + math.sin(a) * r
end

local function genSpots(state)
    state.spots = {}
    local id = 0
    for _, z in ipairs(cfg().detector.zones) do
        for _ = 1, cfg().detector.spotsPerZone do
            id = id + 1
            local x, y = randomIn(z.center, z.radius)
            state.spots[id] = { id = id, x = x, y = y, z = z.center.z, dug = false }
        end
    end
end

local function genChests(state)
    state.chests = {}
    local id = 0
    for _, site in ipairs(cfg().dive.sites) do
        for _ = 1, 2 do
            id = id + 1
            local x, y = randomIn(site.coords, site.radius)
            state.chests[id] = { id = id, x = x, y = y, z = site.coords.z, opened = false }
        end
    end
end

function H.board()
    return { options = {
        { id = 'detector', label = 'Metal detector', detail = 'Sweep the beaches and dig up what you find', level = 1 },
        { id = 'dive', label = 'Dive the wrecks', detail = 'A boat and a tank. Chests are worth much more', level = 1 },
    } }
end

function H.start(ctx, opts)
    local mode = opts.option == 'dive' and 'dive' or 'detector'
    ctx.state.mode = mode
    ctx.state.finds = 0
    ctx.state.value = 0
    if mode == 'detector' then
        genSpots(ctx.state)
    else
        genChests(ctx.state)
        local b = cfg().boat
        local rec = ctx.spawn(b.model, b.coords, { type = 'boat' })
        if not rec then return nil, 'no_vehicle' end
    end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local out = { mode = s.mode, finds = s.finds, depot = Civ.vec(cfg().depot.coords), tank = cfg().dive.tankSeconds }
    if s.mode == 'detector' then
        local spots = {}
        for _, p in pairs(s.spots) do spots[#spots + 1] = { id = p.id, x = p.x, y = p.y, z = p.z, dug = p.dug } end
        table.sort(spots, function(a, b) return a.id < b.id end)
        out.spots = spots
        out.ping = cfg().detector.pingRange
    else
        local chests = {}
        for _, c in pairs(s.chests) do chests[#chests + 1] = { id = c.id, x = c.x, y = c.y, z = c.z, opened = c.opened } end
        table.sort(chests, function(a, b) return a.id < b.id end)
        out.chests = chests
        local sites = {}
        for _, site in ipairs(cfg().dive.sites) do sites[#sites + 1] = { label = site.label, x = site.coords.x, y = site.coords.y, z = site.coords.z, r = site.radius } end
        out.sites = sites
    end
    return out
end

H.act = {}

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    ctx.begin('dig')
    return { quiet = true }
end

local function award(ctx, list, rolls)
    local got = {}
    for _ = 1, rolls do
        local e = roll(list, ctx.level)
        local n = Core.between(e.amount)
        if Core.give(ctx.src, e.item, n) then
            got[#got + 1] = { item = e.item, label = e.label, count = n }
            ctx.state.value = ctx.state.value + (cfg().prices[e.item] or 0) * n
        end
    end
    return got
end

H.act.dig = function(ctx, d)
    local s = ctx.state
    if s.mode ~= 'detector' then return nil, 'refused' end
    local spot = s.spots[math.floor(Core.num(d.id, 1) or 0)]
    if not spot or spot.dug then return nil, 'gone' end
    local p = ctx.pos()
    if not p or Civ.dist2(p, spot) > cfg().detector.digRange * 1.8 then return nil, 'too_far' end
    local t = ctx.since('dig')
    ctx.clear('dig')
    if not t or t < cfg().detector.digSeconds * 800 then return nil, 'too_fast' end
    if ctx.limit('find', cfg().minSecondsBetweenFinds * 1000) then return nil, 'slow_down' end
    local got = award(ctx, cfg().lootGround, 1)
    if #got == 0 then return nil, 'full' end
    spot.dug = true
    s.finds = s.finds + 1
    ctx.member.tasks = ctx.member.tasks + 1
    ctx.xp(cfg().xpPerFind)
    local left = 0
    for _, sp in pairs(s.spots) do if not sp.dug then left = left + 1 end end
    if left == 0 then
        genSpots(s)
        ctx.notify('The beach has shifted. New signals are out there')
    end
    return { got = got }
end

H.act.open = function(ctx, d)
    local s = ctx.state
    if s.mode ~= 'dive' then return nil, 'refused' end
    local chest = s.chests[math.floor(Core.num(d.id, 1) or 0)]
    if not chest or chest.opened then return nil, 'gone' end
    if not ctx.near(vec3(chest.x, chest.y, chest.z), 8.0) then return nil, 'too_far' end
    local t = ctx.since('dig')
    ctx.clear('dig')
    if not t or t < cfg().dive.openSeconds * 800 then return nil, 'too_fast' end
    local got = award(ctx, cfg().lootDive, math.random(2, 3))
    if #got == 0 then return nil, 'full' end
    chest.opened = true
    s.finds = s.finds + 1
    ctx.member.tasks = ctx.member.tasks + 1
    ctx.xp(cfg().xpPerChest)
    local left = 0
    for _, c in pairs(s.chests) do if not c.opened then left = left + 1 end end
    if left == 0 then
        genChests(s)
        ctx.notify('The tide has moved the wreckage. New chests have surfaced')
    end
    return { got = got }
end

H.act.finish = function(ctx)
    if not ctx.near(cfg().depot.coords, 80.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish()
    return { complete = true }
end

function H.sell(info, d)
    local only
    if type(d.items) == 'table' then
        only = {}
        for _, name in ipairs(d.items) do if type(name) == 'string' then only[name] = true end end
    end
    local total, lines = Core.sellAll(info, 'treasurehunter', cfg().prices, only)
    if total <= 0 then return nil, 'nothing' end
    return { total = total, lines = lines }
end

Civ.register('treasurehunter', H)
