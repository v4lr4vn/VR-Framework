# vr-ambulancejob

The ambulance job and death system for **ValRavn**, running on **vr-core**, **ox_lib**, **ox_inventory** and **ox_target**. It's a port of Arius Scripts' ambulance job (version 1.0.4). Hospitals, the death screen, injuries, the CPR revive, stretchers, the medical bag, the EMS tablet, the garage, stashes, pharmacies, outfits and the NPC paramedics all work as before.

## Credits and licence
- The original ambulance job is by [Arius Scripts](https://github.com/Arius-Scripts) (Arius Development).
- It's licensed under the **Apache License 2.0** (see `LICENSE`), and this port keeps that licence. The changes made for vr-core are listed below.
- vr-core port: ValRavn.

## Requirements
- `vr-core`, `ox_lib`, `ox_inventory` and `ox_target` (listed in `fxmanifest.lua`). No SQL: the death state lives in vr-core's `metadata.isdead`.
- **Optional.** These are only used while they're started:

| Resource | Used for |
| --- | --- |
| `vr-dispatch` | distress calls, officer-down and EMS-down alerts (server export `SendAlert`), the tablet's "Open Dispatch" |
| `vr-mdt` | the tablet's "Open MDT" |
| `vr-adminmenu` | its revive actions (`hospital:client:Revive`) |
| `illenium-appearance` | job outfits and switching back to civilian clothes |
| `vr-fuel` | full tank on garage vehicles (`Config.fuelResource`), native fuel otherwise |
| `vr-vehiclekeys` | keys for garage vehicles (not installed yet) |
| `vr-management` | the boss menu (`Config.bossMenu`, not installed yet) |
| txAdmin (`monitor`) | its Heal action revives or heals |

## Installation
1. Add the items in `!INSTALLATION/items.lua` to `ox_inventory/data/items.lua`, and copy `!INSTALLATION/images/*.png` to `ox_inventory/web/images/`.
2. Put `vr-ambulancejob` in your resources and `ensure vr-ambulancejob` after vr-core, ox_lib, ox_inventory and ox_target.
3. Check `config.lua` and `data/hospitals.lua` (coords, grades, prices).

## What changed for vr-core
- **Framework.**
  - The ESX and qb-core bridges were replaced by one vr-core bridge in `modules/compatibility/frameworks/vr/`, with the same `Framework.*` function names.
  - `hasJob` matches the job name or job type from `Config.emsJobs` (the `ambulance` job has type `ems`), and it requires `PlayerData.job.onduty` for job actions. Clothing and the boss menu don't need duty.
  - ox_target `groups` are built from `Config.emsJobs` plus every shared job of type `ems`, so new EMS departments just work.
- **Target and inventory.**
  - Only the ox_target path is kept. qb-target was removed.
  - Only ox_inventory is supported. The non-ox fallbacks (client-side shop and item handling) are gone.
- **Death state.**
  - `metadata.isdead` and `metadata.inlaststand` are set server-side with `SetMetaData` on every death and revive, along with the `dead` state bag.
  - A character saved dead comes back dead. Saved in last stand also counts as dead, and is normalised to `isdead`.
  - On every revive and respawn, the server sets hunger and thirst to 100 through vr-core metadata (vr-consumables and vr-hud read those). Stress is left as it is, and the death flags clear.
  - Exports: server `IsDead(src)` and `RevivePlayer(src)`; client `IsDead()` (the original `isDead()` is kept).
- **Admin menu.** `hospital:client:Revive` (vr-adminmenu's revive) does a full revive plus heal.
- **Dispatch.**
  - The distress call (E on the death screen, or `/distress`) is created on the server. It goes into the EMS tablet list and to vr-dispatch through `SendAlert` with codeName `injured`, code `10-52`, jobs `{'ems'}`.
  - The command is now `/distress`, because vr-dispatch owns `/911`.
  - When an on-duty leo or ems player dies, the server sends `officerdown` / `emsdown` (code `10-99`, jobs `{'leo','ems'}`, priority 1), with a 60 s cooldown per player.
  - The old phone hook `Config.sendDistressCall` was removed.
- **EMS tablet.** It has "Open MDT" (`exports['vr-mdt']:OpenMDT()`) and "Open Dispatch" (`exports['vr-dispatch']:OpenDispatchMenu()`) when those resources are started.
- **Admin commands.** `/revive [id]`, `/revivearea <radius>`, `/heal [id]`, `/healarea <radius>` and `/reviveall` are registered with `VRCore.Commands.Add` and the `admin` permission (`vrcore.admin`). All of them go through the server revive and heal.
- **Integrations.**
  - Outfits use illenium-appearance's exports. Civilian clothes use `illenium-appearance:client:reloadSkin`.
  - Garage vehicles get a full tank through vr-fuel (guarded). Keys are optional.
  - The boss menu event is configurable and guarded.
- **Inventories.**
  - Pharmacies are ox_inventory shops registered with `groups` (job pharmacy: `{ ambulance = grade }`) and `locations`, so ox_inventory checks access, distance and prices itself.
  - Stashes get the EMS job groups (their `min_grade`) and coords. The original's inverted `shared` flag was fixed: `shared = true` is now actually shared.
- **Removed.** `lib.versionCheck`, and every locale except English.
- **Renamed.** Events are `vr-ambulancejob:*`.
- **Bug fixes.**
  - Burn injuries used a bandage instead of burn cream.
  - An error was thrown on damage to an unmapped bone.
  - Injury menus had wrong "back" ids.
  - Outfit props were sent as components.
  - The outfit menu waited forever when closed.
  - The paramedic heal didn't clear the injury state bag.
  - The tablet list was visible to anyone.

## Security fixes
- **`removAddItem`.** Any client could add or remove any item. It's removed. The server now does every item change:
  - **Treatment and revive items** are checked and worn by `Config.consumeItemPerUse` durability on the server, using the first slot with enough durability. The medic must be on duty and in range, and the patient must be in the right state.
  - **Pharmacy purchases** go through ox_inventory shops.
  - **The medical bag** is taken when placed. It's returned once, and only to its owner, on pickup.
- **`useItem`.** It indexed a nil slot and took a client-sent durability amount. It's removed; durability comes from the config.
- **Self-revive.** `updateDeathStatus` still accepts client-reported deaths, but a dead → alive report only counts when the server initiated or expected it: an EMS revive (not before the CPR animation can have finished), an admin menu revive, a txAdmin heal, a respawn after the timer, or the NPC paramedic. Anything else is refused, and the client is put back into its death state.
- **Killer data.** `killedBy` must be a 32-bit integer weapon hash, stored signed. Anything else is dropped.
- **Revive and treatment.** The old instant `revivePlayer` net event (no item, no animation) was removed. A revive now needs:
  - an on-duty, alive EMS within 4 m, a patient who is dead on the server, and a usable defibrillator;
  - no other revive of that patient already running.
  The patient is placed next to the medic using the server's coords for the medic; the original took them from the client.
- **Treatment.** It needs on-duty EMS within range, a real injury in the patient's state bag, and the right item for its cause.
- **Rewards.** `reviveReward` is paid only after a server-verified revive of a patient who was really dead, with the medic still nearby, once per patient per `rewardCooldown`. `baseInjuryReward` is paid per treated injury, at most `maxInjuryRewards` per patient per cooldown.
- **Stretcher and vehicle.** `putOnStretcher` and `togglePatientFromVehicle` need on-duty EMS (the original only offered them to EMS) within range of a target who is dead on the server. The vehicle must be a real vehicle near the medic.
- **Patient data.** `getData` and `getDeathStatus` only answer the player themselves, or on-duty EMS within 5 m. They used to leak anyone's injuries and killer.
- **Distress calls.**
  - They're created server-side with a server cooldown per character.
  - The gps comes from the server's view of the caller's ped.
  - Text is capped (200 characters, 64 for the dispatch title) and stripped of control characters and markdown/HTML brackets.
  - The tablet list (`getDistressCalls`) and closing calls (`callCompleted`, now by id) are on-duty EMS only. The list is capped at 50 calls.
- **NPC paramedic.** The server checks you're at that hospital's paramedic and charges the price from config (cash, then bank, never into the negative). It checks the `RemoveMoney` result and puts the money in the `ambulance` society.
- **Respawn.** The inventory wipe on respawn only happens when the server knows you're dead and the respawn timer has passed.
- **NPC revive (`/ambulance`).** The server checks that you're dead, that no medics are on duty and that the wait time has passed.
- **Medical bag stash.** It's keyed by citizenid instead of license. It's registered with the EMS job groups and the bag's coords, so ox_inventory checks the distance too. Only the bag's owner can open it, from close by.
- **Admin commands.** They use vr-core permissions.
- **txAdmin.** The heal handler only reacts to txAdmin's own server event: it checks the invoking resource is `monitor`, validates the payload, and isn't a net event.

## Integration API
- **Server exports**
  - `exports['vr-ambulancejob']:IsDead(src)`: bool (dead or last stand).
  - `exports['vr-ambulancejob']:RevivePlayer(src)`: bool. A full server-side revive: state, metadata and needs first, then the client.
- **Client exports:** `IsDead()` (and `isDead()`), `createDistressCall()`, `openDistressCalls()`.
- **Client event:** `hospital:client:Revive`, a full revive plus heal. The server accepts the client's report only right after an admin used one of vr-adminmenu's revive actions (same `mod` permission, `Config.adminMenu`). Other resources should call `RevivePlayer` instead.

## Config notes (`config.lua`, `data/hospitals.lua`)
- `respawnTime` (minutes), `waitTimeForNewCall`, `timeToWaitForCommand`: all checked on the server.
- `reviveReward`, `baseInjuryReward`, `rewardCooldown`, `maxInjuryRewards`: medic pay.
- `paramedicTreatmentPrice`, `paramedicAccounts`, `society`: NPC treatment.
- `maxDistance`: server range checks.
- `dispatch`: alert codes.
- `adminMenu`: must match vr-adminmenu's revive permission.
- `consumeItemPerUse`: durability per use.
- Hospitals: the paramedic, garage, stash, pharmacy and outfit coords; garage `min_grade` (vr-core grades are 0-based, the ambulance needs grade 3 by default); boss menu `min_grade`; stash `min_grade`; pharmacy `grade`.

## Not ported / known limits
- ESX, qb-target, qb-inventory and the non-ox fallbacks were dropped.
- There's no boss menu or vehicle keys resource yet. Both are guarded and configurable.
- The `stretcher` item from the original list isn't used by the script (stretchers come from ambulances).
