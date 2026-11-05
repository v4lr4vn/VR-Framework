# vr-notepad

Write a note with the notepad item (or `/notepad`) and leave it on the ground as a crumpled piece of paper. Other players walk up, read it or tear it up. A link to a picture shows up as the picture. Notes can be anonymous.

Written from scratch for the ValRavn framework.

## Setup

1. Make sure the `notepad` item exists in your inventory items (the name is `Config.Item`).
2. Put `vr-notepad` in `[vr]` and restart.

## How it works

- Using the item or `/notepad` opens a writing box. The server opens it, so nobody can create notes without using the item.
- The note is dropped where you stand. Everyone nearby sees the paper and gets "Read the note" and "Tear it up" on the target.
- Text is capped (`Config.MaxLength`), each character can have a few notes out, and the server has a limit. Notes crumble after `Config.ExpireMinutes` and are gone on restart.
- Only an id and a position go to other players. The text is sent only to someone standing at the note who reads it.
- Links are only shown as a picture when they are plain http(s) links ending in .png, .jpg, .gif or .webp. Nothing from the client is trusted as markup.

## Licence

Original work for the ValRavn framework.
