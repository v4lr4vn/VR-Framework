# vr-bankheist

Bank heists for ValRavn, built entirely in game. No coordinates in a config file: you stand where something goes and press a button.

A heist is a set of steps you place around a building: hack terminals, lock boxes to drill, cash and gold areas to grab from, cash registers, jewelry display cases, and vault doors that open through vr-doorlock. The same creator builds banks, shops and jewelry stores. Pick which one in Settings, Heist type: it changes what the police alert says. Steps can wait on each other, so a heist can run hack, then door, then drill, then loot.

## Making a bank

1. Stand in the bank and type `/heistcreator` (admins only).
2. Type a name and press Create. The alert point (where the police alert and map blip go) is set to where you stand. You can aim at a better spot later.
3. Press a step button (Hack terminal, Lock box, Cash area, Gold area, Cash register, Display case, Vault door). The panel hides and you aim in the world exactly like `/doorlock`: a marker follows your crosshair, left click places it, right click cancels. Cash and gold areas show their circle, and the mouse wheel changes the radius. Display cases do too, in small steps.
4. Open a placed step to set its options, pick what it needs first, re-aim it (the crosshair button), or remove it.
5. For a vault door step press Aim at a door, point at the door and click. Use Double door for a pair, then click both halves. The door is made in vr-doorlock for you, locked, and added to the step. You can also pick a door that already exists in vr-doorlock.
6. Press Reset heist to test again as often as you like.

Banks are saved in the database (`vr_bankheist_banks`) and cooldowns survive restarts (`vr_bankheist_state`). Doors made by the creator are removed again if you remove the step, remove the door from the step, or delete the bank. Doors you picked that already existed are never deleted.

### The panel

- **ALT** switches between Locked (mouse on the panel, camera frozen) and Free (walk and look around). Free mode ignores every key so walking can not change anything in the panel.
- Esc closes the panel.
- While it is open you see every step in the world: coloured rings, labels and lines that show what waits on what.
- The little buttons on each step are Go there (teleport), Aim and move, and Remove.

### The steps

| Step | What players do | Options |
|---|---|---|
| Hack terminal | Connect a laptop and hack the bank network in Odin's Eye | Host name, security tier 1 to 5, goal |
| Lock box | Hold E to drill. Watch the heat, a jammed drill can snap the bit | Drill time, difficulty, cash range, bonus item and chance |
| Cash area | Cash stacks sit in a row where you aimed, grab them inside the circle | Grabs, cash per grab, pile prop (presets in the list), radius |
| Gold area | Gold bars sit in a row where you aimed, grab them inside the circle | Grabs, bars per grab, bar prop (presets in the list), radius |
| Cash register | Hold on while the register is forced open once | Time, cash range, tool needed (kept), bonus item and chance |
| Display case | Smash the glass with the base game animation and take the jewelry | Smash animation, loot item and amount, rare item and chance, cash, radius |
| Vault door | Opens the chosen vr-doorlock doors when its requirement is done | Doors (up to 6), how it opens, how long it stays open |

**Needs first** works on hack terminals, lock boxes and vault doors, and any step can wait on one of them. Loops are refused.

Example: hack (goal vault) -> vault door (needs the hack) -> lock box and gold area (need the door).

### Vault doors and the game's own vault door

The vault door of the Fleeca banks is a normal game door object, so vr-doorlock locks and unlocks it like any other door. Unlocking only frees it. To make it swing open by itself the step has an Opens setting:

- `forward` and `reverse` swing the door open when the step completes (and shut again when it relocks). If it swings the wrong way, switch to the other one.
- `unlock` only frees the door, players push it open.

The swing speed is `Config.Vault.rate`.

### Hack goals

- `vault` completes the step so the next one can start (usually a vault door).
- `alarm` silences the police alert for that heist if it is finished before the alert fires.

### Shop heist

Stand in the shop, create a heist, set Heist type to `store`, then place a Cash register on every till. Add a Lock box for the back room safe, and optionally a Hack terminal with goal `alarm` to silence the alert. Registers can ask for a tool in the `Tool needed` field (for example `lockpick`). The tool is checked but not used up. Leave it empty for none.

### Jewelry heist

Set Heist type to `jewelry` and place a Display case on every cabinet: stand in front of it, aim at the glass and click. Scroll the mouse wheel while aiming to set the radius, which is how much around the spot is swapped to broken glass (0.1 to 3 m, default 0.4). Keep it small so the cases next to it stay whole. You can change it later in the step's options. Pick the smash animation that matches the cabinet. `necklace` is for the tall cases and `tray_a` and `tray_b` for the flat ones, the rest are other cases from the game's own jewelry heist.

Players need a weapon in their hand (`Config.Case.needWeapon`). The script plays the game's `missheist_jewel` smash animation, a glass particle, and swaps the cabinet to its smashed version for everyone. The glass stays smashed until the heist resets, then it comes back. The base game map has these cabinets in the Vangelico jewelry store in Rockford Hills. On a custom map the cabinet swap is skipped if the game's cabinet model is not there, the animation and loot still work.

Loot comes from the case's own settings, so you can make some cases pay gold chains and others diamonds. Every item must exist in your inventory. The bundled vr-inventory already has the jewelry set, and vr-fence buys all of it.

## How a heist runs

- It starts with the first loot grab or finished hack. Just connecting does not start it.
- The police alert fires after the bank's alert delay unless an alarm hack silenced it. It goes to vr-mdt and on duty police get a map blip if the bank has blips on.
- It ends when all loot is gone (every lock box, register and case opened and every cash and gold area empty), or after the heist length. Doors lock again after a short grace period. Then the cooldown starts.
- A bank can require a number of on duty police (`Police needed`).
- Cash loot is paid as the `black_money` item (one item per dollar). Gold, jewelry and the like are paid as items. Cleaning the cash and selling the rest is done by vr-fence.
- Cooldowns are saved in the database so a restart does not skip them. Set `Config.ClearCooldownsOnStart = true` to wipe them on every start while testing.

### Items

Add these to the inventory (they are already in the bundled vr-inventory):

| Item | Use |
|---|---|
| `hack_laptop` | Needed to connect to a hack terminal |
| `exploit_kit` | Used up on tier 4 and 5 targets |
| `bank_drill` | Needed to drill, can snap when it jams |
| `gold_bar` | Gold loot |

Names can be changed in `Config.Items`.

## Odin's Eye hacking

The terminal is a small simulated shell. Every session is different: a new user, password, mails, wordlists and exploit list, so players can not memorise a route. The server runs every command, the client only displays it.

Tools: `heimdall` (scan), `fenrir` (wordlist attack), `gungnir` (exploits), `mjolnir` (privilege escalation), `hel` (cover tracks). Plus `ls`, `cd`, `cat`, `pwd`, `whoami`, `help`, `man <tool>`, `clear`, `exit`.

Typical path: scan the host, look around the guest home for a notice mail that hints at the password, pick the matching wordlist and crack the login, read the files, escalate to root, then `sudo vaultctl unlock` (or `sudo alarmctl disable` on an alarm target).

- **Trace** rises with every command and slowly on its own. At 100 you are cut off, police are alerted and the rig is cold for a while.
- Canary files and decoy mails raise the trace if you open them.
- Tier 3 and up need a deep scan and a session token. Tier 4 and 5 use an exploit kit.
- `hel wipe` after finishing delays the police alert. Before finishing it lowers the trace.
- Tiers: Bronze Ward, Iron Ward, Steel Ward, Rune Ward, Aegis. Time limits and trace speeds are in `Config.Hack`.

### Use your own hacking script instead

Set `Config.Hack.provider` to anything other than `'builtin'`. A hack terminal then triggers the server event `vr-bankheist:hackRequested` (`src, bankName, elementId, { host, tier, goal }`) and the built in terminal stays shut. Report the result with:

```lua
exports['vr-bankheist']:CompleteHack(src, bankName, elementId)
exports['vr-bankheist']:FailHack(src, bankName)
```

## Other exports and commands

```lua
exports['vr-bankheist']:GetBanks()
exports['vr-bankheist']:IsActive(bankName)
exports['vr-bankheist']:Reset(bankName)
```

`/heistreset <bank name>` resets a bank from the console or in game.

## Placing loot on counters

Aim at the counter top when you place a cash or gold area. The stacks are laid in a row at exactly that spot and follow the way you were facing. If a prop name is not valid on your game build the script tries the next default prop on its own.

## Door lock keys

While you hack, drill or grab, the E key of vr-doorlock is paused so a door is never locked or unlocked by accident. Restart vr-doorlock and vr-bankheist after updating.

## Checking a step

Target options are tight: each register, case, hack and drill step only shows when you aim at that step itself (neighbouring cases no longer show together), and a line-of-sight check hides the option when there is a wall between you and the step.

`/heistzones` (admin) lists the nearest hack, drill, cash, gold, register and case steps and says why one is not showing on the target, for example the bank is on cooldown, it is waiting for another step, or you are aiming too far from the spot.

## Install

1. Make sure vr-bridge, vr-lib and vr-doorlock are running. Doors are made through vr-doorlock, so it has to be started.
2. `ensure vr-bankheist` after vr-doorlock.
3. Give the items to the shop or players, then build your first bank with `/heistcreator`.

## Notes

- Everything runs on the server. Players can not set prices, skip the drill time or get loot twice.
- No external calls, no telemetry.
- Works with the vr framework, qb, qbox, esx and ox through vr-bridge.
