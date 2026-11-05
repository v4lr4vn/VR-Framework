# vr-phone

A foldable smartphone for your server. It closes to a small screen, half opens (crease across the middle), or opens flat (crease down the middle).
The small screen is a full phone: lock screen with PIN, home screen, dock, notifications and apps. The big screen does the same with more room.
Built on your own framework: vr-lib, vr-mysql, vr-bridge. Nothing from ox is needed.
The Camera also needs the `screenshot-basic` resource running (`Config.Phone.Media.screenshotResource`). Without it the Camera says so and the rest of the phone is fine.

This is **build step 7**. Step 1 was the phone item, the web screen, the three fold states, the lock screen and the home screen.
Step 2 added the quick panel, notifications, battery, signal and the Settings pages.
Step 3 adds **Phone**, **Contacts** and **Messages**, with calls and voicemail.
Step 4 adds **Camera**, **Gallery** and **nearby share** (photos and contacts), plus a Storage page in Settings.
Step 5 adds **Notes**, **Reminders**, **Calendar**, **Calculator**, **Weather** and **Mail**.
Step 6 adds **Wallet**, **Maps** and **Health**.
Step 7 adds the **App Store** and the **custom app API** (other scripts can add their own apps), plus **Music**, charging and the peek.
Settings, Clock, Phone, Contacts, Messages, Camera, Gallery, Notes, Reminders, Calendar, Calculator, Weather, Mail, Wallet, Maps, Health, Music and the App Store are the working apps. The other apps open a "coming soon" page.

## Install

1. Put `vr-phone` in your resources folder.
2. Open a terminal in `vr-phone/web` and run:
   ```
   npm install
   npm run build
   ```
   This fills the `html` folder. The phone shows nothing until you do this.
3. In `server.cfg`, start it after your other vr- resources:
   ```
   ensure vr-lib
   ensure vr-mysql
   ensure vr-bridge
   ensure screenshot-basic
   ensure vr-phone
   ```
4. Add a `phone` item to your inventory (name must match `ItemName` in `config/phone.lua`).
5. Start the server. The tables are created for you (the phone, settings, contacts, messages, calls, voicemail, photo and album tables). `sql/install.sql` is there if you want to run it by hand.
6. For call audio, run a voice script (`vr-voice` by default, set in `Config.Phone.Calls.voice`). Without one, calls still work but are silent.

Press **F1** to take the phone out or put it away. Players can rebind it in the FiveM key settings.

## How a phone is tied to a player

- Each phone item gets its own ID, saved in the item metadata (`phoneId`). The number, PIN, settings and home layout belong to that ID, so if the item is lent, sold or stolen, the data goes with it.
- If your inventory cannot save metadata on an item, the phone is tied to the character instead. When the inventory can save it later, the phone claims the item on its own.
- `RequireItem = false` gives every character a phone with no item.

## The PIN

- 4 or 6 digits. The server never stores the PIN, only a salted hash.
- Wrong tries lock the phone for longer each time: 5 → 30s, 6 → 60s, 7 → 5m, 8+ → 15m. All in `config/phone.lua`.
- After the phone has been away for `autoLockSeconds`, it asks for the PIN again.

## Config

| File | What it holds |
| --- | --- |
| `config/phone.lua` | key, item, fold states, theme, PIN rules, number format, wallpapers, sounds, calls, messages, contacts, photos (`Media`), nearby share (`Share`) |
| `config/apps.lua` | the built-in app list (which ones are installed on a new phone) |
| `config/prop.lua` | the hand prop and animations (placeholder model for now: swap in your own) |
| `locales/en.json` | game-side messages |
| `web/src/locales/en.js` | all text on the phone screen |

Sounds are off. Put your own files in `html/` (add them to the manifest `files` list) and point `Config.Phone.Sounds` at them.
`Sounds.ring` is the default ringtone and `Sounds.ended` plays when a call ends. To let players pick a ringtone, add entries to `Config.Phone.Ringtones`: `{ id = 'classic', label = 'Classic', file = 'sounds/classic.ogg' }`.

## In the hand

The phone is held in front of you in every fold state. It goes up to your ear only while a phone call is **active** (answered), and goes back when the call ends. This works with the screen closed too.
Another script can still switch it by hand:

```lua
-- client side
exports['vr-phone']:SetCallActive(true)   -- phone goes to the ear
exports['vr-phone']:SetCallActive(false)  -- back in front
```

## Phone, Contacts and Messages

- **Phone**: keypad, favourites, recents and voicemail. Missed calls and new voicemail show as a badge.
- **Contacts**: add, edit, favourite, block. Contacts show by name in calls and messages. Up to `Contacts.max` per phone.
- **Messages**: text conversations with read state and unread badges. Messages are cut to `Messages.maxLength`, one phone can send `Messages.perMinute`, and old messages go after `Messages.keepPerThread` per conversation.
- A blocked number can't call you, and its messages are kept but never shown to you. The sender still sees theirs as sent.

### Calls

- A call rings for `Calls.ringTimeoutMs`. If nobody answers, the caller can leave **voicemail** (`voicemailSeconds` to write it). If they don't, it counts as a missed call.
- **Voicemail is typed text, not recorded audio.** Recording needs an audio layer that comes later.
- Both phones need power, signal and no airplane mode. A busy line says so. Weak signal can drop a call (`lowSignalDropChance` each status check). A dead battery, airplane mode, losing the phone or leaving the server ends the call.
- Voice goes through `vr-voice` (`exports['vr-voice']:setPlayerCall(src, channel)`). The channel is `channelBase` plus the call number.
- **The small screen answers calls** (and so does a locked phone). In flex mode the other person is on top and the controls on the bottom. Open mode has two columns.
- With the phone put away, a pill shows the call. **Y** answers and **U** hangs up or declines. Change them in `Calls.answerKey` and `Calls.hangupKey`. Players can rebind both in the game's key settings.

## Battery and signal

The server works out both. The screen only shows them.

- **Battery** drains on standby, with the screen on, and for each open app (Camera, Maps and Music use more). Low Power Mode, airplane mode and no signal change the rate. All numbers are percent per minute in `Config.Phone.Battery`.
- **Charging**: a vehicle with the engine running charges the phone (`charge.vehicle`). `charge.points` lists charging points (`{ coords, radius, rate }`). Other scripts can charge it with `SetCharging` (power banks, wall sockets). The fastest source counts. They do not add up.
- At **20%** Low Power Mode switches itself on (the player can turn this off). It switches off again at 80% while charging. Warnings come at 20% and 10%.
- At **0%** the phone is off. It starts again at 2% (`bootLevel`) and shows the lock screen. While it is off, notifications wait for it.
- **Signal** comes from zones in `config/signal.lua`: `{ name, coords, radius, level }` with level `full`, `low` or `none`. The examples are Fort Zancudo, Mount Chiliad and Cayo Perico, so change them to suit your map. The worst zone wins. With no signal, notifications wait (up to 25) and arrive when signal comes back. Calls and messages should check `GetSignal` first.
- Battery is saved to the database when the player leaves, so a dead phone stays dead.

## The quick panel and notifications

Tap the status bar to pull the panel down (the chevron or Escape closes it). It has Airplane, Bluetooth, Silent, Low Power, an audio output switch, a brightness slider and the notification list. It also works on the lock screen, but only for those switches. Everything else waits for the unlock.

The Cast tile is a placeholder until the screen mirroring script exists.

Players choose how notifications look in Settings: **list**, **stack** (one pile per app) or **count** (one line). Each app has its own rules: allow, banner, lock screen and sound.

## Camera, Gallery and nearby share

**Camera.** Opening it turns the phone into a viewfinder over the game. The mouse turns the viewfinder: the back camera looks around from the player's eyes, and the front camera (selfie) circles the player's head. Keys: **Enter** or left mouse takes the photo, **R** switches between the back and front camera, **T** cycles the timer (off, 3 s, 10 s), **mouse wheel** zooms, **Esc** or **Backspace** closes. The on-screen buttons do the same. The picture is taken with `screenshot-basic`, so the phone itself is never in the photo.

**Walking and selfies.** With the back camera the player walks the way the camera looks. With the front camera the player stands still, faces the camera, holds the phone out at arm's length (`Config.Prop.anims.foot.selfie`, and `Config.Prop.selfie` for where the phone sits in the hand) and looks into the lens. The phone in the hand is hidden from the player's own view. The selfie framing (distance, where the camera aims, starting angle) is `Config.Phone.Media.selfie`: lower `aimHeight` to move the face up the screen, raise it to move it down.

**Photos.** Each photo is shrunk on the screen (`maxWidth`, `quality`) and stored as a small JPEG in the `vr_ph_media` table, with a thumbnail. A photo belongs to the phone, so it moves with the phone item. Limits (`Config.Phone.Media`): `maxPhotos` per phone, `maxBytes` per photo, `cooldownSeconds` between photos. If you have a picture host, set `Config.Phone.Media.upload = function(source, dataUri) return 'https://...' end` and the link is stored instead of the picture.

**Gallery.** Photos, Favourites, Albums and Deleted. Select many, favourite, add to an album, delete (kept for `keepDeletedDays`, then gone), restore, delete forever.

**Nearby share.** Share a photo (or a contact, from Contacts) to a player within `Config.Phone.Share.range` metres. The other player gets a request they can accept or decline. With `requireBluetooth = true` both phones need Bluetooth on in the quick panel.

Not built: video (only photos for now).

## Wallet, Maps and Health

**Wallet.** Shows the bank balance and cash, and sends money to another phone number. Money only moves on the server, from the sender's bank account to whoever holds the other phone (the owner, through the framework, when nobody holds it, even if they are offline). If paying the other side fails, the sender is paid back, so a transfer happens in full or not at all. You can also **ask** a number for money: they get a notification and pay or decline in their Wallet (a request closes after `requestHours`). Limits in `Config.Phone.Wallet`: `minSend`, `maxSend`, `dailyLimit` (per phone, rolling 24 hours), `cooldownSeconds`, `maxOpenRequests`. Sending needs signal. Cash is shown but cannot be sent. With vr-banking running, the Wallet also shows the account number and the latest bank activity (wages, card payments, ATM), read from its tables; without it those parts just stay out. Phone transfers are written to the bank's history by vr-banking itself, under the reason "Wallet: sent to 555-0142". Tables: `vr_ph_wallet_log`, `vr_ph_wallet_requests`.

**Maps.** The map is the same road map the MDT uses (the pictures are copied into `html/tiles`, and `Config.Phone.Maps.tiles` has the same calibration as `Config.Map` in vr-mdt; set `tiles = false` for a plain grid instead). On it are the places from `Config.Phone.Maps.places`, the player's saved places and the player (north up, centred on the player until you drag). Drag to move, wheel or the buttons to zoom, tap a marker or an empty spot (drops a pin). **Start GPS** sets the game's waypoint, so the route shows on the game map and minimap, and **Stop GPS** clears it. A waypoint set from the game map shows here too. The street, area and postal code (from vr-hud, when it runs) are read from the game. Players can save places with a name and an icon (`maxPlaces` each, table `vr_ph_places`). The places in the config are close to the real spots, not exact: stand where you want one, copy your coordinates and edit the list.

**Health.** Steps are counted from the player's own walking and running, from the moment they are in the world (the phone can stay in the pocket). The game reports the walked distance every `reportSeconds`, and the server only believes as many steps as a person can take in that time (`maxStepsPerSecond`), so a client cannot inflate them. One row a day per phone (`vr_ph_health_days`, kept `keepDays`). The app shows today's steps against a daily goal (players change it, 1,000 to 40,000), distance, energy, active time, a 7 day chart and a streak of days that met the goal. It also shows how the character is right now: health, armour, food, water and stress, with a **heart rate that is an estimate** from what the player is doing and how stressed or hurt they are (there is no real heart in the game). Players can switch distances to miles.


## Music

Players paste a YouTube link (watch, youtu.be, shorts or music.youtube.com) and the song plays on their phone. With the **speaker** on, other players close by hear it too, louder the closer they are and silent beyond the reach (5, 8 or 10 m, the player picks; `Config.Phone.Music.range` and `rangeChoices`). Players can switch **Hear nearby phones** off to only hear their own. The app keeps a list of saved songs (`vr_ph_music_tracks`, `maxLibrary` each: only the video id, title and length are stored, never audio), plays one now, adds songs to a queue, plays all or shuffles, and has previous, next, pause and a seek bar.

How it works: the server keeps what each phone plays and where it is up to, and tells every game. Each game works out the volume from the distance four times a second and plays the song through YouTube's own embedded player in a hidden frame (this uses YouTube's official player, nothing is downloaded or copied). Music stops when the phone dies, loses service (`needService`), is dropped, or the player leaves. Videos that the owner does not allow to be played outside YouTube are refused when added, and one that fails to play is skipped with a message.

**The player page.** YouTube refuses to play for a page that has no web address (error 153). So by default (`Config.Phone.Music.player = 'auto'`) the player page is served by this resource from your server's own web address: `https://<your cfx domain>/vr-phone/player` (or `http://ip:port/vr-phone/player`). Things to check if no music plays:
- Open that address in a browser. You should see a black page.
- If the music shows error 153 or "the player page could not be loaded": put `html/player.html` on any web page you own (any static host works, for example GitHub Pages) and set `Config.Phone.Music.player = 'https://your-address/player.html'`.
- `player = 'nui'` loads the page from the phone itself. It only works if YouTube accepts that, so use it only for testing.

Ads: YouTube may play an advert before a song. That is YouTube's player and cannot be switched off here. Use only music you are allowed to play where your server is shared (streaming a video to many people can be a copyright matter for streamers).

## The peek

When the phone is put away, the top of it rises from the bottom of the game screen when something happens, so the player does not need to take it out:
- a new notification shows for a few seconds and the phone goes down again,
- a call (ringing, calling or going on) stays until the call is over (a ringing call that stops ringing, missed or declined, shows how it ended for a moment, then the phone goes down),
- music stays while a song is playing and goes down when it is paused or stops (it comes back when the song plays again).
They can show together, one under the other. Nothing on the peek can be clicked. The call's answer and hang up keys are written on it.

## Charging

The battery drains while the phone is used and charges in these ways (percent per minute, all in `Config.Phone.Battery.charge`, the best one counts, they do not add up):
- **Vehicle** with the engine running (`vehicle`, a USB port).
- **Indoors** in any building (`indoors`): the game says when the player is in an interior and the server trusts it only for this slow rate.
- **At home** inside a vr-housing property (`home`).
- **Charging points** you add with coordinates (`points`).
- **Power bank**: the inventory item `powerbank` (added to vr-inventory's items and sold in the General shops, 35). Using it takes 5 seconds, charges `amount` (40%) at once and is used up. Cooldown `cooldownSeconds`.
- Other scripts can call `exports['vr-phone']:SetCharging(source, rate, 'name')` or `exports['vr-phone']:AddBattery(source, amount)`.

## Notes, Reminders, Calendar, Calculator, Weather and Mail

**Notes.** Title and text, pin to the top, search. Limits in `Config.Phone.Notes`. A note belongs to the phone (`vr_ph_notes`).

**Reminders and Calendar.** Both use the **game clock**, not real time. A date is `YYYY-MM-DD`, and a time is a minute of the day. A reminder can be undated, or have a date with an optional time (with no time it goes off at `Config.Phone.Planner.defaultAlertMinute`, 09:00). An event can be all day or timed, with a length, a place, a colour and an alert (`remindChoices`). The server never watches a clock: the phone client checks its alerts against the game clock and asks the server to fire them, and the server sends the notification (it queues if the phone is off or has no signal). Tables: `vr_ph_reminders`, `vr_ph_events`.

**Calculator.** Runs fully on the screen. Basic and scientific (sin, cos, tan, ln, log, roots, powers, factorial, degrees or radians). It never uses `eval`.

**Weather.** The game has weather types but no temperatures, so the temperature is worked out from the weather and the hour of the game day (`Config.Phone.Weather.base` per type, `daySwing` degrees between 03:00 and 15:00). It shows now, the next weather the game has planned, wind, rain and the next 12 hours. The temperature unit follows `fahrenheit`, and each player can switch. It is an estimate, and the screen says so.

**Mail.** Raven Mail, addresses `name@ravenmail.io` (`Config.Phone.Mail.domain`). An account is not tied to a phone: any phone can sign in, and one phone has one signed-in account at a time (`vr_ph_mail_accounts`, `vr_ph_mail_links`, `vr_ph_mail`). Passwords and the recovery code (shown once when the account is made) are salted and hashed. Wrong tries lock the account for 1, 5, then 30 minutes. Inbox, Starred, Sent and Trash, reply, mark unread, delete (trash is emptied after `keepTrashDays`). Unread mail shows as a badge on the icon and in the notification list.

Scripts can send mail:

```lua
-- from a system sender, to an address (or to a player's own address)
exports['vr-phone']:SendMail('sam@ravenmail.io', { from = 'bank@ravenmail.io', fromName = 'Raven Bank', subject = 'Statement', body = 'Your statement is ready.' })
exports['vr-phone']:GetMailAddress(source)   -- 'name@ravenmail.io' for the account that player is signed in to, or nil
```

## For other scripts

```lua
-- server side
-- Returns true, 'sent' | 'queued' (phone is off, in airplane mode or has no signal). Returns false, reason when it was refused.
exports['vr-phone']:PushNotification(source_or_number, { app = 'messages', title = 'Mum', message = 'Tea is ready' })
exports['vr-phone']:GetBattery(source)     -- { level, charging, powered }
exports['vr-phone']:SetCharging(source, 2.0, 'powerbank')  -- percent per minute. nil as the rate stops that source
exports['vr-phone']:AddBattery(source, 25) -- adds charge at once (negative removes)
exports['vr-phone']:GetSignal(source)      -- { level, bars, service, airplane }
exports['vr-phone']:GetNumber(source)      -- number of the phone they are holding
exports['vr-phone']:GetPhoneId(source)
exports['vr-phone']:GetApps()
exports['vr-phone']:OpenApp(source, 'settings')
exports['vr-phone']:StartCall(source, '555-0142')   -- true | false, reason ('invalid_number', 'no_session', 'in_call', 'line_busy'...)
exports['vr-phone']:EndCall(source)                 -- true if there was a call to end
exports['vr-phone']:GetCall(source)                 -- the call they are in, or nil
exports['vr-phone']:IsInCall(source)
exports['vr-phone']:SendMessage('555-0777', '555-0142', 'Your order is ready')  -- from a number with no player (a shop, a script)
```

## Working on the screen without the game

```
cd web
npm run dev
```

Open the address it prints. A fake game answers for the phone.

- `?fold=cover` `?fold=flex` `?fold=open` picks the fold state
- `?locked=1` starts locked (PIN is **1234**), `?pin=0` starts with no PIN
- `?app=settings` opens an app, `?notify=0` skips the test notifications, `?many=1` sends more of them
- `?battery=15` `?charging=1` `?drain=1` try the battery (empty, charging, going down 2% every 3 seconds)
- `?signal=none` `?signal=low` `?airplane=1` try the signal
- `?style=list` `?style=stack` `?style=count` picks the notification style, `?ringtones=1` gives the Sounds page some ringtones
- `?app=phone` `?app=messages` `?app=contacts` open the new apps. `?incoming=1` makes Sam call you after 2 seconds, `?incoming=unknown` an unknown number calls, `?call=active` starts in a call, `?empty=1` starts with no contacts, texts or calls
- `?app=camera` `?app=gallery` open the new apps. `?photos=0` starts with no photos, `?share=incoming` makes a nearby player send you a photo after 3 seconds, `?bluetooth=0` turns Bluetooth off for sharing
- `?app=notes` `?app=reminders` `?app=calendar` `?app=calculator` `?app=weather` `?app=mail` open the step 5 apps. `?mail=in` starts signed in to Mail (otherwise sign in as **sam** with **secret1**, or make an account), `?notes=0` `?reminders=0` `?events=0` start empty, `?weather=storm` `?next=clear` pick the weather
- `?app=wallet` `?app=maps` `?app=health` open the step 6 apps. `?wallet=poor` a nearly empty bank, `?requests=0` no waiting requests, `?bank=0` no bank lines, `?walk=1` the player walks so the map moves, `?steps=9000` today's steps, `?state=run` the heart rate follows that activity
- **F1** takes the phone out and puts it away

## The App Store

The App Store is on every phone. It lists the apps a player can install or remove. **Phone, Messages, Contacts, Camera, Gallery, Settings and the App Store itself can never be removed** (`essential = true` in `config/apps.lua`). Everything else can be removed and installed again, and **removing an app keeps what the player saved in it**.

- Installing needs signal (`Config.Store.needService`).
- An app can cost money (`price`, bank money). The player pays once; installing it again later is free.
- `Config.Store.featured` puts apps at the top. `Config.Store.apps = { veil = { price = 250 } }` sets a price or switches an app on or off in the store (`listed`).
- Apps that have no screen yet have `listed = false` in `config/apps.lua`, so they are not in the store. Switch them on when the app exists.
- What a phone has installed is saved per phone (`vr_ph_apps`). A new preinstalled app appears by itself; one the player removed stays away.

## Adding an app from another script

Any resource can add an app to the phone and the App Store. The app is a web page of your own resource, shown in a frame inside the phone.

```lua
-- server side of your script
local function add()
    exports['vr-phone']:AddApp({
        id = 'taxi',                  -- a-z, 0-9, _  (2 to 32 characters)
        label = 'Taxi',
        description = 'Order a cab.',
        category = 'Services',
        url = 'ui/index.html',        -- a page of YOUR resource (list it in `files`), or a full https address
        color = '#f5b301',
        glyph = 'car',                -- an icon from the phone's set, or use  image = 'ui/icon.png'
        preinstalled = false,         -- true: every new phone has it
        price = 0,
        -- allow = function(source, phoneId) return true end,   -- keep it away from some players
    })
end
AddEventHandler('vr-phone:server:ready', add)                  -- runs again if vr-phone restarts
if GetResourceState('vr-phone') == 'started' then add() end
```

Other exports: `UpdateApp(id, patch)` and `RemoveApp(id)` (your own apps only), `IsAppInstalled(source, id)`, `SetAppInstalled(source, id, true/false)` (give or take away an app: for jobs, items or rewards; it is free and needs no signal), `PushNotification(source, { app = 'taxi', title = '...', message = '...' })` (tapping it opens your app). Apps go away by themselves when your resource stops. `examples/hello-app` is a small complete example (rename `fxmanifest.lua.example`).

**The page.** Add this to your page and use `VRPhone`:

```html
<script src="https://cfx-nui-vr-phone/html/sdk.js"></script>
<script>
  VRPhone.ready((info) => { /* info.number, info.dark, info.accent, info.fold */ });
  VRPhone.onBack(() => { if (sheetOpen) { closeSheet(); return true; } return false; });  // the back button / Esc
  VRPhone.post('myCallback', { a: 1 }).then((answer) => { /* RegisterNUICallback('myCallback') in your client script */ });
</script>
```
`VRPhone.close()` puts the phone away, `VRPhone.home()` goes home, `VRPhone.open('maps')` opens another app, `VRPhone.on('theme' | 'fold', fn)` tells you when they change. The theme comes as CSS variables (`--vr-bg`, `--vr-surface`, `--vr-surface-2`, `--vr-ink`, `--vr-ink-2`, `--vr-ink-3`, `--vr-line`, `--vr-accent`, `--vr-on-accent`) so your page can look like the rest of the phone. Typing in text boxes and the Esc key are handled for you. The page sits between the status bar and the home pill and fills the screen of whatever fold state the phone is in, so make it fit narrow (cover) and wide (open) layouts. **Do not trust the page for anything that matters** (money, items): do it in your server script, and use `exports['vr-phone']:GetNumber(source)` to know who is asking.

## Adding an app screen to the phone itself

1. Write a Svelte component, for example `web/src/apps/notes/Notes.svelte`. Use `TwoPane` if it has a list and a detail view: it handles the fold states for you.
2. Add one line to `loaders` in `web/src/lib/apps.js`.
3. `npm run build`. Each app is its own file, so it only downloads the first time it is opened.

## The clock

The status bar, lock screen, home screen and Clock app show the **time on the player's own computer** by default. Players can switch to the in-game clock in Settings > Display > Clock source. Set the default for new players with `Config.Phone.TimeSource = 'pc'` or `'game'`. Reminders, Calendar and Weather always use the game clock, so alerts stay in step with the world. In the browser preview, `?gamehour=3` makes the game clock differ from the computer's.

## Veil and Hearth

Both are in the App Store (not on a new phone). Both need signal (`Config.Phone.Veil.needService`, `Config.Phone.Hearth.needService`).

**Veil** is anonymous chat. The player picks an alias (3 to 16 letters, numbers or `_`, case-insensitive and unique, a few words like "admin" are reserved, one change a day). Everyone else sees only the alias: the server never sends a phone number, a phone id or a character name to the screen, and messages are stored against the phone so an alias change follows old messages.
- Rooms from `Config.Phone.Veil.rooms` always exist. Players can make up to `maxOwnedRooms` rooms and be in `maxJoinedRooms`. A room with a password is not listed: it is joined by name and password, and a wrong password looks exactly like "no such room". Passwords are salted and hashed in SQL.
- Direct messages go to an alias. **Block** hides that alias's room messages and drops their direct messages without telling them; a player cannot write to someone they blocked.
- A banner only comes for a direct message or an `@alias` mention. Room history is kept `keepRoomDays` days and `keepRoomMessages` per room, direct messages `keepDmDays`, and player rooms nobody spoke in for `roomExpireDays` close by themselves (the job runs every hour).

**Hearth** is dating. The profile starts from the character: first name, age from the date of birth and gender. If the character has no date of birth the player types an age (18 to 99, `minAge`/`maxAge`). Under-age profiles are refused on the server. `Config.Phone.Hearth.ageFromCharacter = false` ignores the character's date of birth and asks the player to type an age instead (useful for testing with a young character).
- A profile has a bio, up to `maxTags` interests from `Config.Phone.Hearth.tags`, up to `maxPhotos` photos copied from the Gallery, who to show (men, women, everyone) and a visible switch. Age and gender cannot be changed.
- The deck shows visible people who are not you, were not seen before, were active in the last `activeDays` and match what both of you want. `dailyLikes` limits likes in 24 hours (passes are free, and a pass comes round again after 30 days).
- A like from both sides is a match. Both get a banner (`hearth.n.match`), the chat opens, and either side can unmatch (the chat goes too). Photos are sent one at a time when a card needs them.
- Other players only ever get a profile id, a first name, an age, a bio, tags and photos. Chats older than `keepMessageDays` are deleted.

In `npm run dev`: `?app=veil` `?app=hearth`, `?alias=0` starts Veil without an alias, `?hearth=0` starts Hearth without a profile (`?noage=1` as well asks for an age and gender), `?live=0` turns off the pretend incoming messages.

## Settings pages

Profile, Display, Wallpapers, Notifications (style, lock screen text, rules for each app), Sounds, Battery (level, Low Power Mode, use by app), SIM and network, Security (PIN) and About. Each page is one file in `web/src/apps/settings/pages/`.

## Not built yet

Settings: Language (only English exists) and Backup and restore. Mail: attachments and sending to more than one person. Messages: sending photos, GIFs and money inside a text (Wallet sends money by number for now; the config keys are there but do nothing yet). Maps: turn-by-turn directions (the game's own GPS route is used). Voicemail recording (it is typed text for now). Video in the Camera and Gallery. Also: moving and organising icons on the home screen, split screen and the edge panel, screen mirroring, the hand prop model and animations (placeholders).

Notifications that are waiting (phone off, no signal) are kept in memory only. They are lost if the player leaves or the server restarts.

## Checked

- All Lua files compile, and the server side passed 581 logic checks for steps 1 to 3 (phone IDs, PIN lockouts, settings, layout, notifications and their rules, battery, charging, Low Power Mode, signal zones, a dead phone, cleanup, contacts, messages, blocking, limits, calls, ring timeout, voicemail, busy lines, dropped calls, exports), another 105 for step 4 (photos, albums, trash, uploads in pieces, limits, nearby share, timeouts), and another 192 for step 5 (notes, reminders and events, the game date maths, alerts firing once, mail accounts, lockouts, recovery, folders, trash, limits). Another 124 for step 6 (sending money and refunds when the other side fails, offline owners, whoever holds the phone being paid, daily limits, a send during a send, requests: pay, decline, cancel, expire, saved places and their limits, step reports and how many the server accepts, goals and streaks, every callback and the rate limits). The calculator has its own engine test.
- The screen compiles with no warnings and was driven in a browser in all three fold states (lock, home, quick panel, all Settings pages, PIN set, notification styles, empty battery, charging and starting up, low battery warning, Escape, F1, and all of Phone, Contacts, Messages, Camera, Gallery, nearby share, Storage, the call screens, Notes, Reminders, Calendar, Calculator, Weather, Mail, Wallet, Maps and Health on the small, half open and open screens), and click-through tested (send money, pay and decline requests, drop a pin, GPS on and off, save a place, search, zoom, drag, goal and miles).
- There is no blur effect anywhere, so the old blur switch is gone. It can draw black boxes over the game's see-through page, and your vr-ui does not use it either.
- Animations stop when Low Power Mode is on, or when Reduce motion is on in Settings.
- It has not been run inside FiveM itself. The camera keys and the front-camera position, the Maps position and waypoint calls, the step counting and the heart rate in particular need trying in the game.
