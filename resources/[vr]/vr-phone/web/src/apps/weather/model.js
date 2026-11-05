// The game has weather types but no temperatures, so the phone works one out from the weather and the hour of the day:
// each weather has a base temperature (Config.Phone.Weather.base) and the day swings warmer in the afternoon (coldest at 03:00, warmest at 15:00).

export function celsius(kind, hour, cfg = {}) {
  const base = cfg.base?.[kind] ?? 18;
  const swing = cfg.daySwing ?? 5;
  return base + swing * Math.cos(((hour - 15) / 24) * 2 * Math.PI);
}

export const toF = (c) => (c * 9) / 5 + 32;

export function degrees(c, fahrenheit) {
  return Math.round(fahrenheit ? toF(c) : c);
}

// The glyph for a weather type. A clear sky at night is the moon.
export function glyphFor(kind, hour) {
  if (kind === 'clear') return hour < 6 || hour >= 21 ? 'moon' : 'sun';
  return { cloud: 'cloud', rain: 'rain', storm: 'storm', fog: 'fog', snow: 'snow' }[kind] ?? 'sun';
}

// Wind in km/h from metres per second.
export const kmh = (ms) => Math.round((Number(ms) || 0) * 3.6);

// A word for the wind.
export function windWord(ms) {
  const v = Number(ms) || 0;
  if (v < 1.5) return 'calm';
  if (v < 5.5) return 'light';
  if (v < 10.8) return 'moderate';
  if (v < 17.2) return 'strong';
  return 'gale';
}
