# vr-fence

Two places to get rid of what you stole, both placed in game by aiming. No coordinates in a config file.

- **Laundering contact**: turns `black_money` into clean cash for a cut.
- **Pawn shop**: buys gold bars and jewelry for clean cash.

Heist cash from vr-bankheist is paid as `black_money`, and gold and jewelry are paid as items, so these two are where it turns into money you can spend.

## Placing spots

1. Stand where the person should stand and type `/fencecreator` (admins only).
2. Pick Add a laundering contact or Add a pawn shop. The menu hides and you aim like in the heist creator: a marker follows your crosshair, left click places it, right click cancels. The person is placed facing back toward where you were standing.
3. Open the spot from the list to go there, aim and move it, rename it, change the person model, or remove it.
4. Each spot can have its own rate: for laundering it is the share you get back (0.7 is 70%), for the pawn shop it multiplies every price. Leave it at 0 to use the config.

Spots are saved in the database (`vr_fence_spots`). While the creator menu is open you can see every spot in the world as a ring with its name.

## Laundering

Players use the target on the person and choose how much dirty money to clean. They hand it over (a few seconds), the dirty money is taken right away, and the clean cash is ready after a wait. They can walk away and come back: the same menu shows each deal with the time left, and a Collect button once it is ready. Deals are saved in the `vr_fence_jobs` table, so they survive restarts and relogs. A message tells the player when a deal is ready if they are online.

| Setting | Default | Meaning |
|---|---|---|
| `rate` | 0.7 | Share paid back. The rest is the fee |
| `min` | 500 | Smallest deal |
| `maxPerDeal` | 25000 | Biggest single deal |
| `maxPerWindow` | 75000 | Most one character can clean in the window |
| `windowMinutes` | 60 | Length of that window |
| `handoverSeconds` | 3 | How long the hand over takes |
| `minutesBase`, `minutesPer1000`, `minutesMax` | 2, 1.5, 30 | Wait before the cash is ready, grows with the amount |
| `maxOpen` | 3 | Deals a character can have waiting at once |

The window is kept in memory, so a restart resets everyone's allowance.

## Pawn shop

The target opens a menu of everything in the bag that the shop buys, with a price each. Sell one item, a number of them, or Sell everything. Prices are in `Config.Pawn.items`: add any item name with a price to make it buyable. The default list covers gold bars and the whole jewelry set that comes with vr-inventory.

## Events

```lua
AddEventHandler('vr-fence:handedOver', function(src, cid, dirty, paid, spotId) end)
AddEventHandler('vr-fence:laundered', function(src, cid, dirty, paid, spotId) end) -- when the cash is collected
AddEventHandler('vr-fence:sold', function(src, cid, item, count, total, spotId) end)
```

## Install

1. Make sure vr-bridge and vr-lib are running.
2. `ensure vr-fence`.
3. Stand somewhere and use `/fencecreator`.

Everything is checked on the server: the amount, the price, the distance to the spot and the hand over time. Players can not set prices or skip the wait.
