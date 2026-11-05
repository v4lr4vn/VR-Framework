# vr-loading

The ValRavn loading screen. Night Shift look (dark navy, amber accent, IBM Plex), written from scratch for this framework.

## What it shows

- Server wordmark, tagline and a personal welcome with the player's name.
- A **real progress bar**: it follows what the game is actually loading (init functions, data files, the map) and the stage label changes with it ("Reading game data", "Loading the map", "Joining the city"). It never goes backwards and never sits at 100% before the game is ready.
- Rotating tips, a "What's new" panel, and optional Rules, Staff and Links panels (hidden while empty).
- A music player (Space = play/pause, Left/Right = track, Up/Down = volume). The player's volume and pause choice are remembered.
- A procedural night city behind it all, or your own background **videos** and images.

## Install

1. Keep the folder name `vr-loading` (renamed copies refuse to run).
2. `ensure vr-loading` in `server.cfg`, before the other resources.

## Edit it

Everything you will want to change is in **`web/config.js`**: server name and tagline, tips, news, rules, staff, links, backgrounds, music. No HTML knowledge needed. Restart the resource (or the server) after editing; connecting players see the change on their next join.

- **News:** `{ date: '2 Nov', title: '...', text: '...' }`, newest first. Three or four fit nicely.
- **Backgrounds:** drop pictures **or videos** in `web/backgrounds/` and list them in `config.js` as `backgrounds/name.webm`, `backgrounds/name.jpg` and so on. One video loops for ever. With several backgrounds (any mix) each one fades into the next: pictures stay `backgroundStyle.imageSeconds`, a video plays to its end (or `videoMaxSeconds`). `{ video: '...', poster: '...' }` shows a picture until the video plays. `backgroundStyle.dim` darkens them so the text stays readable, and `hideCity` hides the animated city while they show. They are in `fxmanifest.lua` already (`web/backgrounds/*`).
- **Video tips:** videos play **muted** (your music is the sound), so strip the audio. Every connecting player downloads the file, so keep it small: 1080p, 10 to 30 seconds, aim for under 20 MB. WebM (VP9) is the smallest and plays everywhere in the game's browser. MP4 (H.264) works too. To make one: `ffmpeg -i input.mp4 -t 25 -vf "scale=1920:-2,fps=30" -c:v libvpx-vp9 -crf 35 -b:v 0 -an out.webm`. A clip that fails to load or play is skipped, and if none play the night city comes back. Only use footage you have the rights to.
- **Music:** put mp3 files in `song/`, add them to `music.tracks` and to `files` in `fxmanifest.lua` if the file name differs from `song/*`. Set `music.enabled = false` to turn it off. Only use music you have the rights to; the bundled tracks are NoCopyrightSounds releases and the credit line on screen is part of their terms.
- **Colours:** the `:root` block at the top of `web/style.css`.

## Preview without launching the game

Serve the `web` folder with any static server and open `index.html?demo` (for example `python -m http.server` inside `web`, then `http://localhost:8000/?demo`). Demo mode simulates the load events and shows "Preview" as the player name.

## How it closes

`fxmanifest.lua` sets `loadscreen_manual_shutdown`, so the screen stays up through connecting and character select. `client.lua` closes it the first time the player spawns (`playerSpawned`). If your spawn flow never fires that event, call `ShutdownLoadingScreenNui()` yourself once the player is in the world.

`server.lua` passes the player's name to the page (`playerConnecting` handover). The name is written to the page as plain text and cut to 32 characters.

## Files

```
vr-loading/
  fxmanifest.lua   client.lua   server.lua   guard.lua
  web/             index.html  style.css  config.js  app.js  fonts/
  song/            music files
```

## Licence note

The screen itself (`web/`, `client.lua`, `server.lua`) is new and not derived from the stand-in it replaced. The `LICENSE` file in this folder is the GPL-3 text that came with that old stand-in (bd_loadingscreen by BebikDEV); none of its code is included any more. Fonts are IBM Plex (SIL Open Font License).
