// Wallpapers are drawn with CSS gradients, so they cost nothing to load and follow the accent colour.
// The ids must match Config.Phone.Wallpapers in config/phone.lua.
export const wallpapers = {
  aurora:
    'radial-gradient(120% 80% at 12% 8%, var(--accent-light) 0%, transparent 58%), radial-gradient(90% 80% at 92% 18%, #38cfc4 0%, transparent 52%), radial-gradient(110% 90% at 50% 105%, #1c1745 0%, transparent 72%), #2a2160',
  dusk:
    'radial-gradient(110% 80% at 80% 6%, #ffb36b 0%, transparent 55%), radial-gradient(100% 90% at 8% 40%, var(--accent) 0%, transparent 60%), radial-gradient(120% 90% at 60% 110%, #1a1233 0%, transparent 70%), #3a2466',
  ember:
    'radial-gradient(100% 80% at 20% 0%, #ff8a5c 0%, transparent 56%), radial-gradient(90% 80% at 95% 35%, #e0436b 0%, transparent 55%), radial-gradient(120% 90% at 40% 110%, #25101c 0%, transparent 70%), #4a1830',
  tide:
    'radial-gradient(110% 80% at 85% 5%, #7fe3d6 0%, transparent 55%), radial-gradient(100% 90% at 5% 45%, #2f7be0 0%, transparent 60%), radial-gradient(120% 90% at 55% 110%, #0b1d3a 0%, transparent 70%), #12335f',
  paper: 'linear-gradient(160deg, #f3f0e8 0%, #e4dfd2 100%)',
  night:
    'radial-gradient(1.4px 1.4px at 18% 22%, #fff 0, transparent 100%), radial-gradient(1px 1px at 72% 12%, #fff 0, transparent 100%), radial-gradient(1.2px 1.2px at 40% 64%, #cfd6ff 0, transparent 100%), radial-gradient(1px 1px at 86% 70%, #fff 0, transparent 100%), radial-gradient(120% 90% at 50% 110%, #1a1f4a 0%, transparent 70%), #080a18',
};

// Wallpapers that are light, so text and icons on top of them turn dark.
export const lightWallpapers = { paper: true };

export function wallpaper(id) {
  return wallpapers[id] ?? wallpapers.aurora;
}
