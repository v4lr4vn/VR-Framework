# vr-camera

A usable **camera** that takes photos. Each photo becomes a **photo** item you can keep, hand over or show. It's a port of **ps-camera** by Project Sloth (CC BY-NC-SA 4.0, see `LICENSE`) for vr-core and ox_inventory.

## How it works

- Use the `camera` item, aim with the mouse, zoom with the scroll wheel, toggle the flash with `F`, and take the photo with `Enter`. `Backspace` puts the camera away.
- The photo is captured with **screenshot-basic** and stored in **your own database** (table `vr_camera_photos`, created automatically). The `photo` item only holds the photo's id and location.
- Using a `photo` item shows the picture with the street it was taken on.

## Using it from other resources

`exports['vr-camera']:TakePhoto({ quality = 0.6, maxBytes = 600000 })` puts the same camera up (view, zoom, flash, animation, camera in hand), waits for the player to press `Enter` or `Backspace`, and returns `{ ok = true, data = '<image data url>' }` or `{ ok = false, error = 'cancelled' | 'busy' | 'no_camera' | 'too_large' | 'unavailable' }`. This resource saves nothing for these photos: no photo item and no database row. The caller decides what happens to the image. vr-mdt uses it for evidence, report, patient and court photos. `exports['vr-camera']:IsBusy()` says whether the camera is up.

## Setup

- Needs `screenshot-basic` running. A prebuilt copy ships alongside this resource. Without it, the camera tells the player it isn't available.
- **Items** (in `ox_inventory/data/items.lua`): `camera` and `photo`. The images are in `images/`.
- **Config:** `Config.Quality`, `MaxPhotoBytes`, `PhotoCooldown`, `MaxPhotosPerHour` and `PhotoRetentionDays` (0 keeps photos forever).

## Changes from ps-camera

- **No uploads anywhere.** The original sent every photo to a Discord webhook or to Fivemerr. Worse, any player could ask the server for the webhook URL or the Fivemerr API token (`ps-camera:requestWebhook` / `requestFivemerrToken`) and abuse it. Both are gone; photos stay on your server.
- **Free photo items:** `ps-camera:savePhoto` gave a photo item, with any URL, to anyone who fired it. Now the server issues a one-time token when the camera item is used. It then accepts exactly one photo for that token, and only if:
  - the player still has the camera;
  - the photo is a valid JPEG/PNG/WEBP within the size limit;
  - the per-player cooldown and the hourly cap allow it.
- **Photo viewer:** it only displays image data (no outside links), and the location is shown as plain text. The copy-link button is gone, because there is no link any more.
- **Camera view:** it stays up until the frame is captured, so the photo shows what you aimed at.
- **Removed:**
  - the JS "anti-cheat" key export, which kicked players over a client-side check;
  - the qb-inventory paths;
  - the unused moment, Bootstrap JS and jquery-color.
- **Works offline:** jQuery, Font Awesome, Bootstrap CSS and the fonts now ship in `client/nui/vendor` instead of loading from CDNs.
- **Prop:** the streamed prop keeps its model name (`ps_camera`), because the name is inside the model file.
