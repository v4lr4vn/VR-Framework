# vr-civjobs

The Civilian Jobs Mega Pack for ValRavn. Twelve civilian jobs in one resource, with one level system, one crew system, one board and one HUD, all in the Night Shift style.

## The jobs

| Job | What you do | Crew |
|---|---|---|
| Garbage Collector | Drive a round of stops, pick up bags, throw them in the truck, bring it home | Up to 3 |
| Lumberjack | Fell trees in the forest, pick up the logs, load the truck, sell at the sawmill | Up to 3 |
| Scrapyard Worker | Strip a wreck part by part, sort the parts into bins, crush the frame, deliver the bale | Up to 3 |
| Window Cleaner | Drive the van to a building and clean every window | Up to 3 |
| Builder | Carry materials, hammer, drill and weld until the build is done | Up to 3 |
| Trucker | Collect a trailer, haul it to the delivery bay, bring the cab back | Solo |
| Taxi Driver | Take fares around the city, tips on top | Solo |
| Bus Driver | Run a route, stop at every stop, wait for passengers | Solo |
| Paper Round | Ride a bike and throw the paper at every mailbox | Solo |
| Hunter | Hunt game in the woods, skin it and sell meat and pelts | Solo |
| Fisherman | Cast, wait for a bite, win the skill check, sell the catch | Solo |
| Treasure Hunter | Metal detector on the beach or a dive on the wrecks, sell what you find | Solo |

## How it works

- You take the job at the City Hall Job Centre. The job name matches the job here (`garbage`, `lumberjack`, `scrapyard`, `windowcleaner`, `builder`, `trucker`, `taxi`, `busdriver`, `newspaper`, `hunter`, `fisherman`, `treasurehunter`).
- Walk up to the depot clerk and open the work board. Pick a shift and press Start. Your job vehicle appears at the depot.
- Every job has its own level. Each shift earns experience; higher levels pay more (`Config.Levels`).
- Crew jobs: the crew leader invites nearby players who hold the same job from the board. Pay is split between everyone who worked, and every extra member adds a bonus (`Config.Crew`). Press Y to accept an invite and N to decline.
- Money goes to the bank when the shift ends. A work vehicle that is not handed back costs a fee. Crashing the bus costs money too.
- Hunter, fisherman and treasure hunter sell their finds at the depot clerk.
- Optional police alerts for a few dodgy fares and cargo (`Config.Police`).

The server decides everything: distances, timing, loot, prices and pay. The client only asks.

## Setting it up

1. Make sure `vr-core` has the 12 civilian jobs (the update adds them) and `vr-inventory` has the new items (the update adds those too).
2. `ensure vr-civjobs` after `vr-bridge` and `vr-lib`. Folders under `[vr]` are already covered by `ensure [vr]`.
3. The map positions in `config/<job>.lua` are a first guess. Set the real ones in game with `/jobsetup` (below), no file editing needed.

Everything is in `config.lua` and `config/<job>.lua`: depots, vehicles, prices, loot tables, levels, crew size, cooldowns and requirements.

## In-game setup (`/jobsetup`)

Admins (`Bridge.isAdmin` or the ACE `command.<Config.Admin.command>`) run `/jobsetup`. Pick a job, pick a field, then stand where you want it:

- Single spots (depot, vehicle spawn, sawmill, buyer and so on): press **Set to my position**.
- Lists (garbage stops, forests, window sites, bus and newspaper routes, fishing spots, hunting zones and so on): **Add here**, **Move here** or remove an entry. Circles have an editable radius, entries can carry a label, and windows take columns, rows and spacing.
- Numbers (pick-up radius, return radius): type a value.
- Every field has **Reset** to go back to the config file value, and each job has **Reset job**.

You walk around while the panel is open (WASD works; press ALT to toggle mouse and look). The selected field is drawn in the world as markers, circles and heading lines. Changes apply immediately for everyone, are saved in the `vr_civjobs_setup` table, and are re-applied on every restart. The config files stay the defaults.

## Garbage collector

Each stop is a circle (the pick-up radius, set per job in `/jobsetup`). The script uses the bin bags that already exist in the GTA world: target a bag inside the circle, pick it up, throw it in the truck. Bags are counted once when you enter the circle, so a street with fewer bags simply needs fewer; a stop with none is skipped. Picked bags are hidden for the whole crew.

## Lumberjack

Any tree model in `treeModels` can be felled. With no forests set, trees anywhere count; add forest circles in `/jobsetup` to limit felling to those areas.

## Admin

`/civjobs stats <id>`, `/civjobs setlevel <id> <job> <level>`, `/civjobs reset <id> <job>`, `/civjobs end <id>`, `/civjobs here`.

## For other scripts

Server exports: `GetLevel(src, job)`, `GetXp(src, job)`, `AddXp(src, job, amount)`, `GetStats(src)`, `IsWorking(src)`, `EndShift(src)`, `GetJobs()`.

Server events: `vr-civjobs:server:levelUp`, `vr-civjobs:server:sessionStarted`, `vr-civjobs:server:sessionEnded`.

Vehicles carry the state bag `vr_civjob` (the job name). They get a temporary key through `Bridge.vehicle.giveKeys`.

## Works with

vr-core, Qbox, QBCore, ESX and ox_core through vr-bridge. Needs vr-lib and vr-bridge. Progress is saved in `vr_civjobs_progress`.

## Credits and licence

- The idea of each job (what you do and in what order) follows the civilian job packs this was built from: the Quasar Smart Jobs set (`qs`: truck, treasure hunting, taxi, newspaper, hunter, fishing and bus) and the 17mov set (garbage, lumberjack, scrapyard, window cleaning and builder).
- No code, interface, models or other assets from those packs are used. This resource was written new for vr-bridge and only uses props, vehicles and animations that ship with the game.
- Their original names and licence terms still belong to their authors.
