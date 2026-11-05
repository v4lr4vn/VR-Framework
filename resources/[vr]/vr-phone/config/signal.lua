Config = Config or {}
Config.Phone = Config.Phone or {}

-- Signal zones. Inside a zone the phone has the zone's level instead of Config.Phone.Signal.defaultLevel.
--   level 'none' = no service (calls and messages cannot go out, notifications wait)
--   level 'low'  = weak signal (one bar). Calls can drop (once the Phone app exists).
-- Zones can overlap. The worst level wins. These are examples, so change them to suit your map.
Config.Phone.Signal.zones = {
    { name = 'Fort Zancudo',     coords = vector3(-2047.4, 3132.1, 32.8), radius = 700.0,  level = 'none' },
    { name = 'Mount Chiliad',    coords = vector3(501.0, 5604.0, 797.9),  radius = 250.0,  level = 'low' },
    { name = 'Cayo Perico',      coords = vector3(4840.5, -5174.4, 2.0),  radius = 1800.0, level = 'low' },
}
