const types = [
  ['EXTRASUNNY', 'Sunny'], ['CLEAR', 'Clear'], ['NEUTRAL', 'Mild'], ['SMOG', 'Smog'], ['FOGGY', 'Fog'],
  ['CLOUDS', 'Cloudy'], ['OVERCAST', 'Overcast'], ['CLEARING', 'Clearing'], ['RAIN', 'Rain'], ['THUNDER', 'Thunderstorm'],
  ['SNOWLIGHT', 'Light snow'], ['SNOW', 'Snow'], ['BLIZZARD', 'Blizzard'], ['XMAS', 'Deep snow'], ['HALLOWEEN', 'Halloween'],
].map(([name, label]) => ({ name, label }));

const label = (n) => types.find((t) => t.name === n)?.label || n;

export function mockPayload(over = {}) {
  const weather = over.weather || 'CLOUDS';
  const forecast = [
    { weather, label: label(weather), startsIn: 0, endsIn: 1380, temp: 12, current: true },
    { weather: 'OVERCAST', label: 'Overcast', startsIn: 1380, endsIn: 3180, temp: 11 },
    { weather: 'RAIN', label: 'Rain', startsIn: 3180, endsIn: 5400, temp: 9 },
    { weather: 'THUNDER', label: 'Thunderstorm', startsIn: 5400, endsIn: 6900, temp: 7 },
    { weather: 'CLEARING', label: 'Clearing', startsIn: 6900, endsIn: 8700, temp: 8 },
    { weather: 'CLOUDS', label: 'Cloudy', startsIn: 8700, endsIn: 10800, temp: 10 },
    { weather: 'CLEAR', label: 'Clear', startsIn: 10800, endsIn: 13000, temp: 13 },
  ];
  return {
    time: { minute: 872, freeze: false, dayLength: 150, nightShare: 0.3, ns: 21, ne: 6, real: false, ...(over.time || {}) },
    weather: { weather, label: label(weather), blackout: false, freeze: false, dynamic: true, season: 'autumn', snow: false, transition: 45, temp: 12, ...(over.w || {}) },
    forecast,
    types,
    seasons: [{ key: 'autumn', label: 'Autumn' }, { key: 'spring', label: 'Spring' }, { key: 'summer', label: 'Summer' }, { key: 'winter', label: 'Winter' }],
    seasonLabel: 'Autumn',
    presets: [{ label: 'Morning', hour: 7, minute: 0 }, { label: 'Noon', hour: 12, minute: 0 }, { label: 'Evening', hour: 18, minute: 30 }, { label: 'Night', hour: 23, minute: 0 }],
    dayLengths: [48, 90, 120, 150, 180, 1440],
    limits: { min: 20, max: 1440 },
    units: 'C',
    holiday: null,
  };
}
