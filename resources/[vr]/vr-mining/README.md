# vr-mining

Mining, stone cracking, stone washing, gold panning, smelting, gem cutting, jewellery and buyers.

Written from scratch for the ValRavn framework. Places are put down in game, there is nothing to import.

## Setup

1. Put `vr-mining` in `[vr]` and restart. The table is created on the first start.
2. As an admin run `/miningadmin`. Pick **Add a point**, choose the kind, aim where it goes and left click.
3. Open any placed point in the list to rename it, change its kind, move it, go to it or remove it.

## Kinds

- **Mine the rock**: needs a pickaxe, mining drill or mining laser. Gives stone and the odd ore.
- **Crack stone**, **Wash stone**: turn stone into ore and uncut gems.
- **Pan for gold**: needs a gold pan.
- **Smelter**: ore and carbon into copper, iron, steel, gold and silver ingots.
- **Jeweller bench**: cut gems and make rings, necklaces and earrings.
- **Sell ore and bars**, **Sell gems and jewellery**: buyers.

## Config

Everything is in `config.lua`. Each kind has a `mode`:

- `gather` does an action (progress bar and optional skill check) and rolls the `yield` table. Tools, items it uses up, how long the spot stays empty and tool breakage are all settings.
- `craft` shows a list of recipes (what it takes and what it gives).
- `sell` pays cash for the items in its `prices` table.

Add a row to `Config.Kinds` and it shows up in the admin menu. Items that your inventory does not know are hidden from recipe lists.

The server checks distance, tools and items, how long the action took, and rolls the rewards itself. The client only reports that it finished.

## Licence

Original work for the ValRavn framework.
