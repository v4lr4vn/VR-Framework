# vr-vehiclekeys

Vehicle keys for ValRavn. Owners lock and unlock their cars, the engine needs a key, keys can be handed out or lent, and anyone without a key can break in.

## What players can do

- **Lock and unlock** with the lock key (or `/lock`). Your own vehicles and any you hold a key for work from up to 30 metres away. You get the key fob animation, a horn chirp and the lights flash.
- **Start and stop the engine** with the engine key (or `/engine`). Without a key the engine stays off. Holding the exit key when you leave keeps the engine running.
- **Keys menu** (`/keys`): give a permanent copy to someone standing near you, lend a key for an hour, see who has keys to your cars and take them back. If someone gave you a key you can hand it back.
- **Quick hand-out:** `/givekeys` gives a permanent copy of the car you are in (or the one of yours standing next to you) to the closest person. `/lendkeys` lends it for an hour. Add a player ID to pick someone (`/givekeys 12`). If several people are close you pick from a list; if none of your cars is close you pick the car first.
- **Radial menu:** the **Vehicle keys** entry has Give a key, Lend, Who has keys and My keys.
- **Locksmith:** change the locks on a car you own. Every loose key to it stops working.
- **Pick the lock** of a locked vehicle with a lockpick (third eye on the vehicle). It runs a skill check, the lockpick can snap, and the alarm can go off.
- **Hotwire** a car you are driving without a key (hotwire key or `/hotwire`). Needs a lockpick and a skill check.
- **Carjack:** aim a gun at a driver for a moment and they get out. You get the keys.
- **Street cars:** some parked cars are locked when you try the door.

Nobody is given a key binding. Players choose their own keys in `/keybinds` (Lock, Engine, Hotwire, Keys menu).

## Who has keys

| Kind | How | Ends |
|---|---|---|
| Owner | The vehicle is in `player_vehicles` under your character | When the vehicle changes owner |
| Shared | The owner gave you a copy | When the owner takes it back or changes the locks |
| Lent | The owner lent it | After `Config.Keys.lendMinutes`, or when taken back |
| Temporary | Job vehicle taken from a garage, a script handing out keys, an admin | After `Config.Keys.tempMinutes`, when the vehicle is gone, or when it is stored |
| Job or gang | Vehicles taken from a job or gang garage open for everyone in that job or gang | Never; follows the job |

The server decides everything. Shared and lent keys are saved in `vr_vehicle_keys`.

## Police

Break-ins, hotwiring and carjacking can send a call to `vr-mdt` (`Config.Alert`). Each kind has its own chance, and one player only raises one call per cooldown.

## Settings

All in `config.lua`: lock range, which vehicle classes need no key (bicycles by default), engine rules, how many people can hold a key, lend and temporary times, lockpick and hotwire items, skill check difficulty, break and alarm chances, the chance a street car is locked, carjack timing, police alerts, and the locksmith shop (price and places). Add more locksmiths by adding rows to `Config.Locksmith.locations`. `Config.Quick` turns the radial entry off (`radial = false`) and sets how close a car must be for `/givekeys` when you are on foot.

## Admin

`/vehkeys give <id> <plate>`, `/vehkeys remove <id> <plate>`, `/vehkeys clear <plate>`, `/vehkeys who <plate>`, `/vehkeys lock <plate> [off]`. Admins only.

## For other scripts

Server exports:

- `GiveKeys(src, plateOrVehicle, minutes?)` and `RemoveKeys(src, plateOrVehicle)`. `addKey` and `removeKey` do the same.
- `HasKeys(src, plateOrVehicle)`. `hasKey` does the same.
- `GiveKeysToCid(cid, plateOrVehicle, minutes?)`, `ClearKeys(plateOrVehicle)`
- `SetLocked(vehicle, locked)`, `IsLocked(vehicle)`, `Hotwire(vehicle)`
- `OwnerChanged(plate, cid?)` after you change who owns a vehicle in `player_vehicles`

Client export: `HasKeys(plateOrVehicle)`.

Events other scripts already use also work: `vehiclekeys:client:SetOwner` (plate) from a client script, and `vr-vehiclekeys:server:AcquireVehicleKeys` (plate, admins only). Through vr-bridge, `Bridge.vehicle.giveKeys` hands keys to this resource first.

A client script asking for keys with `SetOwner` is checked by the server: the vehicle must be close, must not belong to another character, and must not have a player driving it. Turn this off with `Config.Claims.enabled = false` if every script you run uses the server export instead.

Server events: `vr-vehiclekeys:server:lockChanged` (netId, locked).

State bags on vehicles: `vr_locked` (boolean) and `vr_hotwired` (boolean).

## Works with

vr-core, Qbox, QBCore, ESX and ox_core through vr-bridge. Needs vr-lib and vr-bridge.
