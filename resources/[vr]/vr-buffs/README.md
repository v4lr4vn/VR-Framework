# vr-buffs

Timed buffs for the ValRavn framework. There are two kinds:

- **Icon buffs** (`hacking`, `intelligence`, `luck`, `strength`, `stamina`, `swimming`) show as a round icon with a progress ring on the hud.
- **Status buffs** (`super-health`, `super-armor`, `super-stress`, `super-hunger`, `super-thirst`) turn an existing hud status yellow.

`stamina`, `swimming`, `super-health`, `super-armor` and `super-stress` also do something while they run (run speed, swim speed, health, armour, stress relief). The rest are markers other scripts can check with `HasBuff`.

The server owns every buff. There is no event or callback a player can use to give themselves one. Icons are drawn by **vr-hud** through `hud:client:BuffEffect` and `hud:client:EnhancementEffect`; set `Config.Hud` if your hud has another name. Without a hud everything still works.

## Server exports

```lua
-- time in ms (nil = the buff's maxTime, never more than maxTime). Give the player's source, the citizenid, or both.
exports['vr-buffs']:AddBuff(source, citizenid, 'hacking', 15000)
exports['vr-buffs']:RemoveBuff(citizenid, 'hacking')     -- a server id works too
exports['vr-buffs']:HasBuff(citizenid, 'hacking')
exports['vr-buffs']:GetBuffTime(citizenid, 'hacking')    -- ms left, 0 if none

-- buffs with effects: player's source first, then time in ms and strength
exports['vr-buffs']:AddHealthBuff(source, 30000, 10)      -- +10 HP every Config.EffectTick
exports['vr-buffs']:AddArmorBuff(source, 30000, 10)       -- +10 armour every tick
exports['vr-buffs']:AddStressBuff(source, 30000, 10)      -- -10 stress every tick (done by the server)
exports['vr-buffs']:StaminaBuffEffect(source, 15000, 1.4) -- run speed multiplier
exports['vr-buffs']:SwimmingBuffEffect(source, 20000, 1.4)
```

Strengths are cut to the limits in `Config.Limits`. Adding a buff that is already running adds the time (up to its maximum).

## Client exports (read only)

`HasBuff(name)`, `GetBuff(name)` and `GetBuffNUIData()` report the buffs the server has given this player.

## Behaviour

- Buffs keep counting down while a player is offline and are shown again when the character loads.
- Add your own icon or status buffs in `config.lua`.

## Credits

Written by ValRavn. The export names follow the common buff API used by many hud resources so existing scripts keep working; no code from other resources is used.
