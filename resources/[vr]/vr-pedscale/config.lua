Config = {}

Config.MinHeight = 107
Config.MaxHeight = 213
Config.DefaultHeight = 175

Config.ModelHeights = {
    [`mp_m_freemode_01`] = 178,
    [`mp_f_freemode_01`] = 168,
}
Config.OtherModelHeight = 175

Config.SyncDistance = 120.0

Config.HipHeight = 1.0

function Config.ClampHeight(cm)
    cm = math.floor((tonumber(cm) or Config.DefaultHeight) + 0.5)
    return math.max(Config.MinHeight, math.min(Config.MaxHeight, cm))
end

function Config.FormatHeight(cm)
    cm = tonumber(cm)
    if not cm then return '' end
    local inches = math.floor(cm / 2.54 + 0.5)
    return ('%d\'%d" (%d cm)'):format(inches // 12, inches % 12, math.floor(cm + 0.5))
end
