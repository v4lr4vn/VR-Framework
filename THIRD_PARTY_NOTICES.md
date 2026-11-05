# Third-party notices

The ValRavn Framework is a collection. Original ValRavn code is under the GNU GPL v3.0 (see `LICENSE`). The folders below are derived from, or depend on, other people's work and keep their own licence. Each folder holds its own `LICENSE` (and `NOTICE.md` where present). Do not remove them.

## Derived resources

| Folder | Based on | Author | Licence |
|---|---|---|---|
| `resources/[important]/vr-lib` | ox_lib | Overextended | LGPL-3.0-or-later |
| `resources/[important]/vr-mysql` | oxmysql | Overextended | LGPL-3.0-or-later |
| `resources/[important]/vr-inventory` | ox_inventory | Overextended | GPL-3.0-or-later |
| `resources/[important]/vr-target` | ox_target | Overextended | GPL-3.0-or-later |
| `resources/[vr]/vr-emotes` | rpemotes, via WC Emotes V5 | TayMcKenzieNZ and contributors; White Custom | GPL-3.0 |
| `resources/[vr]/vr-idcard` | um-idcard | uyuyorum | GPL-3.0 |
| `resources/[vr]/vr-policejob` | Arius Scripts police job | Arius Scripts | Apache-2.0 |
| `resources/[vr]/vr-ambulancejob` | Arius Scripts ambulance job | Arius Scripts | Apache-2.0 |
| `resources/[vr]/vr-clothing` | illenium-appearance | snakewiz, iLLeniumStudios | MIT |
| `resources/[vr]/vr-adminmenu` | ps-adminmenu | Project Sloth, OK1ez | **CC BY-NC-SA 4.0** |
| `resources/[vr]/vr-camera` | ps-camera | Project Sloth | **CC BY-NC-SA 4.0** |
| `resources/[vr]/vr-discord` | ps-discord | Walter, Project Sloth | **CC BY-NC-SA 4.0** |
| `resources/[vr]/vr-housing` | ps-housing | Xirvin, Project Sloth | **CC BY-NC-SA 4.0** |
| `resources/[vr]/vr-pause` | ps-pause | Project Sloth | **CC BY-NC-SA 4.0** |
| `resources/[vr]/vr-realtor` | ps-realtor | Xirvin, Project Sloth | **CC BY-NC-SA 4.0** |

**CC BY-NC-SA 4.0 resources are non-commercial.** They may be used and modified only for non-commercial purposes, with attribution, and changes must be shared under the same licence. If your server makes money, remove them (see the README).

The Apache-2.0 resources carry the original `LICENSE`. Files changed from the original are modified for `vr-core`/`vr-bridge`; the original copyright and attribution notices stay in place.

## Data

| Where | What | Licence |
|---|---|---|
| `vr-hud` postal data | nearest-postal by BlockBa5her | MIT |

## Replaced (no code included)

`vr-loading` replaced a stand-in loading screen (bd_loadingscreen by BebikDEV, GPL-3.0). The current screen is new code and none of the old files ship. The GPL-3.0 `LICENSE` that came with it stays in the folder.

## Inspiration only (no code copied)

`vr-buffs`, `vr-microphone`, `vr-signrobbery` and `vr-fuel` are written from scratch for this framework. Their behaviour was inspired by Project Sloth's `ps-buffs`, `ps-microphone` and `ps-signrobbery`, and by the `cc-fuel` and LegacyFuel family of scripts.

## Bundled dependencies (unmodified)

These are other people's resources that the framework needs. They are included as they are, under the MIT licence. Each folder keeps its own `LICENSE` file with the original copyright notice. Do not remove it.

| Folder | Author | Licence |
|---|---|---|
| `resources/[important]/bob74_ipl` | Bob74 | MIT |
| `resources/[important]/fivem-freecam` | Deltanic | MIT |
| `resources/[vr]/screenshot-basic` | The CitizenFX Developers (Cfx.re) | MIT |

## Dependencies that are not redistributed

Listed in the README and installed separately (or by the txAdmin recipe). Not part of this repository.

| Resource | Author | Licence |
|---|---|---|
| `baseevents` | Cfx.re | see cfx-server-data |

## Assets that are not included

Maps, clothing packs and vehicle packs (`[maps]`, `[clothing]`, `[cars]`) and the extras `lvc`, `wk_wars2x` and `zapquake` belong to their own authors and are excluded from this repository. Check each author's terms before you install or redistribute them.

## Fonts

IBM Plex Sans Condensed and IBM Plex Mono are used by the interface under the SIL Open Font License 1.1.
