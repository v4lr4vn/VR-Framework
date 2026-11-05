# ValRavn Framework

A complete, self-contained FiveM roleplay framework. One core (`vr-core`), one shared look (**Night Shift**), one bridge so scripts don't care which framework they run on, and 53 `vr-` resources on top: jobs, economy, housing, vehicles, law enforcement, medical, businesses and tools that let admins build the world without touching config files.

> **Alpha release (v1.0.0-alpha.1).** This is not finished. Expect bugs, missing polish and breaking changes between releases, and do not run it on a live community yet. Most features were developed against test harnesses and then checked on a live server by the author; the newest work (everything in [Testing status](#testing-status)) has not had a full in-game pass. Read [Known limitations](#known-limitations) before you build on it, and please report what you find.

---

## Contents

- [Highlights](#highlights)
- [How it fits together](#how-it-fits-together)
- [Quick start](#quick-start)
- [Compatibility with other frameworks](#compatibility-with-other-frameworks)
- [Resource catalogue](#resource-catalogue)
- [Night Shift UI](#night-shift-ui)
- [Build the world in game](#build-the-world-in-game)
- [Jobs, duty and whitelisting](#jobs-duty-and-whitelisting)
- [Configuration](#configuration)
- [Developing](#developing)
- [Licensing](#licensing)
- [Testing status](#testing-status)
- [Known limitations](#known-limitations)
- [Credits](#credits)

---

## Highlights

- **One look everywhere.** Menus, notifications, dialogs, the radial menu, inventory, HUD, banking, job menu, restaurant tools and more use the same *Night Shift* theme.
- **Built in game, not in config files.** Restaurants, farms, heists, fences, doors, garages, civilian jobs, mining and recycling spots and DJ areas are placed by standing where something goes and pressing a key. An **Admin** tab in the radial menu opens each creator.
- **Framework-agnostic scripts.** `vr-bridge` gives scripts one API for players, money, jobs, items, targets, society accounts, vehicles and voice. Resources written against it run on `vr-core`, QBCore, Qbox, ESX or ox_core.
- **QBCore scripts run on vr-core.** `vr-core` ships a QBCore compatibility layer and aliases (`qb-core`, `ox_lib`, `ox_inventory`, `oxmysql`, `ox_target`), so most third-party QBCore resources work without edits. See [Compatibility](#compatibility-with-other-frameworks).
- **Server-authoritative.** Money, items, stress, vehicle wear, wages, fuel and licences are decided on the server. The client only asks.
- **No outside calls.** Banking, garages, dealerships, weather and the rest run entirely on your own server and database.
- **Real jobs from player businesses.** A restaurant created in game is a real framework job: it appears in the job menu, pays wages from the restaurant's own account and shows as *Whitelisted*.
- **Zero-step database.** `vr-core` creates its own tables on first start. You only need an empty database.

## How it fits together

```
                          ┌────────────────────────────────────────────┐
   Gameplay resources     │ restaurant · farming · civjobs · mechanic  │
   (resources/[vr])       │ banking · garages · housing · mdt · …      │
                          └──────────────────────┬─────────────────────┘
                                                 │ Bridge.* / lib.*
                          ┌──────────────────────▼─────────────────────┐
   Platform               │ vr-bridge   vr-lib   vr-ui   vr-keybinds   │
   (resources/[important])│ vr-target   vr-inventory   vr-voice         │
                          └──────────────────────┬─────────────────────┘
                          ┌──────────────────────▼─────────────────────┐
   Core                   │ vr-core  ·  vr-mysql                        │
                          └────────────────────────────────────────────┘
```

| Layer | Resource | Role |
|---|---|---|
| Core | `vr-core` | Players, characters, money, jobs, gangs, items, vehicles, permissions, callbacks |
| Core | `vr-mysql` | FXServer ↔ MySQL/MariaDB (node-mysql2) |
| Platform | `vr-bridge` | One API over vr-core, Qbox, QBCore, ESX and ox_core. Events such as `playerLoaded`, `jobChanged`, `dutyChanged` |
| Platform | `vr-lib` | Callbacks, zones, points, streaming, locale, commands, keybinds and UI helpers (`lib.*`) |
| Platform | `vr-ui` | Notifications, prompts, menus, dialogs, progress bars, skill checks and the radial menu |
| Platform | `vr-keybinds` | Player-chosen key bindings for every script. Nothing is bound until the player picks a key |
| Platform | `vr-target` | Third-eye targeting with an aim-to-pick reticle |
| Platform | `vr-inventory` | Slot inventory, stashes, item metadata and spoilage bars |
| Platform | `vr-voice` | Proximity voice on FiveM's built-in mumble |

## Quick start

### Option A: txAdmin recipe (easiest)

1. In txAdmin choose **Deploy Server → Custom Template** and paste the raw URL of [`recipe.yaml`](recipe.yaml). If you forked this repository, open it first and change `v4lr4vn/VR-Framework` to your fork's name.
2. Fill in your Cfx.re licence key and database details when txAdmin asks. An empty database is enough.
3. After deployment, add yourself as an admin in `server.cfg` (see [Admin access](#admin-access)).
4. Add the maps, clothing and vehicles you want (see [Assets that are not in this repository](#assets-that-are-not-in-this-repository)) (`screenshot-basic`, used by `vr-camera` and MDT photos, is already included).

### Option B: manual install

Requirements:

- A FiveM server (FXServer), OneSync on, game build set in `server.cfg` (`sv_enforceGameBuild 3751`)
- MySQL or MariaDB with an **empty** database
- Node.js only if you want to rebuild a UI (compiled `html/` folders are included)

Steps:

1. Copy this repository's `resources/` folder into your server directory.
2. Copy `server.cfg.example` to `server.cfg`. Fill in `sv_licenseKey`, `mysql_connection_string` and your admin identifier.
3. Install `baseevents` (Cfx.re), which is not included here; it comes with the Cfx.re default resources. [`bob74_ipl`](https://github.com/Bob74/bob74_ipl), [`fivem-freecam`](https://github.com/Deltanic/fivem-freecam) and [`screenshot-basic`](https://github.com/citizenfx/screenshot-basic) are included in this repository, unmodified, under their MIT licences.
4. Start the server. The start order matters:

```cfg
ensure vr-mysql
ensure vr-core        # creates its tables on first start
ensure vr-ui
ensure vr-lib
ensure vr-keybinds
ensure vr-bridge
ensure vr-voice
ensure vr-target
ensure vr-inventory
ensure [vr]           # everything else, alphabetically
```

The first start prints the table install in the console. If your database user cannot create tables, import `resources/[important]/vr-core/sql/vrcore.sql` and `addons.sql` by hand. Other resources create their own tables when they first run.

### Admin access

```cfg
add_ace group.admin command allow
add_principal identifier.fivem:YOUR_FIVEM_ID group.admin
add_principal group.admin vrcore.god
add_principal vrcore.god vrcore.admin
add_principal vrcore.admin vrcore.mod
```

`vr-core` permission levels are `vrcore.god` > `vrcore.admin` > `vrcore.mod`. Every creator tool checks permissions on the server itself. Hiding the Admin tab is never what protects a tool.

## Compatibility with other frameworks

There are two separate things here.

**1. Running third-party QBCore scripts on vr-core (`Config.QBBridge = true`).** `vr-core` mirrors its `VRCore:*` events to `QBCore:*`, exposes the QBCore player object and callback style, and declares aliases so scripts that depend on these names resolve to the ValRavn versions:

| A script asks for | It gets |
|---|---|
| `qb-core` | `vr-core` |
| `ox_lib` (including `@ox_lib/init.lua`) | `vr-lib` |
| `oxmysql`, `mysql-async`, `ghmattimysql` | `vr-mysql` |
| `ox_inventory` and `qb-inventory` | `vr-inventory` |
| `ox_target`, `qb-target` and `qtarget` | `vr-target` |
| `pma-voice` exports | `vr-voice` |

It is a compatibility layer, not a guarantee. Scripts that reach into QBCore internals can still break. Test the ones you rely on.

**2. Running ValRavn scripts on another framework (through `vr-bridge`).** Resources that import `@vr-bridge/import.lua` call `Bridge.*` instead of vr-core directly. `vr-bridge` detects the running framework (`vr-core`, Qbox, QBCore, ESX or ox_core) and adapts. Resources marked **bridge** in the catalogue below can run that way. Resources marked **core** call `vr-core` directly and need it.

Not covered yet: Qbox/ESX/ox_core *shims* that let their own scripts run on vr-core. Only the QBCore layer exists.

### Bridge API (server)

```lua
Bridge.player(src)            Bridge.cid(src)           Bridge.source(cid)
Bridge.playerByCid(cid)       Bridge.coords(src)        Bridge.name(src)
Bridge.money(src, type)       Bridge.addMoney(...)      Bridge.removeMoney(...)
Bridge.getMeta(src, key)      Bridge.setMeta(src, k, v) Bridge.notify(src, ...)
Bridge.useItem(name, fn)      Bridge.isAdmin(src)       Bridge.on(event, fn)
Bridge.inventory.count/add/remove/canCarry
Bridge.target.addSphereZone/addModel
```

Events: `playerLoaded`, `playerUnloaded`, `jobChanged`, `gangChanged`, `dutyChanged`, `moneyChanged`, `societyChanged`. Add `'@vr-bridge/import.lua'` to `shared_scripts` and read `vr-bridge/README.md` for the full reference.

## Resource catalogue

**Type:** *bridge* = runs through vr-bridge (framework-agnostic), *core* = needs vr-core, *own* = no framework dependency.
**Licence:** see [Licensing](#licensing). "ValRavn" means original code under this repository's GPL-3.0.

### Platform (`resources/[important]`)

| Resource | Type | What it does |
|---|---|---|
| `vr-core` | – | Characters, money, jobs, gangs, items, vehicles, permission levels, QBCore layer |
| `vr-mysql` | – | MySQL/MariaDB connection (based on oxmysql, LGPL-3.0) |
| `vr-bridge` | – | Framework adapter and shared API |
| `vr-lib` | – | Shared library (based on ox_lib, LGPL-3.0) |
| `vr-ui` | – | Notifications, context menus, dialogs, progress, skill checks, radial menu |
| `vr-keybinds` | bridge | `/keybinds`: players choose their own keys |
| `vr-target` | bridge | Third-eye targeting (based on ox_target, GPL-3.0) |
| `vr-inventory` | bridge | Inventory and stashes (based on ox_inventory, GPL-3.0) |
| `vr-voice` | bridge | Proximity voice on built-in mumble |

### Economy

| Resource | Type | What it does |
|---|---|---|
| `vr-banking` | bridge | Personal and savings accounts, cards and ATMs, loans, credit scores, debt collection and repossession |
| `vr-dealership` | bridge | Dealerships with sales staff, a self-service showroom, bank finance and test drives |
| `vr-fence` | bridge | Money laundering contact and a pawn shop (aim-to-place) |
| `vr-cityhall` | bridge | Replace a lost ID or licence, Job Centre, business licences |

### Jobs and businesses

| Resource | Type | What it does |
|---|---|---|
| `vr-multijob` | bridge | The job menu: hold several jobs, switch, go on/off duty, leave a job. Whitelisted and Civilian groups |
| `vr-restaurant` | bridge (partly) | Restaurants and bars: owners, staff ranks and wages, kitchens, designed dishes, fridges and spoilage, tills, licences, hygiene, inspections. Every restaurant is a real job |
| `vr-farming` | bridge | Fields, crops, watering, harvest, a farm store and a well |
| `vr-civjobs` | bridge | Twelve civilian jobs: garbage, lumberjack, scrapyard, window cleaning, builder, trucker, taxi, bus, newspaper, hunter, fishing, treasure hunting. One level system, one crew system |
| `vr-mechanic` | core | Part wear and breakdowns, repairs with parts, performance and cosmetic tuning, billing |
| `vr-mining` | bridge | Rock faces, stone cracking and washing, gold panning, smelting, gem cutting and buyers. Places set in game |
| `vr-recycle` | bridge | Sorting line, dumpster diving, scrap searching, a materials trader, buyers and bottle banks. Places set in game |

### Law and medical

| Resource | Type | What it does |
|---|---|---|
| `vr-policejob` | core | Police job (port of Arius Scripts, Apache-2.0) |
| `vr-ambulancejob` | core | Ambulance job with death system (port of Arius Scripts, Apache-2.0) |
| `vr-mdt` | bridge | Mobile data terminal and dispatch for police, EMS and the DOJ. Sentences feed `vr-prison`; fines are handled here |
| `vr-prison` | bridge | Life inside prison: cells, outfits, work and workout stations, the canteen |

### Property and vehicles

| Resource | Type | What it does |
|---|---|---|
| `vr-housing` | core | Houses, apartments, furniture modeler, storage (CC BY-NC-SA, see Licensing) |
| `vr-realtor` | core | Real-estate tablet for housing (CC BY-NC-SA) |
| `vr-garages` | bridge | Public, job, gang and house garages and the impound |
| `vr-vehiclekeys` | bridge | Lock, engine, shared and lent keys, lockpicking, hotwiring, carjacking, locksmith |
| `vr-fuel` | bridge | Consumption, pumps, petrol cans and siphoning |
| `vr-doorlock` | bridge | Door locks with an in-game editor |

### Crime

| Resource | Type | What it does |
|---|---|---|
| `vr-bankheist` | bridge | Heists built in game: hack terminals, drill lock boxes, grab cash and gold, vault doors through `vr-doorlock` |
| `vr-signrobbery` | bridge | Steal road signs, carry them, scrap them for materials |

### Social and lifestyle

| Resource | Type | What it does |
|---|---|---|
| `vr-phone` | bridge | Foldable smartphone; the host other scripts add apps to |
| `vr-emotes` | core | Emotes, dances, walks, moods, live preview, player-chosen quick keys (GPL-3.0, based on rpemotes) |
| `vr-djbooth` | bridge | Placeable speakers, linked sound systems, boomboxes, car stereos, shared song queue |
| `vr-microphone` | bridge | Microphone stands and a megaphone item that carry your voice further (needs `vr-voice`) |
| `vr-clothing` | core | Clothing, barbers, tattoos, surgeons, outfits, character creation (MIT, based on illenium-appearance) |
| `vr-multicharacter` | core | Character select, creation with live preview, spawn choice |
| `vr-idcard` | core | On-screen ID cards and licences |
| `vr-camera` | bridge | Camera item; photos kept as items (CC BY-NC-SA) |
| `vr-cards` | bridge | Trading cards: booster packs, foils, binders, grading |
| `vr-notepad` | bridge | Write a note and leave it on the ground for others to read or tear up |
| `vr-wellness` | core | Stress relief: yoga spots and smoking |
| `vr-buffs` | bridge | Timed buffs: HUD icons, health and armour over time, stress relief, run and swim speed |
| `vr-pedscale` | core | Per-character height, synced to everyone |
| `vr-weather` | bridge | Synced weather, time and seasons with a configurable day length |

### Interface and server

| Resource | Type | What it does |
|---|---|---|
| `vr-hud` | bridge | Health, armour, hunger, thirst, stamina, oxygen, stress, vehicle info, voice, street, compass, postal codes. Players can drag the layout |
| `vr-loading` | own | Loading screen with real progress, news, tips, a music player (`web/config.js`) |
| `vr-pause` | own | Custom pause menu background, header and colours (CC BY-NC-SA) |
| `vr-discord` | own | Connection queue with optional Discord role allowlist and priority (CC BY-NC-SA) |
| `vr-noIdlecam` | own | Client-side idle camera toggle |

### Admin and tools

| Resource | Type | What it does |
|---|---|---|
| `vr-admintools` | bridge | The **Admin** tab in the radial menu; one click opens each creator |
| `vr-adminmenu` | core | Players, vehicles, inventories, teleports, world controls, noclip, spectate (CC BY-NC-SA; a placeholder until a custom menu is built) |

## Night Shift UI

Night Shift is the shared theme: a dark, flat style with hairline borders, small radii and one amber accent.

| Token | Value | | Token | Value |
|---|---|---|---|---|
| `--bg` | `#0A0E14` | | `--accent` | `#F5A524` |
| `--panel` | `#111823` | | `--accent-2` | `#FFC85C` |
| `--panel-2` | `#1A2433` | | `--ok` | `#3DD68C` |
| `--line-2` | `#223042` | | `--danger` | `#FF5A52` |
| `--text` | `#E6EDF5` | | `--info` | `#5AA9FF` |

Type is **IBM Plex Sans Condensed** with **IBM Plex Mono** for numbers. The fonts ship inside the resources, so nothing loads from a CDN except Font Awesome icons in the two ported housing screens.

Resources with their own Night Shift screens: `vr-ui`, `vr-inventory`, `vr-target`, `vr-keybinds`, `vr-hud`, `vr-multijob`, `vr-doorlock`, `vr-banking`, `vr-garages`, `vr-cityhall`, `vr-civjobs`, `vr-dealership`, `vr-bankheist`, `vr-mdt`, `vr-mechanic`, `vr-weather`, `vr-emotes`, `vr-cards`, `vr-clothing`, `vr-housing` (furniture modeler) and `vr-realtor` (tablet). Everything else draws its menus and dialogs through `vr-ui`, so it matches automatically.

## Build the world in game

Admins do not edit coordinates. Press the radial key (default **Z**), choose **Admin**, pick a tool and aim.

| Tab item | Opens | Command |
|---|---|---|
| Restaurants | Restaurant creator | `/restaurantcreator` |
| Farming | Fields, farm store, well | `/farmcreator` |
| Fence | Laundering contact, pawn shop | `/fencecreator` |
| Bank heists | Heist builder | `/heistcreator` |
| Doors | Door lock editor | `/doorlock` |
| Garages | Garage builder | `/garage` |
| Civ jobs | Civilian job setup | `/jobsetup` |
| DJ zones | Speaker areas | `/djzones` |
| Housing | Realtor tablet | `/housing` |
| Admin menu | Admin menu | `/admin` |

The commands still work. Add your own entries in `vr-admintools/config.lua`, or from another resource:

```lua
exports['vr-admintools']:AddTool({ id = 'mytool', label = 'My tool', icon = 'wrench', command = 'mytool' })
```

If you remove `vr-housing`, `vr-realtor` or `vr-adminmenu`, delete their entries from the `vr-admintools` config too, or they will show up in the tab and do nothing.

## Jobs, duty and whitelisting

- Jobs live in `vr-core`. `vr-multijob` shows the ones a character holds, split into **Whitelisted** and **Civilian**, and lets them switch, go on or off duty and leave.
- A job counts as whitelisted when it is in `Config.WhitelistJobs`, when its definition sets `whitelisted = true`, or when its type is a whitelisted type (`Config.WhitelistByType`, with exceptions in `Config.OpenJobTypes`).
- **Every restaurant is a job.** When an admin creates one, `vr-restaurant` defines a job named `rest_<id>` through `Bridge.defineJob`, with the owner's rank ladder as grades. Hiring, firing, rank changes, wage changes and ownership changes show in the job menu, and clocking in from the menu clocks in at the restaurant.
- Runtime jobs are re-created if `vr-core` restarts. `Bridge.canDefineJobs()` tells a script whether the running framework supports this (vr-core and QBCore do).

## Configuration

Every resource has a commented `config.lua`. The ones people change first:

| File | What to change |
|---|---|
| `server.cfg` | Licence key, hostname, `mysql_connection_string`, admin principals |
| `vr-core/config.lua` | `Config.QBBridge`, database auto-install, money types, defaults |
| `vr-multijob/config.lua` | Job limit (`MaxJobs`), whitelisted jobs, icons, descriptions |
| `vr-restaurant/config.lua` | Wage timing, licence days, hygiene, inspections, allowed picture hosts (`Config.Images`) |
| `vr-fuel/config.lua` | Prices, consumption, stations, jerry can item |
| `vr-buffs/config.lua` | Buff icons, colours, limits |
| `vr-weather/config.lua` | Day length and night share |
| `vr-bridge/config.lua` | Framework detection, notifications, admin groups |
| `vr-admintools/config.lua` | The tools in the Admin tab |

Resource-specific notes are in each folder's `README.md` where one exists.

## Developing

- **Write a script that works on any framework:** import `@vr-bridge/import.lua` and call `Bridge.*`.
- **Show UI in Night Shift:** use `lib.notify`, `lib.registerContext`, `lib.inputDialog` and `lib.addRadialItem`. They forward to `vr-ui`. For your own NUI, copy the tokens above.
- **Rebuild a UI:** `cd resources/[vr]/<resource>/web` (or `ui`), `npm install`, `npm run build`, then commit the rebuilt `html/` folder.
- **Create a job from your script:** `Bridge.defineJob(name, def)` and `Bridge.removeJobDef(name)` (server).
- **Use buffs and fuel from other scripts:**

```lua
-- vr-buffs (server). id is a player source or a citizen id.
-- AddBuff(source, citizenid, name, milliseconds, value): either of the first two may be nil
exports['vr-buffs']:AddBuff(src, nil, 'super-health', 60000, 1)
exports['vr-buffs']:HasBuff(src, 'luck')
exports['vr-buffs']:GetBuffTime(src, 'luck')
exports['vr-buffs']:RemoveBuff(src, 'luck')

-- vr-fuel (client)
exports['vr-fuel']:GetFuel(vehicle)
exports['vr-fuel']:SetFuel(vehicle, 100.0)
```

## Licensing

**The repository is a collection.** There is no single licence for every file.

- **Original ValRavn code** (everything marked "ValRavn" in the catalogue, plus `recipe.yaml`, this README and `server.cfg.example`) is licensed under the **GNU GPL v3.0**. See [`LICENSE`](LICENSE).
- **Derived resources keep their upstream licence**, which applies to that folder only. Do not remove the `LICENSE` and `NOTICE.md` files inside them.
- Full list with attribution: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

| Licence | Resources |
|---|---|
| GPL-3.0-or-later | `vr-inventory` (ox_inventory), `vr-target` (ox_target), `vr-emotes` (rpemotes), `vr-idcard`, `vr-loading` |
| LGPL-3.0-or-later | `vr-lib` (ox_lib), `vr-mysql` (oxmysql) |
| Apache-2.0 | `vr-policejob`, `vr-ambulancejob` (Arius Scripts) |
| MIT | `vr-clothing` (illenium-appearance) |
| **CC BY-NC-SA 4.0 (non-commercial)** | `vr-adminmenu`, `vr-camera`, `vr-discord`, `vr-housing`, `vr-pause`, `vr-realtor` (Project Sloth) |

### Non-commercial resources

The six CC BY-NC-SA resources may **not** be used commercially. If your server takes money in any form (paid access, perks, donations tied to benefits), remove them: delete the folders and their `ensure` lines, and clear their entries from `vr-admintools/config.lua`. Other resources only talk to `vr-housing`, `vr-camera` and `vr-adminmenu` through run-time checks (for example the MDT's property list and `vr-multicharacter`'s house spawns), so the framework starts without them. That path has not had a full in-game test.

### Assets that are not in this repository

Maps, clothing packs, vehicle packs and a few extras have their own authors and licences. They are **excluded** by `.gitignore` and are not part of this project. Bring your own:

- `[maps]`, `[clothing]`, `[cars]` (the example `server.cfg` ensures `[maps]` and `[clothing]`; remove those lines if you have none)
- `lvc`, `wk_wars2x`, `zapquake`
- Dependency installed separately: `baseevents` (Cfx.re)

## Testing status

Honest summary of what has and has not been checked on a running server.

- **Checked on a live server by the author during development:** most of the older resources (core, inventory, targeting, HUD and the like).
- **Rewritten or changed recently and covered by automated Lua tests, but not yet played through together:** `vr-prison`, MDT fines, `vr-mining`, `vr-recycle`, `vr-notepad`, `vr-buffs`, `vr-fuel`, `vr-microphone`, `vr-signrobbery`, the QBCore layer and the `provide` aliases.
- **Not tested at all:** running the bridge-native resources on Qbox, ESX or ox_core, and running without the six non-commercial resources.

If you hit a bug, open an issue with the console output and the resource name.

## Known limitations

- `Bridge.defineJob` only works on `vr-core` and QBCore. On other frameworks `vr-restaurant` still runs, but restaurants are not added to the job menu.
- A restaurant's job is lost if `vr-core` restarts without `vr-restaurant`. It is re-created within seconds once `vr-restaurant` runs.
- `vr-housing` and `vr-realtor` load Font Awesome icons from a CDN, so those icons need internet access on the player's machine.
- A few resources are not in Night Shift yet: `vr-phone` (still in development), `vr-adminmenu` (a placeholder until a custom menu is built), `vr-camera`, `vr-pause`, `vr-discord`.
- The compatibility layer covers QBCore only. Qbox, ESX and ox_core scripts do not run on vr-core yet.
- There is no export alias for `ox_lib` itself, only for `@ox_lib/` path imports. Scripts that call `exports.ox_lib:…` directly may need `vr-lib` substituted by hand.
- Several third-party maps and clothing packs are not shipped, so a fresh install has no custom MLOs until you add them.

## Credits

- **ValRavn**: the framework, `vr-core`, `vr-bridge`, `vr-ui` and the original gameplay resources.
- **Overextended**: ox_lib, oxmysql, ox_inventory and ox_target, the basis of `vr-lib`, `vr-mysql`, `vr-inventory` and `vr-target`.
- **Project Sloth** (and contributors Xirvin, OK1ez, Walter): the basis of `vr-adminmenu`, `vr-camera`, `vr-discord`, `vr-housing`, `vr-pause` and `vr-realtor`.
- **Arius Scripts**: the basis of `vr-policejob` and `vr-ambulancejob`.
- **uyuyorum**: um-idcard, the basis of `vr-idcard`.
- **snakewiz and iLLeniumStudios**: illenium-appearance, the basis of `vr-clothing`.
- **TayMcKenzieNZ and contributors, White Custom (WC Emotes)**: rpemotes, the basis of `vr-emotes`.
- **BlockBa5her**: nearest-postal data used in `vr-hud`.
- **Bob74** (bob74_ipl), **Deltanic** (fivem-freecam) and **Cfx.re** (screenshot-basic): included unmodified under the MIT licence. **Cfx.re** (baseevents) is installed separately.
- Ideas for `vr-buffs`, `vr-fuel`, `vr-microphone` and `vr-signrobbery` come from Project Sloth's `ps-*` scripts and the `cc-fuel` / LegacyFuel family. The ValRavn versions are written from scratch.

Thank you to everyone whose work this builds on.
