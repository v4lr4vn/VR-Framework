# vr-multicharacter

Character select, character creation and spawn choice for vr-core, in one resource. Night Shift look. It replaces the old `vr-multicharacter` screen and the separate `vr-spawn` resource.

## The flow

1. **Select.** The characters on the licence are listed on the left, the selected one stands in the apartment in the middle, and their details sit on the right (date of birth, nationality, phone, job, cash, bank, last played). The preview ped wears the character's saved clothes, face and tattoos from vr-clothing and plays a quiet idle pose. Drag the middle to turn them, or use the arrows. **Face** and **Body** move the camera between a close shot and a full-length one.
2. **Create.** Name, date of birth, gender, nationality and (with vr-pedscale) height. The preview ped changes live with gender and height. A new character is sent straight to `Config.FirstSpawn`, and the clothing creator opens on arrival for face, hair and skin.
3. **Spawn.** Returning characters get a map (the same dispatch map vr-mdt uses) with their spawn options: **Last location**, **their houses**, **Work** (if their job has a workplace spawn) and **The City** (public spots). Click a row or a pin, drag and scroll to move around the map, press Enter. **Backspace** goes back to character select (only while still on the map).

Keys: Up/Down browse, Enter play or spawn, N new character, Backspace back (spawn screen), Esc back (create screen).

## Config

Everything is in `config.lua`.

| Setting | What it does |
|---|---|
| `Config.Interior`, `PedCoords`, `CamCoords`, `HiddenCoords` | The apartment the preview ped stands in and where the camera sits. |
| `Config.IdleAnim` | Pose for the preview ped. `nil` to turn it off. |
| `Config.MinAge` | Youngest allowed character. `0` turns the check off. Checked in the page and again on the server. |
| `Config.DefaultNumberOfCharacters`, `PlayersNumberOfCharacters` | Slots per player, with per-licence overrides. |
| `Config.EnableDeleteButton`, `customNationality`, `Tagline` | Delete button, free-text nationality, the line at the bottom right of the screen. |
| `Config.FirstSpawn` | Where brand new characters appear. |
| `Config.ShowSpawnMenu` | `true`: every returning character gets the map. `false`: only characters that own a house do; the rest go straight to their last location. |
| `Config.JobSpawns` | `{ jobname = { label, coords } }`. Shows a **Work** row to people with that job. |
| `Config.PublicSpawns` | The **The City** list. Empty the table to remove it. Ground height is snapped automatically, but a spot inside a building spawns people inside it, so check each one after editing. |
| `Config.Map` | World-to-map numbers for the picture in `web/map.jpg`. They must match vr-mdt's `Config.Map`. |

## Houses

vr-housing registers itself: owned and keyed properties show up on the map, and a character that logged out inside a property comes back inside it. Housing that uses the qb-houses tables (`player_houses` + `houselocations`) works automatically. Any other housing script can offer houses:

```lua
exports['vr-multicharacter']:RegisterHouseProvider(function(source, citizenid)
    return { houses = { { id = 'grove_12', label = 'Grove St 12', coords = vector4(x, y, z, heading) } } }
end, 'myhousing:client:enterHouse') -- optional client event that takes them inside (gets the id)
```

`exports['vr-spawn']:RegisterHouseProvider` still works (this resource provides that name), and so do the `vr-spawn:server:begin` and `vr-spawn:client:entered` events. When an enter event has taken the player inside, it should fire `TriggerEvent('vr-spawn:client:entered')`; the screen stays faded out until then, for up to 15 seconds.

## The map

`web/map.jpg` is vr-mdt's dispatch map (its tile pyramid stitched into one image), so there is no dependency on vr-mdt running. If you replace the map in vr-mdt, rebuild this picture from the same tiles and keep `Config.Map` in step.

## Preview without launching the game

Serve the `web` folder with any static server and open `index.html?demo` (add `&view=create`, `&view=spawn` or `&view=delete`). The page then runs on sample data and nothing is sent to the game.

## Files

```
vr-multicharacter/
  fxmanifest.lua  config.lua  guard.lua  countries.json  locales/en.lua
  client.lua         select + create: preview ped, cameras, menu open/close
  server.lua         slots, create/delete/login, validation
  spawn_client.lua   spawn options, map data, placing the ped, enter-house wait
  spawn_server.lua   house providers, begin-spawn, change character
  web/               the page (index.html, style.css, app.js), map.jpg, fonts
```

## Notes

- The page has no external dependencies (the old one loaded Vuetify, axios and an icon font from CDNs) and scales to any resolution.
- Changed server behaviour: a failed creation (full slots, bad name, under age) now returns the player to the form with a message instead of leaving them on a black screen.
- Labels in the page are English. The `ui.*` strings in `locales/en.lua` are no longer read; the notification strings still are.
- `server.lua` and parts of `client.lua` carry over from the earlier port of qb-multicharacter (GPL-3). The page, camera work and spawn flow are new.
