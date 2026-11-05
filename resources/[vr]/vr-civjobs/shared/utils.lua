Civ = Civ or {}

function Civ.xpFor(level)
    return math.floor(Config.Levels.base * Config.Levels.growth ^ (level - 1))
end

function Civ.levelOf(xp)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    local level, left = 1, xp
    while level < Config.Levels.max do
        local need = Civ.xpFor(level)
        if left < need then break end
        left = left - need
        level = level + 1
    end
    return level, left, Civ.xpFor(level)
end

function Civ.mult(level)
    return 1 + (math.max(1, level or 1) - 1) * Config.Levels.payPerLevel
end

function Civ.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Civ.dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Civ.round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

function Civ.pick(list)
    return list[math.random(#list)]
end

function Civ.shuffle(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

function Civ.vec(v)
    if not v then return nil end
    return { x = v.x + 0.0, y = v.y + 0.0, z = (v.z or 0.0) + 0.0, w = v.w and v.w + 0.0 or nil }
end
