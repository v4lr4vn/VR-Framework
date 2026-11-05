-- Signal strength. Zones in config/signal.lua make some places weak or dead.
-- Airplane mode (a setting on the phone) turns signal off whatever the zone says.
local Signal = {}
Phone.Signal = Signal

local cfg = Config.Phone.Signal

-- 3 is best. The worst level wins when zones overlap.
local rank = { none = 1, low = 2, full = 3 }
local bars = { none = 0, low = 1, full = 4 }

local function valid(level)
    return rank[level] and level or nil
end

-- The signal level at a position. coords needs x, y and z.
function Signal.levelAt(coords)
    local level = valid(cfg.defaultLevel) or 'full'
    if cfg.enabled == false or not coords then return 'full' end

    for _, zone in ipairs(cfg.zones or {}) do
        local z = valid(zone.level)
        if z and rank[z] < rank[level] then
            local dx, dy, dz = coords.x - zone.coords.x, coords.y - zone.coords.y, coords.z - zone.coords.z
            if dx * dx + dy * dy + dz * dz <= zone.radius * zone.radius then level = z end
        end
    end
    return level
end

function Signal.bars(level, airplane)
    if airplane then return 0 end
    return bars[level] or 0
end

-- What the phone can do with this signal.
function Signal.hasService(level, airplane)
    return not airplane and level ~= 'none'
end

function Signal.carrier()
    return cfg.carrier or 'Raven Mobile'
end
