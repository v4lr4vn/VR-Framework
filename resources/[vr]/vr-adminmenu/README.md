# vr-adminmenu

The in-game admin menu for **ValRavn**, running on **vr-core**, **ox_inventory** and **ox_lib**. It's a port of Project Sloth's admin menu (version 1.2.1), and the UI and actions are unchanged: players, vehicles, inventories, teleports, trolls, world controls, staff chat, the resource manager and the command list.

## Credits and licence
- The original admin menu is by [Project Sloth](https://github.com/Project-Sloth): [OK1ez](https://github.com/OK1ez), [Lenzh](https://github.com/Lenzh), [LeSiiN](https://github.com/LeSiiN) and the Project Sloth team.
- It's licensed under the **GNU GPL v3** (see `LICENSE`), and this port keeps that licence.
- This port only changes what's listed below.

## Requirements
- `vr-core`, `vr-mysql`, `ox_lib` (v3.8.0 or newer) and `ox_inventory`. These are listed in `fxmanifest.lua`.
- Optional resources are only used while they're started. Point `Config.Resources` at the ones you run, or set an entry to `false`:

| Key | Default | Used for |
| --- | --- | --- |
| weathersync | `vr-weathersync` | weather, time and blackout (its `setWeather`, `setTime` and `setBlackout` server exports) |
| vehiclekeys | `vr-vehiclekeys` | giving keys for spawned vehicles and after a plate change |
| clothing | `illenium-appearance` | Give Clothing Menu (`illenium-appearance:client:openClothingShopMenu`) |
| ambulance | `vr-ambulancejob` | revive (`Config.ReviveEvent`, default `hospital:client:Revive`) |
| police | `vr-policejob` | Toggle Cuffs (`police:client:GetCuffed`) |
| mechanic | `vr-mechanicjob` | repairs part damage too when fixing a vehicle |
| sound | `interact-sound` | Play Sound |
| voice | `vr-voice` | Mute Player (local mute) |
| hud | `vr-hud` | dev mode toggle and the stress display |
| logs | `vr-log` | audit log of every admin action, sent through `<logs>:server:CreateLog` |

- **Fuel** goes through `Config.Fuel` (`vr-fuel` by default, or `ox_fuel` / `LegacyFuel` / ...). It falls back to the native fuel level when that resource isn't running.
- **Owned vehicles.** Admin Car, Give Car, Set Vehicle Garage State, Change Plate, Spawn Personal Vehicle and the vehicle list on the Players page all use your garage resource's table, `Config.VehicleTable` (default `player_vehicles`). vr-core doesn't create that table. If it's missing, those actions just report it.
- **Warnings** go into `Config.WarnsTable` (default `player_warns`). It's created on start if it doesn't exist.

## Installation
1. Put `vr-adminmenu` in your resources and add `ensure vr-adminmenu` to your config after vr-core, ox_lib and ox_inventory.
2. Give your staff vr-core permission groups, as described in vr-core's README:
   ```
   add_principal identifier.license:XXXX vrcore.mod     # moderator
   add_principal identifier.license:YYYY vrcore.admin   # admin
   add_principal identifier.license:ZZZZ vrcore.god     # owner
   ```
3. Use `/admin` or PageDown to open the menu, and `/nc` or PageUp to noclip. Both keys can be changed in `shared/config.lua`.

## What changed for vr-core
- **Renames.** The resource and every event are now `vr-adminmenu:*`. The NUI's resource-name fallback in `html/index.js` was patched; nothing else in the built bundle changed. The page title, the Svelte sources and the dev data were renamed too.
- **Core.**
  - It uses `exports['vr-core']:GetCoreObject()`, `VRCore.Functions.*` and `VRCore:*` events (`VRCore:Client:OnPlayerLoaded`, `VRCore:ToggleDuty`, `VRCore:Notify`).
  - Jobs, gangs and vehicles are read live through `exports['vr-core']:GetShared(...)`. Grades use vr-core's string keys.
  - `/admin` is registered through `VRCore.Commands.Add`, so the resource doesn't need `add_ace` rights.
- **Database.**
  - Bans are written to `vr_bans` with vr-core's own columns (`name, license, discord, ip, reason, expire, bannedby`), so vr-core's `IsPlayerBanned` enforces them.
  - Offline inventory clears update `vr_players.inventory`. The `oxmysql` include became `@vr-mysql/lib/MySQL.lua`.
- **Inventory.** Everything goes through ox_inventory exports only:
  - `AddItem`, `ClearInventory`, `forceOpenInventory` (player, stash, and trunks through the vehicle's net id) and `UpdateVehicle`.
  - The NUI item list comes from `exports.ox_inventory:Items()`.
  - Clear Inventory keeps the `money` item (`Config.ClearInventoryKeep`), because cash is mirrored from vr-core.
- **Clothing.** It uses illenium-appearance instead of qb-clothing.
- **Remove Stress.** It's done on the server: `stress` metadata is set to 0 and `hud:client:UpdateStress` is sent. vr-hud only relieves a capped amount per client request.
- **Fix Vehicle.** vr-core has no `/fix`, so the menu repairs the vehicle itself. The same goes for Fix Vehicle for player.
- **Moved to the server.** Weather, time, blackout and Play Sound now run on the server. Weather, time and blackout use weathersync's exports. Play Sound uses `InteractSound_CL:PlayOnOne`, so the clients no longer fire those resources' net events.
- **Logging.** The client-side `qb-log` call was replaced with a server-side audit log, which is only sent when `vr-log` is running.
- **Removed.** The qb-inventory, ps-inventory, lj-inventory and qbx_core branches, the `trunkitems`/`gloveboxitems` updates (qb-inventory), the ESX notes and every locale except English.
- **Fixes.**
  - Freeze is now tracked per player.
  - The laser no longer starts a new endless loop on every toggle.
  - Spectate no longer hangs when the target leaves.
  - Give Car showed a missing locale key.
  - Set Ped didn't notify the admin.
  - The staff chat notification text is fixed.
  - Set On Fire and Explode used the server id as an entity.

## Security fixes
Every server event and callback now checks the caller's vr-core permission on the server, for that specific action. The required group comes from the action's `perms` in the server's own `Config` (the strictest one if several actions share an event). Nothing the client sends decides it.

1. **Escalation through the action key.** The original checked the perms of the action key the client sent, not of the event being run. A mod could call `GiveMoney`, `SetPerms` or `givecar` with the key of any mod action. Each event now checks its own perms.
2. **`ValidateClientAction` and `ValidateCommand`** took the event name and the perms from the client. A client could pass `'mod'` for admin actions, or make the server fire any client event at itself. Now the client only sends the key, and the event and perms come from the server config. `/setammo` now needs the Set Ammo permission (admin) instead of a hard-coded `mod`.
3. **Unchecked events and callbacks.** These had no permission check at all. Each one is now checked, or was replaced by a checked server callback:
   - `OpenInv`, `OpenStash` and `OpenTrunk` let anyone open any player's inventory, stash or trunk.
   - `ChangePlate` let anyone rename any plate in the database. It's now a callback that reads the current plate from your vehicle on the server.
   - `GetVehicleByPlate` and `CheckAlreadyPlate` were open too. Both are gone.
   - `spectate:teleport` let anyone teleport under any player. It now only works for the player you're spectating.
   - `GetPlayers` leaked every player's license, Discord and Steam ids, money, phone number and vehicles.
   - `GetResources` was also open.
4. **Set Perms** passed the client's string straight into an `add_principal` console command, which allowed command injection. Now:
   - Only `mod`, `admin` and `god` are accepted.
   - You can only grant a group below your own (god can grant any group).
   - You can never change someone ranked above you, so self-promotion is impossible.
5. **Rank protection.** Ban, kick, warn, freeze, drunk, cuff, set ped, clear inventory, remove money, set bucket, bring, set job, set gang, set perms and play sound are refused against staff ranked above you. Banning or kicking yourself is refused too.
6. **Admin Car** took the model, hash and plate from the client, which let anyone insert any owned vehicle. The server now reads the model and plate from the vehicle you're sitting in, and the model must be in vr-core's shared vehicles.
7. **Input validation.**
   - Money: whole numbers from 1 to `Config.MaxMoneyAmount`, and only the money types the config offers. Remove Money checks the balance and `RemoveMoney`'s result.
   - Items: the item must exist in ox_inventory, with a whole amount from 1 to `Config.MaxItemAmount`.
   - Giving the `money` item (cash) also needs the Give Money permission, so mods can't mint cash with Give Item.
   - Plates: up to 8 letters, numbers or spaces.
   - Ban durations, weather types, times and sounds must come from the config lists. Ped models must be in `data/ped.lua`. Routing buckets must be whole numbers of 0 or more. Reasons, stash names and garage names are length-capped.
   - Target ids must be connected players. The original passed `-1` straight through to `TriggerClientEvent`, which revived everyone.
8. **Staff chat** took the sender's name and citizenid from the client, which allowed impersonation. The server now fills them in and caps the message length and the history.
9. **Spawn Personal Vehicle** used an unchecked core spawn callback with a client-chosen model. It's now a permission-checked server callback that spawns the model stored for that plate.
10. **Resource control** validates the resource name and the state. The old `print(json.encode(data))` of client input is gone.
11. **No version check, update notifier or telemetry.** Logging only goes to your own log resource.

## Permissions model
`Config.Actions`, `Config.PlayerActions` and `Config.OtherActions` each have a `perms` of `mod`, `admin` or `god`. Higher groups inherit lower ones through vr-core's principals.

- `Config.MenuPerms` sets who can open the menu. With `Config.RequireAdminDuty`, players with `admin` must be opted in (vr-core optin) to open it.
- `Config.ResourcePerms`, `ResourceListPerms`, `ShowCommandsPerms` and `StaffChatPerms` gate the other pages.
- Command actions (`dv`, `tpm`) run vr-core's own commands, so they keep vr-core's ace (`admin`).
