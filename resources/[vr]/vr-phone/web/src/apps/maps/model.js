// Maps maths and look-up tables that do not need the screen, so they can be tested on their own.

// Icons a saved place can have. Each one is a glyph in lib/glyphs.js.
export const ICONS = ['pin', 'home', 'work', 'star', 'heart', 'food', 'bag', 'fuel', 'cross', 'shield', 'bank', 'plane', 'anchor', 'wrench'];
const GLYPH = { pin: 'maps', home: 'home', work: 'work', star: 'star', heart: 'heart', food: 'food', bag: 'bag', fuel: 'fuel', cross: 'cross', shield: 'shield', bank: 'bank', plane: 'plane', anchor: 'anchor', wrench: 'wrench' };
export const glyphOf = (icon) => GLYPH[icon] ?? 'maps';

export const CATEGORIES = ['services', 'shops', 'travel', 'places'];
export const COLOR = { services: '#3b82f6', shops: '#e0922a', travel: '#7a5cff', places: '#1fa596', saved: '#e8527a', pin: '#475569' };

// How far the map can zoom out (half the map's height, in metres) as a multiple of the closest zoom.
export const ZOOM_STEPS = 6;

export function radiusFor(zoom, range = 250) {
  return range * 2 ** Math.max(0, Math.min(ZOOM_STEPS - 1, zoom));
}

// Metres across the screen -> a world-to-screen function. The map is north-up: up on the screen is +y in the world.
export function projection({ cx, cy, width, height, radius }) {
  const ppm = Math.min(width, height) / 2 / radius;
  return {
    ppm,
    x: (wx) => width / 2 + (wx - cx) * ppm,
    y: (wy) => height / 2 - (wy - cy) * ppm,
    // and back again
    wx: (sx) => cx + (sx - width / 2) / ppm,
    wy: (sy) => cy - (sy - height / 2) / ppm,
  };
}

// Grid spacing in metres that keeps the lines roughly 70 pixels apart.
export function gridStep(ppm) {
  const wanted = 70 / ppm;
  for (const step of [10, 25, 50, 100, 250, 500, 1000, 2000, 5000]) if (step >= wanted) return step;
  return 5000;
}

export function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

// Degrees clockwise from north, from one point to another.
export function bearingTo(from, to) {
  const deg = (Math.atan2(to.x - from.x, to.y - from.y) * 180) / Math.PI;
  return (deg + 360) % 360;
}

export function distanceText(m) {
  if (!Number.isFinite(m)) return '';
  if (m < 1000) return `${Math.round(m / 10) * 10 || Math.round(m)} m`;
  return `${(m / 1000).toFixed(m < 10000 ? 1 : 0)} km`;
}

// Whole minutes for a straight-line distance. Roads are longer than a straight line, so a drive gets a margin.
export function minutes(m, how) {
  const metresPerSecond = how === 'drive' ? 14 : 1.4;
  const detour = how === 'drive' ? 1.35 : 1.15;
  return Math.max(1, Math.round((m * detour) / metresPerSecond / 60));
}

const POINTS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
export const compassPoint = (bearing) => POINTS[Math.round((((bearing % 360) + 360) % 360) / 45) % 8];
