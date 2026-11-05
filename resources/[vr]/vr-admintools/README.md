# vr-admintools

An **Admin** tab in the radial menu (default key **Z**). It is only there for admins, and each item opens one of the in-game creators, so nobody has to remember or type the commands.

| Item | Command it runs | Needs |
|---|---|---|
| Restaurants | `/restaurantcreator` | vr-restaurant |
| Farming | `/farmcreator` | vr-farming |
| Fence | `/fencecreator` | vr-fence |
| Bank heists | `/heistcreator` | vr-bankheist |
| Doors | `/doorlock` | vr-doorlock |
| Garages | `/garage` | vr-garages |
| Civ jobs | `/jobsetup` | vr-civjobs |
| DJ zones | `/djzones` | vr-djbooth |
| Housing | `/housing` | vr-realtor |
| Admin menu | `/admin` | vr-adminmenu |

An item only shows while the resource it opens is running.

## Install

Put the folder in `resources/[vr]` (it starts with the rest of that folder, after `vr-ui` and `vr-bridge`). Nothing else to set up.

## Who sees the tab

Anyone `vr-bridge` calls an admin (`Bridge.isAdmin`: your `group.admin` / `command` ACE, or the framework's admin group). A player who has the ACE for only some of the commands (`add_ace group.x command.garage allow`) sees only those items. The server answers when the player loads and every `Config.RecheckSeconds` (30), so a promotion or demotion shows up within half a minute.

The tab is a shortcut and not a lock: every creator still checks permission itself. The old commands keep working.

## Add your own

In `config.lua`, add a row to `Config.Tools`:

```lua
{ id = 'mytool', label = 'My tool', icon = 'wrench', command = 'mytool', resource = 'my-resource' },
```

or from another resource (server side):

```lua
exports['vr-admintools']:AddTool({ id = 'mytool', label = 'My tool', icon = 'wrench', command = 'mytool' })
```

`icon` is a Font Awesome name without `fa-`. `resource` is optional.

## Notes

- Uses `exports['vr-ui']` for the radial menu. If `vr-ui` restarts, the tab is put back automatically.
- The `Housing` item runs `/housing`, which opens the realtor tablet. Whether an admin can use the tablet is decided by `vr-realtor` (`Config.RealtorPerms`).
