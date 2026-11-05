# vr-bridge 2.0

One API that every ValRavn script uses, so the same script runs on **vr-core, Qbox, QBCore, ESX and ox_core**.
It works like jim_bridge: a script adds the loader to its manifest and gets a `Bridge` table in its own resource.

```lua
dependencies { 'vr-bridge', 'vr-lib' }

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
}
```

`@vr-bridge/mysql.lua` loads the `MySQL` helper from vr-mysql or oxmysql, whichever the server runs.

## What it finds on its own

| Part | Checked in this order | Convar to force it |
|---|---|---|
| Framework | vr-core, qbx_core, qb-core, es_extended, ox_core | `vr_bridge:framework` |
| Inventory | vr-inventory, ox_inventory, qs-inventory, ps-inventory, lj-inventory, qb-inventory, then the framework's own | `vr_bridge:inventory` |
| Target | vr-target, ox_target, qb-target, then a built-in "press E" fallback | `vr_bridge:target` |
| Database | vr-mysql, oxmysql | `vr_bridge:database` |
| Society money | the framework (vr-core, ox_core, esx_addonaccount), Renewed-Banking, qb-banking, okokBanking, fd_banking, qb-management, then its own table | `vr_bridge:society` (use `bridge` for its own table) |
| Fuel | vr-fuel, ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel, Renewed-Fuel, okokGasStation, qs-fuelstations and more | `vr_bridge:fuel` |
| Vehicle keys | vr-vehiclekeys, qbx_vehiclekeys, qb-vehiclekeys, Renewed-Vehiclekeys, wasabi_carlock, MrNewbVehicleKeys, qs-vehiclekeys, cd_garage, okokGarage and more | `vr_bridge:keys` |
| Voice | vr-voice, pma-voice | `vr_bridge:voice` |
| Notify and text UI | vr-ui, ox_lib, then the framework | `vr_bridge:notify`, `vr_bridge:textUI` |

The server console prints what it picked when vr-bridge starts.

Grades are 0-based on every framework. On ox_core, grade 1 is grade 0 here.

## Server

**Players**
- `Bridge.player(src)` returns `{ source, cid, name, firstname, lastname, dob, gender, phone, job, gang, money, metadata }`
- `job` is `{ name, label, type, grade, gradeName, isboss, onduty }`. `gang` is the same without `type` and `onduty`, or `nil`.
- `Bridge.cid(src)`, `Bridge.source(cid)`, `Bridge.name(src)`, `Bridge.license(src)`, `Bridge.playerByCid(cid)`, `Bridge.sources()`, `Bridge.players()`
- `Bridge.hasGroup(src, 'police' | { 'police', 'sheriff' } | { police = 2 })` returns the group name and grade, or `false`
- `Bridge.hasJob(src, filter, onduty)`, `Bridge.groups(src)`
- `Bridge.setJob(src, job, grade)`, `Bridge.setGang(src, gang, grade)`, `Bridge.setDuty(src, on)`
- `Bridge.getMeta(src, key)`, `Bridge.setMeta(src, key, value)`
- `Bridge.isAdmin(src)`, `Bridge.adminGroups()`, `Bridge.status(src)`, `Bridge.coords(src)`, `Bridge.save(src)`

**Money**
- `Bridge.money(src, 'cash' | 'bank')`, `Bridge.addMoney`, `Bridge.removeMoney`, `Bridge.setMoney`
- `Bridge.pay(src, amount, reason, 'cash' | 'bank' | nil)` takes bank first, then cash, and returns `true, account`
- Offline characters: `Bridge.chars.bank(cid)`, `Bridge.chars.addBank(cid, amount, reason)`, `Bridge.chars.takeBank(cid, amount, reason)`

**Society**
- `Bridge.society.balance(name)`, `.add(name, amount, reason)`, `.remove(name, amount, reason)`, `.set(name, amount, reason)`, `.backend()`

**Jobs and gangs**
- `Bridge.jobs()`, `Bridge.gangs()`, `Bridge.job(name)`, `Bridge.isJob(name)`, `Bridge.isGang(name)`
- `Bridge.defineJob(name, def)` creates or changes a job while the server runs, `Bridge.removeJobDef(name)` removes it, `Bridge.canDefineJobs()` says whether the framework supports it (vr-core and QBCore). `def` is `{ label, type, defaultDuty, offDutyPay, whitelisted, description, icon, source, grades = { [0] = { name, payment, isboss, display } } }`. `whitelisted = true` lists the job under Whitelisted in vr-multijob. `display` is a pay figure to show in the job menu when the job is paid by something other than the framework paycheck.
- `Bridge.groupLabel(name, 'job' | 'gang')`, `Bridge.grade(job, level)`, `Bridge.grades(job)`, `Bridge.jobsOfType('leo')`

**Items**
- `Bridge.inventory.count(src, item, metadata)`, `.has`, `.add(src, item, count, metadata, slot)`, `.remove(src, item, count, metadata, slot)`
- `.removeExact(src, item, count, metadata)`, `.canCarry`, `.search(src, item, metadata)`, `.getSlot(src, slot)`, `.setMetadata(src, slot, metadata)`
- `.items(src)`, `.item(name)`, `.itemDefs()`, `.label(name)`, `.itemExists(name)`, `.image(name)`
- `.registerStash`, `.openStash`, `.stashItems`, `.stashAdd`, `.stashRemove`, `.registerShop`, `.clear`, `.confiscate`, `.giveBack`
- `Bridge.useItem(name, function(src, item) end)` registers a usable item on any framework. `item` has `name`, `slot`, `metadata` and `count`.
- `Bridge.usable(name)` returns the use function another resource registered.

**Vehicles**
- `Bridge.vehicleList()`, `Bridge.vehicleData(model)`, `Bridge.vehicleLabel(model)`
- `Bridge.vehicle.giveKeys(src, vehicle, plate)`, `Bridge.vehicle.setFuel(vehicle, amount)`

**Voice**
- `Bridge.voice.playersInRadio(channel)`, `Bridge.voice.setRadio(src, channel)`, `Bridge.voice.call(exportName, ...)`, `Bridge.voice.has(exportName)`

**Other**
- `Bridge.notify(src, message, type, duration, title)`
- `Bridge.callback.register(name, fn)`, `Bridge.callback.await(name, src, timeout, ...)`
- `Bridge.db.query / single / scalar / insert / update`

**Events**: `Bridge.on(name, fn)` with `playerLoaded`, `playerUnloaded`, `jobChanged`, `gangChanged`, `dutyChanged`, `moneyChanged` and `societyChanged`.

## Client

- `Bridge.playerData()` returns the same shape as the server, plus `citizenid`. `Bridge.loggedIn()`, `Bridge.cid()`, `Bridge.job()`, `Bridge.gang()`
- `Bridge.hasGroup(filter, onduty)`, `Bridge.groups()`, `Bridge.money(account)`, `Bridge.getMeta(key)`
- `Bridge.needs()` returns `{ hunger, thirst, stress }` from 0 to 100. It works with QB metadata, esx_status and ox_core statuses.
- `Bridge.inventory.count(item, metadata)`, `.has`, `.search`, `.items()`, `.label`, `.image`, `.openStash(id, data)`
- `Bridge.target.addSphereZone / addBoxZone / addPolyZone / removeZone / addModel / removeModel / addEntity / addLocalEntity / addGlobalVehicle / addGlobalPlayer / addGlobalPed / addGlobalObject` and the matching `remove` calls. These use ox_target-style options and also work with qb-target.
- `Bridge.vehicle.getFuel(veh)`, `.setFuel(veh, amount)`, `.giveKeys(veh, plate)`, `.plate(veh)`, `.getProps(veh)`, `.setProps(veh, props)`
- `Bridge.voice.setRadio(channel)`, `.radioChannel()`, `.setProperty(key, value)`, `.setRadioAnim(enabled)`
- `Bridge.notify(message, type, duration, title)`, `Bridge.textUI.show(text)`, `Bridge.textUI.hide()`, `Bridge.requestModel`, `Bridge.requestAnimDict`, `Bridge.cache`
- **Events**: `playerLoaded`, `playerUnloaded`, `jobChanged`, `gangChanged`, `dutyChanged`, `playerData`, `needs` and `itemCount`.

## Exports on vr-bridge itself

`info`, `framework`, `adminGroups`, `societyBalance`, `addSocietyMoney`, `removeSocietyMoney`, `registerUsable` and `isUsable` (server), plus `info`, `playerData` and `loggedIn` (client).

vr-lib's `lib.addCommand` uses `adminGroups` for `restricted = true` commands, so admins on QBCore (`qbcore.god` / `qbcore.admin`) can use them too.
