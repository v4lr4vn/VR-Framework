# vr-microphone

Microphone stands and a megaphone for the ValRavn framework. Both lift your voice range through **vr-voice** (`overrideProximityRange` / `clearProximityOverride`).

- **Stands:** stand inside a box from `Config.Stands` and your voice range becomes that stand's `range`. `prop = true` spawns a microphone stand there while you are within 150 m. Add your own stands to the list.
- **Megaphone:** use the `megaphone` item to pick it up and use it again to put it away. While held your range is `Config.MegaphoneRange`. It drops if you die, cancel the animation or lose the item. If you stand in a stand box and hold the megaphone, the larger range wins.

The item has to exist in your inventory: `megaphone` with an image named `megaphone.png`. The image ships in `images/`.

## Credits

Written by ValRavn. The idea of voice zones and a megaphone is a common one on FiveM servers; no code from other resources is used.
