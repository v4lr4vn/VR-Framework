# vr-farming

Fields, crops, watering and harvest. Everything is placed in game by aiming, nothing is typed into a config file.

It makes the raw ingredients. Restaurants and bars (vr-restaurant) turn them into meals and drinks.

## How it plays

1. An admin places fields, a farm store and a well with `/farmcreator`.
2. Buy seeds, a watering can and fertiliser at the farm store.
3. Use a seed from your bag while standing in a field. It plants just in front of you.
4. Fill the can at a well, then use the target on a plant to water it. Add fertiliser if you have it.
5. When the plant is ripe, target it and harvest. The crop goes into your bag with a quality (Poor, Good, Great).
6. Sell crops to the farm store, or keep them for a restaurant.

Looking after a plant matters. A watering lasts a limited time, and a plant that stays dry gets sick. A sick plant gives fewer crops at a lower quality, and a dead one has to be dug up.

## Placing things

Stand where you want it and type `/farmcreator` (admins only).

- **Field**: walk round the edge and press **E** at each corner (3 to 40). **Backspace** undoes the last corner, **Enter** saves, **X** cancels. The field is exactly the shape you drew, so it can be a rectangle, an L, anything. Then pick which crops may grow there (pick none for all crops) and tick **Irrigated field** if the land already has irrigation: plants there water themselves and never need a can. While the menu is open every field shows as green walls, with its crops floating above it.
- **Farm store**: aim where the seller stands.
- **Well**: aim at the water. Players fill their can here.

Open a spot from the list to go there, aim and move it, rename it, change the person model, change which crops a field grows or whether it is irrigated, redraw a field's outline (plants outside the new shape are removed), change the radius of an old round field, set the store's buy price multiplier, or remove it. Removing a field removes the plants growing in it.

Spots are saved in `vr_farm_spots`, plants in `vr_farm_plants` and watering can charges in `vr_farm_cans`.

## Rules (config.lua)

| Setting | Default | Meaning |
|---|---|---|
| `growthScale` | 1.0 | Speed of everything. `0.1` is ten times faster, good for testing |
| `maxPlantsPerPlayer` / `maxPlantsPerField` | 40 / 150 | Limits |
| `spacing` | 0.9 | Closest two plants may be, in metres |
| `protectMinutes` | 30 | Only the owner can harvest for this long after it ripens |
| `witherMinutes` | 90 | A ripe crop nobody picks dies after this |
| `graceMinutes`, `dieMinutes` | 8, 30 | How long a plant can be dry, then how long until it dies |
| `fertiliserGrowth`, `fertiliserYield` | 1.25, 1.3 | What fertiliser does |
| `seedBack` | 0.4 | Chance of getting seeds back when you harvest |
| `canCapacity` | 8 | Waterings in a full can |

Time while the server is off does not count, so a restart never kills anyone's crops.

## Crops

Nine crops come with it: wheat, corn, potato, carrot, cucumber, onion, lettuce, tomato and pumpkin. A crop can be set to grow back after harvest with `regrow` (the share of its growth it goes back to), but none use it yet. Each crop has its own grow time, how long one watering lasts, yield, store price and seed price in `Config.Crops`. Add a crop by adding a row and the matching items to vr-inventory (the crop is its own name, the seed is `<name>_seed`).

The items are added to `vr-inventory/data/items.lua` by the install package. There are no item images yet, so they show the inventory's missing image until you add `<item>.png` files.

## Quality

Quality comes from the plant's health at harvest (80+ is Great, 50+ is Good, lower is Poor). It changes how many you get and the sell price, and it is stored on the item as `metadata.quality` (1, 2 or 3) so restaurants can use it.

## Plant models

Each stage uses the first prop in its list that exists in your game, so a missing prop never breaks anything. Change them in `Config.Models` and `Config.CropModels`. If none of a stage's props exist the plant is invisible but still works through its target.

## Events and exports

```lua
AddEventHandler('vr-farming:bought', function(src, cid, item, count, total, spotId) end)
AddEventHandler('vr-farming:sold', function(src, cid, item, count, total, spotId) end)

exports['vr-farming']:GetCropInfo('wheat')   -- the crop's config row
exports['vr-farming']:GetQuality(3)          -- { label = 'Great', yield = 1.2, price = 1.3 }
```

## Install

1. Make sure vr-bridge, vr-lib and vr-inventory are running.
2. The package adds the items to vr-inventory. Restart vr-inventory.
3. `ensure vr-farming` (it is inside `[vr]`, so it starts with the rest).
4. Stand somewhere and use `/farmcreator`.

Everything is checked on the server: distances, how long an action took, what you carry, who owns a plant and how much time has passed. A player cannot grow faster or pick someone else's crop early.
