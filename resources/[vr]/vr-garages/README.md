# vr-garages

Garages for ValRavn. Server checks everything, no outside calls. Uses the standard `player_vehicles` table
(created if missing) so the admin menu, MDT, inventory trunks and the bank all keep working.

## Using it

Walk into a garage area and press **E** (remappable in Keybinds). On foot it opens the garage, in the driver seat it parks the car.

- **Public garages, hangars and boat houses** take cars, aircraft or boats (`category`).
- **Job garages** only open for members (and on duty when `requireDuty` is set) and only hand out the job vehicles set
  for them (see below). Personal cars are not shown or parked there.
- **Gang garages** only open for gang members. They work like a private garage for members' own cars and can also hand
  out gang vehicles.
- **House garages** come from vr-housing automatically. The owner and keyholders can use them.
- A car parked at another garage can be brought to where you are for `Config.TransferFee`.

## Job vehicles

Job and gang garages can hand out vehicles straight from the config, like a spawner. Members open the garage, pick a
vehicle from **Job vehicles** and it comes out with a full tank. They drive it back into any garage of the same job and
press **E** to return it. Nothing is saved to `player_vehicles`.

```lua
police_fleet = {
    label = 'Mission Row Garage', type = 'job', group = 'police', category = 'car', radius = 14.0, requireDuty = true,
    center = vec3(474.0, -1012.7, 29.31),
    spawns = { vec4(473.89, -1015.31, 29.31, 357.73) },
    ped = { model = 'mp_m_weapexp_01', coords = vec4(466.21, -1010.05, 29.46, 0.0) },
    setupMenu = true,
    vehicles = {
        { model = 'police', label = 'Patrol Cruiser', grade = 0, plate = 'LSPD', livery = 0, extras = { [1] = true, [2] = false } },
        { model = 'police3', label = 'Interceptor', grade = 2, plate = 'LSPD', maxMods = true, colours = { 0, 0 } },
    },
},
```

| Vehicle option | What it does |
| --- | --- |
| `model` | Spawn name |
| `label` | Name shown in the garage (defaults to the game name) |
| `grade` | Lowest job or gang grade that can take it out |
| `plate` | Plate prefix, the rest is filled with numbers. Eight characters makes a fixed plate |
| `livery` | Livery number to start with (0 is the first) |
| `extras` | Extras switched on (`true`) or off (`false`) |
| `colours` | Primary and secondary paint ids |
| `maxMods` | Engine, brakes, gearbox, suspension, armour and turbo maxed out |
| `mods` | Any other vehicle properties, same format as `lib.setVehicleProperties` |
| `fuel` | Starting fuel (defaults to `Config.JobVehicles.fuel`) |

Garage options: `ped` stands a worker at the garage, `setupMenu` opens a livery and extras menu after a vehicle comes out.
Garages built in game with `/garage` keep their vehicle list from the config entry with the same id.

`Config.JobVehicles`: `limit` is how many job vehicles one player can have out (0 for no limit). With `returnOtherWhenFull`
taking another sends their empty one back. `removeOnLeave` removes a player's empty job vehicles when they leave.

Server events: `vr-garages:server:jobVehicleOut` (plate, citizenid, group, model, source) and `jobVehicleReturned`.
Job vehicles carry the state bag `vr_jobveh`.

## Impound

- Police on duty (`Config.Impound.jobs`) use the eye on a vehicle and pick **Impound vehicle**: reason, release fee and hold time.
  Unregistered cars are simply removed.
- Owners collect impounded cars at the impound lot once the hold time is up, paying the fee from bank or cash.
- Cars that were left out and are gone show at the impound lot and can be recovered for `recoverFee`.
- Cars repossessed by vr-banking wait at the impound lot and cannot leave until the debt is cleared.
- With `ReturnOutVehiclesOnStart`, cars left out when the server stops go back to their last garage on the next start.

## Building garages in game

Type **/garage** (needs `command.garage`, admins have it) to open the garage builder:

- Every garage is listed with where it comes from: **Config**, **Edited** in game, **Built in game** or **Removed**.
- Pick one to change its name, type, job or gang, what it holds, the duty check, the map blip and the radius.
- **Place centre**, **Add spot** and **Place a worker** close the panel so you can walk or drive to the spot.
  Face the way it should point and press **E** (Backspace cancels). Every spot is drawn in the world while the builder is open.
- Job and gang garages get a vehicle list: model (checked against the game), name, lowest rank, plate start, livery,
  extras, paint and max mods.
- **Save** makes it live for everyone straight away. **Remove** hides a garage, **Reset to config** throws away in-game
  changes to a config garage and **Bring back** restores a removed one.

Everything built in game is saved in `vr_garage_locations`. The old `/garage create`, `spawn`, `radius` and similar
subcommands still work.

## Exports (server)

`AddVehicle(cid, model, { garage, plate, props, fleet })` returns the plate, `GetVehicle(plate)`, `GetPlayerVehicles(cid)`,
`SetVehicleGarage(plate, garage, state)`, `SetVehicleOwner(plate, cid)`, `ImpoundVehicle(plate, { fee, reason, hours, by })`,
`ReleaseImpound(plate)`, `IsVehicleOut(plate)`, `GeneratePlate()`, `GetGarages()`. camelCase versions also exist.

Server events: `vr-garages:server:vehicleOut`, `vehicleStored`, `impounded`, `impoundReleased`.
Spawned vehicles carry state bags `vr_plate`, `vr_owner`, `vr_mileage` and `vr_status`, which are saved back when parked.
