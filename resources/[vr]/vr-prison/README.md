# vr-prison

Life inside the walls for the ValRavn framework. Sentences, the clock and release come from `vr-mdt` (the Prison tab, the booking flow at the PD and court sentences). This resource adds what happens to a prisoner once they are in.

- A cell, picked by who has the fewest people in it
- A prison outfit that goes on at intake and comes off at release (the real clothes are saved and put back)
- Work and workout stations that take time off the sentence and pay canteen credit
- A canteen that sells things for that credit
- An admin menu to place everything in game. No coordinates to type

## Install

1. Make sure `vr-mdt` is on the version that has the prison exports (2.2.1 or the release that shipped with this resource).
2. Put `vr-prison` in `[vr]`. It starts after `vr-mdt` and `vr-bridge` on its own.
3. Restart. The tables are created on the first start. There is no SQL file to import.
4. In game, as an admin, run `/prisonadmin` (or open the Admin radial and pick Prison).

## Placing things

`/prisonadmin` opens the menu. Pick what to add, then aim where it goes and left click. Right click cancels.

| Add | Where to aim |
| --- | --- |
| Work or workout station | Where the prisoner stands to do the job (kitchen sink, laundry machine, weights). Pick the type first |
| Canteen | At the counter |
| Cell | Where the prisoner wakes up. Place at least one per bed |

Pick any placed point in the list to rename it, move it, change a station's type, go to it or remove it. Markers and names show while the menu is open.

### The prison outfit

Dress your character the way you want prisoners to look, open `/prisonadmin` and choose **Save what I am wearing as the prison outfit**. It is stored for your character's sex (male or female freemode). Until you save one the defaults from `config.lua` are used.

## How a sentence plays out

1. An officer books someone at the PD (`/book`, or the third eye on the suspect) or a court sentences them. The MDT starts the clock and moves them inside.
2. This resource sees the sentence start. The prisoner is put in a cell, the real clothes are saved, the prison outfit goes on.
3. While inside they can work. Work stations only show for prisoners. Each shift is a progress bar and a skill check, then it takes time off and pays credit. Each station has a cooldown.
4. The canteen spends the credit on items.
5. When the time is up (or someone is released from the MDT) the clothes are put back. Credit that is left over is gone.

Time off for work is capped at half of the sentence (`Config.Cap.percent`) and the last minute is always served (`Config.Cap.keepSeconds`). Logging out and in again keeps everything: the cell, the credit and the outfit.

`/prisonstats` shows how much time work has taken off and how much credit a prisoner has. `/jailtime` (from the MDT) shows the time left.

## Config

Everything is in `config.lua`.

- `Config.Stations` has one row per station type: label, icon, how long the shift lasts, minutes off, credit paid, cooldown, skill check and animation. Add a row and it shows up in the admin menu.
- `Config.Canteen.items` lists what is for sale. Items your inventory does not know are skipped.
- `Config.Outfits` holds the default outfits.
- `Config.Cap` limits how much work can take off.
- `Config.Outfit.enforce` puts the outfit back on if something else changes it, for instance a relog that loads the saved look.

## For developers

Server exports:

```lua
exports['vr-prison']:IsInmate(source)        -- true while the player is serving a sentence
exports['vr-prison']:GetCredits(citizenid)   -- canteen credit
exports['vr-prison']:AddCredits(citizenid, n) -- add (or take with a negative number)
```

`vr-mdt` exports used by this resource: `PrisonStatus(cid)`, `PrisonInfo()` and `PrisonReduce(cid, seconds, keepSeconds)`. The `vr-mdt:server:prisonChanged` event drives everything.

Tables: `vr_prison_points`, `vr_prison_stats`, `vr_prison_outfits`.

## What is not here yet

Breakouts, contraband and guard tools are left for a later version.

## Licence

Written for the ValRavn framework. Idea reference only from other prison resources, no code is shared with them.
