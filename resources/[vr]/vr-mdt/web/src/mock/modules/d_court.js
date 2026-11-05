import { fail } from '../index.js';
import { push } from '../state.js';
import { personByCid } from './d_people.js';

const now = () => Math.floor(Date.now() / 1000);
const H = 3600;
const D = 86400;
const year = new Date().getFullYear();
const rooms = ['Courtroom 1', 'Courtroom 2', 'Courtroom 3', 'Judge chambers'];
const statusLabel = { filed: 'Filed', scheduled: 'Scheduled', in_session: 'In session', verdict: 'Verdict', closed: 'Closed', dismissed: 'Dismissed' };
const verdictLabel = { guilty: 'Guilty', not_guilty: 'Not guilty', dismissed: 'Dismissed', plea: 'Plea agreement' };

function p(cid) {
  const x = personByCid(cid);
  return x ? { cid, name: x.name } : null;
}

function atHour(daysAhead, hour, minute = 0) {
  const d = new Date();
  d.setDate(d.getDate() + daysAhead);
  d.setHours(hour, minute, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

let seq = 0;
function kase(o) {
  seq += 1;
  const created = now() - (o.age || 3) * D;
  return {
    id: 300 + seq,
    number: `SA-${year}-${String(seq).padStart(4, '0')}`,
    status: 'filed',
    charges: [],
    hearingAt: null,
    courtroom: null,
    verdict: null,
    sentence: null,
    reportId: null,
    caseId: null,
    summary: '',
    createdBy: 'DA1',
    createdAt: created,
    updatedAt: o.updated ? now() - o.updated : created + H,
    events: [{ id: seq * 100, at: created, kind: 'filed', author: 'Colin Ward', text: 'Case filed by Colin Ward' }],
    ...o,
  };
}

const cases = [
  kase({
    title: 'State v. Cruz', defendant: p('DCR40219'), prosecutor: p('DA1'), defense: p('LAW1'), judge: p('JUD1'), status: 'scheduled', age: 6, updated: 40 * 60,
    hearingAt: atHour(1, 14), courtroom: 'Courtroom 2', reportId: 1187, caseId: 42,
    charges: [{ id: 12, title: 'Armed robbery', count: 1 }, { id: 31, title: 'Evading a peace officer', count: 1 }, { id: 4, title: 'Brandishing a firearm', count: 2 }],
    summary: 'Robbery of the 24/7 on Innocence Blvd on the night of the 2nd. Defendant was identified from store CCTV and arrested after a short vehicle pursuit on Strawberry Ave.\n\nDefense has indicated it will contest the identification.',
    events: [
      { id: 1, at: now() - 6 * D, kind: 'filed', author: 'Colin Ward', text: 'Case filed by Colin Ward' },
      { id: 2, at: now() - 5 * D, kind: 'note', author: 'Saul Becker', text: 'Defense requests the full CCTV export from the store, not just the stills attached to the report.' },
      { id: 3, at: now() - 4 * D, kind: 'note', author: 'Colin Ward', text: 'Full export added to evidence locker, case #42.' },
      { id: 4, at: now() - 40 * 60, kind: 'scheduled', author: 'Harlan Price', text: 'Hearing set for tomorrow 14:00 in Courtroom 2' },
    ],
  }),
  kase({ title: 'State v. Grant', defendant: p('RTL20917'), prosecutor: p('DA2'), defense: p('LAW2'), judge: p('JUD3'), status: 'in_session', age: 9, updated: 25 * 60, hearingAt: atHour(0, new Date().getHours(), 0), courtroom: 'Courtroom 1', charges: [{ id: 7, title: 'Grand theft auto', count: 3 }, { id: 40, title: 'Possession of stolen property', count: 1 }], summary: 'Chop shop operation on Popular St. Three vehicles recovered with altered VINs.' }),
  kase({ title: 'State v. Varga', defendant: p('PQA77310'), prosecutor: p('DA3'), defense: p('LAW3'), judge: p('JUD1'), status: 'scheduled', age: 4, updated: 3 * H, hearingAt: atHour(2, 10, 30), courtroom: 'Courtroom 3', charges: [{ id: 22, title: 'Assault with a deadly weapon', count: 1 }] }),
  kase({ title: 'State v. Bell', defendant: p('BCE10442'), prosecutor: p('DA1'), defense: null, judge: p('JUD4'), status: 'scheduled', age: 2, updated: 5 * H, hearingAt: atHour(4, 9), courtroom: 'Judge chambers', charges: [{ id: 51, title: 'Public intoxication', count: 1 }, { id: 52, title: 'Disorderly conduct', count: 1 }] }),
  kase({ title: 'State v. Okoro', defendant: p('JHO55128'), prosecutor: p('DA2'), defense: p('LAW4'), judge: p('JUD3'), status: 'scheduled', age: 3, updated: 9 * H, hearingAt: atHour(8, 15), courtroom: 'Courtroom 1', charges: [{ id: 60, title: 'Possession with intent to distribute', count: 1 }] }),
  kase({ title: 'State v. Hale', defendant: p('VHL33019'), prosecutor: p('DA1'), defense: p('LAW1'), judge: null, status: 'filed', age: 1, updated: 2 * H, charges: [{ id: 70, title: 'Fraud', count: 4 }, { id: 71, title: 'Money laundering', count: 1 }], summary: 'Property deeds forged across four Vinewood Hills sales.' }),
  kase({ title: 'State v. Unknown male (Pier shooting)', defendant: { name: 'John Doe' }, prosecutor: p('DA3'), defense: null, judge: null, status: 'filed', age: 0.5, updated: 50 * 60, charges: [{ title: 'Attempted murder', count: 1 }] }),
  kase({ title: 'State v. Mack', defendant: p('TMK90215'), prosecutor: p('DA2'), defense: p('LAW3'), judge: p('JUD1'), status: 'verdict', age: 12, updated: D, verdict: 'plea', sentence: { fine: 2500, months: 6, notes: 'Plea to reduced charge of reckless endangerment.', apply: true, executed: true, recorded: true, jailed: true }, charges: [{ id: 33, title: 'Reckless endangerment', count: 1 }] }),
  kase({ title: 'State v. Fontaine', defendant: p('EFN47731'), prosecutor: p('DA1'), defense: p('LAW2'), judge: p('JUD3'), status: 'closed', age: 20, updated: 6 * D, verdict: 'not_guilty', sentence: { fine: 0, months: 0, notes: 'Jury not persuaded on provenance of the paintings.', apply: false, executed: false }, charges: [{ id: 41, title: 'Receiving stolen property', count: 2 }] }),
  kase({ title: 'State v. Mori', defendant: p('KMR12094'), prosecutor: p('DA3'), defense: p('LAW4'), judge: p('JUD4'), status: 'dismissed', age: 15, updated: 9 * D, verdict: 'dismissed', sentence: { fine: 0, months: 0, notes: 'Insufficient evidence.', apply: false }, charges: [{ id: 55, title: 'Vandalism', count: 1 }] }),
  kase({ title: 'State v. Ruiz', defendant: p('HRZ88402'), prosecutor: p('DA1'), defense: p('LAW1'), judge: p('JUD1'), status: 'closed', age: 30, updated: 14 * D, verdict: 'guilty', sentence: { fine: 12000, months: 30, notes: '', apply: true, executed: false, recorded: false, jailed: false, missing: ['sentencing', 'prison'] }, charges: [{ id: 80, title: 'Vehicular manslaughter', count: 1 }, { id: 81, title: 'Driving under the influence', count: 1 }] }),
  kase({ title: 'State v. Petrova', defendant: p('NPT30586'), prosecutor: p('DA2'), defense: p('LAW3'), judge: p('JUD3'), status: 'scheduled', age: 5, updated: 26 * H, hearingAt: atHour(11, 11), courtroom: 'Courtroom 2', charges: [{ id: 90, title: 'Trespassing', count: 1 }] }),
];

for (const c of cases) {
  if (!c.verdict) continue;
  const at = c.updatedAt - 3600;
  const terms = [c.sentence.months ? `${c.sentence.months} months` : '', c.sentence.fine ? `$${c.sentence.fine} fine` : ''].filter(Boolean).join(', ');
  const convicted = c.verdict === 'guilty' || c.verdict === 'plea';
  c.events.push({ id: c.id * 10 + 1, at: at - 2 * D, kind: 'scheduled', author: c.judge?.name || 'Harlan Price', text: `Hearing set in ${rooms[c.id % rooms.length]}` });
  c.events.push({ id: c.id * 10 + 2, at, kind: 'verdict', author: c.judge?.name || 'Harlan Price', text: `Verdict: ${verdictLabel[c.verdict]}.${convicted ? ` Sentence: ${terms || 'none'}.` : ''}${c.sentence.apply ? (c.sentence.executed ? ' Sentence applied.' : ' Sentence recorded but not applied.') : ''}${c.sentence.notes ? ` ${c.sentence.notes}` : ''}` });
  if (c.status === 'closed') c.events.push({ id: c.id * 10 + 3, at: c.updatedAt, kind: 'status', author: c.judge?.name || 'Harlan Price', text: 'Status changed from Verdict to Closed' });
}

function role(c, cid) {
  if (c.judge?.cid === cid) return 'judge';
  if (c.prosecutor?.cid === cid) return 'prosecutor';
  if (c.defense?.cid === cid) return 'defense';
  return null;
}

function final(c) {
  return !!c.verdict || c.status === 'closed' || c.status === 'dismissed';
}

function view(c, s) {
  const manage = s.boss;
  const me = 'JUD1';
  return {
    ...c,
    role: role(c, me),
    can: {
      edit: manage && c.status !== 'closed' && c.status !== 'dismissed',
      schedule: manage && !final(c),
      verdict: manage && !final(c),
      note: manage || role(c, me) !== null,
    },
  };
}

function row(c) {
  return {
    id: c.id, number: c.number, title: c.title, status: c.status, defendant: c.defendant?.name, prosecutor: c.prosecutor?.name, defense: c.defense?.name,
    judge: c.judge?.name, hearingAt: c.hearingAt, courtroom: c.courtroom, verdict: c.verdict, chargeCount: c.charges.length, updatedAt: c.updatedAt,
    mine: role(c, 'JUD1') !== null || undefined,
  };
}

function event(c, kind, text) {
  c.events.push({ id: Date.now(), at: now(), kind, author: 'Harlan Price', text });
  c.updatedAt = now();
  push('court:changed', { id: c.id, number: c.number, status: c.status });
}

function readCase(d) {
  const title = String(d.title || '').trim();
  if (title.length < 3) return fail('bad_request');
  const defendant = d.defendantCid ? p(d.defendantCid) : String(d.defendantName || '').trim() ? { name: String(d.defendantName).trim() } : null;
  if (!defendant) return fail('bad_request');
  const charges = (d.charges || []).filter((x) => String(x.title || '').trim().length >= 2).map((x) => ({ id: x.id || null, title: String(x.title).trim(), count: Number(x.count) || 1 }));
  return {
    title, defendant, prosecutor: d.prosecutorCid ? p(d.prosecutorCid) : null, defense: d.defenseCid ? p(d.defenseCid) : null, judge: d.judgeCid ? p(d.judgeCid) : null,
    charges, reportId: d.reportId || null, caseId: d.caseId || null, summary: d.summary || '',
  };
}

export default function (reg, regCallback, s) {
  reg('court.list', (d) => {
    const status = d.status || 'all';
    const q = String(d.q || '').trim().toLowerCase();
    let list = [...cases];
    if (d.mine) list = list.filter((c) => role(c, 'JUD1') || c.createdBy === 'JUD1');
    if (q) list = list.filter((c) => `${c.number} ${c.title} ${c.defendant?.name || ''}`.toLowerCase().includes(q));
    const counts = { all: list.length, open: 0 };
    for (const k of Object.keys(statusLabel)) counts[k] = 0;
    for (const c of list) {
      counts[c.status] += 1;
      if (['filed', 'scheduled', 'in_session'].includes(c.status)) counts.open += 1;
    }
    if (status === 'open') list = list.filter((c) => ['filed', 'scheduled', 'in_session'].includes(c.status));
    else if (status !== 'all') list = list.filter((c) => c.status === status);
    list.sort((a, b) => b.updatedAt - a.updatedAt);
    return { rows: list.map(row), page: 1, more: false, counts };
  });
  reg('court.get', (d) => {
    const c = cases.find((x) => x.id === Number(d.id));
    return c ? view(c, s) : fail('not_found');
  });
  reg('court.calendar', () => {
    const from = now() - H;
    const to = now() + 14 * D;
    const hearings = cases
      .filter((c) => c.hearingAt && c.hearingAt >= from && c.hearingAt <= to && ['scheduled', 'in_session'].includes(c.status))
      .sort((a, b) => a.hearingAt - b.hearingAt)
      .map((c) => ({ id: c.id, number: c.number, title: c.title, status: c.status, defendant: c.defendant?.name, judge: c.judge?.name, hearingAt: c.hearingAt, courtroom: c.courtroom, mine: role(c, 'JUD1') !== null }));
    return { hearings, courtrooms: rooms, days: 14 };
  });
  reg('court.save', (d) => {
    if (!s.boss) return fail('not_allowed');
    const f = readCase(d);
    if (f.__error) return f;
    if (d.id) {
      const c = cases.find((x) => x.id === Number(d.id));
      if (!c) return fail('not_found');
      if (c.status === 'closed' || c.status === 'dismissed') return fail('locked');
      if (c.verdict) {
        if (d.status && d.status !== c.status && d.status !== 'closed') return fail('locked');
        if (d.status === 'closed' && c.status !== 'closed') {
          event(c, 'status', `Status changed from ${statusLabel[c.status]} to Closed`);
          c.status = 'closed';
        }
        c.summary = d.summary || '';
        return view(c, s);
      }
      if (d.status === 'scheduled' && !c.hearingAt) return fail('no_hearing');
      const before = c.status;
      Object.assign(c, f, { status: d.status || c.status });
      if (before !== c.status) event(c, 'status', `Status changed from ${statusLabel[before]} to ${statusLabel[c.status]}`);
      else c.updatedAt = now();
      return view(c, s);
    }
    seq += 1;
    const c = { ...kase({ ...f, age: 0 }), id: 300 + seq + 50, number: `SA-${year}-${String(seq).padStart(4, '0')}`, createdBy: 'JUD1' };
    c.events = [{ id: Date.now(), at: now(), kind: 'filed', author: 'Harlan Price', text: 'Case filed by Harlan Price' }];
    cases.unshift(c);
    return view(c, s);
  });
  reg('court.schedule', (d) => {
    const c = cases.find((x) => x.id === Number(d.id));
    if (!c) return fail('not_found');
    if (final(c)) return fail('locked');
    if (d.clear) {
      c.hearingAt = null;
      c.courtroom = null;
      c.status = 'filed';
      event(c, 'scheduled', 'Hearing cancelled');
      return view(c, s);
    }
    if (!d.hearingAt || d.hearingAt < now() - 300) return fail('bad_time');
    if (!rooms.includes(d.courtroom)) return fail('bad_request');
    c.hearingAt = d.hearingAt;
    c.courtroom = d.courtroom;
    c.status = 'scheduled';
    event(c, 'scheduled', `Hearing set for ${new Date(d.hearingAt * 1000).toISOString().slice(0, 16).replace('T', ' ')} UTC in ${d.courtroom}`);
    return view(c, s);
  });
  reg('court.note', (d) => {
    const c = cases.find((x) => x.id === Number(d.id));
    if (!c) return fail('not_found');
    const text = String(d.text || '').trim();
    if (!text) return fail('bad_request');
    event(c, 'note', text.slice(0, 1000));
    return view(c, s);
  });
  reg('court.verdict', (d) => {
    const c = cases.find((x) => x.id === Number(d.id));
    if (!c) return fail('not_found');
    if (final(c)) return fail('locked');
    if (!verdictLabel[d.verdict]) return fail('bad_request');
    const convicted = d.verdict === 'guilty' || d.verdict === 'plea';
    const apply = convicted && !!d.apply;
    const executed = apply && !!c.defendant?.cid;
    c.verdict = d.verdict;
    c.status = d.verdict === 'dismissed' ? 'dismissed' : 'verdict';
    c.sentence = {
      fine: convicted ? Number(d.fine) || 0 : 0, months: convicted ? Number(d.months) || 0 : 0, notes: d.notes || null, apply, executed,
      missing: apply && !executed ? ['sentencing', 'prison'] : undefined, reason: apply && !c.defendant?.cid ? 'no_defendant' : undefined,
    };
    const terms = [c.sentence.months ? `${c.sentence.months} months` : '', c.sentence.fine ? `$${c.sentence.fine} fine` : ''].filter(Boolean).join(', ');
    event(c, 'verdict', `Verdict: ${verdictLabel[d.verdict]}.${convicted ? ` Sentence: ${terms || 'none'}.` : ''}${apply ? (executed ? ' Sentence applied.' : ' Sentence recorded but not applied.') : ''}`);
    return { ...view(c, s), executed, missing: c.sentence.missing };
  });
}
