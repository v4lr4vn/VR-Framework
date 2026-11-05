local cfg = Config.Jobs.builder
local H = {}

local function pick(i)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    local ok, err = Cj.act('pick', { i = i })
    if not ok then return Cj.fail(err) end
    Cj.carry(cfg.carryModel, 'box', 'block')
end

local function place(i)
    local ok, err = Cj.act('place', { i = i })
    if not ok then return Cj.fail(err) end
    Cj.drop()
end

local function work(i, t)
    local w = cfg.work[t.type]
    local c = t.at
    Cj.timed({ label = w.label, seconds = w.seconds, scenario = w.scenario, face = vec3(c.x, c.y, c.z) }, 'work', { i = i })
end

local function spots()
    local s = Cj.session
    if not s or s.job ~= 'builder' or s.data.phase ~= 'build' then return {} end
    local out = {}
    for i, t in ipairs(s.data.tasks) do
        if not t.done then
            if t.type == 'carry' then
                if not s.data.carry and not t.holder then
                    out[#out + 1] = { coords = vec3(t.from.x, t.from.y, t.from.z), range = cfg.carryRange - 0.5, text = '[E] Pick up ' .. t.label:lower(), onUse = function() pick(i) end }
                elseif s.data.carry and s.data.carryTask == i then
                    out[#out + 1] = { coords = vec3(t.to.x, t.to.y, t.to.z), range = cfg.carryRange - 0.5, text = '[E] Set it down', color = { 90, 200, 120 }, onUse = function() place(i) end }
                end
            else
                out[#out + 1] = { coords = vec3(t.at.x, t.at.y, t.at.z), range = cfg.workRange - 0.5, text = '[E] ' .. t.label, color = { 255, 140, 60 }, onUse = function() work(i, t) end }
            end
        end
    end
    return out
end

local function hud(view)
    local d = view.data
    Cj.hudSet(d.site, {
        { label = 'Build', value = ('%d%%'):format(d.percent) },
        { label = 'Jobs done', value = ('%d / %d'):format(d.done, d.total) },
        { label = 'Next', value = d.phase == 'build' and 'Follow the markers' or 'Report to the foreman', state = d.phase == 'build' and nil or 'go' },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }, d.percent)
end

function H.start(view)
    Cj.blip('site', view.data.depot, { sprite = 566, colour = 47, label = 'Building site' })
    Cj.setSpots('builder', spots)
    H.sync(view)
end

function H.sync(view)
    hud(view)
    if not view.data.carry and Cj.isCarrying('block') then Cj.drop() end
    if view.data.phase == 'complete' then
        Cj.finishZone('finish', view.data.depot, 'Report to the foreman', 14.0)
    end
end

function H.stop()
    Cj.clearSpots('builder')
end

Cj.register('builder', H)
