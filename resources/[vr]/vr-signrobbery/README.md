# vr-signrobbery

Steal road signs, carry them around and scrap them for materials.

- **Stealing:** aim at a sign from `Config.Signs` with the third eye and choose *Steal Sign*. A skill check and a progress bar follow. The server checks distance, the per-player cooldown and the hourly limit, and removes the sign for everybody, including players who join later. Signs come back when the server restarts.
- **Carrying:** use the sign item to hold it. Use it again to put it away. It drops if you die, stop the animation or lose the item.
- **Scrapping:** at `Config.Scrap.coords` choose *Scrap Sign*, pick a sign and receive materials from `Config.Scrap.items`.
- **Police:** `Config.Dispatch.chance` is the chance that a theft sends a 10-10 alert through vr-mdt.

All checks run on the server. The client only asks, shows progress and displays results.

## Items

Each sign needs an inventory item with the name from `Config.Signs` (`stopsign`, `yieldsign`, ...). The images ship in `images/`. The materials from `Config.Scrap.items` have to exist as items as well.

## Credits

Written by ValRavn. The idea of stealing and scrapping road signs is common on FiveM servers. No code from other resources is used.
