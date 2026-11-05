const now = () => Math.floor(Date.now() / 1000);
const DAY = 86400;

const state = {
  money: { cash: 320, bank: 18450 },
  items: { id_card: false, driver_license: true, weaponlicense: false },
  licences: [
    { id: 1, number: 'LS-000112', type: 'food', name: 'Night Owl Diner', issued: now() - 24 * DAY, expires: now() + 6 * DAY, status: 'active' },
    { id: 2, number: 'LS-000087', type: 'vehicles', name: 'Rae Hale Motors', issued: now() - 70 * DAY, expires: now() - 4 * DAY, status: 'expired' },
    { id: 3, number: 'LS-000031', type: 'trade', name: 'Hale and Sons Repairs', issued: now() - 90 * DAY, expires: now() + 40 * DAY, status: 'revoked', note: 'Operating without insurance' },
  ],
  held: { taxi: true },
  job: 'taxi',
  nextId: 4,
};

const types = [
  { id: 'retail', label: 'Retail shop', icon: 'fa-store', fee: 2500, days: 30, description: 'Sell goods to the public from a premises or a stall' },
  { id: 'food', label: 'Food and drink', icon: 'fa-utensils', fee: 3500, days: 30, description: 'Restaurants, bars, cafes and food trucks' },
  { id: 'trade', label: 'Trades and repairs', icon: 'fa-screwdriver-wrench', fee: 2000, days: 30, description: 'Mechanics, builders, cleaners and other trades' },
  { id: 'vehicles', label: 'Vehicle sales', icon: 'fa-car-side', fee: 6000, days: 30, description: 'Buy and sell cars, bikes and boats' },
  { id: 'entertainment', label: 'Entertainment', icon: 'fa-martini-glass-citrus', fee: 4500, days: 30, description: 'Clubs, venues, events and nightlife' },
  { id: 'services', label: 'Professional services', icon: 'fa-briefcase', fee: 3000, days: 30, description: 'Consultancy, legal, finance and office work' },
];

const docs = [
  { item: 'id_card', label: 'Identity card', description: 'A new card with your details on it', icon: 'fa-id-card', fee: 100, licence: null },
  { item: 'driver_license', label: "Driver's licence", description: 'Only if you already passed your test', icon: 'fa-car', fee: 250, licence: true },
  { item: 'weaponlicense', label: 'Firearms licence', description: 'Only if you already hold the permit', icon: 'fa-gun', fee: 500, licence: false },
];

const jobs = [
  { job: 'taxi', label: 'Taxi', grade: 0, gradeLabel: 'Driver', salary: 60, icon: 'fa-taxi', description: 'Pick people up around the city and drive them where they need to go' },
  { job: 'bus', label: 'Bus Driver', grade: 0, gradeLabel: 'Trainee', salary: 55, icon: 'fa-bus', description: 'Run a route and carry passengers between stops' },
  { job: 'trucker', label: 'Trucker', grade: 0, gradeLabel: 'Hauler', salary: 80, icon: 'fa-truck-front', description: 'Haul freight across the map' },
  { job: 'garbage', label: 'Sanitation', grade: 0, gradeLabel: 'Collector', salary: 45, icon: 'fa-trash-can', description: 'Empty the bins and keep the streets clean' },
  { job: 'reporter', label: 'Reporter', grade: 0, gradeLabel: 'Freelancer', salary: 50, icon: 'fa-microphone', description: 'Cover the stories that matter' },
];

const view = (l) => {
  const t = types.find((x) => x.id === l.type);
  const left = l.expires - now();
  return {
    ...l,
    typeLabel: t.label,
    icon: t.icon,
    fee: t.fee,
    status: l.status === 'active' && left <= 0 ? 'expired' : l.status,
    renewable: (l.status === 'active' && left <= 7 * DAY) || (l.status === 'active' && left <= 0),
  };
};

export function mockPayload() {
  const list = state.licences.filter((l) => l.status !== 'surrendered').map(view);
  const count = Object.keys(state.held).length;
  return {
    desk: { id: 'cityhall', label: 'Los Santos City Hall' },
    citizen: { name: 'Rae Hale', cid: 'ABC12345' },
    money: { ...state.money },
    documents: {
      enabled: true,
      cooldownMinutes: 5,
      items: docs.map((d) => ({
        ...d,
        carrying: state.items[d.item],
        entitled: d.licence === null ? true : d.licence,
        wait: 0,
        blocked: state.items[d.item],
      })),
    },
    jobcentre: {
      enabled: true,
      maxJobs: 3,
      canQuit: true,
      count,
      jobs: jobs.map((j) => ({ ...j, current: state.job === j.job, held: !!state.held[j.job] })),
    },
    business: {
      enabled: true,
      max: 3,
      types,
      licences: list,
      active: list.filter((l) => l.status === 'active').length,
      nameMin: 3,
      nameMax: 32,
      renewWindowDays: 7,
      reprintFee: 50,
      certificate: true,
    },
    now: now(),
  };
}

const ok = (data) => ({ ok: true, data });
const fail = (error, data) => ({ ok: false, error, data });

const pay = (fee) => {
  if (state.money.bank + state.money.cash < fee) return false;
  const bank = Math.min(state.money.bank, fee);
  state.money.bank -= bank;
  state.money.cash -= fee - bank;
  return true;
};

export function mockCall(action, data) {
  if (action === 'open') return ok(mockPayload());
  if (action === 'document.replace') {
    const d = docs.find((x) => x.item === data.item);
    if (!d) return fail('bad_request');
    if (d.licence === false) return fail('not_entitled');
    if (state.items[d.item]) return fail('carrying');
    if (!pay(d.fee)) return fail('no_money');
    state.items[d.item] = true;
    return ok({ item: d.item, label: d.label, fee: d.fee });
  }
  if (action === 'job.take') {
    const j = jobs.find((x) => x.job === data.job);
    if (!j) return fail('bad_request');
    if (state.job === j.job) return fail('already');
    if (!state.held[j.job] && Object.keys(state.held).length >= 3) return fail('job_limit');
    state.held[j.job] = true;
    state.job = j.job;
    return ok({ job: j.job, label: j.label, grade: 0 });
  }
  if (action === 'job.quit') {
    const j = jobs.find((x) => x.job === data.job);
    if (!j || !state.held[j.job]) return fail('not_held');
    delete state.held[j.job];
    if (state.job === j.job) state.job = 'unemployed';
    return ok({ job: j.job, label: j.label });
  }
  if (action === 'business.apply') {
    const t = types.find((x) => x.id === data.type);
    const name = String(data.name || '').trim().replace(/\s+/g, ' ');
    if (!t) return fail('bad_request');
    if (name.length < 3) return fail('bad_name');
    if (state.licences.some((l) => l.name.toLowerCase().replace(/\W/g, '') === name.toLowerCase().replace(/\W/g, '') && l.status === 'active')) return fail('name_taken');
    if (state.licences.filter((l) => view(l).status === 'active').length >= 3) return fail('limit');
    if (!pay(t.fee)) return fail('no_money');
    const l = { id: state.nextId, number: `LS-${String(100 + state.nextId).padStart(6, '0')}`, type: t.id, name, issued: now(), expires: now() + t.days * DAY, status: 'active' };
    state.nextId += 1;
    state.licences.push(l);
    return ok(view(l));
  }
  const l = state.licences.find((x) => x.id === data.id);
  if (action === 'business.renew') {
    if (!l) return fail('not_found');
    const v = view(l);
    if (l.status === 'revoked') return fail('revoked');
    if (!v.renewable) return fail('too_early');
    if (!pay(v.fee)) return fail('no_money');
    l.expires = Math.max(l.expires, now()) + 30 * DAY;
    l.status = 'active';
    return ok(view(l));
  }
  if (action === 'business.surrender') {
    if (!l) return fail('not_found');
    if (l.status === 'revoked') return fail('revoked');
    l.status = 'surrendered';
    return ok({ number: l.number, refund: 0 });
  }
  if (action === 'business.reprint') {
    if (!l) return fail('not_found');
    if (view(l).status !== 'active') return fail('not_active');
    if (!pay(50)) return fail('no_money');
    return ok({ number: l.number, fee: 50 });
  }
  return fail('bad_request');
}
