# vr-idcard

On-screen ID cards and licences for vr-core. Using the item shows the card on screen to the nearest player, or to yourself when nobody is near.

Based on [um-idcard](https://github.com/alp1x/um-idcard) by uyuyorum {um} (GPL-3.0).

## What it does

- **Every new character gets a real card.** vr-multicharacter's starter `id_card` and `driver_license` are made here. They carry the character's name, date of birth, sex, nationality, height (from vr-pedscale) and citizen ID.
- **Photos are taken on first use.** The first time the owner uses a card, it takes their photo with hats, glasses and masks removed, then shows the card.
  - Someone else using a card that has no photo yet sees it blank. It never photographs whoever is holding it.
- **Photos are stored in the database** (`vr_mugshots`, created on first start). They show up straight away, with no restart and no upload service, and they're deleted with the character.
- **Old cards renew themselves.** Cards made before vr-idcard are swapped for a new one when their owner uses them.

## Config (`config.lua`)

- **`mugshotsUpload`:**
  - `'database'` (default)
  - `'fivemanage'`: needs `set fivemanage:key "TOKEN"` in server.cfg.
- **`licenses`:** one entry per card item, each with a header, background colour and prop. The item must also exist in `ox_inventory/data/items.lua`.
  - **Badges:** put a png in `web/assets/badges/` and set `badge = 'name'` on the licence. The card then shows that badge with the holder's job grade.
- **`settings`:** close key, auto close, and photo scale.

## For other resources

```lua
exports['vr-idcard']:CreateMetaLicense(source, 'driver_license')      -- give a filled-in card
exports['vr-idcard']:CreateMetaLicense(source, { 'id_card', 'weaponlicense' })
exports['vr-idcard']:IsCard('id_card')                                 -- true
```

## License

GPL-3.0, the same as the original.
