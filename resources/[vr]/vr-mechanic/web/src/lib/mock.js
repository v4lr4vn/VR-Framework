const parts = [
  { key: 'brakes', label: 'Brakes', item: 'brake_pads', icon: 'circle-stop' },
  { key: 'clutch', label: 'Clutch & gearbox', item: 'clutch_kit', icon: 'gear' },
  { key: 'engine', label: 'Engine', item: 'engine_parts', icon: 'gears' },
  { key: 'radiator', label: 'Radiator', item: 'radiator_parts', icon: 'fan' },
  { key: 'suspension', label: 'Suspension', item: 'suspension_parts', icon: 'arrows-up-down' },
  { key: 'tyres', label: 'Tyres', item: 'tyre_set', icon: 'life-ring' },
];

export const inspectPayload = {
  plate: '62KQT481',
  label: 'Karin Sultan RS',
  status: { engine: 71.4, brakes: 22.6, clutch: 54, suspension: 88.1, tyres: 9.8, radiator: 100 },
  mileage: 184320,
  engine: 612,
  body: 744,
  parts,
  repairs: { engine: 'engine_parts', body: 'body_panel' },
  items: { engine_parts: 2, brake_pads: 1, clutch_kit: 0, suspension_parts: 1, tyre_set: 3, radiator_parts: 0, body_panel: 2, repair_kit: 1 },
  workshop: "Benny's Original Motorworks",
  canTune: true,
  warnAt: 30,
};

const performance = [
  { key: 'modEngine', label: 'Engine', levels: [0, 4000, 9000, 16000, 26000] },
  { key: 'modBrakes', label: 'Brakes', levels: [0, 2500, 5000, 9000] },
  { key: 'modTransmission', label: 'Transmission', levels: [0, 3500, 7000, 12000] },
  { key: 'modSuspension', label: 'Suspension', levels: [0, 2000, 4000, 6500, 9000] },
  { key: 'modArmor', label: 'Armour', levels: [0, 5000, 10000, 16000, 24000, 34000] },
  { key: 'modTurbo', label: 'Turbo', toggle: true, price: 18000 },
];

const bodyMods = [
  { key: 'modSpoilers', label: 'Spoiler', id: 0 },
  { key: 'modFrontBumper', label: 'Front bumper', id: 1 },
  { key: 'modRearBumper', label: 'Rear bumper', id: 2 },
  { key: 'modSideSkirt', label: 'Side skirts', id: 3 },
  { key: 'modExhaust', label: 'Exhaust', id: 4 },
  { key: 'modFrame', label: 'Roll cage', id: 5 },
  { key: 'modGrille', label: 'Grille', id: 6 },
  { key: 'modHood', label: 'Hood', id: 7 },
  { key: 'modFender', label: 'Left fender', id: 8 },
  { key: 'modRightFender', label: 'Right fender', id: 9 },
  { key: 'modRoof', label: 'Roof', id: 10 },
  { key: 'modHorns', label: 'Horn', id: 14 },
];

const prices = { paint: 600, pearl: 400, wheelColor: 300, paintType: 300, wheels: 1500, windowTint: 400, plateIndex: 200, neon: 1500, neonColor: 300, xenon: 700, xenonColor: 200, livery: 800, horn: 150, body: 900 };

const swatches = [
  ['Black', [13, 17, 22]], ['Jet', [28, 29, 33]], ['Graphite', [76, 81, 87]], ['Silver', [156, 161, 166]], ['White', [242, 242, 238]],
  ['Red', [182, 17, 27]], ['Crimson', [120, 10, 20]], ['Orange', [247, 134, 22]], ['Gold', [194, 148, 79]], ['Yellow', [245, 210, 26]],
  ['Lime', [102, 184, 31]], ['Green', [21, 92, 45]], ['Teal', [0, 128, 128]], ['Cyan', [40, 200, 230]], ['Blue', [27, 107, 216]],
  ['Navy', [34, 49, 79]], ['Purple', [98, 18, 154]], ['Magenta', [200, 30, 150]], ['Pink', [223, 88, 145]], ['Brown', [78, 52, 36]],
  ['Sand', [196, 170, 120]], ['Olive', [85, 90, 50]],
].map(([label, rgb]) => ({ label, rgb }));

const neonColors = [
  ['White', [255, 255, 255]], ['Blue', [2, 21, 255]], ['Electric blue', [3, 83, 255]], ['Mint', [0, 255, 140]], ['Lime', [94, 255, 1]], ['Yellow', [255, 255, 0]],
  ['Gold', [255, 150, 0]], ['Orange', [255, 62, 0]], ['Red', [255, 1, 1]], ['Pink', [255, 50, 100]], ['Hot pink', [255, 5, 190]], ['Purple', [35, 1, 255]],
].map(([label, rgb]) => ({ label, rgb }));

const palette = [
  [0, 'Black', '#0D1116'], [1, 'Graphite black', '#1C1D21'], [6, 'Graphite', '#4C5157'], [4, 'Silver', '#9CA1A6'], [111, 'White', '#F2F2EE'], [157, 'Ice white', '#E0E3E7'],
  [120, 'Chrome', '#C8CDD1'], [27, 'Red', '#B6111B'], [35, 'Candy red', '#8F0D14'], [38, 'Orange', '#F78616'], [158, 'Gold', '#C2944F'], [88, 'Yellow', '#F5D21A'],
  [92, 'Lime', '#9CC52E'], [53, 'Green', '#155C2D'], [49, 'Racing green', '#16362A'], [68, 'Sky blue', '#3C8FC0'], [70, 'Ultra blue', '#1B6BD8'], [64, 'Navy', '#22314F'],
  [145, 'Purple', '#62129A'], [137, 'Pink', '#DF5891'], [96, 'Brown', '#4E3424'], [99, 'Bronze', '#9C7C44'],
].map(([id, label, hex]) => ({ id, label, hex }));

const xenonColors = [
  [255, 'Stock', '#DCE6FF'], [0, 'White', '#FFFFFF'], [1, 'Blue', '#2A5CFF'], [2, 'Electric blue', '#3B93FF'], [3, 'Mint', '#3CFFB4'], [4, 'Lime', '#9DFF3C'], [5, 'Yellow', '#FFEF3C'],
  [6, 'Gold', '#FFC23C'], [7, 'Orange', '#FF8A3C'], [8, 'Red', '#FF3C3C'], [9, 'Pony pink', '#FF7AB8'], [10, 'Hot pink', '#FF3CC8'], [11, 'Purple', '#A03CFF'], [12, 'Blacklight', '#5A3CFF'],
].map(([id, label, hex]) => ({ id, label, hex }));

const opts = (names) => names;

export const tunePayload = {
  workshop: { id: 'bennys', label: "Benny's Original Motorworks" },
  plate: '62KQT481',
  label: 'Karin Sultan RS',
  prices,
  performance,
  bodyMods,
  commission: 20,
  customers: [{ id: 14, distance: 2.1 }, { id: 31, distance: 5.7 }],
  me: { cash: 2450, bank: 48210, company: { label: 'Mechanic', balance: 182400 } },
  preview: true,
  palette,
  swatches,
  neonColors,
  xenonColors,
  maxBill: 250000,
  options: {
    perf: { modEngine: 4, modBrakes: 3, modTransmission: 3, modSuspension: 4, modArmor: 5, modTurbo: 1 },
    body: {
      modSpoilers: opts(['Carbon lip', 'Low wing', 'Race wing', 'GT wing', 'Ducktail']),
      modFrontBumper: opts(['Carbon splitter', 'Race bumper', 'Street bumper']),
      modRearBumper: opts(['Diffuser', 'Race diffuser']),
      modSideSkirt: opts(['Carbon skirts', 'Wide skirts']),
      modExhaust: opts(['Titanium tips', 'Big bore', 'Twin exit', 'Side exit']),
      modHood: opts(['Vented hood', 'Carbon hood', 'Race hood']),
      modRoof: opts(['Carbon roof']),
      modHorns: opts(['Horn 1', 'Horn 2', 'Horn 3', 'Horn 4', 'Horn 5']),
    },
    livery: { key: 'modLivery', options: ['ValRavn Racing', 'Stripes', 'Sponsor pack'] },
    bike: false,
    wheelTypes: [[0, 'Sport'], [1, 'Muscle'], [2, 'Lowrider'], [3, 'SUV'], [4, 'Off-road'], [5, 'Tuner'], [7, 'High end'], [8, "Benny's Original"], [9, "Benny's Bespoke"], [10, 'Open wheel'], [11, 'Street'], [12, 'Track']],
    neon: true,
  },
  current: {
    modEngine: 1, modBrakes: -1, modTransmission: 0, modSuspension: -1, modArmor: -1, modTurbo: false,
    modSpoilers: -1, modFrontBumper: 0, modRearBumper: -1, modSideSkirt: -1, modExhaust: 1, modFrame: -1, modGrille: -1, modHood: -1, modFender: -1, modRightFender: -1, modRoof: -1, modHorns: -1,
    color1: [27, 107, 216], color2: [13, 17, 22], paintType1: 1, paintType2: 0, pearlescentColor: 0, wheelColor: 0,
    wheels: 0, modFrontWheels: 3, modCustomTiresF: false, windowTint: -1, plateIndex: 0,
    neonEnabled: [false, false, false, false], neonColor: [255, 255, 255], modXenon: false, xenonColor: 255, livery: -1, modLivery: -1,
  },
};

export const designPayload = {
  ...tunePayload,
  design: true,
  performance: [],
  customers: undefined,
  me: undefined,
  commission: undefined,
};

const tasks = [
  { n: 1, id: 'paint1', label: 'Primary paint', work: 'paint', price: 900, done: true, seconds: 20 },
  { n: 2, id: 'wheels', label: 'Wheels', work: 'wheel', price: 1500, done: true, seconds: 12 },
  { n: 3, id: 'neon', label: 'Neon kit', work: 'under', price: 1800, done: false, seconds: 14 },
  { n: 4, id: 'windowTint', label: 'Window tint', work: 'glass', price: 400, done: false, seconds: 12 },
  { n: 5, id: 'modSpoilers', label: 'Spoiler', work: 'body', price: 900, done: false, seconds: 10 },
];

export const orderPayload = (status, role) => ({
  id: 12, status, source: 'customer', plate: '62KQT481', vehicle: 'Karin Sultan RS', customer: 'Ty Okafor', workshop: "Benny's Original Motorworks",
  items: [{ label: 'Primary paint', price: 600 }, { label: 'Primary finish', price: 300 }, { label: 'Wheels', price: 1500 }, { label: 'Neon kit', price: 1500 }, { label: 'Neon colour', price: 300 }, { label: 'Window tint', price: 400 }, { label: 'Spoiler', price: 900 }],
  tasks: status === 'paid' ? tasks : tasks.map((t) => ({ ...t, done: status === 'done' })),
  total: 5500, created: Math.floor(Date.now() / 1000) - 3600, mechanic: status === 'paid' || status === 'done' ? 'Rosa Vance' : null, role, commission: 20,
});

export const boardPayload = {
  orders: [
    { id: 14, status: 'paid', source: 'mechanic', plate: '81JDF220', vehicle: 'Bravado Buffalo', customer: 'Ana Ruiz', workshop: "Benny's Original Motorworks", total: 26000, tasks: 3, done: 1, created: Math.floor(Date.now() / 1000) - 600 },
    { id: 12, status: 'open', source: 'customer', plate: '62KQT481', vehicle: 'Karin Sultan RS', customer: 'Ty Okafor', workshop: "Benny's Original Motorworks", total: 5500, tasks: 5, done: 0, created: Math.floor(Date.now() / 1000) - 3600 },
    { id: 9, status: 'billed', source: 'customer', plate: '45KPL991', vehicle: 'Pegassi Faggio', customer: 'Lee Park', workshop: 'LS Customs Burton', total: 1100, tasks: 2, done: 0, created: Math.floor(Date.now() / 1000) - 86400 * 2 },
  ],
};

export const shopPayload = {
  workshop: { id: 'bennys', label: "Benny's Original Motorworks" },
  items: [
    { item: 'engine_parts', label: 'Engine parts', price: 600, have: 2 },
    { item: 'brake_pads', label: 'Brake pads', price: 250, have: 1 },
    { item: 'clutch_kit', label: 'Clutch kit', price: 400, have: 0 },
    { item: 'suspension_parts', label: 'Suspension parts', price: 450, have: 1 },
    { item: 'tyre_set', label: 'Tyre set', price: 350, have: 3 },
    { item: 'radiator_parts', label: 'Radiator parts', price: 300, have: 0 },
    { item: 'body_panel', label: 'Body panels', price: 250, have: 2 },
    { item: 'repair_kit', label: 'Repair kit', price: 400, have: 1 },
  ],
  me: { cash: 2450, bank: 48210, company: { label: 'Mechanic', balance: 182400 } },
};

export const invoicePayload = { customers: [{ id: 14, distance: 2.1 }, { id: 31, distance: 5.7 }], max: 250000, commission: 20, seconds: 60 };

export const billPayload = {
  token: 'T1', kind: 'order', note: 'Order #12', mechanic: 'Rosa', business: 'Mechanic', workshop: "Benny's Original Motorworks", vehicle: 'Karin Sultan RS', plate: '62KQT481',
  items: [{ label: 'Engine level 3', price: 16000 }, { label: 'Primary paint', price: 600 }, { label: 'Primary finish', price: 300 }, { label: 'Spoiler', price: 900 }, { label: 'Turbo', price: 18000 }],
  amount: 35800, seconds: 60, cash: 2450, bank: 48210,
};

const LABELS = { color1: 'Primary paint', color2: 'Secondary paint', paintType1: 'Primary finish', paintType2: 'Secondary finish', pearlescentColor: 'Pearlescent', wheelColor: 'Wheel colour', wheels: 'Wheels', modFrontWheels: 'Wheels', windowTint: 'Window tint', plateIndex: 'Plate style', neonEnabled: 'Neon kit', neonColor: 'Neon colour', modXenon: 'Xenon lights', xenonColor: 'Xenon colour', livery: 'Livery', modLivery: 'Livery' };
const GROUP = { color1: 'paint', color2: 'paint', paintType1: 'paintType', paintType2: 'paintType', pearlescentColor: 'pearl', wheelColor: 'wheelColor', wheels: 'wheels', modFrontWheels: 'wheels', modCustomTiresF: 'wheels', windowTint: 'windowTint', plateIndex: 'plateIndex', neonEnabled: 'neon', neonColor: 'neonColor', modXenon: 'xenon', xenonColor: 'xenonColor', livery: 'livery', modLivery: 'livery' };

function quote(changes) {
  const items = [];
  let wheels = false;
  for (const [k, v] of Object.entries(changes)) {
    const perf = performance.find((p) => p.key === k);
    if (perf) {
      if (perf.toggle) items.push({ key: k, label: v ? perf.label : `Remove ${perf.label.toLowerCase()}`, price: v ? perf.price : 0 });
      else items.push({ key: k, label: v < 0 ? `${perf.label} stock` : `${perf.label} level ${v + 1}`, price: perf.levels[v + 1] || 0 });
      continue;
    }
    const body = bodyMods.find((b) => b.key === k);
    if (body) {
      items.push({ key: k, label: body.label, price: v < 0 ? 0 : k === 'modHorns' ? prices.horn : prices.body });
      continue;
    }
    if (GROUP[k] === 'wheels') {
      if (wheels) continue;
      wheels = true;
    }
    items.push({ key: k, label: LABELS[k] || k, price: prices[GROUP[k]] || 0 });
  }
  items.sort((a, b) => a.label.localeCompare(b.label));
  return { items, total: items.reduce((s, i) => s + i.price, 0) };
}

export async function mockCall(action, data) {
  await new Promise((r) => setTimeout(r, 120));
  switch (action) {
    case 'design.quote':
    case 'tune.quote':
      return Object.keys(data.changes || {}).length ? { ok: true, data: quote(data.changes) } : { ok: false, error: 'nothing_to_do' };
    case 'tune.bill':
      return { ok: true, data: { token: 'T2', amount: quote(data.changes).total, seconds: 60 } };
    case 'tune.self':
      return { ok: true, data: { total: quote(data.changes).total, orderId: 15 } };
    case 'design.order':
      return { ok: true, data: { id: 16, total: quote(data.changes).total } };
    case 'order.bill':
      return { ok: true, data: { token: 'T4', amount: 5500, seconds: 60 } };
    case 'order.cancel':
      return { ok: true, data: { ...orderPayload('cancelled', 'customer') } };
    case 'customers':
      return { ok: true, data: invoicePayload.customers };
    case 'bill.labour':
      return { ok: true, data: { token: 'T3', amount: data.amount, seconds: 60 } };
    case 'shop.buy': {
      const it = shopPayload.items.find((i) => i.item === data.item);
      return { ok: true, data: { item: data.item, count: data.count, total: it.price * data.count, have: it.have + data.count, me: shopPayload.me } };
    }
    default:
      return { ok: true, data: {} };
  }
}

const WHEEL_NAMES = ['Inferno', 'Deep Five', 'Lozspeed Mk.V', 'Diamond Cut', 'Chrono', 'Feroci RR', 'FiftyNine', 'Mercie', 'Synthetic Z', 'Organic Type 0', 'Endo v.1', 'GT One', 'Duper 7', 'Uzer', 'Ground Ride', 'S Racer', 'Venum', 'Cosmo', 'Dash VIP', 'Ice Kid', 'Ruff Weld', 'Wangan Master', 'Super Five', 'Endo v.2', 'Split Six'];
export const mockWheels = (t) => WHEEL_NAMES.slice(0, 12 + ((Number(t) || 0) % 6) * 2);
