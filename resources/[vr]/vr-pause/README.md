# vr-pause

Changes the pause menu: background, title, the server name and text in the header, and the menu colours. It's a port of **ps-pause** by Project Sloth (CC BY-NC-SA 4.0, see `LICENSE`).

## Configuration

Edit `config.lua`:
- `Config.Background`: one of `background_blue`, `background_darkblue`, `background_darkerblue`, `background_darkgreen`, `background_green`, `background_other`, `background_pink`, `background_red` or `background_yellow`.
- `Config.Opacity`: 0–255.
- `Config.Header`:
  - `TITLE` and `SUBTITLE` set the top-left title.
  - `SERVER_NAME`, `SERVER_TEXT` and `SERVER_DISCORD` set the top-right header. Put your Discord invite in `SERVER_DISCORD` if you want it shown.
  - The other keys rename the menu tabs.
- `Config.RGBA`: the line, option and waypoint colours.

## Changes from ps-pause

- Project Sloth's branding is replaced with ValRavn: the title, the header texts and the Project Sloth background.
- The background is drawn every frame while the menu is open, so it no longer flickers. It reloads its textures if the game unloaded them.
- A stray scaleform call is removed.

The texture file keeps its original name (`stream/ps_pause.ytd`, dictionary `ps_pause`), because the texture names are inside the file.
