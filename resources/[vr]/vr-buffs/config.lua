Config = {}

-- Name of the hud resource that draws the icons. Without it everything still works, just without icons.
Config.Hud = 'vr-hud'

-- How often (ms) health, armour and stress effects are applied.
Config.EffectTick = 5000

-- How often (ms) the hud progress rings are refreshed.
Config.HudTick = 6000

-- Upper limits for effect strength. Anything above is cut down, anything below the minimum is raised.
Config.Limits = {
    health  = { min = 0,   max = 25 },    -- hit points per tick
    armor   = { min = 0,   max = 25 },    -- armour per tick
    stress  = { min = 0,   max = 25 },    -- stress removed per tick
    stamina = { min = 1.0, max = 1.49 },  -- run speed multiplier
    swimming = { min = 1.0, max = 1.49 }, -- swim speed multiplier
}

local HOUR = 60 * 60 * 1000

-- kind 'icon': a round icon with a progress ring.
-- kind 'status': colours an existing hud status (health, armor, ...) instead.
-- effect: what the buff does while it runs (see Config.Limits); no effect means it is only a marker other scripts can check.
Config.Buffs = {
    hacking      = { kind = 'icon', icon = 'database',  color = '#ffffff', ring = '#FFD700', maxTime = HOUR },
    intelligence = { kind = 'icon', icon = 'lightbulb', color = '#ffffff', ring = '#FFD700', maxTime = HOUR },
    luck         = { kind = 'icon', icon = 'dollarsign', color = '#ffffff', ring = '#FFD700', maxTime = HOUR },
    strength     = { kind = 'icon', icon = 'dumbbell',  color = '#ffffff', ring = '#FFD700', maxTime = HOUR },
    stamina      = { kind = 'icon', icon = 'wind',      color = '#ffffff', ring = '#FFD700', maxTime = HOUR, effect = 'stamina' },
    swimming     = { kind = 'icon', icon = 'swimmer',   color = '#ffffff', ring = '#FFD700', maxTime = HOUR, effect = 'swimming' },

    ['super-hunger'] = { kind = 'status', color = '#FDE829', maxTime = HOUR },
    ['super-thirst'] = { kind = 'status', color = '#FDE829', maxTime = HOUR },
    ['super-health'] = { kind = 'status', color = '#FDE829', maxTime = HOUR, effect = 'health' },
    ['super-armor']  = { kind = 'status', color = '#FDE829', maxTime = HOUR, effect = 'armor' },
    ['super-stress'] = { kind = 'status', color = '#FDE829', maxTime = HOUR, effect = 'stress' },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-buffs'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
