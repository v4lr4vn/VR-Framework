# vr-keybinds

Players choose every key themselves. Nothing is bound until a player picks a key, so scripts can't fight over the same key.

- **First login:** once the character has spawned, a setup screen opens. The essentials (inventory, third eye, phone, radio) must be set before it closes. Everything else is optional.
- **Later:** `/keybinds`, or the "Open key bindings" action if the player binds it.
- **Saved per account** (Rockstar licence) in the `vr_keybinds` table, so the same keys follow the player on every character and every PC.
- **Combinations** with Shift, Ctrl or Alt are allowed. If a plain key and a combination share a key, holding the modifier fires only the combination.
- **Reserved keys:** W, A, S, D, Space, Esc, Enter, Backspace, T (chat) and F8 (console) can't be used. Keys GTA also uses (E, F, R, Tab and so on) show a warning first.
- **Keyboard only.** FiveM can't let a script set GTA's own key bindings, so this uses its own key layer, which reads the keyboard. Mouse buttons and controllers are not supported.
- **While another screen has focus** (MDT, inventory, chat), keys don't fire. Actions marked `allowInUi` (radio talk, voice range) still fire, but only on keys that can't type text: modifiers, F-keys, Caps Lock, Tab, Insert, Home and similar.

## Adding a key to a script

Scripts that already use `lib.addKeybind` from vr-lib need no changes: `defaultKey` becomes the suggestion shown in the menu.

For other scripts, load the import and register:

```lua
client_scripts {
    '@vr-keybinds/import.lua',
    'client/main.lua',
}
```

```lua
local bind = Keybinds.add({
    name = 'menu',
    label = 'Open the job menu',
    description = 'Shown under the label in the menu',
    suggested = 'J',
    essential = false,
    allowInUi = false,
    onPressed = function(self) end,
    onReleased = function(self) end,
})

bind:disable(true)
bind:getCurrentKey()
bind:isControlPressed()
bind:isBound()
```

The action id is `<resource>:<name>`. Use that id in `KeybindConfig.essential` to make an action required, and add the resource to a category in `config.lua`.

## Exports (client)

`register(def)`, `unregister(id)`, `getBind(id)`, `getKeyLabel(id)`, `isDown(id)`, `setBind(id, bind, mode)`, `checkBind(id, bind)`, `labelFor(bind)`, `keyData()`, `open()`, `isOpen()`.

A bind is `{ k = <Windows virtual key code>, m = nil | 'shift' | 'ctrl' | 'alt' }`. `mode` is `'replace'` or `'swap'` when the key is already in use.

## Admin

`/keybindsreset <id>` (ace `command.keybindsreset`) clears a player's keys. They see the setup screen again.
