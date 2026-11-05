local H = {}
local cfg = function() return Config.Jobs.lumberjack end

local felled = {}
local modelSet

local function models()
    if not modelSet then
        modelSet = {}
        for _, name in ipairs(cfg().treeModels) do modelSet[joaat(name)] = true end
    end
    return modelSet
end

local function key(x, y)
    return ('%d:%d'):format(math.floor(x), math.floor(y))
end

local function inForest(c)
    if #cfg().forests == 0 then return true end
    for _, f in ipairs(cfg().forests) do
        if Civ.dist2(c, f.center) <= f.radius then return true end
    end
    return false
end

local function activeFelled()
    local now = os.time()
    local out = {}
    for k, v in pairs(felled) do
        if v.expires <= now then felled[k] = nil else out[#out + 1] = { key = v.key, x = v.x, y = v.y, z = v.z, model = v.model, seconds = v.expires - now } end
    end
    return out
end

function H.board()
    return { extra = { forests = #cfg().forests } }
end

function H.start(ctx)
    ctx.state.ground = {}
    ctx.state.loaded = 0
    ctx.state.delivered = 0
    ctx.state.trees = 0
    local rec = ctx.spawn(cfg().vehicle.model, cfg().vehicle.coords)
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local ground = {}
    for k, v in pairs(s.ground) do
        if v.left > 0 then ground[#ground + 1] = { key = k, x = v.x, y = v.y, z = v.z, left = v.left } end
    end
    return {
        loaded = s.loaded,
        capacity = cfg().vehicle.capacity,
        delivered = s.delivered,
        trees = s.trees,
        carry = ctx.member and ctx.member.carry or false,
        ground = ground,
        felled = activeFelled(),
        sawmill = Civ.vec(cfg().sawmill),
        forests = (function()
            local out = {}
            for _, f in ipairs(cfg().forests) do out[#out + 1] = { x = f.center.x, y = f.center.y, z = f.center.z, r = f.radius } end
            return out
        end)(),
    }
end

function H.left(sess, src)
    local m = sess.members[src]
    if m and m.carry then
        local k = m.carryKey
        if k and sess.state.ground[k] then sess.state.ground[k].left = sess.state.ground[k].left + 1 end
        m.carry = false
    end
end

H.act = {}

H.act.chop = function(ctx, d)
    local c = Core.vec(d)
    if not c then return nil, 'bad_request' end
    if not ctx.near(c, cfg().chopRange + 2.0) then return nil, 'too_far' end
    if not inForest(c) then return nil, 'out_of_zone' end
    local model = math.floor(tonumber(d.model) or 0)
    if not models()[model] then return nil, 'bad_request' end
    local k = key(c.x, c.y)
    local now = os.time()
    if felled[k] and felled[k].expires > now then return nil, 'felled' end
    local began = ctx.since('chop')
    if not began or began < cfg().chopSeconds * 800 then return nil, 'too_fast' end
    ctx.clear('chop')
    local n = Core.between(cfg().logsPerTree)
    felled[k] = { key = k, x = c.x, y = c.y, z = c.z, model = model, expires = now + cfg().treeRespawnSeconds }
    ctx.state.ground[k] = { x = c.x, y = c.y, z = c.z, left = n }
    ctx.state.trees = ctx.state.trees + 1
    ctx.xp(cfg().xpPerTree)
    ctx.member.tasks = ctx.member.tasks + 1
    TriggerClientEvent('vr-civjobs:client:felled', -1, { key = k, x = c.x, y = c.y, z = c.z, model = model, seconds = cfg().treeRespawnSeconds })
    return { key = k, logs = n }
end

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    ctx.begin('chop')
    return { quiet = true }
end

H.act.pickup = function(ctx, d)
    if ctx.member.carry then return nil, 'refused' end
    local g = type(d.key) == 'string' and ctx.state.ground[d.key]
    if not g or g.left <= 0 then return nil, 'gone' end
    if not ctx.near(vec3(g.x, g.y, g.z), 12.0) then return nil, 'too_far' end
    if ctx.limit('pickup', 500) then return nil, 'slow_down' end
    g.left = g.left - 1
    ctx.member.carry = true
    ctx.member.carryKey = d.key
    return { key = d.key }
end

H.act.load = function(ctx)
    local s = ctx.state
    if not ctx.member.carry then return nil, 'refused' end
    if s.loaded >= cfg().vehicle.capacity then return nil, 'full' end
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    local p = ctx.pos()
    if not p or Civ.dist(p, GetEntityCoords(veh)) > cfg().loadRange then return nil, 'too_far' end
    if ctx.limit('load', 500) then return nil, 'slow_down' end
    ctx.member.carry = false
    s.loaded = s.loaded + 1
    return { loaded = s.loaded }
end

H.act.unload = function(ctx)
    local s = ctx.state
    if s.loaded <= 0 then return nil, 'empty' end
    local veh = ctx.vehicle()
    if not veh then return nil, 'no_vehicle' end
    if not ctx.near(cfg().sawmill, cfg().sawmillRadius) then return nil, 'too_far' end
    if Civ.dist(GetEntityCoords(veh), cfg().sawmill) > cfg().sawmillRadius + 12.0 then return nil, 'truck_far' end
    local n = s.loaded
    s.loaded = 0
    s.delivered = s.delivered + n
    ctx.earn(n * cfg().pricePerLog, n * cfg().xpPerLog)
    return { delivered = n }
end

H.act.finish = function(ctx)
    if ctx.state.delivered <= 0 then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, 60.0) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx, reason)
    if ctx.state.delivered > 0 and reason == 'done' then
        return { complete = true }
    end
    return {}
end

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(8000)
        TriggerClientEvent('vr-civjobs:client:felledSync', src, activeFelled())
    end)
end)

RegisterNetEvent('vr-civjobs:server:requestFelled', function()
    local src = source
    if Core.throttle(src, 'felled', 5000) then return end
    TriggerClientEvent('vr-civjobs:client:felledSync', src, activeFelled())
end)

Civ.register('lumberjack', H)
