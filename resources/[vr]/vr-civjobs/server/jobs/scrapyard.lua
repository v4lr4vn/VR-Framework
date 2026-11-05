local H = {}
local cfg = function() return Config.Jobs.scrapyard end

local function partOf(id)
    for _, p in ipairs(cfg().parts) do
        if p.id == id then return p end
    end
    return nil
end

local function share(kind)
    local c = cfg()
    local count = #c.parts
    local pr = c.progression
    if kind == 'part' then return c.reward * pr.parts / 100 / count end
    if kind == 'crush' then return c.reward * pr.crush / 100 end
    return c.reward * pr.deliver / 100
end

local function wreck(ctx)
    return ctx.vehicle(ctx.state.wreckIndex)
end

function H.start(ctx)
    local c = cfg()
    local bay = Civ.pick(c.bays)
    local model = Civ.pick(c.wrecks)
    local rec = ctx.spawn(model, bay, { wreck = true })
    if not rec then return nil, 'no_vehicle' end
    ctx.state.wreckIndex = #ctx.sess.vehicles
    ctx.state.phase = 'strip'
    ctx.state.removed = {}
    ctx.state.sorted = {}
    ctx.state.sortedCount = 0
    ctx.state.baleHolder = nil
    return true
end

function H.view(ctx)
    local s = ctx.state
    local removed, sorted = {}, {}
    for id in pairs(s.removed) do removed[#removed + 1] = id end
    for id in pairs(s.sorted) do sorted[#sorted + 1] = id end
    local rec = ctx.sess.vehicles[s.wreckIndex]
    return {
        phase = s.phase,
        wreck = rec and rec.netId or nil,
        removed = removed,
        sorted = sorted,
        parts = #cfg().parts,
        carry = ctx.member and ctx.member.carry or false,
        carryPart = ctx.member and ctx.member.carryPart or nil,
        holder = s.baleHolder,
        percent = (function()
            local pr = cfg().progression
            local n = #cfg().parts
            local p = s.sortedCount / n * pr.parts
            if s.phase == 'deliver' then p = p + pr.crush end
            if s.phase == 'done' then p = 100 end
            return math.floor(p)
        end)(),
        crusher = Civ.vec(cfg().crusher),
        buyer = Civ.vec(cfg().buyer),
        bins = (function()
            local out = {}
            for _, b in ipairs(cfg().bins) do out[#out + 1] = { kind = b.kind, label = b.label, x = b.coords.x, y = b.coords.y, z = b.coords.z } end
            return out
        end)(),
    }
end

function H.left(sess, src)
    local m = sess.members[src]
    if not m then return end
    if m.carryPart and sess.state.removed[m.carryPart] then sess.state.removed[m.carryPart] = nil end
    if sess.state.baleHolder == src then sess.state.baleHolder = nil end
    m.carry, m.carryPart = false, nil
end

H.act = {}

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    ctx.begin('work')
    return { quiet = true }
end

local function elapsedOk(ctx, seconds)
    local t = ctx.since('work')
    ctx.clear('work')
    return t ~= nil and t >= seconds * 800
end

H.act.remove = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'strip' or ctx.member.carry then return nil, 'refused' end
    local part = partOf(d.part)
    if not part or s.removed[part.id] then return nil, 'gone' end
    local w = wreck(ctx)
    if not w then return nil, 'no_vehicle' end
    local p = ctx.pos()
    if not p or Civ.dist(p, GetEntityCoords(w)) > cfg().partRange then return nil, 'too_far' end
    if not elapsedOk(ctx, part.seconds) then return nil, 'too_fast' end
    s.removed[part.id] = true
    ctx.member.carry, ctx.member.carryPart = true, part.id
    return { part = part.id }
end

H.act.sort = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'strip' or not ctx.member.carry then return nil, 'refused' end
    local part = partOf(ctx.member.carryPart)
    if not part then return nil, 'refused' end
    local bin
    for _, b in ipairs(cfg().bins) do
        if b.kind == d.kind then bin = b end
    end
    if not bin then return nil, 'bad_request' end
    if not ctx.near(bin.coords, cfg().binRange) then return nil, 'too_far' end
    if bin.kind ~= part.kind then return nil, 'wrong_bin' end
    if ctx.limit('sort', 500) then return nil, 'slow_down' end
    ctx.member.carry, ctx.member.carryPart = false, nil
    s.sorted[part.id] = true
    s.sortedCount = s.sortedCount + 1
    ctx.earn(share('part'), math.floor(cfg().xp * cfg().progression.parts / 100 / #cfg().parts))
    if s.sortedCount >= #cfg().parts then
        s.phase = 'crush'
        ctx.notify('Frame stripped. Crush what is left of it')
    end
    return { sorted = s.sortedCount }
end

H.act.crush = function(ctx)
    local s = ctx.state
    if s.phase ~= 'crush' then return nil, 'refused' end
    local w = wreck(ctx)
    if not w then return nil, 'no_vehicle' end
    local p = ctx.pos()
    if not p or Civ.dist(p, GetEntityCoords(w)) > cfg().partRange + 2.0 then return nil, 'too_far' end
    if not elapsedOk(ctx, cfg().crushSeconds) then return nil, 'too_fast' end
    s.phase = 'deliver'
    ctx.earn(share('crush'), math.floor(cfg().xp * cfg().progression.crush / 100))
    return { phase = s.phase }
end

H.act.bale = function(ctx)
    local s = ctx.state
    if s.phase ~= 'deliver' or s.baleHolder or ctx.member.carry then return nil, 'refused' end
    local w = wreck(ctx)
    local from = w and GetEntityCoords(w) or cfg().crusher
    if not ctx.near(from, 10.0) then return nil, 'too_far' end
    s.baleHolder = ctx.src
    ctx.member.carry, ctx.member.carryPart = true, 'bale'
    return { holder = ctx.src }
end

H.act.deliver = function(ctx)
    local s = ctx.state
    if s.phase ~= 'deliver' or s.baleHolder ~= ctx.src then return nil, 'refused' end
    if not ctx.near(cfg().buyer, cfg().buyerRange) then return nil, 'too_far' end
    s.baleHolder = nil
    ctx.member.carry, ctx.member.carryPart = false, nil
    s.phase = 'done'
    ctx.earn(share('deliver'), math.floor(cfg().xp * cfg().progression.deliver / 100))
    return { finish = true }
end

function H.finish(ctx)
    if ctx.state.phase == 'done' then
        return { complete = true }
    end
    return { penalty = cfg().penaltyIncomplete }
end

Civ.register('scrapyard', H)
