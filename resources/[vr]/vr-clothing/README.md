# vr-clothing

Clothing shops, barbers, tattoo parlours, plastic surgeons, saved outfits, job outfits and the character creator for vr-core.

## Credits and licence

Based on [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) by iLLeniumStudios, which is based on fivem-appearance by snakewiz. Released under the MIT licence, see `LICENSE`.

## What changed from illenium-appearance

- Renamed to `vr-clothing`, including events, exports and database tables.
- Only vr-core is supported. The ESX, ox_core and Qbox code, the qb-target and qb-radialmenu code, and the one-time migration commands from other clothing scripts were removed.
- Tables are `vr_clothing_skins`, `vr_clothing_outfits`, `vr_clothing_outfit_codes` and `vr_clothing_job_outfits`. On the first start they are created and filled from the old `playerskins`, `player_outfits`, `player_outfit_codes` and `management_outfits` tables, which are left untouched as a backup.
- Scripts that still call `illenium-appearance` or `fivem-appearance` exports, or trigger `illenium-appearance:client:` events, keep working.

## Look

The editor is in the Night Shift style. Colours and corner sizes are set in `shared/theme.lua` (sent to the UI as CSS variables), so a different look needs no rebuild of the UI. `dist/nightshift.css` adds the font (IBM Plex Sans Condensed, shipped in `dist/fonts`), the amber accent and the Save button. The UI code itself is unchanged.

## Convar

`setr vr-clothing:locale en`
