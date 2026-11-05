const now = () => Math.floor(Date.now() / 1000);
const H = 3600;
const D = 86400;

const tiers = [
  { min: 800, key: 'exceptional', label: 'Exceptional', maxLoan: 150000, rate: 5 },
  { min: 740, key: 'verygood', label: 'Very good', maxLoan: 75000, rate: 8 },
  { min: 670, key: 'good', label: 'Good', maxLoan: 35000, rate: 12 },
  { min: 580, key: 'fair', label: 'Fair', maxLoan: 12000, rate: 18 },
  { min: 0, key: 'poor', label: 'Poor', maxLoan: 3000, rate: 28 },
];
const tierOf = (s) => tiers.find((t) => s >= t.min);

const db = {
  me: { name: 'Rae Hale', cid: 'EVR38271', cash: 1840 },
  score: 712,
  accounts: [
    { id: 1, number: '4012837465', type: 'personal', label: 'Personal account', balance: 24310, frozen: false, rights: { view: true, deposit: true, withdraw: true, transfer: true, manage: true, owner: true }, created: now() - 40 * D },
    { id: 2, number: '4098123311', type: 'savings', label: 'Rainy day', balance: 61200, frozen: false, rate: 0.5, nextInterest: now() + 9 * H, rights: { view: true, deposit: true, withdraw: true, transfer: true, manage: true, owner: true }, created: now() - 22 * D },
    { id: 3, number: '4055519082', type: 'shared', label: 'Vinewood house', balance: 8650, frozen: false, rights: { view: true, deposit: true, withdraw: true, transfer: true, manage: true, owner: true }, myRole: 'owner', created: now() - 12 * D,
      members: [
        { cid: 'EVR38271', name: 'Rae Hale', role: 'owner', added: now() - 12 * D, me: true },
        { cid: 'EVR11902', name: 'Marco Ortega', role: 'manager', added: now() - 11 * D },
        { cid: 'EVR77310', name: 'Dee Walsh', role: 'member', added: now() - 3 * D },
      ] },
    { id: 4, number: '4033190044', type: 'job', label: 'Los Santos Police', balance: 482900, frozen: false, rights: { view: true, deposit: true, withdraw: true, transfer: true, manage: true, owner: false }, created: now() - 60 * D },
  ],
  cards: [
    { id: '4539817265430912', last4: '0912', holder: 'Rae Hale', mine: true, status: 'active', locked: false, account: { number: '4012837465', label: 'Personal account', type: 'personal' }, created: now() - 30 * D },
    { id: '4111983344572208', last4: '2208', holder: 'Rae Hale', mine: true, status: 'frozen', locked: false, account: { number: '4055519082', label: 'Vinewood house', type: 'shared' }, created: now() - 9 * D },
  ],
  loans: [
    { id: 17, principal: 15000, interest: 1800, total: 16800, remaining: 9800, installment: 1400, arrears: 0, fees: 0, term: 12, paidCount: 5, missed: 0, nextDue: now() + 14 * H + 1200, status: 'active', rate: 12, plate: '82KLM441', vehicle: 'Karin Sultan', created: now() - 5 * D, defaultAfter: 3 },
  ],
  debts: [],
  held: [],
  history: {},
  vehicles: [
    { plate: '82KLM441', model: 'sultan', name: 'Karin Sultan', value: 7200, pledged: true, held: false },
    { plate: '19RAE007', model: 'buffalo', name: 'Bravado Buffalo', value: 21000, pledged: false, held: false },
    { plate: '44XQN108', model: 'bison', name: 'Bravado Bison', value: 18000, pledged: false, held: false },
  ],
  cases: [
    { id: 41, loanId: 9, cid: 'EVR50213', name: 'Jonah Pike', amount: 12480, original: 11980, status: 'open', online: true, created: now() - 2 * D, updated: now() - 3 * H,
      claimed: { by: 'Rae Hale', mine: true, expires: now() + 40 * 60 },
      vehicles: [{ plate: '71JPK220', model: 'sultan', name: 'Karin Sultan', collateral: true, held: false, tracked: true, staged: true }, { plate: '33ZZT901', model: 'faggio', name: 'Pegassi Faggio', collateral: false, held: false }],
      log: [{ at: now() - 2 * D, text: 'Opened after loan #9 defaulted' }, { at: now() - 50 * 60, text: 'Claimed by Rae Hale', by: 'Rae Hale' }, { at: now() - 20 * 60, text: 'Trace on 71JPK220: signal found', by: 'Rae Hale' }] },
    { id: 39, loanId: 6, cid: 'EVR22094', name: 'Sasha Novak', amount: 4630, original: 4130, status: 'open', online: false, created: now() - 5 * D, updated: now() - D,
      vehicles: [{ plate: '08SNV332', model: 'blista', name: 'Dinka Blista', collateral: false, held: true }],
      log: [{ at: now() - 5 * D, text: 'Opened after loan #6 defaulted' }, { at: now() - D, text: 'Lou Tran repossessed 08SNV332 · $500 repo fee added', by: 'Lou Tran' }] },
    { id: 36, loanId: 4, cid: 'EVR90017', name: 'Arlo Mendes', amount: 28750, original: 28750, status: 'open', online: false, created: now() - 7 * D, updated: now() - 6 * D,
      claimed: { by: 'Lou Tran', mine: false, expires: now() + 25 * 60 },
      vehicles: [{ plate: '55ARL900', model: 'baller', name: 'Gallivanter Baller', collateral: true, held: false, tracked: true }],
      log: [{ at: now() - 7 * D, text: 'Opened after loan #4 defaulted' }] },
  ],
};

const kinds = ['salary', 'payment_out', 'transfer_in', 'withdraw', 'deposit', 'payment_out', 'transfer_out', 'payment_out', 'interest', 'repayment'];
const reasons = { salary: 'Salary', payment_out: '24/7 Supermarket', transfer_in: 'From Marco Ortega', withdraw: 'ATM withdrawal', deposit: 'Cash deposit at branch', transfer_out: 'Rent for March', interest: 'Interest at 0.5%', repayment: 'Loan #17 installment' };
for (const a of db.accounts) {
  let bal = a.balance;
  const rows = [];
  for (let i = 0; i < 18; i++) {
    const kind = a.type === 'savings' ? (i % 3 === 0 ? 'interest' : 'deposit') : kinds[(i + a.id) % kinds.length];
    const out = ['payment_out', 'withdraw', 'transfer_out', 'repayment'].includes(kind);
    const amount = (out ? -1 : 1) * Math.round(((i * 137 + a.id * 53) % 900) + 40) * (kind === 'salary' ? 4 : 1);
    rows.push({ id: 1000 - i, kind, amount, balance: bal, reason: reasons[kind], other: kind.startsWith('transfer') ? '4077120934' : null, actor_name: 'Rae Hale', card: kind === 'withdraw' ? '0912' : null, at: now() - i * 7 * H - a.id * 600 });
    bal -= amount;
  }
  db.history[a.id] = rows;
}

const ok = (data) => ({ ok: true, data });
const fail = (error, data) => ({ ok: false, error, data });

function overview() {
  const t = tierOf(db.score);
  return {
    bank: 'ValRavn Bank', branch: 'Legion Square', now: now(),
    me: { ...db.me, credit: { score: db.score, tier: t.label, key: t.key } },
    accounts: db.accounts, cards: db.cards, loans: db.loans, debts: db.debts, held: db.held, collector: true,
    settings: {
      cardFee: 50, pinLength: 4,
      savings: { rate: 0.5, periodHours: 24, maxBalance: 2000000, minBalance: 1000 },
      loans: { enabled: true, terms: [4, 8, 12, 24], intervalHours: 24, minAmount: 1000, lateFee: 10, defaultAfter: 3, collateral: true },
      limits: { maxShared: 3, maxSavings: 1, maxMembers: 8, transferLimit: 1000000 },
      credit: { min: 300, max: 850, tiers },
    },
  };
}

function quote(d) {
  const t = tierOf(db.score);
  const v = db.vehicles.find((x) => x.plate === d.plate && !x.pledged);
  const maxLoan = v ? Math.floor(Math.min(t.maxLoan * 2, t.maxLoan + v.value)) : t.maxLoan;
  const rate = v ? Math.max(1, t.rate - 3) : t.rate;
  const amount = Math.floor(Number(d.amount) || 0);
  const term = d.term || 4;
  const interest = Math.ceil((amount * rate) / 100 * term / 12);
  const reasons = [];
  if (amount < 1000) reasons.push('too_small');
  if (amount > maxLoan) reasons.push('too_large');
  if (db.loans.filter((l) => l.status === 'active').length >= 1) reasons.push('max_loans');
  return { approved: reasons.length === 0, reasons, score: db.score, tier: { key: t.key, label: t.label }, term, amount, rate, interest, total: amount + interest, installment: Math.ceil((amount + interest) / term), maxLoan, intervalHours: 24, collateral: v || null };
}

const atm = { card: null, tries: 3 };

const handlers = {
  overview: () => ok(overview()),
  history: (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    return ok({ account: a, history: db.history[a.id] || [], cards: a.rights.manage ? db.cards.filter((c) => c.account.number === a.number) : [] });
  },
  deposit: (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    if (d.amount > db.me.cash) return fail('no_cash');
    a.balance += d.amount; db.me.cash -= d.amount;
    db.history[a.id].unshift({ id: Date.now(), kind: 'deposit', amount: d.amount, balance: a.balance, reason: 'Cash deposit at branch', at: now() });
    return ok(true);
  },
  withdraw: (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    if (d.amount > a.balance) return fail('no_funds');
    a.balance -= d.amount; db.me.cash += d.amount;
    db.history[a.id].unshift({ id: Date.now(), kind: 'withdraw', amount: -d.amount, balance: a.balance, reason: 'Cash withdrawal at branch', at: now() });
    return ok(true);
  },
  transfer: (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    if (d.amount > a.balance) return fail('no_funds');
    if (String(d.to).replace(/\s/g, '').length !== 10) return fail('no_account');
    a.balance -= d.amount;
    db.history[a.id].unshift({ id: Date.now(), kind: 'transfer_out', amount: -d.amount, balance: a.balance, reason: d.note || 'Transfer', other: d.to, at: now() });
    return ok({ to: d.to });
  },
  lookup: (d) => (String(d.number).replace(/\s/g, '').length === 10 ? ok({ number: d.number, type: 'personal', kind: 'Personal', name: 'Marco O.' }) : fail('no_account')),
  'shared.create': (d) => {
    const id = Math.max(...db.accounts.map((a) => a.id)) + 1;
    db.accounts.push({ id, number: `40${Math.floor(Math.random() * 1e8)}`, type: 'shared', label: d.label, balance: 0, rights: { view: true, deposit: true, withdraw: true, transfer: true, manage: true, owner: true }, myRole: 'owner', members: [{ cid: db.me.cid, name: db.me.name, role: 'owner', me: true, added: now() }], created: now() });
    db.history[id] = [];
    return ok({ id });
  },
  'savings.open': () => fail('limit'),
  'account.rename': (d) => { db.accounts.find((x) => x.id === d.account).label = d.label; return ok(true); },
  'account.close': (d) => { db.accounts = db.accounts.filter((x) => x.id !== d.account); return ok({ moved: 0 }); },
  'members.add': (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    a.members.push({ cid: d.cid, name: 'Lou Tran', role: d.role || 'member', added: now() });
    return ok({ name: 'Lou Tran' });
  },
  'members.remove': (d) => { const a = db.accounts.find((x) => x.id === d.account); a.members = a.members.filter((m) => m.cid !== d.cid); return ok(true); },
  'members.role': (d) => { const a = db.accounts.find((x) => x.id === d.account); a.members.find((m) => m.cid === d.cid).role = d.role; return ok(true); },
  'cards.order': (d) => {
    const a = db.accounts.find((x) => x.id === d.account);
    const id = `4${String(Math.floor(Math.random() * 1e15)).padStart(15, '0')}`;
    db.cards.unshift({ id, last4: id.slice(-4), holder: db.me.name, mine: true, status: 'active', locked: false, account: { number: a.number, label: a.label, type: a.type }, created: now() });
    return ok({ last4: id.slice(-4) });
  },
  'cards.freeze': (d) => { db.cards.find((c) => c.id === d.card).status = d.frozen ? 'frozen' : 'active'; return ok(true); },
  'cards.cancel': (d) => { db.cards = db.cards.filter((c) => c.id !== d.card); return ok(true); },
  'cards.pin': () => ok(true),
  'cards.unlock': (d) => { db.cards.find((c) => c.id === d.card).locked = false; return ok(true); },
  credit: () => {
    const t = tierOf(db.score);
    return ok({
      score: db.score, min: 300, max: 850, tier: { key: t.key, label: t.label, maxLoan: t.maxLoan, rate: t.rate }, nextTier: { label: 'Very good', min: 740 }, tiers,
      stats: { paid: 2, active: 1, defaults: 0, payments: 19, missed: 1, since: now() - 40 * D },
      history: [
        { delta: 4, score: 712, reason: 'Loan #17 payment on time', at: now() - 10 * H },
        { delta: 4, score: 708, reason: 'Loan #17 payment on time', at: now() - 34 * H },
        { delta: -20, score: 704, reason: 'Loan #17 payment missed', at: now() - 58 * H },
        { delta: 4, score: 724, reason: 'Loan #17 payment on time', at: now() - 82 * H },
        { delta: -5, score: 720, reason: 'Loan #17 opened', at: now() - 5 * D },
        { delta: 15, score: 725, reason: 'Loan #12 paid off early', at: now() - 9 * D },
      ],
    });
  },
  'loans.vehicles': () => ok(db.vehicles),
  'loans.quote': (d) => ok(quote(d)),
  'loans.apply': (d) => { const q = quote(d); return q.approved ? ok({ id: 18, amount: q.amount, installment: q.installment }) : fail(q.reasons[0], q); },
  'loans.pay': (d) => {
    const l = db.loans.find((x) => x.id === d.loan);
    const amt = d.amount === 'full' ? l.remaining : d.amount === 'due' ? Math.min(l.installment, l.remaining) : d.amount;
    l.remaining -= amt;
    if (l.remaining <= 0) l.status = 'paid';
    return ok({ remaining: l.remaining, status: l.status });
  },
  'debts.pay': () => ok({ cleared: true, released: [], left: 0 }),
  'collections.list': () => ok({ cases: db.cases, me: { name: db.me.name, cid: db.me.cid }, settings: { claimMinutes: 60, commission: 10, repoPay: 750, repoFee: 500, vehicles: true }, now: now() }),
  'collections.claim': (d) => { const c = db.cases.find((x) => x.id === d.case); c.claimed = { by: db.me.name, mine: true, expires: now() + 3600 }; c.log.push({ at: now(), text: `Claimed by ${db.me.name}`, by: db.me.name }); return ok(true); },
  'collections.release': (d) => { const c = db.cases.find((x) => x.id === d.case); c.claimed = null; return ok(true); },
  'collections.note': (d) => { const c = db.cases.find((x) => x.id === d.case); c.log.push({ at: now(), text: d.text, by: db.me.name }); return ok(true); },
  'collections.trace': () => ok({ found: true, x: 120, y: -900, radius: 140 }),
  'collections.locate': () => ok({ found: true, x: 120, y: -900, z: 30, radius: 20 }),
  'atm.cards': () => ok({ cards: db.cards.map((c) => ({ id: c.id, last4: c.last4, holder: c.holder, account: c.account.number, status: c.status })), bank: 'ValRavn Bank', pinLength: 4 }),
  'atm.pin': (d) => {
    if (d.pin !== '1234') { atm.tries -= 1; return fail(atm.tries <= 0 ? 'card_locked' : 'bad_pin', atm.tries); }
    atm.card = db.cards.find((c) => c.id === d.card);
    return handlers['atm.state']();
  },
  'atm.state': () => {
    const a = db.accounts.find((x) => x.number === atm.card.account.number);
    return ok({ account: { number: a.number, label: a.label, type: a.type, balance: a.balance }, holder: atm.card.holder, last4: atm.card.last4, dailyLimit: 5000, dailyLeft: 4200, fastCash: [100, 200, 500, 1000, 2000], allowDeposit: true });
  },
  'atm.withdraw': (d) => { const a = db.accounts.find((x) => x.number === atm.card.account.number); if (d.amount > a.balance) return fail('no_funds'); a.balance -= d.amount; db.me.cash += d.amount; return handlers['atm.state'](); },
  'atm.deposit': (d) => { const a = db.accounts.find((x) => x.number === atm.card.account.number); if (d.amount > db.me.cash) return fail('no_cash'); a.balance += d.amount; db.me.cash -= d.amount; return handlers['atm.state'](); },
  'atm.history': () => ok((db.history[1] || []).slice(0, 8)),
  'atm.end': () => ok(true),
};

export function mockCall(action, data = {}) {
  const fn = handlers[action];
  const res = fn ? fn(data) : fail('bad_request');
  return new Promise((r) => setTimeout(() => r(JSON.parse(JSON.stringify(res))), 120));
}

export function mockDebt() {
  db.debts = [db.cases[0]];
  db.held = [{ plate: '08SNV332', model: 'blista', name: 'Dinka Blista', caseId: 39, seizedAt: now() - D }];
  db.loans[0].status = 'collections';
}
