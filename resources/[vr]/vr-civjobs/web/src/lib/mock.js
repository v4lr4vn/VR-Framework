const q = new URLSearchParams(location.search);

const base = {
  job: 'garbage',
  label: 'Sanitation',
  icon: 'fa-trash-can',
  description: 'Drive the round, collect every bag at each stop and bring the truck home',
  crew: 3,
  level: 7,
  xp: 640,
  xpNext: 1480,
  done: 38,
  earned: 24120,
  mult: 1.12,
  qualified: true,
  needsJob: 'garbage',
  active: null,
  busyWith: null,
  options: [
    { id: 'small', label: 'Short round', detail: '4 stops', level: 1, locked: false },
    { id: 'medium', label: 'Standard round', detail: '7 stops', level: 5, locked: false },
    { id: 'long', label: 'Long round', detail: '11 stops', level: 12, locked: true },
  ],
};

const fisher = {
  ...base,
  job: 'fisherman',
  label: 'Fisherman',
  icon: 'fa-fish',
  description: 'Cast a line from the shore, land the catch and sell it at the fish market',
  crew: 0,
  level: 4,
  xp: 210,
  xpNext: 900,
  done: 12,
  earned: 6310,
  mult: 1.06,
  options: [
    { id: 'free', label: 'Free fishing', detail: 'No contract, just sell what you catch', level: 1, locked: false },
    { id: 'starter', label: 'Local favourites', detail: '4 Carp, 3 Perch, $250', level: 1, locked: false },
    { id: 'harbour', label: 'Harbour supper', detail: '5 Mackerel, 2 Snapper, $420', level: 2, locked: false },
    { id: 'river', label: 'River run', detail: '4 Trout, 2 Salmon, $650', level: 3, locked: false },
    { id: 'deepsea', label: 'Deep sea order', detail: '2 Grouper, 2 Tuna, $1,500', level: 6, locked: true },
  ],
  extra: {
    carried: [
      { item: 'fish_carp', label: 'Carp', count: 6, price: 22 },
      { item: 'fish_mackerel', label: 'Mackerel', count: 3, price: 30 },
      { item: 'fish_tuna', label: 'Tuna', count: 1, price: 150 },
    ],
    bait: { item: 'fishing_bait', price: 6, perCast: 1, bonus: 25 },
    baitCount: 8,
  },
};

const crewed = {
  ...base,
  active: {
    job: 'garbage', me: 1, host: 1, started: 0, pool: 180, vehicles: [], data: {},
    members: [
      { src: 1, name: 'Rae Hale', tasks: 12, host: true },
      { src: 4, name: 'Dex Morrow', tasks: 9, host: false },
    ],
  },
};

const pick = () => {
  const v = q.get('view');
  if (v === 'fisher') return fisher;
  if (v === 'crew') return crewed;
  if (v === 'locked') return { ...base, qualified: false };
  return base;
};

export const mockOpen = () => JSON.parse(JSON.stringify(pick()));

export const mockCall = async (action) => {
  if (action === 'crew.nearby') return { ok: true, data: [{ src: 7, name: 'Mika Ford' }, { src: 9, name: 'Sol Okafor' }] };
  if (action === 'sell') return { ok: true, data: { total: 312, lines: [] } };
  if (action === 'shop') return { ok: true, data: { count: 5, cost: 30 } };
  if (action === 'start') return { ok: true, data: crewed };
  return { ok: true, data: true };
};

export const mockHud = () => ({
  title: 'Garbage round',
  pct: 48,
  lines: [
    { label: 'Stop', value: '3 / 7' },
    { label: 'Bags here', value: '2 / 4' },
    { label: 'Bags total', value: '14' },
    { label: 'Shift pay', value: '$210' },
  ],
});

const SJOBS = [
  { id: 'fisherman', label: 'Fisherman', icon: 'fa-fish', changed: 1, fields: 2 },
  { id: 'garbage', label: 'Garbage Collector', icon: 'fa-trash-can', changed: 2, fields: 5 },
  { id: 'lumberjack', label: 'Lumberjack', icon: 'fa-tree', changed: 0, fields: 6 },
];

const SJOB = {
  id: 'garbage',
  label: 'Garbage Collector',
  icon: 'fa-trash-can',
  fields: [
    { id: 'depot', label: 'Clerk and board', kind: 'vec4', hint: 'Stand where the clerk should stand, facing the way they should face', value: { x: -321.7, y: -1545.9, z: 31.0, w: 0 }, custom: true },
    { id: 'spawn', label: 'Vehicle spawn', kind: 'vec4', value: { x: -316.6, y: -1536.2, z: 27.6, w: 330 }, custom: false },
    { id: 'stopRadius', label: 'Pick-up radius', kind: 'number', min: 8, max: 80, value: 25, custom: true },
    {
      id: 'stops', label: 'Stops', kind: 'list', min: 4, max: 60, custom: true,
      hint: 'Stand in the middle of a street with bags and add it. Every bin bag within the pick-up radius can be collected',
      item: { pos: 'vec3', radius: false, extra: [] },
      value: [{ x: 114.8, y: -1462.3, z: 29.3 }, { x: -6.1, y: -1566.2, z: 29.2 }, { x: -1.6, y: -1464.4, z: 30.5 }, { x: -67.6, y: -1413.6, z: 29.3 }],
    },
    {
      id: 'forests', label: 'Forests', kind: 'list', min: 1, max: 20, custom: false,
      item: { pos: 'area', radius: true, defaultR: 80, extra: [{ key: 'label', label: 'Name', type: 'text' }, { key: 'water', label: 'Water', type: 'choice', options: ['ocean', 'lake', 'river'] }] },
      value: [{ x: -600, y: 5420, z: 62, r: 120, label: 'North woods', water: 'lake' }],
    },
  ],
};

export const mockSetup = () => ({ jobs: JSON.parse(JSON.stringify(SJOBS)), job: JSON.parse(JSON.stringify(SJOB)) });

export const mockSetupCall = async (action) => {
  if (action === 'job') return { ok: true, data: { job: JSON.parse(JSON.stringify(SJOB)), jobs: JSON.parse(JSON.stringify(SJOBS)) } };
  return { ok: true, data: { job: JSON.parse(JSON.stringify(SJOB)), jobs: JSON.parse(JSON.stringify(SJOBS)) } };
};
