import { fail } from '../index.js';
import { push } from '../state.js';
import { citizens } from './d_people.js';

const now = () => Math.floor(Date.now() / 1000);
const H = 3600;
const D = 86400;
const me = { cid: 'MED1', name: 'Tess Moreau', callsign: 'MEDIC 3' };
const owen = { cid: 'MED2', name: 'Owen Price', callsign: 'MEDIC 5' };
const nia = { cid: 'MED3', name: 'Nia Okafor', callsign: 'MEDIC 7' };

const profiles = {
  DCR40219: { allergies: 'Penicillin (hives)\nLatex', conditions: 'Type 1 diabetes\nMild asthma', medications: 'Insulin glargine, 20 units nightly\nSalbutamol inhaler as needed', notes: 'Carries a glucose kit in her taxi. Prefers to be called Dee.', emergencyContact: 'Rosa Delgado (partner) 555-0136', updatedAt: now() - 2 * D, updatedBy: 'Owen Price' },
  RTL20917: { allergies: null, conditions: 'Old fracture, left tibia (2019)', medications: null, notes: null, emergencyContact: 'Hector Ruiz (employer) 555-0121', updatedAt: now() - 9 * D, updatedBy: 'Tess Moreau' },
  BCE10442: { allergies: 'Codeine', conditions: 'Alcohol use disorder\nHypertension', medications: 'Amlodipine 5 mg daily', notes: 'Frequent attender. Usually found near Legion Square.', emergencyContact: null, updatedAt: now() - 20 * D, updatedBy: 'Nia Okafor' },
};

let nextId = 2210;
const reports = [
  { id: 2209, cid: 'DCR40219', name: 'Dana Cruz', type: 'treatment', title: 'Hypoglycaemic episode in vehicle', outcome: 'treated_released', callId: 1039, author: me, createdAt: now() - 35 * 60,
    body: 'Called by bystander to a taxi parked on Vinewood Blvd. Patient confused and sweating, BM 2.1 mmol/L.\n\nOral glucose given, recovered within 10 minutes. Ate a snack on scene, BM 6.4 on recheck.', treatment: 'Oral glucose gel 40 g. Advised to check sensor alarms.',
    injuries: [] },
  { id: 2208, cid: 'RTL20917', name: 'Milo Grant', type: 'transport', title: 'Hand laceration, garage accident', outcome: 'transported', callId: null, author: nia, createdAt: now() - 5 * H,
    body: 'Deep laceration across the left palm from an angle grinder. Bleeding controlled with pressure.', treatment: 'Pressure dressing, elevation. Transported to Pillbox for sutures.',
    injuries: [{ region: 'left_arm', kind: 'laceration', severity: 'moderate' }] },
  { id: 2207, cid: null, name: 'Unknown male, approx. 30', type: 'transport', title: 'GSW chest, Del Perro Pier', outcome: 'admitted', callId: 1031, author: me, createdAt: now() - 9 * H,
    body: 'Found on the pier boardwalk with a single gunshot wound to the right chest. Decreased air entry on the right.\n\nNeedle decompression on scene, rapid transport. Police on scene, suspect not located.', treatment: 'Chest seal, needle decompression, two large-bore IVs, high-flow oxygen.',
    injuries: [{ region: 'chest', kind: 'gunshot', severity: 'critical' }, { region: 'right_arm', kind: 'laceration', severity: 'minor' }] },
  { id: 2206, cid: 'BCE10442', name: 'Marcus Bell', type: 'checkup', title: 'Welfare check, Legion Square', outcome: 'refused', callId: null, author: owen, createdAt: now() - D,
    body: 'Intoxicated but alert and oriented. Declined transport and signed refusal.', treatment: 'Observation only.', injuries: [{ region: 'head', kind: 'blunt', severity: 'minor' }] },
  { id: 2205, cid: 'TMK90215', name: 'Tyrone Mack', type: 'treatment', title: 'Motorbike collision, Route 68', outcome: 'admitted', callId: null, author: owen, createdAt: now() - 2 * D,
    body: 'Rider thrown from bike at moderate speed. Helmet on. Obvious deformity of the right lower leg.', treatment: 'Splinted, analgesia, transported.',
    injuries: [{ region: 'right_leg', kind: 'fracture', severity: 'severe' }, { region: 'left_arm', kind: 'laceration', severity: 'minor' }, { region: 'back', kind: 'blunt', severity: 'moderate' }] },
  { id: 2204, cid: 'JHO55128', name: 'Jade Okoro', type: 'treatment', title: 'Kitchen burn', outcome: 'treated_released', callId: null, author: me, createdAt: now() - 3 * D,
    body: 'Hot oil splash to the right forearm.', treatment: 'Cooled for 20 minutes, cling film dressing.', injuries: [{ region: 'right_arm', kind: 'burn', severity: 'moderate' }] },
  { id: 2203, cid: 'VHL33019', name: 'Victor Hale', type: 'death', title: 'Cardiac arrest, Vinewood Hills', outcome: 'deceased', callId: null, author: nia, createdAt: now() - 4 * D,
    body: 'Witnessed collapse at home. CPR by family before arrival. Resuscitation attempted for 30 minutes without return of circulation.', treatment: 'ALS protocol, 4 shocks, adrenaline x6.', injuries: [] },
  { id: 2202, cid: 'NPT30586', name: 'Nina Petrova', type: 'other', title: 'Fall on stairs, university campus', outcome: 'treated_released', callId: null, author: me, createdAt: now() - 6 * D,
    body: 'Slipped on wet stairs, twisted left ankle.', treatment: 'RICE advice, crutches loaned.', injuries: [{ region: 'left_leg', kind: 'blunt', severity: 'minor' }] },
];

function find(id) {
  return reports.find((r) => r.id === Number(id));
}

function row(r) {
  return { id: r.id, cid: r.cid, name: r.name, type: r.type, title: r.title, outcome: r.outcome, callId: r.callId, injuryCount: r.injuries.length, author: r.author, createdAt: r.createdAt, updatedAt: r.updatedAt || r.createdAt };
}

function full(r, s) {
  return { ...row(r), body: r.body, treatment: r.treatment, injuries: r.injuries, canEdit: r.author.cid === me.cid || s.boss, canDelete: s.boss };
}

export default function (reg, regCallback, s) {
  reg('patients.search', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    if (!q) {
      const seen = new Map();
      for (const r of reports) if (r.cid && !seen.has(r.cid)) seen.set(r.cid, { cid: r.cid, name: r.name, lastSeen: r.createdAt, profile: !!profiles[r.cid] });
      return { recent: true, list: [...seen.values()] };
    }
    const list = citizens
      .filter((p) => p.name.toLowerCase().includes(q) || p.cid.toLowerCase().includes(q) || p.phone.includes(q))
      .map((p) => ({ cid: p.cid, name: p.name, dob: p.dob, gender: p.gender, phone: p.phone, profile: !!profiles[p.cid] }));
    return { recent: false, list };
  });
  reg('patients.get', (d) => {
    const p = citizens.find((x) => x.cid === d.cid);
    if (!p) return fail('not_found');
    return {
      identity: { cid: p.cid, name: p.name, dob: p.dob, phone: p.phone, gender: p.gender, nationality: p.nationality, jobLabel: p.jobLabel, online: p.cid === 'DCR40219', bloodtype: p.bloodtype },
      profile: profiles[p.cid] || {},
      reports: reports.filter((r) => r.cid === p.cid).map(row),
    };
  });
  reg('patients.save', (d) => {
    if (!citizens.some((x) => x.cid === d.cid)) return fail('not_found');
    const clean = (v, n) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, n) : null);
    profiles[d.cid] = {
      allergies: clean(d.allergies, 1000), conditions: clean(d.conditions, 1000), medications: clean(d.medications, 1000), notes: clean(d.notes, 1000),
      emergencyContact: clean(d.emergencyContact, 96), updatedAt: now(), updatedBy: me.name,
    };
    return profiles[d.cid];
  });
  reg('medreports.list', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    let list = [...reports];
    if (d.mine) list = list.filter((r) => r.author.cid === me.cid);
    if (d.cid) list = list.filter((r) => r.cid === d.cid);
    if (q) list = list.filter((r) => `${r.title} ${r.name} ${r.cid || ''} ${r.author.name}`.toLowerCase().includes(q));
    list.sort((a, b) => b.createdAt - a.createdAt);
    return { rows: list.map(row), page: 1, more: false };
  });
  reg('medreports.get', (d) => {
    const r = find(d.id);
    return r ? full(r, s) : fail('not_found');
  });
  reg('medreports.save', (d) => {
    const title = String(d.title || '').trim();
    if (title.length < 3 || !d.type) return fail('bad_request');
    const person = d.cid ? citizens.find((x) => x.cid === d.cid) : null;
    if (d.cid && !person) return fail('unknown_person');
    const name = person ? person.name : String(d.name || '').trim();
    if (name.length < 2) return fail('bad_request');
    const fields = { cid: person ? person.cid : null, name, type: d.type, title, body: d.body || '', treatment: d.treatment || '', outcome: d.outcome || null, callId: d.callId || null, injuries: (d.injuries || []).slice(0, 30), updatedAt: now() };
    let r;
    if (d.id) {
      r = find(d.id);
      if (!r) return fail('not_found');
      Object.assign(r, fields);
    } else {
      nextId += 1;
      r = { id: nextId, author: me, createdAt: now(), ...fields };
      reports.unshift(r);
    }
    push('medreports:changed', { id: r.id, cid: r.cid });
    return full(r, s);
  });
  reg('medreports.delete', (d) => {
    if (!s.boss) return fail('not_allowed');
    const i = reports.findIndex((r) => r.id === Number(d.id));
    if (i < 0) return fail('not_found');
    reports.splice(i, 1);
    push('medreports:changed', { id: Number(d.id), deleted: true });
    return { id: Number(d.id) };
  });
}
