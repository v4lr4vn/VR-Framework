# vr-hud 2.0

Player and vehicle HUD for vr-core, in the vr-ui theme. Written from scratch (Svelte 5 + Vite), no Vue, Quasar or jQuery.

## Install
1. Remove the old `vr-hud`, drop this folder in `resources/`, and `ensure vr-hud` after `vr-core`, `vr-voice` and `vr-inventory`.
2. Do not also run the `map` resource from Postal_Code_Map. This resource already ships its map textures in `stream/`.
3. The UI is pre-built in `html/`. To change it: `cd web && npm install && npm run build`.

## What it shows
- Health, armor, hunger, thirst, stamina, oxygen, stress. Each is Always, Auto (shown past a percentage) or Hidden, per player.
- Vehicle: speed, fuel, seatbelt/harness, engine, lights (low/high), indicators, gear (upgrade, see below).
- Voice: proximity bars, radio channel (only while on one), server ID.
- Street, compass, in-game time, nearest postal code.
- Custom minimap frame. On foot, the minimap and compass are hidden unless the player turns them on.
- Press **I** (or `/hud`) for settings. **Edit layout** lets the player drag every element. Settings and layout are saved per player (client KVP).

## Postals
`/postal <code>` draws a GPS route, `/postal` clears it. Exports: `getPostal()`, `getDistance()`, `getNearest()`.
Logic and data format from nearest-postal by BlockBa5her (MIT, see `data/NEAREST-POSTAL-LICENSE.txt`). Keep the original credit for the postal data.

## Gears (upgrade)
Off by default. Unlock per player with `exports['vr-hud']:SetGearsUnlocked(true)` or `TriggerEvent('vr-hud:client:SetGears', true)`, or set `Config.GearsUnlocked = true`.

## Kept for other resources
Events: `hud:client:UpdateNeeds`, `hud:client:UpdateStress`, `hud:server:GainStress`, `hud:client:UpdateHarness`, `seatbelt:client:ToggleSeatbelt`, `hud:client:ShowAccounts`. Commands: `/cash`, `/bank`. Client export: `SetSeatbelt(bool)`. Server export: `RelieveStress(source, amount)` (players can't relieve their own stress from the client).

## Not carried over from the old HUD
Buff and enhancement icons, nitrous bar, cruise indicator, altitude, cinematic bars, dev-mode overlay, the old settings menu, and the ox_inventory harness check (now `vr-inventory`).

## Minimap tuning
The radar is positioned from the frame's on-screen rect using ratios in `Config.Minimap`, taken from the previous HUD. If the map and frame don't line up on your resolution, adjust `map` and `blur` there.
