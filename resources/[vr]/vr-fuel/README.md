# vr-fuel

Fuel for every vehicle in the ValRavn framework: consumption, fuel stations, petrol cans and siphoning.

- **Consumption:** the driver's client uses fuel while the engine runs. Idle uses little, full revs use a lot (`Config.Usage`), scaled by vehicle class (`Config.Classes`). An empty tank stops the engine. Cycles (class 13) and models in `Config.NoFuel` never use fuel.
- **Level:** kept in the vehicle's state bag `vrFuel` (percent), so every player and the server see the same value. The server runs with state bag strict mode, so clients can not write the bag: the driver's client (or the player refuelling) reports the level once a second with `vr-fuel:set` and the server checks it (you must be driving or within 12 m, and a level may only rise at refuelling speed) before writing it. Levels set on the server through the bridge (`Bridge.vehicle.setFuel`, which writes the bag `fuel`) are copied into `vrFuel`.
- **Pumps:** target a pump, choose *Get Fuel*, and a progress bar runs while the tank fills. The server takes the money first and refunds anything not delivered if you stop early. Prices and limits are in `config.lua`.
- **Petrol cans:** buy one at a pump, refill it at a pump, pour it into a car, or siphon a car into it (needs the `fuelsiphon` item). The can is a `WEAPON_PETROLCAN` item of vr-inventory; its level is the weapon's durability (0-100).
- **Safety:** pump purchases are checked on the server (distance to a station, cooldown, whole units only, money taken first). Starting to refuel with the engine running has a chance to explode (`Config.Explosion`).

## Items

Add the siphon item to vr-inventory's `data/items.lua`:

```lua
['fuelsiphon'] = { label = 'Fuel Siphon', weight = 2500, stack = true, close = true, description = 'A fuel siphon to extract fuel from vehicles' },
```

`WEAPON_PETROLCAN` is already a vr-inventory weapon. The siphon image ships in `images/`.

## Exports (server)

`SetFuel(vehicle, 0-100)`, `GetFuel(vehicle)`.

## Exports (client)

`GetFuel(vehicle)`, `SetFuel(vehicle, 0-100)`, `IsSiphonFuelAllowed(vehicle)`, `IsPetrolCanRefuelAllowed(vehicle)`, `CanPumpRefuelPetrolCan()`.

vr-hud reads `exports['vr-fuel']:GetFuel(vehicle)` when `Config.FuelScript = 'vr-fuel'`.

## Credits

Written by ValRavn. Earlier versions were a port of another fuel script; this version is a clean rewrite and uses no code from it.
