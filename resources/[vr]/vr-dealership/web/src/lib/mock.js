const cats = ['compacts', 'sedans', 'suvs', 'coupes', 'muscle', 'sportsclassics', 'sports', 'super', 'motorcycles', 'offroad', 'vans'];
const names = [
  ['blista', 'Blista', 'Dinka', 13000, 'compacts'], ['brioso', 'Brioso R/A', 'Grotti', 20000, 'compacts'], ['issi2', 'Issi', 'Weeny', 9500, 'compacts'],
  ['asea', 'Asea', 'Declasse', 12500, 'sedans'], ['fugitive', 'Fugitive', 'Cheval', 24000, 'sedans'], ['schafter2', 'Schafter', 'Benefactor', 45000, 'sedans'],
  ['baller', 'Baller', 'Gallivanter', 54000, 'suvs'], ['granger', 'Granger', 'Declasse', 38000, 'suvs'], ['huntley', 'Huntley S', 'Enus', 62000, 'suvs'],
  ['f620', 'F620', 'Ocelot', 65000, 'coupes'], ['felon', 'Felon', 'Lampadati', 48000, 'coupes'],
  ['dominator', 'Dominator', 'Vapid', 62000, 'muscle'], ['vigero', 'Vigero', 'Declasse', 39000, 'muscle'], ['gauntlet', 'Gauntlet', 'Bravado', 48000, 'muscle'],
  ['comet2', 'Comet', 'Pfister', 92000, 'sports'], ['sultan', 'Sultan', 'Karin', 12000, 'sports'], ['elegy2', 'Elegy RH8', 'Annis', 95000, 'sports'],
  ['adder', 'Adder', 'Truffade', 280000, 'super'], ['t20', 'T20', 'Progen', 340000, 'super'], ['nero', 'Nero', 'Truffade', 410000, 'super'],
  ['bati', 'Bati 801', 'Pegassi', 24000, 'motorcycles'], ['faggio', 'Faggio', 'Pegassi', 4000, 'motorcycles'], ['sanchez', 'Sanchez', 'Maibatsu', 9500, 'motorcycles'],
  ['bifta', 'Bifta', 'BF', 21000, 'offroad'], ['rebel2', 'Rebel', 'Karin', 22000, 'offroad'], ['speedo', 'Speedo', 'Vapid', 19000, 'vans'],
];

export const catalogue = names.map(([model, name, brand, price, category]) => ({ model, name, brand, price, category }));

export function mockStats(models) {
  const out = {};
  for (const m of models) {
    const v = catalogue.find((x) => x.model === m);
    const p = v ? Math.log10(v.price) - 3.9 : 0.5;
    out[m] = { speed: 38 + p * 9 + (m.length % 3), accel: 0.18 + p * 0.07, braking: 0.6 + p * 0.25, traction: 1.9 + p * 0.3, seats: v?.category === 'motorcycles' ? 2 : v?.category === 'super' ? 2 : 4 };
  }
  return out;
}

export function shopPayload(staff = false) {
  return {
    dealer: { id: 'pdm', label: 'Premium Deluxe Motorsport', shop: 'pdm' },
    catalogue,
    colors: [
      { id: 0, label: 'Black', hex: '#0D1116' }, { id: 111, label: 'White', hex: '#F2F2EE' }, { id: 4, label: 'Silver', hex: '#9CA1A6' },
      { id: 6, label: 'Graphite', hex: '#4C5157' }, { id: 27, label: 'Red', hex: '#B6111B' }, { id: 38, label: 'Orange', hex: '#F78616' },
      { id: 88, label: 'Yellow', hex: '#F5D21A' }, { id: 55, label: 'Lime', hex: '#66B81F' }, { id: 49, label: 'Racing Green', hex: '#16362A' },
      { id: 70, label: 'Ultra Blue', hex: '#1B6BD8' }, { id: 64, label: 'Navy', hex: '#22314F' }, { id: 145, label: 'Purple', hex: '#62129A' },
      { id: 137, label: 'Pink', hex: '#DF5891' }, { id: 96, label: 'Brown', hex: '#4E3424' },
    ],
    categories: { compacts: 'Compacts', sedans: 'Sedans', suvs: 'SUVs', coupes: 'Coupes', muscle: 'Muscle', sportsclassics: 'Sports Classics', sports: 'Sports', super: 'Super', motorcycles: 'Motorcycles', offroad: 'Off-road', vans: 'Vans' },
    me: { name: 'Rae Hale', staff, grade: staff ? 2 : 0, discount: staff ? 10 : 0, maxMarkup: 25, commission: 10, boss: staff ? null : { job: 'police', label: 'LSPD', balance: 482900 }, cash: 4200, bank: 61200 },
    selfService: { open: !staff, markup: 0, staffOnDuty: staff ? 1 : 0 },
    finance: { enabled: true },
    display: staff ? ['adder', 'schafter2', 'comet2', 'vigero', 't20', 'bati', 'italigtb', 'nero'] : null,
    testDrive: { seconds: 120 },
  };
}

export const offerPayload = {
  token: 'x', dealer: 'Premium Deluxe Motorsport', seller: 'Marco', model: 'comet2', label: 'Pfister Comet', price: 86000, base: 92000,
  payment: 'finance', color: 27, seconds: 60, cash: 4200, bank: 61200,
  finance: { approved: true, reasons: [], down: 8600, financed: 77400, rate: 9, installment: 6872, term: 12, total: 82466, intervalHours: 24, tier: { label: 'Good' } },
};

export function mockCall(action, data) {
  let res;
  if (action === 'quote') {
    const price = data.price || catalogue.find((v) => v.model === data.model)?.price || 0;
    const down = Math.max(Math.ceil(price * 0.1), data.down || 0);
    const financed = price - down;
    const term = data.term || 12;
    const interest = Math.ceil(financed * 0.09 * term / 12);
    const approved = financed <= 56000;
    res = { ok: true, data: { approved, reasons: approved ? [] : ['too_large'], price, down, minDown: Math.ceil(price * 0.1), financed, term, rate: 9, interest, total: financed + interest, installment: Math.ceil((financed + interest) / term), maxLoan: 56000, intervalHours: 24, tier: { label: 'Good' } } };
  } else if (action === 'customers') res = { ok: true, data: [{ id: 14, distance: 1.8 }, { id: 22, distance: 4.1 }] };
  else if (action === 'offer') res = { ok: true, data: { finance: true } };
  else if (action === 'buy') res = { ok: true, data: { plate: '19RAE007', delivered: true } };
  else if (action === 'testdrive') res = { ok: true, data: { seconds: 120 } };
  else if (action === 'display.set') res = { ok: true, data: true };
  else if (action === 'sales.mine') res = { ok: true, data: [{ label: 'Karin Sultan', plate: '82KLM441', price: 11400, payment: 'bank', buyer_name: 'Dee Walsh', commission: 1140, at: Date.now() / 1000 - 3600 }] };
  else res = { ok: false, error: 'bad_request' };
  return new Promise((r) => setTimeout(() => r(JSON.parse(JSON.stringify(res))), 120));
}
