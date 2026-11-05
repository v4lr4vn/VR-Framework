# vr-policejob

Police job for the ValRavn **vr-core** server: handcuffs, search, drag, put in / take out of vehicles, fines, armory, garage, stashes, work clothes, station cameras, props (cones, barriers, spike strips), the police menu (Adam status, broadcasts, meetings, interdicted areas, panic button) and links to vr-mdt and vr-dispatch.

This is a port of **ars_policejob** by Arius Scripts to vr-core. The menus, target options and animations work as before; the framework layer, the server-side checks and the integrations changed.

## Credits and licence
- Original: [ars_policejob](https://github.com/Arius-Scripts/ars_policejob) by **Arius Scripts** (Arius Development).
- Licence: Apache License 2.0 (see `LICENSE`). This port keeps that licence; the files changed for vr-core are marked by this README.
- vr-core port: ValRavn.

## Requirements
- Hard: `vr-core`, `ox_lib`, `ox_inventory`, `ox_target`.
- Optional (only used while started): `vr-dispatch` (panic / backup alerts, "Open Dispatch"), `vr-mdt` (fine log, "Open MDT"), `illenium-appearance` (work clothes), `vr-fuel`, `vr-voice` (meeting radio), a vehicle keys resource (`Config.VehicleKeys`), a boss menu resource (`Config.BossMenu`), `pickle_prisons` (arrest option).

## What changed for vr-core
- **Framework:** the esx / qb compatibility files are replaced by `modules/compatibility/frameworks/vr/{client,server}.lua`, which keep the function names the rest of the script calls (`hasJob`, `playerJob`, `getPlayerJobGrade`, `removeAccountMoney`, `toggleClothes`, `openBossMenu`, ...). ESX paths are gone.
- **Jobs:**
  - Job lists in the config are `{ 'police' }`. Any job whose vr-core type is in `Config.JobTypes` (`leo`) also counts, so a new leo department just works.
  - ox_target options check the job and duty in `canInteract` instead of `groups` (groups only know job names).
  - ox_inventory stashes use job groups `{ police = minGrade }`. Add a new department's name to the station `jobs` for its stashes.
- **Duty:** the KVP duty store (`updateDuty`, `getDutyStatus`) is removed. Duty is vr-core's `job.onduty`: the station duty points fire `VRCore:ToggleDuty`, and the UI follows `VRCore:Client:SetDuty` / `OnJobUpdate`. Every job action needs the officer on duty, on the server too.
- **Handcuffs:**
  - The server keeps the cuff state and syncs `metadata.ishandcuffed` (`SetMetaData`) and the replicated state bag `isHandcuffed`.
  - Exports: server `IsHandcuffed(src)`, client `IsHandcuffed()` (the old `cuffed` / `cuffs` client exports stay).
  - vr-adminmenu's **Toggle Cuffs** fires `police:client:GetCuffed` on the target's client. That asks the server to toggle, and the server only accepts it when a staff member (`Config.AdminCuffPermissions`) sent `vr-adminmenu:server:CuffPlayer` for that player in the last 15 seconds.
  - Logout, drop and a resource restart clear cuff and drag state; a stale `ishandcuffed` flag is cleared at login.
  - Breaking free (`Config.BreakCuffsItem`, default `lockpick`) goes through the server: one item used per attempt, uncuffed on success.
- **Police menu:** "Open MDT" (`exports['vr-mdt']:OpenMDT()`) and "Open Dispatch" (`exports['vr-dispatch']:OpenDispatchMenu()`) show while those resources run. A "Panic button" entry sends a 10-99.
- **Dispatch:** the panic button and the "Officer Down" (11-45) status send `exports['vr-dispatch']:SendAlert(..., src)` from the server (codeName `panic`, code `10-99`, jobs `leo` + `ems`, priority 1). The "Needs Backup" (11-99) status sends codeName `officerbackup`, code `10-32`, jobs `leo`. When vr-dispatch isn't running (or the export fails), the original emergency blip goes to on-duty police only.
- **Fines:** money goes into the `police` society (`AddSocietyMoney('police', amount, 'fine')`) and is logged with `exports['vr-mdt']:LogFine{ officer, target, amount, reason }`.
- **Other integrations:** clothing through illenium-appearance (civilian clothes reload the saved skin), garage vehicles get fuel through vr-fuel (native fallback) and keys only when a keys resource runs, meeting radio through vr-voice, the arrest option only while `pickle_prisons` runs, the boss menu only while `Config.BossMenu.resource` runs.
- **Events** are renamed to `vr-policejob:server:*` / `vr-policejob:client:*`.
- **Removed:** `lib.versionCheck`, `provides { esx_policejob, qb-policejob }` and the qb `IsHandCuffed` alias, the fr / it locales.
- **Fixed on the way:** personal stashes (`shared = false`) were never created; station stash `min_grade` was ignored; the 300 radius option sent 200; wrong locale keys (location, meeting frequency); helmet props used the wrong field for illenium-appearance; a cuff race where controls weren't disabled; using a lockpick while not cuffed used it up.

## Security fixes
- **Armory (`giveItemToPlayer`):** trusted a client-sent jobs list, stash, item and quantity, so anyone could get any item. Now `vr-policejob:server:takeArmoryItem(stationId, itemIndex)`: the station and item come from the config, the item must be in the list for the officer's grade, the officer must be on duty and within 3 m of the armory, the quantity is capped at the configured amount minus what they carry, stock is checked and removed from the storage first (and put back if the officer can't take it), rate limited.
- **`getItemCount`:** could read any inventory (other players, any stash). Now only the station stashes the caller's job uses, on duty, with the stash grade.
- **Fines:** no target, distance or amount checks. Now: target online and within 5 m, not yourself; whole-number amount from 1 to `Config.Fines.max`; reason up to 200 characters, cleaned; per-officer cooldown; `RemoveMoney('bank', ...)` must return true before the society deposit, the MDT log and the notifications.
- **Cuff / uncuff / drag / put in / take out:** online, loaded target within 4 m, not yourself, officer on duty; drag and put-in need the target cuffed (server state); take-out needs the target in a vehicle that is unlocked unless they're cuffed; cuffing uses up a cuff item the officer really has. Drag state lives on the server, so another officer can't hijack it and it's always released.
- **Broadcasts:** `broadcastMsg`, `callMeeting`, `sendStatusNotification`, `activateBlip` and `createEmergencyBlip` relayed client data to every player. Now they go to on-duty police only (broadcasts and interdicted areas: police and EMS), with length caps, cleaned text, per-officer rate limits and server-side values: the status code comes from `Config.StatusCodes` by index, interdicted areas use the officer's own position and only the configured radii / types / up to 60 minutes, meetings need `Config.MettingMenuGrade` on the server, emergency blips are built on the server.
- **Stashes:** ox_inventory groups don't check duty, so an `openInventory` hook requires on-duty police for the station stashes. The armory storage now has coords (it could be opened from anywhere).
- **Client events** coming from the server ignore calls from other client resources (`GetInvokingResource`).
- No update checks, telemetry or webhooks.

## Config notes
- `Config.Fines`: cap, cooldown, distance, reason length, society.
- `Config.Security`: distances and cooldowns used by the server.
- `Config.StatusCodes`: the Adam status list; `alert = 'backup' | 'panic'` raises a dispatch alert.
- `Config.Broadcast` / `Config.InterdictArea`: who receives them (job types or names).
- `Config.BossMenu`: no boss menu resource runs yet; set the resource and its open event.
- `Config.PoliceStations`: coords, armory lists per grade, garage vehicles and grades, stashes and their grades.

## Not ported / known limits
- The garage still spawns vehicles on the client (as the original did); the grade check there is client-side.
- Props (cones, barriers, spike strips) are client-side networked objects with no server events to validate.
- The break-free skill check runs on the client; the server only makes sure the item is used up.
