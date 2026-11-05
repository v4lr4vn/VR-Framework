// Small colour helpers. The accent is a hex string from the server, and the phone has to work in the
// game's browser, so everything is worked out here instead of with newer CSS colour functions.

export function hexToRgb(hex) {
  const n = parseInt(String(hex).replace('#', ''), 16);
  if (Number.isNaN(n)) return [122, 92, 255];
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex([r, g, b]) {
  const part = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
  return `#${part(r)}${part(g)}${part(b)}`;
}

function luminance([r, g, b]) {
  const f = (c) => {
    c /= 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}

// A readable text colour for something drawn on top of `hex`.
export function inkOn(hex) {
  return luminance(hexToRgb(hex)) > 0.42 ? '#17142a' : '#ffffff';
}

// Moves a colour toward white (amount > 0) or black (amount < 0). amount is -1..1.
export function shade(hex, amount) {
  const target = amount >= 0 ? 255 : 0;
  const k = Math.abs(amount);
  return rgbToHex(hexToRgb(hex).map((c) => c + (target - c) * k));
}

export function mix(hexA, hexB, t) {
  const a = hexToRgb(hexA);
  const b = hexToRgb(hexB);
  return rgbToHex(a.map((c, i) => c + (b[i] - c) * t));
}
