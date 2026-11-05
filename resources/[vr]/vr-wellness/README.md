# vr-wellness

Ways to lower stress, for vr-core + vr-hud. Stress is only ever changed on the server.

- **Yoga:** go to a yoga spot (blip on the map), target it, "Do yoga". 30 s, removes 25 stress, 10 minute cooldown.
- **Smoking:** use a `cigarette` item (needs a `lighter` in the inventory, not used up). 12 s, removes 8 stress, uses the cigarette up, 45 s cooldown.
- Press **X** to stop either one early. Nothing is gained if you stop.
- Other resources can call `exports['vr-wellness']:Relieve(source, amount)` on the server (max 50 per call).

## Install
1. `ensure vr-wellness` after `vr-core`, `vr-ui`, `vr-target`, `vr-inventory` and `vr-hud`.
2. Add the cigarette item to `vr-core/shared/items.lua`, and a `cigarette.png` to the inventory images:

```lua
cigarette = { name = 'cigarette', label = 'Cigarette', weight = 10, type = 'item', image = 'cigarette.png', unique = false, useable = true, shouldClose = true, description = 'Needs a lighter.' },
```
3. Put cigarettes somewhere players can get them (a shop, or admin `/giveitem`).

## Yoga spots
Stand where you want one and run `/yogaspot` (needs ace `command.yogaspot`). It copies a line to paste into `Config.Yoga.spots`.
The starter spot is a guess on the Del Perro pier, so check it before you rely on it.
