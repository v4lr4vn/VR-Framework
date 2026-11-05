const meta = {
  rarities: {
    common: { label: 'Common', order: 1, color: '#AAB4C0' },
    uncommon: { label: 'Uncommon', order: 2, color: '#3DD68C' },
    rare: { label: 'Rare', order: 3, color: '#5AA9FF' },
    epic: { label: 'Epic', order: 4, color: '#B79CFF' },
    legendary: { label: 'Legendary', order: 5, color: '#F5A524' },
  },
  groups: {
    dev: { label: 'Development', icon: 'code', color: '#5AA9FF' },
    staff: { label: 'Staff', icon: 'shield-halved', color: '#FF6F91' },
    community: { label: 'Community', icon: 'people-group', color: '#3DD68C' },
  },
  foils: { none: 'Standard', shiny: 'Shiny', holo: 'Holo foil' },
  grades: { 10: 'Gem Mint', 9: 'Mint', 8: 'NM-MT', 7: 'Near Mint', 6: 'EX-MT', 5: 'Excellent', 4: 'VG-EX', 3: 'Very Good', 2: 'Good', 1: 'Poor' },
  company: 'EGC',
  companyName: 'ValRavn Grading Co.',
};

const base = { set: 'EVO', setId: 'evo', setLabel: 'ValRavn Origins', year: 2026, total: 20 };
const card = (o) => ({ ...base, image: `${o.id}.png`, ...o });

export const C = {
  founder: card({ id: 'evo001', number: 1, name: 'ValRavn', title: 'Founder', group: 'dev', rarity: 'legendary', quote: 'Wrote the first line of ValRavn and has not slept since.' }),
  lead: card({ id: 'evo002', number: 2, name: 'Lead Developer', title: 'Development', group: 'dev', rarity: 'epic', quote: 'It works on my machine. It works on yours now too.' }),
  admin: card({ id: 'evo004', number: 4, name: 'Senior Admin', title: 'Staff', group: 'staff', rarity: 'rare', quote: 'Calm voice, fast teleport.' }),
  legend: card({ id: 'evo007', number: 7, name: 'Community Legend', title: 'Community', group: 'community', rarity: 'rare', quote: 'Here since day one. Knows where the bodies are parked.' }),
  mod: card({ id: 'evo008', number: 8, name: 'Moderator', title: 'Staff', group: 'staff', rarity: 'uncommon', quote: 'Reads the rules so you do not have to.' }),
  racer: card({ id: 'evo012', number: 12, name: 'Top Racer', title: 'Community', group: 'community', rarity: 'uncommon', quote: 'Brakes are a suggestion.' }),
  helper: card({ id: 'evo014', number: 14, name: 'Helper', title: 'Staff', group: 'staff', rarity: 'common', quote: 'First to answer, last to log off.' }),
  owl: card({ id: 'evo017', number: 17, name: 'Night Owl', title: 'Community', group: 'community', rarity: 'common', quote: 'Logs in when the city goes quiet.' }),
  taxi: card({ id: 'evo020', number: 20, name: 'Taxi Driver', title: 'Community', group: 'community', rarity: 'common', quote: 'Knows a shortcut. It is not shorter.' }),
};

let n = 0;
const copy = (c, foil = 'none', extra = {}) => ({ ...c, uid: `U${++n}`, foil, serial: 100 + n * 7, price: 50, ...extra });

export const packPayload = {
  pack: { id: 'origins', label: 'ValRavn Origins Booster', set: 'ValRavn Origins', code: 'EVO' },
  cards: [copy(C.owl), copy(C.taxi, 'none', { new: true }), copy(C.racer, 'shiny'), copy(C.admin, 'holo', { new: true }), copy(C.founder, 'holo', { new: true })],
  meta,
};

const graded = copy(C.lead, 'holo', { grade: 10, cert: '40918273', sub: { centering: 10, corners: 10, edges: 9, surface: 10 }, price: 18000 });

export const cardPayload = { card: graded, meta };

const slots = {};
[C.founder, C.lead, C.admin, C.legend, C.mod, C.racer, C.helper].forEach((c, i) => {
  slots[String(i + 1)] = copy(c, i === 0 ? 'holo' : i === 3 ? 'shiny' : 'none');
});
slots['2'] = graded;

export const binderPayload = {
  id: 3,
  title: "Rae's Binder",
  pages: 20,
  perPage: 9,
  slots,
  hand: [copy(C.owl), copy(C.taxi, 'shiny'), copy(C.helper), copy(C.mod, 'holo')],
  progress: [{ id: 'evo', code: 'EVO', label: 'ValRavn Origins', owned: 7, total: 20 }],
  count: 7,
  capacity: 180,
  meta,
};

export const shopPayload = {
  label: 'ValRavn Cards & Collectibles',
  packs: [{ id: 'origins', label: 'ValRavn Origins Booster', price: 750, cards: 5, set: 'ValRavn Origins', code: 'EVO' }],
  binder: { price: 1500, capacity: 180 },
  hand: [copy(C.owl, 'none', { price: 25 }), copy(C.taxi, 'shiny', { price: 40 }), copy(C.admin, 'holo', { price: 600 }), graded, copy(C.mod, 'none', { price: 60 })],
  grading: {
    tiers: [{ id: 'standard', label: 'Standard', fee: 250, minutes: 30 }, { id: 'express', label: 'Express', fee: 1000, minutes: 5 }],
    max: 10,
    submissions: [
      { id: 4, card: copy(C.legend, 'holo'), tier: 'standard', readyIn: 0, ready: true },
      { id: 5, card: copy(C.racer), tier: 'standard', readyIn: 1260, ready: false },
    ],
  },
  sell: true,
  unclaimed: 0,
  me: { cash: 4200, bank: 61250 },
  meta,
};

export async function mockCall(action, data) {
  await new Promise((r) => setTimeout(r, 120));
  if (action === 'nui:packCount') return 2;
  if (action === 'nui:nextPack') return { ok: true, data: { ...packPayload, cards: [copy(C.helper), copy(C.owl), copy(C.mod), copy(C.legend, 'shiny'), copy(C.lead, 'none', { new: true })] } };
  if (action.startsWith('nui:')) return true;
  if (action === 'binder.put') return { ok: true, data: { slot: data.slot, card: binderPayload.hand.find((c) => c.uid === data.uid) } };
  if (action === 'binder.take') return { ok: true, data: { slot: data.slot, card: binderPayload.slots[String(data.slot)] } };
  if (action === 'binder.move') return { ok: true, data: { from: data.from, to: data.to } };
  if (action === 'binder.rename') return { ok: true, data: { title: data.title } };
  if (action === 'shop.collect') return { ok: true, data: { graded: [{ ...shopPayload.grading.submissions[0].card, grade: 9, cert: '11223344', sub: { centering: 9, corners: 10, edges: 9, surface: 9 } }], given: 1, shop: shopPayload } };
  if (action.startsWith('shop.')) return { ok: true, data: { shop: shopPayload, total: 600, sold: 1, submitted: 1, count: 1 } };
  return { ok: true, data: {} };
}
