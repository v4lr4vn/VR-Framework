const now = () => Math.floor(Date.now() / 1000);

const base = [
  { plate: '19RAE007', model: 'buffalo', label: 'Bravado Buffalo', nickname: 'Night Shift', category: 'car', status: 'stored', garage: 'alta', garageLabel: 'Alta Street', fuel: 82, engine: 97, body: 91, mileage: 412800, mine: true, usable: true },
  { plate: '44XQN108', model: 'bison', label: 'Bravado Bison', category: 'car', status: 'stored', garage: 'motel', garageLabel: 'Pink Cage Motel', fuel: 35, engine: 64, body: 58, mileage: 1890400, mine: true, usable: true },
  { plate: '82KLM441', model: 'sultan', label: 'Karin Sultan', category: 'car', status: 'out', garage: 'alta', garageLabel: 'Alta Street', fuel: 51, engine: 88, body: 76, mileage: 920300, mine: true, usable: true },
  { plate: '61VLK220', model: 'faggio', label: 'Pegassi Faggio', category: 'car', status: 'lost', garage: 'beach', garageLabel: 'Vespucci Beach', fuel: 12, engine: 41, body: 33, mileage: 230100, mine: true, usable: true },
  { plate: '08SNV332', model: 'blista', label: 'Dinka Blista', category: 'car', status: 'impounded', garage: 'impound', garageLabel: 'Davis Impound Lot', fuel: 66, engine: 90, body: 70, mileage: 110000, mine: true, usable: true,
    impound: { reason: 'Parked across two disabled bays outside Pillbox', fee: 750, readyAt: now() + 2 * 3600, by: 'Rae Hale', at: now() - 3600 } },
  { plate: '33ZZT901', model: 'baller', label: 'Gallivanter Baller', category: 'car', status: 'held', garage: 'impound', garageLabel: 'Davis Impound Lot', fuel: 70, engine: 100, body: 100, mileage: 54000, mine: true, usable: false,
    impound: { reason: 'Repossessed by the bank', fee: 0, readyAt: 0, by: 'ValRavn Bank', at: now() - 86400 } },
];

const db = { vehicles: JSON.parse(JSON.stringify(base)) };

const garages = {
  alta: { id: 'alta', label: 'Alta Street', type: 'public', category: 'car' },
  police_fleet: { id: 'police_fleet', label: 'Mission Row Garage', type: 'job', category: 'car', groupLabel: 'Law Enforcement' },
  impound: { id: 'impound', label: 'Davis Impound Lot', type: 'impound', category: 'all' },
};

export function mockPayload(id = 'alta') {
  const g = garages[id];
  let vehicles = db.vehicles.map((v) => ({ ...v, here: v.garage === id }));
  if (g.type === 'impound') vehicles = vehicles.filter((v) => ['impounded', 'lost', 'held'].includes(v.status));
  else if (g.type === 'job') vehicles = [];
  const jobVehicles = g.type === 'job' ? [
    { id: 1, model: 'police', label: 'Patrol Cruiser', name: 'Vapid Police Cruiser', grade: 0, allowed: true, category: 'car', plate: 'LSPD' },
    { id: 2, model: 'police3', label: 'Interceptor', name: 'Vapid Police Interceptor', grade: 2, allowed: true, category: 'car', plate: 'LSPD' },
    { id: 3, model: 'policeb', label: 'Traffic Bike', name: 'Western Police Bike', grade: 1, allowed: true, category: 'car', plate: 'LSPD' },
    { id: 4, model: 'fbi2', label: 'Command SUV', name: 'Declasse Granger', grade: 4, allowed: false, category: 'car', plate: 'LSPD' },
  ] : [];
  return { garage: g, vehicles, jobVehicles, jobLimit: 1, fees: { transfer: 250, recover: 250 }, now: now() };
}

const ok = (data) => ({ ok: true, data });
const fail = (error, data) => ({ ok: false, error, data });

export function mockCall(action, data, garageId) {
  const v = db.vehicles.find((x) => x.plate === data.plate);
  let res;
  if (action === 'open') res = ok(mockPayload(garageId));
  else if (action === 'takeOut') {
    if (v.garage !== garageId && !data.transfer) res = fail('elsewhere', { fee: 250 });
    else { v.status = 'out'; v.garage = garageId; res = ok({ netId: 1 }); }
  } else if (action === 'locate') res = ok({ x: 1, y: 2, z: 3 });
  else if (action === 'jobveh.take') res = ok({ netId: 1, plate: 'LSPD4821' });
  else if (action === 'rename') { v.nickname = data.name; res = ok(true); }
  else if (action === 'impound.release') {
    if (v.impound && v.impound.readyAt > now()) res = fail('not_ready', { readyAt: v.impound.readyAt });
    else { v.status = 'out'; res = ok({ netId: 1, fee: 250 }); }
  } else res = fail('bad_request');
  return new Promise((r) => setTimeout(() => r(JSON.parse(JSON.stringify(res))), 100));
}

const spot = (x, y, z, w) => ({ x, y, z, w });
const bdb = {
  garages: [
    { id: 'alta', label: 'Alta Street', type: 'public', category: 'car', group: null, requireDuty: false, blip: true, setupMenu: false, center: { x: -330.01, y: -780.33, z: 33.96 }, radius: 18, spawns: [spot(-341.57, -767.45, 33.56, 92.61)], ped: null, vehicles: [], source: 'config' },
    { id: 'police_fleet', label: 'Mission Row Garage', type: 'job', category: 'car', group: 'police', requireDuty: true, blip: true, setupMenu: true, center: { x: 474.0, y: -1012.7, z: 29.31 }, radius: 14, spawns: [spot(473.89, -1015.31, 29.31, 357.73), spot(450.47, -1019.84, 28.45, 90.05)], ped: { model: 'mp_m_weapexp_01', x: 466.21, y: -1010.05, z: 29.46, w: 0 }, vehicles: [
      { model: 'centurionlssd', label: 'Bear Cat', grade: 0, plate: 'LSPD' },
      { model: 'police2', label: 'Police 2', grade: 2, plate: 'LSPD', livery: 1, extras: [{ id: 1, on: true }, { id: 2, on: false }], maxMods: true },
    ], source: 'edited' },
    { id: 'ems_fleet', label: 'Pillbox Garage', type: 'job', category: 'car', group: 'ambulance', requireDuty: true, blip: true, setupMenu: true, center: { x: 294.28, y: -608.32, z: 43.32 }, radius: 12, spawns: [spot(294.28, -608.32, 43.32, 69.6)], ped: { model: 'mp_m_weapexp_01', x: 291.22, y: -614.9, z: 42.42, w: 332.9 }, vehicles: [{ model: 'ambulance', label: 'Ambulance', grade: 0, plate: 'EMS' }], source: 'config' },
    { id: 'grove_lot', label: 'Grove Street Lot', type: 'gang', category: 'car', group: 'ballas', requireDuty: false, blip: false, setupMenu: false, center: { x: 100, y: -1900, z: 21 }, radius: 10, spawns: [], ped: null, vehicles: [], source: 'built' },
    { id: 'impound', label: 'Davis Impound Lot', type: 'impound', category: 'all', group: null, requireDuty: false, blip: true, setupMenu: false, center: { x: 400.45, y: -1630.87, z: 29.29 }, radius: 20, spawns: [spot(407.2, -1645.58, 29.31, 228.28)], ped: null, vehicles: [], source: 'config' },
    { id: 'higgins', label: 'Higgins Helitours', type: 'public', category: 'air', group: null, requireDuty: false, blip: true, setupMenu: false, center: { x: -722.12, y: -1472.74, z: 5 }, radius: 25, spawns: [spot(-724.83, -1443.89, 5, 135.78)], ped: null, vehicles: [], source: 'removed' },
  ],
};

const grades = (names) => names.map((name, level) => ({ level, name }));

export function mockBuilder() {
  return {
    garages: JSON.parse(JSON.stringify(bdb.garages)),
    groups: {
      job: [
        { name: 'ambulance', label: 'EMS', grades: grades(['Recruit', 'Paramedic', 'Doctor', 'Surgeon', 'Chief']) },
        { name: 'mechanic', label: 'LS Customs', grades: grades(['Recruit', 'Novice', 'Experienced', 'Advanced', 'Manager']) },
        { name: 'police', label: 'Law Enforcement', grades: grades(['Recruit', 'Officer', 'Sergeant', 'Lieutenant', 'Chief']) },
      ],
      gang: [{ name: 'ballas', label: 'Ballas', grades: grades(['Recruit', 'Enforcer', 'Shot Caller', 'Boss']) }],
    },
    radius: 18,
    me: { x: 215.4, y: -810.2, z: 30.7, w: 160 },
  };
}

export function builderCall(action, data) {
  let res;
  if (action === 'builder.save') {
    const i = bdb.garages.findIndex((g) => g.id === data.id);
    if (data.isNew && i >= 0) res = fail('id_taken');
    else {
      const g = { ...data.garage, id: data.id, source: i >= 0 && bdb.garages[i].source === 'config' ? 'edited' : i >= 0 ? bdb.garages[i].source : 'built' };
      if (i >= 0) bdb.garages[i] = g;
      else bdb.garages.push(g);
      res = ok({ garages: bdb.garages, id: data.id });
    }
  } else if (action === 'builder.delete') {
    const g = bdb.garages.find((x) => x.id === data.id);
    if (g.source === 'built') bdb.garages = bdb.garages.filter((x) => x.id !== data.id);
    else g.source = 'removed';
    res = ok({ garages: bdb.garages });
  } else if (action === 'builder.reset') {
    const g = bdb.garages.find((x) => x.id === data.id);
    g.source = 'config';
    res = ok({ garages: bdb.garages });
  } else res = fail('bad_request');
  return new Promise((r) => setTimeout(() => r(JSON.parse(JSON.stringify(res))), 120));
}
