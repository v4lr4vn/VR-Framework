# vr-restaurant

Food management for the server. It replaces vr-consumables: everything that script did still works here (same items, same exports, same `giveconsumable` command), and restaurants are built on top.

**Remove vr-consumables when you install this.** Both cannot run, because they would both claim the same items. This resource declares `provide 'vr-consumables'`, so anything that calls `exports['vr-consumables']` keeps working.

## What is in 1.0

- Every consumable vr-consumables had (burger, water, sprunk, coffee, beer and so on) with the same effects, emotes, drunk and drug effects and exports.
- Restaurants placed in game with `/restaurantcreator`.
- An owner for each restaurant, chosen by an admin.
- A staff office (target at the spot the admin placed it) where staff clock in and out and managers run the business.
- Your own staff list with ranks the owner designs: name, level, wage and what each rank can do.
- Wages paid from the restaurant's own bank balance, every 15 minutes, to people who are online and clocked in. The staff office shows when the next payday is and whether the account covers it.

Dishes, recipes, kitchens, tills, the supplier and farm ingredients come in the next stages.

## Added in 1.1

- **Crafting areas.** Admins place the work spots for each business with the same aim-and-click tool as the heist creator: prep counter, grill, fryer, oven, hob, bar, drinks dispenser, brewing, fridge, till, self-serve counter and cleaning point. 
- **City Hall.** Any restaurant with a price shows up at the clerk (a new "Restaurants and food licences" option, added to vr-cityhall) to buy. The clerk also sells and renews the food licence, and lets an owner hand the business back.
- **Licences.** Real days, set per business (21 to 42, roughly 3 to 6 game months). Buying a business does not include a licence. Renewing opens in the last 7 days and adds on to what is left.
- **Hygiene.** Every cleaning point gets dirty while staff are clocked in. Staff clean them with the target at the point. The rating (0 to 5 stars) is half the average dirt and half the worst corner. A business with no cleaning points is capped at 40 percent.
- **Inspections.** Every 30 minutes each open business that has staff clocked in has a chance of a random visit (doubled if it is dirty or unlicensed). Failing (no licence or hygiene under 35 percent) costs a fine, a strike and a closure. Hygiene closures last 2 hours times the strike count. An unlicensed business stays closed until the licence is bought. Three strikes shut it down for good, the owner loses it and cannot buy another for 14 days, and the place goes back on sale after 14 days. Strikes fade after 7 days without a new one.
- **Food Standards job.** The `foodstandards` job (add it with /setjob, or to the Job Centre). On duty officers get a "Food standards inspection" target at every restaurant: see the licence, hygiene and every cleaning point, read the history, warn, fine (up to 5000, from the business account), close for hours, lift a closure, and at grade 3 shut a business down for good.

## Added in 1.2: the kitchen

- **Every area works now.** Prep, grill, fryer, oven, hob, bar, drinks dispenser and brewing are cooking spots. The fridge, hot box, serving tray and self-serve counter are storage. The till takes payment. Staff need to be clocked in, the business open, and the right rank permission (`cook` for the kitchen, `till` for the till).
- **Fridge.** Target **Open** opens the fridge as a normal inventory (vr-inventory stash) where staff drag ingredients in and out. Cooking uses what is in the business's fridges. Target **Order stock** is the only fridge menu: anyone with the `money` permission picks an ingredient from the wholesale list (`Config.Ingredients`), pays from the business account, and it lands in that fridge. Food in the fridge keeps 3x longer.
- **Hot box.** Opens as a normal inventory. Staff keep cooked dishes in here and they spoil 2x slower.
- **Prep steps.** The prep counter turns one ingredient into another (`shared/recipes.lua`): cut potatoes (2 per potato), ground meat (2 per boar, deer, coyote or rabbit), sliced tomato, shredded lettuce, chopped onion. They come out into your pockets with their own freshness timer, then go in the fridge like any ingredient. Each prep step adds a little mess. These are the only built-in recipes: every finished dish is designed by the business.
- **Designed dishes and drinks.** In the staff office, **Menu and dishes** lets anyone with the `menu` permission combine ingredients (including prepped ones) into their own dish or drink (up to 8 ingredients, 30 dishes). Where it is made decides what it is: bar, drinks dispenser and brewing make drinks, everything else makes food. Food must have something filling in it and a drink something to drink. A dish is a normal consumable called `rd_<id>`. **Add starter dishes** adds a burger, fries, sandwich, tosti and a few drinks (`Config.Starters`) that the business can then edit or delete.
- **Prices.** The price list shows only the dishes and drinks the business made. 0 takes one off the menu.
- **Till.** A server rings up an order for a nearby customer. The customer gets a pay-or-decline box. The money goes into the business account.
- **Serving tray.** Opens as a normal inventory. After a till sale staff put the order on the tray and the customer drags it out. It is free to take because it was paid at the till.
- **Self-serve counter.** Opens as a normal inventory. Staff stock it, customers drag items out and are charged the menu price automatically (unpriced or spoiled items cannot be taken). **View prices** shows the price list.
- **Stacking.** Everything is given a spoil time rounded to a ten minute step (`Config.Storage.stackSeconds`), so things prepped or cooked around the same time are identical and stack, in your pockets, the fridge and the hot box. The fridge and hot box move spoil times in the same whole steps, so stacks stay together.
- **Making more than one.** Prep and cook menus ask how many to make (up to `Config.Cook.maxBatch`, limited by what is in stock). The first takes the normal time and every extra adds `batchFactor` of it, so ten potatoes take far longer than one but less than ten times as long. Mess grows the same way.
- **Dish pictures.** When an owner designs a dish there is an optional "Picture link". It must be a direct https link to an image (.png, .jpg, .jpeg, .webp or .gif) on one of the sites in `Config.Images.hosts` (imgur, Discord, postimages, ibb, catbox, GitHub raw by default). Dishes cooked after that show the picture in the inventory (it is stored as the item's `imageurl`); ones already made keep their old picture. Add hosts, or set `allowAny`, in the config. `enabled = false` turns it off.
- **Going off.** Cooked dishes and ordered ingredients get a freshness timer (shown as a bar on the item). Spoiled ingredients cannot be cooked with and spoiled food cannot be eaten or sold. The fridge and hot box push the spoil time back (in whole steps) so food ages slower inside.
- **Mess.** Every dish made adds dirt to the cleaning points, so a busy kitchen needs cleaning more.

New ingredient items (flour, sugar, salt, cooking_oil, bread_bun, bread_loaf, cheese, butter, coffee_beans, soda_syrup, cola_syrup, mustard_seed) go in vr-inventory `data/items.lua`. Each needs an image at `web/images/<name>.png`.

## Added in 1.3: restaurants are real jobs

- **Every restaurant is a framework job** named `rest_<id>` (prefix in `Config.Jobs.prefix`). It shows up in the job menu (`vr-multijob`) for everyone who works there, so owners and staff can switch to it, go on duty from the menu and leave it like any other job.
- **Ranks become grades.** The owner's rank ladder (by level) is the job's grade list, with the owner on top. Rank names and wages shown in the job menu follow the restaurant's own settings. Paying is still done by the restaurant (from its account, only while clocked in), so the framework paycheck for these jobs is 0 and nothing is paid twice.
- **They are whitelisted.** You have to be hired (or be the owner) to hold one, so they appear under *Whitelisted* in the job menu (`Config.Jobs.whitelisted`).
- **Duty is one thing.** Clocking in at the staff office puts the character on duty in the job menu, and going on duty from the job menu clocks them in. A closed or foreign restaurant refuses, with a message.
- **Hiring, firing, rank changes, quitting and ownership changes** update the job within a few seconds. Someone who leaves a restaurant job from the job menu is clocked out.
- **Nothing to set up.** Jobs are created when the restaurant is, removed when it is deleted, and re-created after a `vr-core` restart.
- Needs a framework that can add jobs at runtime (`vr-core` or QBCore through `vr-bridge`). On other frameworks a warning is printed at start and restaurants work as before without a job. `Config.Jobs.enabled = false` turns the whole feature off.
- `exports['vr-restaurant']:GetJobName(id)` returns the job name of a restaurant.

## Setting one up

1. Stand where the staff office should be and run `/restaurantcreator`, then **Add a restaurant here**. Give it a name, the most its owner may earn each payday, a price at City Hall (0 means not for sale) and how many real days a licence lasts.
2. Open it from the list. **Crafting areas** lets you place each area: choose the kind, then aim at the spot and left click (right click cancels). Add at least one **Cleaning point** or the hygiene score is capped.
3. Either sell it at City Hall by leaving a price, or **Set the owner** by server id.
4. The owner uses the **Staff office** target to clock in, put money in the account, hire people and create ranks, and the City Hall clerk to buy the licence.

## How wages work

- An admin sets a limit for each restaurant. The owner can pay themselves up to that.
- No rank can be paid more than the owner is paid. If the owner lowers their own wage, or an admin lowers the limit, every rank above the new figure drops to it.
- Every `Config.Pay.minutes` (15) the server pays everyone who is online and **clocked in**. The money comes out of the restaurant's account. If the account is short that person is not paid and is told so.
- Staff who are offline or clocked out are not paid.

## Ranks and who can do what

- Every rank has a level from 1 to 99. The owner counts as 100.
- You can only manage ranks and people **below** your own level, and you can only give permissions you have yourself.
- Permissions: hire, fire and promote staff; create and edit ranks; use the business account; change dishes and prices; use the kitchen; run the till. The last three are used by the next stages.
- One character can work at one restaurant.
- A hired player gets a job offer they can accept or decline.

## Admin

`/restaurantcreator` lists every restaurant with its owner, staff and account. Per restaurant you can go there, set or remove the owner, rename it, change the wage limit, set the price and licence length, place and edit its crafting areas, move the office to where you stand, or remove it (its balance is shown before you confirm).

## For other scripts

- `exports['vr-restaurant']:HasPermission(src, 'till', onDuty)` returns the restaurant id or false.
- `exports['vr-restaurant']:IsOnDuty(src)`
- `exports['vr-restaurant']:GetBusinessOf(src)`
- `exports['vr-restaurant']:GetBusinesses()`
- `exports['vr-restaurant']:IsOpen(id)`, `HasLicence(id)`, `GetHygiene(id)`, `AddMess(id, amount)` (kitchen work adds dirt to the cleaning points)
- `exports['vr-restaurant']:OpenBusinesses()` opens the City Hall menu
- `exports['vr-restaurant']:GetStock(id, item)` counts fresh stock in a business's fridges
- All the old consumables exports: `GetConsumables`, `GetConsumable`, `SaveConsumable`, `DeleteConsumable`, `GiveConsumable`, `Consume`, `CancelConsume`, `IsConsuming`.

## Tables

`vr_rest_businesses`, `vr_rest_ranks`, `vr_rest_staff`, `vr_rest_stations`, `vr_rest_inspections`, `vr_rest_bans`, `vr_rest_storage`, `vr_rest_menu`, `vr_rest_dishes` (with an `image` column for the picture link), plus `vr_consumables` (dishes saved in game, the same table vr-consumables used, so nothing is lost). Each restaurant keeps its own money in the `balance` column of `vr_rest_businesses` (the framework's society accounts only exist for jobs and gangs, so they could not be used). Fridge, hot box, tray and counter contents are vr-inventory stashes named `rest_<station id>`; `vr_rest_storage` is only read once to move 1.2.0 stock into the stashes.
