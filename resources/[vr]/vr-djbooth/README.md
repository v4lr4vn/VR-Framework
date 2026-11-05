# vr-djbooth

Speakers players buy, place and link together, plus boomboxes and car stereos. Each group of speakers plays from one shared song queue. Built for ValRavn on vr-core, ox_lib, ox_inventory and ox_target.

Version 2.0 was a full rewrite; 2.1 added the Range slider and boomboxes that stay put; 2.2 added the Range Booster and the link distance shown while placing; 2.3 lets admins set each area's max speakers and clear speakers with `/djclear`. Nothing from the old jim-djbooth port is left, so the code is ValRavn's own, and the old fixed DJ booths are gone.

## What players can do

- **Buy speakers** at YouTool: Wall, Ceiling, Floor and Large speakers, a Boombox, a Car Sound System and a Range Booster.
- **Place a speaker** by using the item. A see-through copy follows where you look and snaps to the surface:
  - Wall speakers sit flat against walls.
  - Floor speakers stand on floors and tables.
  - Ceiling speakers hang from ceilings.
- **Placement controls:**
  - `E` places.
  - Scroll turns it, and `Shift` + scroll turns it in small steps.
  - `Backspace` or right click cancels.
  - The outline is green when the spot is allowed and red when it isn't, with the reason shown.
  - **Link distance:** above the bar it shows the nearest speaker in the same place, how far away it is and the most it can be (for example *Links to Benny's Floor · 18.4 m away (max 20 m)*). A line is drawn to that speaker: green if the new one will link to it, amber if it's too far and will start a new group.
- **Where speakers can go:**
  - **Your home:** owner or key holder, while you're inside it.
  - **Your business:** inside its area, while you're on duty for that job.
  - **Limits:** each business area has its own max, set by admins (10 unless changed, up to 100), and 10 per home.
- **Linking:**
  - A new speaker joins the closest group in the same place within 20 m (100 m with a Range Booster). Otherwise it starts a new group.
  - Groups chain: each speaker only has to be in range of one speaker already in the group, not the first one.
  - In the panel's Speakers tab you can link speakers in the same place into the group (in range of any speaker already in it) or unlink them. You don't need to walk over to the far speaker.
- **The panel:** target a speaker and choose *Sound system*. It shows what's playing with a progress bar (click to jump), play/pause, stop, next, repeat (off / queue / song), shuffle and volume. It also has:
  - **Range slider:** how far the group (or boombox, or car) can be heard, 5 to 100 m. Until someone moves it, each speaker uses its own range; *Reset* goes back to that.
  - **Add box:** paste a YouTube link or a direct audio link (mp3, ogg, radio stream).
  - **Queue:** play now, move up or down, remove, clear.
  - **Group name:** click the pencil to rename the group.
- **Who controls it:**
  - **Business groups:** anyone on duty for that job.
  - **Home groups:** the owner and key holders.
  - **Admins:** can control any group.
- **Picking up:** target the speaker and choose *Pick up* to get the item back.
- **Range Booster:**
  - A small dish that goes on a wall, one per home or business, placed like a wall speaker.
  - While it's up, that place's speakers can link up to 100 m apart instead of 20 m. It doesn't play anything.
  - Anyone who can place speakers there can pick it up. Groups already linked stay linked; only new links go back to 20 m.
- **Boombox:**
  - Goes anywhere, one per character. Only its owner can use it or pick it up (the item comes back).
  - It stays where you put it, through logouts and restarts. Its music stops while you're offline.
  - Using another boombox while one is out shows a warning with the street the old one is on. *Keep the old one* cancels. *Place new boombox* places the new one and removes the old one for good (no item back).
- **Car Sound System:**
  - Use the item from the driver seat to install it (saved to the plate).
  - Open the stereo with `/stereo` from the driver or front passenger seat. It can be bound to a key in *Settings > Key Bindings > FiveM*.
  - Only whoever installed it (or an admin) can take it out again.

The queue keeps going on its own: the next song starts when one ends, even if the DJ walks away.

## How it sounds

- **Distance:** volume fades over each speaker's range (by default Wall 20 m, Ceiling 18 m, Floor 25 m, Large 35 m, Boombox 15 m, car 18 m; the panel's Range slider changes it up to 100 m). With linked speakers you hear the ones near you.
- **Walls:**
  - **Muffled:** when you and the speaker are in different buildings, or one of you is inside and the other outside.
  - **Slightly muffled:** when you're in another room of the same building.
  - **Not muffled:** a speaker on an outside wall sounds normal to people outside.
  - **Cars:** with the windows up and doors shut, a car's music is muffled from outside and full inside.
- **YouTube vs direct links:**
  - **YouTube:** plays in YouTube's own player, which can only be turned down, so "muffled" means quieter.
  - **Direct links:** if the site hosting the file allows it (CORS), they go through the browser's audio engine. That gives a real muffle filter and left/right panning as you turn. If the site doesn't allow it, the link still plays, with the same volume-only behaviour as YouTube.
- **Links that are refused:** direct links to IP addresses or local networks. Every listener's game downloads the file, so this stops it reaching a home network. `Config.AudioHosts` can limit direct links to a list of sites.

## Admins

- **`/djzones`** (admin) draws business areas in game:
  1. *Create a business area*.
  2. Enter the name, the vr-core job name and the max speakers.
  3. Walk to each corner and press `E` (`Backspace` undoes, `Enter` finishes, `X` cancels).
  4. Set the bottom and top height.

  Each area in the same menu shows how many speakers it has out of its max, and can be:
  - **Edited:** change its name and max speakers (1 to 100). Lowering the max below what's placed keeps those speakers; no more can go in until some are picked up.
  - **Cleared:** *Remove all speakers here* takes every speaker and the Range Booster in that area, after a confirmation showing how many.
  - Shown, teleported to, or deleted. An area that still has speakers in it can't be deleted, so clear it first.
- **`/djclear`** (admin) removes every placed speaker, Range Booster and boombox on the server, after a confirmation showing how many. Car sound systems stay. Nobody gets the items back, and each clear is written to the server console with the admin's name.
- **Business areas in config:** they can also go in `Config.Businesses` in `config.lua`, each with a fixed `id` that must never change once speakers are placed.
- **Removing speakers:** admins get *Remove speaker (admin)* on every speaker and Range Booster.

## Install

1. **Items:** the `ox_inventory/data/items.lua` block is already added in the ValRavn framework:
   ```lua
   ['speaker_wall']    = { label = 'Wall Speaker',     weight = 300,   stack = true,  close = true, description = 'Goes on a wall in your home or at your business.' },
   ['speaker_ceiling'] = { label = 'Ceiling Speaker',  weight = 200,   stack = true,  close = true, description = 'Hangs from a ceiling in your home or at your business.' },
   ['speaker_floor']   = { label = 'Floor Speaker',    weight = 800,   stack = true,  close = true, description = 'Stands on a floor or table in your home or at your business.' },
   ['speaker_large']   = { label = 'Large Speaker',    weight = 200,   stack = true,  close = true, description = 'A big club speaker for your business or home.' },
   ['boombox']         = { label = 'Boombox',          weight = 250,   stack = false, close = true, description = 'A portable speaker. Use it to set it down anywhere.' },
   ['car_stereo']      = { label = 'Car Sound System', weight = 300,   stack = true,  close = true, description = 'Install it from the driver seat of a vehicle.' },
   ['range_booster']   = { label = 'Range Booster',    weight = 200,   stack = true,  close = true, description = 'Goes on a wall in your home or business. Lets its speakers link up to 100 m apart.' },
   ```
2. **Shop:** the seven items are in the YouTool shop (`ox_inventory/data/shops.lua`).
3. **Database:** the six tables are created on first start: `vr_djbooth_systems`, `vr_djbooth_speakers`, `vr_djbooth_boomboxes`, `vr_djbooth_boosters`, `vr_djbooth_zones` and `vr_djbooth_vehicles`. Updating from 2.0 adds the `range_m` column to `vr_djbooth_systems` by itself.
4. **vr-housing:** needs the `IsInside` export, which is included in ValRavn's vr-housing.

## Config (`config.lua`)

- `Config.Speakers`: item → label, prop model, surface (`wall` / `floor` / `ceiling`) and hearing radius. If a model faces the wrong way once placed, set its `yaw` (usually `180`).
- `Config.Boombox` and `Config.CarStereo`: their items, radius, `/stereo` command and key, and who can use them.
- `Config.Booster`: the Range Booster's item, prop model (`prop_satdish_s_03`), link range (100 m) and how many per place (1).
- `Config.Range`: the Range slider's lowest and highest value and its step (5 to 100 m in 5 m steps).
- `Config.Limits`:
  - speakers per business (the default for new areas) and per home
  - the highest max an admin can give one area (`maxPerZone`, 100)
  - link range without a booster (20 m)
  - queue length (50)
  - placing and panel distances
- `Config.Businesses`, `Config.AudioHosts`, `Config.MasterVolume`, `Config.DefaultVolume`, `Config.StreamDistance`.
- `Config.Occlusion`: how much walls and car bodies muffle.

## Security

- **Server checks:** every request is checked again on the server: the item, the distance, where it is, job and duty, home keys and being inside, the routing bucket, and limits. Requests are also rate limited.
- **Item safety:** the item is taken before anything is saved and refunded if the save fails. Pickups and uninstalls check inventory space first.
- **Song length and errors:** these come from players' browsers. Someone who controls the group is trusted straight away. Anyone else needs a second listener to agree. One griefer can't skip songs or fake a length, and one player whose video is blocked in their country doesn't skip it for everyone.
- **Text from players and browsers:** titles and names are cleaned and length-limited on the server, and the panel only ever shows them as text.
- **Network:** no web calls, telemetry or update checks. The YouTube player script is only loaded once a YouTube song is in earshot.

## Things to check in game

- **Facing:** the speaker models and the Range Booster dish face the right way (`yaw` in config if not), and ceiling speakers hang the right way up.
- **Interiors:** speakers placed in MLO interiors show from every room. If one disappears from some angles, note which MLO so it can be looked at.

## Credits

- **Code:** written for ValRavn.
- **Font:** Inter (SIL Open Font License, `html/fonts/Inter-LICENSE.txt`).
