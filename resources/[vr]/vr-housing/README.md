# vr-housing

Houses, apartments, furniture and storage for **vr-core**. It's a port of [ps-housing](https://github.com/Project-Sloth/ps-housing) by Xirvin & Project Sloth (GPL-3.0, see `LICENSE`).

## Needs

vr-core, vr-mysql, ox_lib, ox_target, ox_inventory and fivem-freecam. ox_doorlock is only needed for MLO properties. Realtors use **vr-realtor** to list and sell properties.

## Setup

Nothing to import. The `properties` table creates itself on first start.

## How it ties into vr-core

- **Spawning:** owned and keyed properties show up as spawn options on the spawn map in vr-multicharacter. Logging out inside a property brings the character back inside it. If they lost their keys meanwhile, they come back at the front door.
- **Character select:** switching characters clears everything and reloads it for the new character.
- **Deleting a character:** their houses go back on the market with keys, furniture and the stash cleared. Their apartments are removed, and their keys to other people's properties are taken away. `Config.ReturnHousesToMarketOnDelete` controls the houses.
- **New characters:** with `Config.StartingApartment = true`, new characters get an apartment in `Config.StartingApartmentName`. They still spawn at vr-multicharacter's first spawn point (`Config.FirstSpawn`).
- **Storage:** every storage unit in a property opens the same ox_inventory stash, `property_<id>`. Only the owner, key holders and police inside during a raid can open it.
- **Wardrobe:** the wardrobe furniture opens the illenium-appearance outfit menu.

## Fixed from ps-housing

- Furniture prices, labels and limits come from the server's catalog. Before, the client sent the price.
- Only the owner can add or remove keys. Before, an operator-precedence bug let anyone do it. Keys can only go to someone standing in the property with you.
- Realtor changes go through a whitelist with grade checks (in vr-realtor). Before, any realtor could call any property method.
- An offline seller's money now really reaches their bank. Before, the query targeted a column that doesn't exist.
- A sale resets keys, furniture and the stash for the new owner.
- Removed the client-triggerable house migration, qb-inventory stash events and the apartment creation event.
- MLO doors are created and removed server-side through ox_doorlock. Realtors don't need the doorlock admin permission any more, and deleting a property removes its doors.
- Fixed: owner blips appearing for everyone, garden furniture never unloading, door updates losing the street name, and the shared furniture lists between properties.

## For other scripts

`exports['vr-housing']` (also reachable as `exports['ps-housing']`):

- Server: `IsOwner(source, propertyId)`, `registerProperty(data)`, `getMainDoor(propertyId, index)`.
- Client: `GetProperties()`, `GetProperty(id)`, `GetApartments()`, `GetApartment(name)`, `GetShells()`, `CreateTempShell(...)`.

It also fires the usual `qb-garages:client:addHouseGarage` / `removeHouseGarage` events, so a garage script can add house garages.
