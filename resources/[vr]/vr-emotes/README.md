# vr-emotes

Emotes, dances, prop emotes, shared emotes, walking styles and moods. It replaces WC Emotes V5 and uses its emote list and streamed props.

## Credits and licence

Based on [rpemotes](https://github.com/TayMcKenzieNZ/rpemotes) by TayMcKenzieNZ and contributors, through WC Emotes V5 by White Custom. The emote list in `shared/animations.lua` and the crouch, crawl, pointing, binocular and news camera code come from those projects. Custom animations and props belong to their creators. The licence is GPL-3.0, see `LICENSE`.

## What players get

- **Emote menu:** `/emotes` or the menu key. Tabs for Favourites, Quick slots, Emotes, Dances, Props, Shared, Custom, Walks and Moods, plus Animals when the player is a dog. Search covers every emote.
- **Live preview:** hover an emote and a copy of your character beside the menu plays it, with props. Only you can see the copy. Moods zoom in on the face. Preview is off in vehicles.
- **Quick slots:** 10 slots. Select an emote, choose **Quick slot**, then press the key you want. Keys go through vr-keybinds, so nothing is bound until the player picks it. Pressing a slot's key again stops the emote.
- **Shared emotes:** asks the nearest player. They press Y to accept or L to decline. The server checks the request, the distance and who is answering, so nobody can force another player into an emote.
- **Remembered per account:** favourites and quick slots. Walking style and mood are remembered per character.

## Keys (all unbound until set in /keybinds)

Open menu, stop emote, hands up, point, crouch, crawl, ragdoll, quick emote 1–10. The suggestions in `Config.Suggested` show as one-click picks in the key menu.

## Commands

`/e <name> [variation]`, `/e c`, `/emote`, `/emotes`, `/emotemenu`, `/nearby [name]`, `/walk <name|reset>`, `/walks`, `/mood <name|reset>`, `/moods`, `/handsup`, `/pointing`, `/crouch`, `/crawl`, `/binoculars`, `/newscam`, `/idlecamon`, `/idlecamoff`, `/emotecancel`.

## Config

- `AdultEmotesDisabled` is **true** by default. Adult emotes are found by their flag, their animation and their name, so the ones that weren't flagged in the old list are hidden too.
- `AnimalEmotesEnabled`, `SharedEmotesEnabled`, `SharedDistance`, `SharedRequestSeconds`.
- `Preview` turns the live preview on or off. `PreviewDelay` is how long to hover before it starts, in ms.
- `QuickSlots` sets the number of quick slots.

## Exports (client)

- **Same names as the old emote script:** `EmoteCommandStart(name, variation)`, `EmoteCancel()`, `CanCancelEmote(bool)`, `IsPlayerInAnim()`, `toggleWalkstyle(bool, message)`, `IsPlayerCrouched()`, `IsPlayerProne()`, `IsPlayerCrawling()`, `IsPlayerPointing()`.
- **New:** `PlayEmote('Emotes:wave')`, `OpenMenu(tab)`, `CloseMenu()`, `IsMenuOpen()`, `getWalkstyle()`, `setWalkstyle(clipset)`, `resetWalkstyle()`, `IsPlayerInHandsUp()`.

## Database

`vr_emote_prefs` (created on start): licence → favourites, quick slots, and walking style and mood per character.
