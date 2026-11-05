# vr-cards

ValRavn trading cards: booster packs with cards of the community, staff and developers, shiny and holo foils, rare pull effects, binders and grading. Everything runs on the server and in the game, with no outside calls.

## Opening packs

Use a **card pack** from the inventory. The pack appears on screen: click it to tear it open and the cards are dealt face down. Click each card to flip it, or use **Flip all**. Epic and Legendary cards shake before they turn, and rare pulls get a burst, a flash and a sound. Sounds are made in the player's own game, so only the person opening the pack hears them. There is a mute button in the corner.

The cards go into the player's pockets as soon as the pack opens, so nothing is lost if the game closes halfway. If their pockets are full, the cards wait at the card shop.

## Cards

Cards are set up in `cards.lua`: name, title, group (`dev`, `staff`, `community`), rarity, picture and a quote. Pictures go in the `images` folder (see `images/README.md`).

- Rarities: Common, Uncommon, Rare, Epic and Legendary (`Config.Rarities`).
- Every pack slot rolls a rarity from `Config.SlotOdds`. The last slot is always Rare or better.
- Foils are rolled per card: **Holo foil** (rainbow) and **Shiny** (light sweep), with chances per rarity in `Config.Foils`.
- Every copy gets a print number (#1, #2, … per card) and a hidden condition (centering, corners, edges, surface).
- Cards are inventory items, so players can give, trade and sell them. Use one to look at it up close; holo and shiny cards catch the light as you move the mouse.

## Binders

A binder holds `Config.Binder.pages` pages of 9 pockets. Use it from the inventory: pick a card from your pockets and click a pocket to store it, or pick a stored card to inspect it, move it or take it out. The header shows how much of each set is in the binder. Click the title to rename it.

The cards belong to the binder, so whoever holds the binder item can open it. Trading the binder trades the whole collection.

## The card shop

The shop (default at Legion Square) sells packs and binders, buys cards back and runs the grading service. Prices for buy-backs come from the rarity, foil and grade (`Config.Rarities[].sell`, `Config.Foils.sell`, `Config.Grading.sell`).

**Grading:** send up to `maxPerSubmit` cards to ValRavn Grading Co. for a fee. Standard and Express take different times (`Config.Grading.tiers`). When they are back the player gets a message and collects the cards in slabs with a grade from 1 to 10 (Gem Mint 10), the four subgrades and a certificate number. The grade comes from the condition the card was printed with, so it cannot be rerolled.

## Commands

- `/givepack [id] [pack] [count]` gives packs (ace `command.givepack`).
- `/givecard [id] [card id] [none|shiny|holo]` gives a specific card, for example a staff member's own card (ace `command.givecard`).
- `/cardshop` moves the shop to where you stand (ace `command.cardshop`).

## Exports (server)

`GivePack(src, pack, count)`, `GiveCard(src, cardId, foil)`, `GetCatalog()`, `GetCollection(citizenid)`. Event `vr-cards:server:packOpened` fires with the player, pack and cards.
