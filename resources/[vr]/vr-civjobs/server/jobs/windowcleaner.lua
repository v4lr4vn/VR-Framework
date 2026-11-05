local H = {}
local cfg = function() return Config.Jobs.windowcleaner end

local function build(site)
    local rad = math.rad(site.heading)
    local rx, ry = math.cos(rad), math.sin(rad)
    local list = {}
    for r = 1, site.rows do
        for c = 1, site.cols do
            local off = (c - (site.cols + 1) / 2) * site.spacing
            list[#list + 1] = {
                x = site.center.x + rx * off,
                y = site.center.y + ry * off,
                z = site.center.z + (r - 1) * site.stepZ,
                done = false,
            }
        end
    end
    return list
end

function H.board()
    return { options = (function()
        local out = {}
        for i, s in ipairs(cfg().sites) do out[#out + 1] = { id = tostring(i), label = s.label, detail = ('%d windows'):format(s.rows * s.cols), level = 1 } end
        return out
    end)() }
end

function H.start(ctx, opts)
    local c = cfg()
    local idx = tonumber(opts.option)
    local site = (idx and c.sites[idx]) or Civ.pick(c.sites)
    ctx.state.site = site
    ctx.state.windows = build(site)
    ctx.state.cleaned = 0
    ctx.state.phase = 'clean'
    local rec = ctx.spawn(c.vehicle.model, c.vehicle.coords)
    if not rec then return nil, 'no_vehicle' end
    return true
end

function H.view(ctx)
    local s = ctx.state
    local windows = {}
    for i, w in ipairs(s.windows) do windows[i] = { x = w.x, y = w.y, z = w.z, done = w.done } end
    return {
        phase = s.phase,
        label = s.site.label,
        heading = s.site.heading,
        windows = windows,
        cleaned = s.cleaned,
        total = #s.windows,
        depot = Civ.vec(cfg().depot.coords),
    }
end

H.act = {}

H.act.begin = function(ctx)
    if ctx.limit('begin', 300) then return nil, 'slow_down' end
    ctx.begin('clean')
    return { quiet = true }
end

H.act.clean = function(ctx, d)
    local s = ctx.state
    if s.phase ~= 'clean' then return nil, 'refused' end
    local i = math.floor(Core.num(d.i, 1, #s.windows) or 0)
    local w = s.windows[i]
    if not w or w.done then return nil, 'gone' end
    if not ctx.near(vec3(w.x, w.y, w.z), cfg().cleanRange) then return nil, 'too_far' end
    local t = ctx.since('clean')
    ctx.clear('clean')
    if not t or t < cfg().cleanSeconds * 800 then return nil, 'too_fast' end
    w.done = true
    s.cleaned = s.cleaned + 1
    ctx.earn(cfg().pricePerWindow, cfg().xpPerWindow)
    if s.cleaned >= #s.windows then
        s.phase = 'return'
        ctx.notify('All windows done. Take the van back to the depot')
    end
    return { cleaned = s.cleaned }
end

H.act.finish = function(ctx)
    if ctx.state.phase ~= 'return' then return nil, 'not_done' end
    if not ctx.near(cfg().depot.coords, cfg().stopRadius * 2) then return nil, 'too_far' end
    return { finish = true }
end

function H.finish(ctx)
    if ctx.state.phase == 'return' then
        return { complete = true, bonus = cfg().completionBonus, xp = cfg().xpCompletion }
    end
    return {}
end

Civ.register('windowcleaner', H)
