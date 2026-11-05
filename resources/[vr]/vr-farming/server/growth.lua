-- The growth model. A plant is only worked out when somebody looks at it and on a slow tick,
-- so nothing here runs every frame and there is one small table per plant.
Growth = {}

local function rules() return Config.Rules end

function Growth.scale() return rules().growthScale or 1.0 end

function Growth.growSeconds(crop) return crop.growMinutes * 60.0 * Growth.scale() end

-- Water lost per second (a watering is 100).
function Growth.drain(crop) return 100.0 / (crop.waterMinutes * 60.0 * Growth.scale()) end

-- Moves a plant forward to `now`. Returns true when anything moved.
-- `irrigated` is true when the plant stands in a field with its own irrigation: it is always watered.
function Growth.advance(p, crop, now, irrigated)
    local dt = now - p.last
    if dt <= 0 then return false end
    local from = p.last
    p.last = now
    if p.readyAt or p.deadAt then return true end

    local total = Growth.growSeconds(crop)
    local drain = Growth.drain(crop)
    local rate = p.fert and rules().fertiliserGrowth or 1.0

    local wet = 0.0
    if irrigated then
        wet = dt
        p.water = 100.0
    else
        if p.water > 0 then wet = math.min(dt, p.water / drain) end
        p.water = math.max(0.0, p.water - drain * dt)
    end

    local gain = wet * rate
    if p.progress + gain >= total then
        local need = (total - p.progress) / rate
        p.progress = total
        p.readyAt = math.floor(from + need + 0.5)
    else
        p.progress = p.progress + gain
        p.dry = p.dry + (dt - wet)
    end
    return true
end

-- 100 for a plant that was looked after, down to 0 for one that dried out.
function Growth.health(p)
    local r = rules()
    local scale = Growth.scale()
    local over = p.dry - r.graceMinutes * 60.0 * scale
    if over <= 0 then return 100.0 end
    return math.max(0.0, 100.0 - over / (r.dieMinutes * 60.0 * scale) * 100.0)
end

function Growth.stages() return 4 end

-- 1 seedling, 2 growing, 3 nearly there, 4 ready to harvest.
function Growth.stage(p, crop)
    if p.readyAt then return 4 end
    local total = Growth.growSeconds(crop)
    local share = math.max(0.0, math.min(0.9999, p.progress / total))
    return 1 + math.floor(share * 3)
end

function Growth.tier(health)
    local q = Config.QualityHealth
    if health >= q.great then return 3 end
    if health >= q.good then return 2 end
    return 1
end

function Growth.roll(range)
    local a, b = range[1], range[2] or range[1]
    return math.random(math.floor(a), math.floor(b))
end

-- How many you get and at what quality.
function Growth.harvest(p, crop)
    local tier = Growth.tier(Growth.health(p))
    local mult = Config.Quality[tier].yield * (p.fert and rules().fertiliserYield or 1.0)
    local count = math.max(1, math.floor(Growth.roll(crop.yield) * mult + 0.5))
    return count, tier
end

-- Seconds until ripe if kept watered (0 when ripe).
function Growth.remaining(p, crop)
    if p.readyAt then return 0 end
    local rate = p.fert and rules().fertiliserGrowth or 1.0
    return math.max(0.0, (Growth.growSeconds(crop) - p.progress) / rate)
end
