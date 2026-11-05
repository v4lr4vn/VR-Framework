import { fail } from '../index.js';
import { push } from '../state.js';
import { chargeByTitle, expand, sum, setReferenceCheck } from './reports_penal.js';
import { citizens, officers, personByCid, mockCan, meOf } from './reports_people.js';
import { mockPhoto } from './reports_media.js';

const now = () => Math.floor(Date.now() / 1000);
const H = 3600;
const D = 86400;
const PAGE = 25;
const rules = { pleaReduction: 0.25, maxDiscretion: 0.5 };

let personSeq = 500;
let sentenceSeq = 900;
const lookups = { caseOf: () => null, evidenceCount: () => 0 };

export function setLookups(fns) {
  Object.assign(lookups, fns);
}

function officerOf(cid) {
  return officers.find((o) => o.cid === cid);
}

function charges(list) {
  return list.map((x) => {
    const [title, count] = Array.isArray(x) ? x : [x, 1];
    return { id: chargeByTitle(title).id, count };
  });
}

function bounds(total, plea) {
  const factor = plea ? 1 - rules.pleaReduction : 1;
  const maxFine = Math.floor(total.fine * factor + 0.5);
  const maxMonths = Math.floor(total.months * factor + 0.5);
  return { fine: maxFine, months: maxMonths, minFine: Math.ceil(maxFine * (1 - rules.maxDiscretion) - 1e-9), minMonths: Math.ceil(maxMonths * (1 - rules.maxDiscretion) - 1e-9) };
}

function person(cidOrName, role, list = [], extra = {}) {
  const known = personByCid(cidOrName);
  const p = {
    id: ++personSeq,
    cid: known ? cidOrName : null,
    name: known ? known.name : cidOrName,
    callsign: role === 'officer' ? officerOf(cidOrName)?.callsign || null : null,
    role,
    notes: extra.notes || '',
    charges: role === 'suspect' ? charges(list) : [],
    sentence: null,
  };
  if (extra.sentence) p.pendingSentence = extra.sentence;
  return p;
}

function author(cid) {
  const o = officerOf(cid);
  return { cid: o.cid, name: o.name, callsign: o.callsign };
}

function sentence(report, p, opts) {
  const items = expand(p.charges);
  const total = sum(items);
  const b = bounds(total, opts.plea);
  const fine = opts.fine ?? b.fine;
  const months = opts.months ?? b.months;
  const officer = author(opts.by || report.author.cid);
  return {
    id: ++sentenceSeq,
    reportId: report.id,
    cid: p.cid,
    name: p.name,
    charges: items.map((i) => ({ id: i.id, title: i.title, class: i.class, count: i.count, fine: i.fine, months: i.months, points: i.points })),
    fine,
    paid: opts.paid ?? fine,
    months,
    points: total.points,
    plea: !!opts.plea,
    jailed: months > 0,
    officer: `${officer.callsign} ${officer.name}`,
    officerCid: officer.cid,
    at: report.createdAt + 1500,
    source: 'report',
  };
}

function report(id, o) {
  const createdAt = now() - o.ago;
  const r = {
    id,
    type: o.type,
    title: o.title,
    body: o.body || '',
    location: o.location || null,
    callId: o.callId || null,
    caseId: o.caseId || null,
    author: author(o.author),
    createdAt,
    updatedAt: createdAt + (o.edited || 0),
    locked: !!o.locked,
    tags: o.tags || [],
    people: o.people || [],
    vehicles: o.vehicles || [],
    images: (o.images || []).map(([kind, caption]) => ({ id: mockPhoto(kind), caption })),
  };
  for (const p of r.people) {
    if (p.pendingSentence) {
      p.sentence = sentence(r, p, p.pendingSentence);
      delete p.pendingSentence;
    }
  }
  return r;
}

export const reports = [
  report(2114, {
    type: 'arrest', title: 'Armed robbery, 24/7 Innocence Blvd', author: 'COP2', ago: 35 * 60, edited: 600, callId: 1041, caseId: 312, location: 'Innocence Blvd & Elgin Ave', tags: ['robbery', 'firearm'],
    body: 'Responded to a robbery alarm at the 24/7 on Innocence Blvd at 02:14. The clerk, Hector Ruiz, said a man in a black ski mask pointed a pistol at him and took about $1,800 from the register.\n\n1-ADAM-12 spotted a black Buffalo S matching the description leaving northbound on Elgin Ave. After a short foot pursuit near the car wash the driver, Tyrell Banks, was detained. A black ski mask and a 9mm pistol were found under the passenger seat.\n\nBanks declined to make a statement. Store CCTV was secured and is attached to case #312.',
    people: [
      person('TBK77204', 'suspect', ['Armed robbery', 'Brandishing a weapon', 'Evading on foot', 'Carrying a firearm without a licence'], { notes: 'Detained near the Elgin Ave car wash. Declined to make a statement.' }),
      person('HRZ88402', 'victim', [], { notes: 'Store clerk. Uninjured, shaken.' }),
      person('KMR4456', 'witness', [], { notes: 'Customer in the store during the robbery.' }),
      person('COP1', 'officer'),
    ],
    vehicles: [{ plate: '81KTR093', label: 'Bravado Buffalo S · black', note: 'Suspect vehicle, impounded at Davis lot' }],
    images: [['cctv', 'CCTV, register camera'], ['mask', 'Ski mask under the passenger seat']],
  }),
  report(2113, {
    type: 'traffic', title: 'Pursuit on Del Perro Fwy, green Sultan RS', author: 'COP3', ago: 3 * H, callId: 1038, location: 'Del Perro Fwy, eastbound', tags: ['pursuit'],
    body: 'Attempted a stop on a green Sultan RS doing about 110 in a 65 zone. The driver accelerated and left the freeway at Vespucci Blvd, running two red lights. Pursuit ended after 4 minutes when the vehicle stalled in the Del Perro Pier car park.\n\nDriver identified as Dana Cruz. No valid driver licence on record. She pleaded guilty at the scene.',
    people: [
      person('DCR40219', 'suspect', ['Felony evading', 'Reckless driving', 'Driving without a valid licence'], { sentence: { plea: true } }),
      person('COP4', 'officer'),
    ],
    vehicles: [{ plate: '46EEK572', label: 'Karin Sultan RS · green', note: 'Registered to the driver' }],
    images: [['sedan', 'Vehicle where it stopped']],
  }),
  report(2112, {
    type: 'incident', title: 'Fight outside Bahama Mamas', author: 'COP4', ago: 9 * H, location: 'Bahama Mamas West, Del Perro',
    body: 'Called to a fight in the queue outside Bahama Mamas. Ellis Dawson punched Wes Hagan twice after an argument over the queue. Dawson pulled away when cuffed and had to be taken to the ground.\n\nHagan was drunk and shouting at patrons and staff. Both refused medical treatment.',
    people: [
      person('DSN1178', 'suspect', ['Battery', 'Resisting arrest'], { notes: 'Small cut on the knuckles.' }),
      person('HGN5521', 'suspect', ['Disturbing the peace', 'Public intoxication'], { sentence: {} }),
      person('ADL3087', 'witness', [], { notes: 'Door staff. Saw the first punch.' }),
    ],
  }),
  report(2111, {
    type: 'investigation', title: 'Shell casings recovered on Grove St', author: 'COP7', ago: 26 * H, caseId: 311, location: 'Grove St, Davis', locked: true, tags: ['shooting', 'ballistics'],
    body: 'Canvassed Grove St after the third drive-by this week. Three 9mm casings found in the road outside 1104 and marked 1 to 3. Four bullet strikes on the front wall of 1104, no injuries.\n\nBobby Lang saw a green two-door car leave towards Forum Dr straight after the shots.',
    people: [
      person('Driver of a green two-door sedan', 'other', [], { notes: 'Left towards Forum Dr after the shots.' }),
      person('LNG8890', 'witness', [], { notes: 'Lives across the road. Willing to give a formal statement.' }),
      person('COP3', 'officer'),
    ],
    images: [['casings', 'Casings marked 1 to 3'], ['wall', 'Strikes on the wall of 1104']],
  }),
  report(2110, {
    type: 'arrest', title: 'Narcotics stop on Forum Dr', author: 'COP1', ago: 30 * H, caseId: 309, location: 'Forum Dr, Strawberry', locked: true, tags: ['narcotics', 'firearm'],
    body: 'Stopped a silver Kuruma for a broken tail light. Strong smell of cannabis. Search found 42 bagged pills in the centre console and an unlicensed pistol in the glovebox.',
    people: [person('PLK3301', 'suspect', ['Possession with intent to distribute', 'Carrying a firearm without a licence'], { sentence: { fine: 6000, months: 32 } })],
    vehicles: [{ plate: '77BRA555', label: 'Karin Kuruma · silver', note: 'Searched at the roadside' }],
    images: [['bag', 'Pills from the centre console'], ['pistol', 'Pistol from the glovebox']],
  }),
  report(2109, {
    type: 'use_of_force', title: 'Taser deployed during arrest of Calvin Ford', author: 'COP5', ago: 2 * D, location: 'Popular St, La Mesa',
    body: 'Ford was asked to step out of his van after a welfare check. He shoved Officer Ortega into the door and ran. After two warnings I deployed my taser once, both probes connected. Ford was cuffed without further force and checked by EMS at the scene.',
    people: [person('FRD9902', 'suspect', ['Resisting arrest', 'Assault on a public servant']), person('COP2', 'officer'), person('COP1', 'officer')],
    vehicles: [{ plate: '52WRT319', label: 'Bravado Bison · white', note: '' }],
  }),
  report(2108, {
    type: 'traffic', title: 'DUI checkpoint, Vespucci Blvd', author: 'COP1', ago: 2 * D + 5 * H, location: 'Vespucci Blvd checkpoint',
    body: 'Driver failed the roadside breath test twice. Admitted to four drinks at Yellow Jack.',
    people: [person('MRT6620', 'suspect', ['Driving under the influence'], { sentence: { plea: true, paid: 600 } })],
    vehicles: [{ plate: '30HJK862', label: 'Pegassi Faggio · mint', note: 'Left parked, keys with the driver' }],
  }),
  report(2107, {
    type: 'incident', title: 'Vandalism at Legion Square', author: 'COP3', ago: 3 * D, location: 'Legion Square',
    body: 'Spray paint on the fountain and two benches. The suspect ran towards Vinewood before units arrived.',
    people: [person('Unknown male, red hoodie', 'suspect', ['Vandalism']), person('VLD2043', 'witness', [], { notes: 'Called it in.' })],
  }),
  report(2106, {
    type: 'arrest', title: 'Burglary of a Mirror Park home', author: 'COP7', ago: 4 * D, caseId: 313, location: 'Nikola Ave, Mirror Park',
    body: 'Neighbour reported a man carrying a television out of a house whose owners are away. Jack Whitlow was found loading it into an Emperor parked behind the house.',
    people: [person('WTL1904', 'suspect', ['Burglary', 'Possession of stolen property'])],
    vehicles: [{ plate: '66PQX201', label: 'Albany Emperor · rusted', note: 'Television and jewellery box in the boot' }],
  }),
  report(2105, {
    type: 'other', title: 'Lost wallet returned to its owner', author: 'COP5', ago: 5 * D,
    body: 'A wallet handed in at Mission Row front desk was returned to Priya Shah. Cash and cards accounted for.',
    people: [person('SHA7731', 'victim', [], { notes: 'Owner of the wallet.' })],
  }),
  report(2104, {
    type: 'traffic', title: 'Hit and run on Strawberry Ave', author: 'COP4', ago: 5 * D + 3 * H, location: 'Strawberry Ave & Davis Ave',
    body: 'A white van rear-ended a red Blista at the lights and drove off south. Driver of the Blista has minor neck pain.',
    people: [person('VLD2043', 'victim', [], { notes: 'Minor injuries, treated at Pillbox.' }), person('Unknown driver of a white van', 'other')],
    vehicles: [{ plate: '20GHL774', label: 'Dinka Blista · red', note: 'Victim vehicle, rear damage' }],
  }),
  report(2103, {
    type: 'investigation', title: 'Missing person: Priya Shah', author: 'COP7', ago: 6 * D, caseId: 314,
    body: 'Reported missing by her roommate after she did not come home on Thursday night. Last seen leaving the Tequi-la-la.',
    people: [person('SHA7731', 'victim'), person('OKF8812', 'witness', [], { notes: 'Roommate. Last saw her on Thursday.' })],
  }),
  report(2102, {
    type: 'arrest', title: 'Trespassing at Humane Labs', author: 'COP2', ago: 7 * D, location: 'Humane Labs, Grand Senora',
    body: 'Found inside the outer fence of Humane Labs at 03:00. Refused to give his name until booked.',
    people: [person('NVR5530', 'suspect', ['Trespassing', 'Failure to identify'], { sentence: {} })],
  }),
  report(2101, {
    type: 'incident', title: 'Noise complaint, Vinewood Hills party', author: 'COP1', ago: 8 * D, location: 'Kimble Hill Dr',
    body: 'Third complaint this month about the same address. Host was warned and the music turned down.',
    people: [person('OKF8812', 'suspect', ['Disturbing the peace'])],
  }),
];

const filler = [
  ['traffic', 'Speeding on Route 68', 'Speeding'],
  ['traffic', 'Running a red light, Alta St', 'Running a red light or stop sign'],
  ['incident', 'Public intoxication, Vespucci Beach', 'Public intoxication'],
  ['traffic', 'Illegal parking outside Pillbox', 'Illegal parking'],
  ['incident', 'Jaywalking on Power St', 'Jaywalking'],
  ['traffic', 'No licence at a traffic stop', 'Driving without a valid licence'],
  ['incident', 'Shoplifting at Binco', 'Petty theft'],
  ['arrest', 'Trespassing at the Del Perro Pier', 'Trespassing'],
  ['traffic', 'Failure to yield to an ambulance', 'Failure to yield to an emergency vehicle'],
  ['incident', 'Disturbance at Yellow Jack', 'Disturbing the peace'],
];
const authors = ['COP3', 'COP4', 'COP5', 'COP2', 'COP1', 'COP7'];
for (let i = 0; i < 20; i++) {
  const [type, title, charge] = filler[i % filler.length];
  const civ = citizens[(i * 5) % citizens.length];
  reports.push(report(2100 - i, { type, title, author: authors[i % authors.length], ago: (9 + i) * D + i * 1700, people: [person(civ.cid, 'suspect', [charge], i % 3 === 0 ? {} : { sentence: {} })] }));
}

setReferenceCheck((id) => reports.some((r) => r.people.some((p) => p.charges.some((c) => c.id === id) || p.sentence?.charges.some((c) => c.id === id))));

function rights(s, r) {
  const me = meOf(s);
  const editor = (r.author.cid === me.cid && mockCan(s, 'reports.create')) || mockCan(s, 'reports.edit_any');
  return {
    edit: editor && (!r.locked || s.boss),
    lock: mockCan(s, 'reports.edit_any'),
    delete: mockCan(s, 'reports.delete'),
    sentence: mockCan(s, 'sentencing.apply'),
    evidence: mockCan(s, 'evidence.manage'),
    link: mockCan(s, 'cases.manage'),
  };
}

function header(r) {
  return { id: r.id, type: r.type, title: r.title, location: r.location, callId: r.callId, caseId: r.caseId, author: r.author, createdAt: r.createdAt, updatedAt: r.updatedAt, locked: r.locked, tags: r.tags };
}

function full(s, r) {
  const people = r.people.map((p) => {
    const items = p.sentence ? p.sentence.charges : expand(p.charges);
    const t = sum(items);
    return { id: p.id, cid: p.cid, name: p.name, callsign: p.callsign, role: p.role, notes: p.notes, charges: items, totals: t, sentenced: !!p.sentence, sentence: p.sentence };
  });
  const c = r.caseId ? lookups.caseOf(r.caseId) : null;
  return {
    ...header(r),
    body: r.body,
    people,
    officers: [{ ...r.author, author: true }, ...r.people.filter((p) => p.role === 'officer').map((p) => ({ cid: p.cid, name: p.name, callsign: p.callsign, personId: p.id }))],
    vehicles: r.vehicles,
    images: r.images,
    case: c ? { id: c.id, title: c.title, status: c.status } : null,
    evidenceCount: lookups.evidenceCount(r.id),
    rules,
    can: rights(s, r),
  };
}

function canRead(s) {
  return mockCan(s, 'reports.create') || mockCan(s, 'reports.view');
}

function changed(id, deleted) {
  push('reports:changed', { id, deleted: deleted || undefined });
}

function personFor(d) {
  const r = reports.find((x) => x.id === d.reportId);
  const p = r?.people.find((x) => x.id === d.personId);
  if (!r || !p) return { error: 'not_found' };
  if (p.role !== 'suspect') return { error: 'not_suspect' };
  if (!p.cid) return { error: 'no_cid' };
  return { r, p };
}

function quote(r, p, plea) {
  const items = expand(p.charges);
  if (!items.length) return null;
  const total = sum(items);
  const b = bounds(total, plea);
  return { reportId: r.id, personId: p.id, cid: p.cid, name: p.name, charges: items, total, plea, max: { fine: b.fine, months: b.months }, min: { fine: b.minFine, months: b.minMonths }, points: total.points, rules, sentenced: !!p.sentence };
}

export default function (reg, regCallback, s) {
  reg('reports.list', (d) => {
    if (!canRead(s)) return fail('not_allowed');
    const q = String(d.q || '').trim().toLowerCase();
    const num = q.match(/^#?(\d+)$/);
    const me = meOf(s);
    let list = reports.filter((r) => {
      if (d.type && r.type !== d.type) return false;
      if (d.mine && r.author.cid !== me.cid && !r.people.some((p) => p.role === 'officer' && p.cid === me.cid)) return false;
      if (d.cid && !r.people.some((p) => p.cid === d.cid)) return false;
      if (!q) return true;
      if (num && r.id === Number(num[1])) return true;
      return [r.title, r.author.name, r.author.callsign, r.location || '', ...r.people.map((p) => p.name)].some((x) => String(x).toLowerCase().includes(q));
    });
    list = list.sort((a, b) => b.id - a.id);
    const total = list.length;
    const pages = Math.max(1, Math.ceil(total / PAGE));
    const page = Math.min(Math.max(1, Number(d.page) || 1), pages);
    const items = list.slice((page - 1) * PAGE, page * PAGE).map((r) => {
      const others = r.people.filter((p) => p.role !== 'officer');
      return { ...header(r), suspects: others.filter((p) => p.role === 'suspect').slice(0, 4).map((p) => p.name), peopleCount: others.length, sentenced: r.people.some((p) => p.sentence) };
    });
    return { items, total, page, pages, pageSize: PAGE };
  });

  reg('reports.get', (d) => {
    if (!canRead(s)) return fail('not_allowed');
    const r = reports.find((x) => x.id === Number(d.id));
    return r ? full(s, r) : fail('not_found');
  });

  reg('reports.save', (d) => {
    if (!mockCan(s, 'reports.create') && !mockCan(s, 'reports.edit_any')) return fail('not_allowed');
    const title = String(d.title || '').trim().slice(0, 96);
    if (title.length < 3) return fail('bad_request');
    let r = d.id ? reports.find((x) => x.id === d.id) : null;
    if (d.id && !r) return fail('not_found');
    if (r) {
      const can = rights(s, r);
      if (!can.edit) return fail(r.locked ? 'locked' : 'not_allowed');
    }
    if (d.caseId && !lookups.caseOf(d.caseId)) return fail('unknown_case');
    const me = meOf(s);
    const old = r ? r.people : [];
    const people = [];
    for (const p of d.people || []) {
      const prev = p.id ? old.find((x) => x.id === p.id) : null;
      if (prev && prev.sentence) {
        people.push({ ...prev, notes: p.notes || '' });
        continue;
      }
      if (p.role === 'officer' && p.cid === (r ? r.author.cid : me.cid)) continue;
      const known = p.cid ? personByCid(p.cid) : null;
      if (p.cid && !known) return fail('unknown_person');
      people.push({
        id: prev ? prev.id : ++personSeq,
        cid: p.cid || null,
        name: known ? known.name : String(p.name || '').trim(),
        callsign: p.role === 'officer' ? officerOf(p.cid)?.callsign || null : null,
        role: p.role,
        notes: p.notes || '',
        charges: p.role === 'suspect' ? (p.charges || []).map((c) => ({ id: c.id, count: c.count || 1 })) : [],
        sentence: null,
      });
    }
    for (const p of old) if (p.sentence && !people.some((x) => x.id === p.id)) people.push(p);
    const fields = {
      type: d.type, title, body: d.body || '', location: d.location || null, callId: d.callId || null, caseId: d.caseId || null,
      tags: d.tags || [], people, vehicles: (d.vehicles || []).map((v) => ({ plate: v.plate, label: v.label || null, note: v.note || null })), images: d.images || [], updatedAt: now(),
    };
    if (r) Object.assign(r, fields);
    else {
      r = { id: Math.max(...reports.map((x) => x.id)) + 1, author: { cid: me.cid, name: me.name, callsign: me.callsign }, createdAt: now(), locked: false, ...fields };
      reports.unshift(r);
    }
    changed(r.id);
    return full(s, r);
  });

  reg('reports.lock', (d) => {
    if (!mockCan(s, 'reports.edit_any')) return fail('not_allowed');
    const r = reports.find((x) => x.id === d.id);
    if (!r) return fail('not_found');
    r.locked = d.locked === true;
    r.updatedAt = now();
    changed(r.id);
    return full(s, r);
  });

  reg('reports.delete', (d) => {
    if (!mockCan(s, 'reports.delete')) return fail('not_allowed');
    const i = reports.findIndex((x) => x.id === d.id);
    if (i < 0) return fail('not_found');
    reports.splice(i, 1);
    changed(d.id, true);
    return { deleted: true };
  });

  reg('sentencing.preview', (d) => {
    if (!mockCan(s, 'sentencing.apply')) return fail('not_allowed');
    const { r, p, error } = personFor(d);
    if (error) return fail(error);
    return quote(r, p, d.plea === true) || fail('no_charges');
  });

  reg('sentencing.apply', (d) => {
    if (!mockCan(s, 'sentencing.apply')) return fail('not_allowed');
    const { r, p, error } = personFor(d);
    if (error) return fail(error);
    if (p.sentence) return fail('already_sentenced');
    const q = quote(r, p, d.plea === true);
    if (!q) return fail('no_charges');
    const fine = d.fine ?? q.max.fine;
    const months = d.months ?? q.max.months;
    if (fine > q.max.fine || months > q.max.months) return fail('above_max');
    if (fine < q.min.fine || months < q.min.months) return fail('below_min');
    const paid = p.cid === 'TBK77204' ? Math.min(fine, 2400) : fine;
    const me = meOf(s);
    p.sentence = { ...sentence(r, p, { plea: d.plea === true, fine, months, paid, by: me.cid }), at: now() };
    changed(r.id);
    return { sentence: p.sentence, warnings: [], unpaid: fine - paid };
  });

  reg('sentencing.list', (d) => {
    const out = [];
    for (const r of reports) for (const p of r.people) if (p.cid === d.cid && p.sentence) out.push(p.sentence);
    return out.sort((a, b) => b.id - a.id);
  });
}
