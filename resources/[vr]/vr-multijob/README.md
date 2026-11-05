# vr-multijob

A job menu in the Night Shift look. A character can hold several jobs, switch between them, go on or off duty, and leave a job. Open it with `/jobmenu`, or with the key the player picks in `/keybinds` (Job menu).

## What players can do

- See every job they hold, split into Whitelisted and Civilian, with a search box.
- **Switch** to a job at the rank they hold there.
- **Go on or off duty** for the job they are working.
- **Leave** a job (asks first). **Not working for now** switches to unemployed without losing the other jobs.
- A job taken anywhere else (City Hall Job Centre, a boss menu, an admin) lands on the list by itself.

A player holds up to `Config.MaxJobs` jobs. Admins are not limited.

## What counts as whitelisted

A job is listed under **Whitelisted** when any of these is true:

- its name is in `Config.WhitelistJobs` (police, ambulance, dispatch, mechanic, judge, prosecutor, lawyer, debtcollector, foodstandards, cardealer by default);
- its definition says `whitelisted = true` (restaurants created with `vr-restaurant` do this, so every restaurant job is whitelisted);
- its type is a whitelisted type and `Config.WhitelistByType` is on (a job with a type other than none, that is not listed in `Config.OpenJobTypes`).

Everything else is under **Civilian**. The pay shown for a grade is its `display` figure when the job sets one (restaurants do, because their wages are paid by the restaurant) and the framework `payment` otherwise. A job's `description` and `icon` can come from its definition, with `Config.Descriptions` and `Config.FontAwesomeIcons` taking priority.

## Settings

All in `config.lua`: `MaxJobs`, `AllowSelfRemove`, `ActionCooldown`, `IgnoredJobs`, `DenyDuty`, `WhitelistJobs`, `WhitelistByType`, `OpenJobTypes`, `Descriptions`, `FontAwesomeIcons`, `FallbackJob` and the hint line at the bottom of the menu.

## Admin

`/addjob <id> <job> <grade>` and `/removejob <id> <job>`. Admins only.

## For other scripts

Server exports:

- `GetJobs(citizenid)` returns `{ police = 2, tow = 0 }`
- `AddJob(citizenid, job, grade)`, `UpdateJobRank(citizenid, job, grade)`, `RemoveJob(citizenid, job)`
- `HasJob(citizenid, job)`, `GetMaxJobs()`

`TriggerEvent('vr-multijob:server:removeJob', citizenid, job)` drops a job from a list (leave out `job` to clear all). It is a server-only event.

The list is saved in `vr_multijobs`, created on start.

## Works with

vr-core, Qbox, QBCore, ESX and ox_core through vr-bridge. Needs vr-lib and vr-bridge. The menu key goes through vr-keybinds when it is running.

## What changed from the first version

- New Night Shift screen, built on Svelte. Source is in `web/`, the build is in `html/`.
- Runs through vr-bridge instead of calling vr-core directly.
- `Config.Side` is gone. The menu is centred.
- No default key is forced on anyone; players pick theirs in `/keybinds`.
- Gangs are not jobs and can't be added.
- New exports `HasJob` and `GetMaxJobs`. The old exports and the `removeJob` event work as before.
- The server checks everything: the client only asks to switch, go on duty or leave, and the grade always comes from the saved list.
- Data in `vr_multijobs` is unchanged, so existing lists carry over.

## Credits and licence

- Original idea and the first version of this resource: [ps-multijob](https://github.com/Project-Sloth/ps-multijob) by Project Sloth: [xFutte](https://github.com/xFutte), [Silent](https://github.com/S1lentcodes), [Jay](https://github.com/jay-fivem), [Snipe](https://github.com/pushkart2).
- No licence file shipped with the copy the first port was made from. The original licence terms from the upstream repository apply to anything that still comes from it.
- This version is a rewrite for vr-bridge; the interface and server code were written new.
