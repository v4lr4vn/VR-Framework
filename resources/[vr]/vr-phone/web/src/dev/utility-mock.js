// A fake server for Wallet, Maps and Health, for working on the screens in a normal browser.
//   ?walk=1        the player walks north-east so the map moves
//   ?wallet=poor   a nearly empty bank account
//   ?requests=0    no waiting payment requests
//   ?bank=0        no vr-banking lines in the Wallet
const params = new URLSearchParams(location.search);
const now = () => Math.floor(Date.now() / 1000);

// ---- wallet

const wallet = {
  bank: params.get('wallet') === 'poor' ? 40 : 12450,
  cash: 380,
  sentToday: 0,
  nextId: 100,
  transfers: [
    { id: 5, kind: 'received', amount: 250, number: '555-0188', note: 'Dinner', at: now() - 3600 * 5 },
    { id: 4, kind: 'sent', amount: 60, number: '555-0199', note: null, at: now() - 3600 * 28 },
    { id: 3, kind: 'sent', amount: 1200, number: '555-0188', note: 'Rent share', at: now() - 3600 * 80 },
  ],
  incoming: params.get('requests') === '0' ? [] : [{ id: 11, number: '555-0123', amount: 45, note: 'Fuel', at: now() - 900 }],
  outgoing: [],
};
const numbers = new Set(['555-0188', '555-0199', '555-0123', '555-0155']);

function walletView() {
  return {
    cash: wallet.cash,
    bank: wallet.bank,
    account: '4047120934',
    limits: { min: 1, max: 25000, daily: 50000, left: 50000 - wallet.sentToday, note: 60 },
    transfers: wallet.transfers,
    recents: [...new Set(wallet.transfers.filter((r) => r.kind === 'sent').map((r) => r.number))],
    incoming: wallet.incoming,
    outgoing: wallet.outgoing,
    bankLines:
      params.get('bank') === '0'
        ? null
        : [
            { id: 31, kind: 'salary', amount: 840, balance: 12450, reason: 'Salary', at: now() - 3600 * 3 },
            { id: 30, kind: 'payment_out', amount: -96, balance: 11610, reason: 'Card payment', at: now() - 3600 * 20 },
            { id: 29, kind: 'withdraw', amount: -200, balance: 11706, reason: 'ATM withdrawal', at: now() - 3600 * 46 },
          ],
  };
}

function pay(number, amount, note) {
  if (wallet.bank < amount) return { ok: false, reason: 'no_funds' };
  if (wallet.sentToday + amount > 50000) return { ok: false, reason: 'daily_limit' };
  wallet.bank -= amount;
  wallet.sentToday += amount;
  wallet.transfers.unshift({ id: wallet.nextId++, kind: 'sent', amount, number, note: note || null, at: now() });
  return { ok: true, bank: wallet.bank };
}

function amountOf(raw) {
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n) || n < 1) return { reason: 'invalid_amount' };
  if (n > 25000) return { reason: 'too_much' };
  return { n };
}

function walletHandle(name, data) {
  switch (name) {
    case 'walletOverview':
      return { ok: true, wallet: walletView() };
    case 'walletSend':
    case 'walletRequest': {
      const a = amountOf(data.amount);
      if (!a.n) return { ok: false, reason: a.reason };
      if (data.number === '555-0142') return { ok: false, reason: 'self' };
      if (!numbers.has(data.number)) return { ok: false, reason: 'not_in_service' };
      if (name === 'walletSend') return pay(data.number, a.n, data.note);
      wallet.outgoing.unshift({ id: wallet.nextId++, number: data.number, amount: a.n, note: data.note || null, at: now() });
      return { ok: true };
    }
    case 'walletRespond': {
      const r = wallet.incoming.find((x) => x.id === data.id);
      if (!r) return { ok: false, reason: 'not_found' };
      if (data.accept) {
        const res = pay(r.number, r.amount, r.note);
        if (!res.ok) return res;
      }
      wallet.incoming = wallet.incoming.filter((x) => x.id !== data.id);
      return { ok: true };
    }
    case 'walletCancel':
      wallet.outgoing = wallet.outgoing.filter((x) => x.id !== data.id);
      return { ok: true };
  }
}

// ---- maps

const CATALOG = [
  ['Central Hospital', 'services', 'cross', 298, -584], ['Central Police Station', 'services', 'shield', 441, -982],
  ['Sandy Shores Sheriff', 'services', 'shield', 1853, 3687], ['Bank, Legion Square', 'services', 'bank', 149, -1040],
  ['City Hall', 'services', 'pin', -544, -204], ['Legion Square', 'places', 'pin', 195, -934],
  ['Vinewood Boulevard', 'places', 'pin', 300, 190], ['Vespucci Beach', 'places', 'pin', -1305, -1520],
  ['Mirror Park', 'places', 'pin', 1060, -690], ['International Airport', 'travel', 'plane', -1037, -2737],
  ['Harbour Docks', 'travel', 'anchor', 1000, -2960], ['Gun Store, Pillbox Hill', 'shops', 'bag', 22, -1107],
  ['Customs Garage, Burton', 'shops', 'wrench', -365, -131], ['Corner Store, Strawberry', 'shops', 'bag', 25, -1347],
].map(([name, category, icon, x, y], i) => ({ id: `c${i + 1}`, name, category, icon, x, y, z: 30 }));

const maps = {
  saved: [{ id: 1, name: 'Home', x: 128, y: -1260, z: 29, icon: 'home' }],
  nextId: 2,
  waypoint: null,
  x: 215,
  y: -905,
  started: Date.now(),
};

function position() {
  if (params.get('walk') === '1') {
    const t = (Date.now() - maps.started) / 1000;
    maps.x = 215 + t * 2.2;
    maps.y = -905 + t * 1.4;
  }
  return {
    x: maps.x, y: maps.y, z: 30, bearing: params.get('walk') === '1' ? 57 : 20,
    street: 'Strawberry Avenue', zone: 'Strawberry', postal: '412', speed: params.get('walk') === '1' ? 8 : 0,
    driving: false, waypoint: maps.waypoint,
  };
}

function mapsHandle(name, data) {
  switch (name) {
    case 'mapsState':
      return { ok: true, catalog: CATALOG, saved: maps.saved };
    case 'mapsPos':
      return position();
    case 'mapsGo':
      maps.waypoint = { x: data.x, y: data.y };
      return { ok: true, waypoint: maps.waypoint };
    case 'mapsStop':
      maps.waypoint = null;
      return { ok: true };
    case 'mapsSave': {
      if (!data.name) return { ok: false, reason: 'empty' };
      if (maps.saved.length >= 50) return { ok: false, reason: 'full' };
      const p = { id: maps.nextId++, name: data.name, x: data.x, y: data.y, z: data.z, icon: data.icon || 'pin' };
      maps.saved.unshift(p);
      return { ok: true, place: p };
    }
    case 'mapsRemove':
      maps.saved = maps.saved.filter((p) => p.id !== data.id);
      return { ok: true };
  }
}

// ---- health

const health = {
  today: { steps: Number(params.get('steps') ?? 5230), metres: 3920, active: 2640, kcal: 235 },
  week: [6200, 9100, 8300, 2100, 11250, 7400, 5230],
};

function dayText(back) {
  const d = new Date(Date.now() - back * 86400000);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function healthHandle(name) {
  switch (name) {
    case 'healthOverview':
      return {
        ok: true,
        health: {
          today: { ...health.today, kcal: Math.round(health.today.steps * 0.045) },
          week: health.week.map((steps, i) => ({ day: dayText(6 - i), steps: i === 6 ? health.today.steps : steps, metres: steps * 0.75, active: steps / 2 })),
          goal: 8000,
          streak: 2,
          restingRate: 64,
        },
      };
    case 'healthVitals': {
      const states = ['rest', 'walk', 'run', 'sprint'];
      const state = params.get('state') || states[Math.floor(Date.now() / 6000) % 4];
      return { health: 82, armour: 25, hunger: 61, thirst: 47, stress: state === 'sprint' ? 38 : 12, state };
    }
  }
}

export function utilityHandle(name, data) {
  return walletHandle(name, data ?? {}) ?? mapsHandle(name, data ?? {}) ?? healthHandle(name, data ?? {});
}

export function utilityFeatures() {
  return {
    wallet: { min: 1, max: 25000, note: 60 },
    maps: { range: 250, maxPlaces: 50, nameLength: 40, atlas: null },
    health: { goalRange: [1000, 40000], reportSeconds: 10, restingRate: 64 },
  };
}
