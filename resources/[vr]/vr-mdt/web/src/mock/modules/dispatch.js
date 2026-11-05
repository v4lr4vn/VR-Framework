import { fail } from '../index.js';
import { push } from '../state.js';

const now = () => Math.floor(Date.now() / 1000);

const units = [
  { cid: 'COP1', name: 'Rae Hale', callsign: '1-ADAM-12', dept: 'police', job: 'police', gradeName: 'Chief', status: 'enroute', since: now() - 50, callId: 1042, radio: 1 },
  { cid: 'COP2', name: 'Marco Ortega', callsign: '1-LINCOLN-4', dept: 'police', job: 'police', gradeName: 'Sergeant', status: 'enroute', since: now() - 45, callId: 1042, radio: 1 },
  { cid: 'COP3', name: 'Dee Walsh', callsign: '2-DAVID-7', dept: 'police', job: 'police', gradeName: 'Officer', status: 'available', since: now() - 600, radio: 2 },
  { cid: 'COP4', name: 'Ivan Kerr', callsign: '1-KING-2', dept: 'police', job: 'police', gradeName: 'Officer', status: 'onscene', since: now() - 240, callId: 1040, radio: 1 },
  { cid: 'COP5', name: 'Sara Lind', callsign: '3-MARY-1', dept: 'police', job: 'police', gradeName: 'Recruit', status: 'available', since: now() - 900, radio: 0 },
  { cid: 'MED1', name: 'Tess Moreau', callsign: 'MEDIC 3', dept: 'ems', job: 'ambulance', gradeName: 'Paramedic', status: 'onscene', since: now() - 200, callId: 1040, radio: 5 },
  { cid: 'MED2', name: 'Owen Price', callsign: 'MEDIC 5', dept: 'ems', job: 'ambulance', gradeName: 'Doctor', status: 'available', since: now() - 1200, radio: 5 },
];

const positions = {
  COP1: { x: 120, y: -1500, h: 0 },
  COP2: { x: 380, y: -1000, h: 0 },
  COP3: { x: -200, y: -900, h: 0 },
  COP4: { x: -560, y: -560, h: 0 },
  COP5: { x: 250, y: -350, h: 0 },
  MED1: { x: -590, y: -530, h: 0 },
  MED2: { x: 300, y: -610, h: 0 },
};

function u(cid, at) {
  const x = units.find((v) => v.cid === cid);
  return { cid, name: x.name, callsign: x.callsign, dept: x.dept, attachedAt: at };
}

const calls = [
  {
    id: 1042, codeName: 'shooting', code: '10-71', title: 'Shots fired', priority: 1, icon: 'crosshair', origin: '911',
    description: 'Multiple shots heard outside the liquor store. Caller saw a dark green sedan leave northbound on Strawberry.',
    coords: { x: 150, y: -1650, z: 29 }, street: 'Davis Ave & Strawberry Ave', jobs: ['leo'], status: 'active', createdAt: now() - 42,
    caller: { anonymous: true }, info: [{ label: 'Weapon', value: 'Pistol' }, { label: 'Vehicle', value: 'Dark green sedan' }],
    units: [u('COP1', now() - 40), u('COP2', now() - 30)],
    notes: [
      { at: now() - 42, text: 'Created from a 911 call', system: true },
      { at: now() - 40, text: '1-ADAM-12 attached', system: true },
      { at: now() - 20, name: 'Marco Ortega', callsign: '1-LINCOLN-4', text: 'Suspect vehicle dark green sedan, plate unknown' },
    ],
  },
  {
    id: 1041, codeName: 'storerobbery', code: '10-90', title: 'Store robbery', priority: 1, icon: 'store', origin: 'auto',
    coords: { x: 25, y: -1345, z: 29 }, street: '24/7, Innocence Blvd', jobs: ['leo'], status: 'active', createdAt: now() - 135,
    info: [{ label: 'Store', value: '24/7 Innocence Blvd' }], units: [], notes: [{ at: now() - 135, text: 'Alarm triggered', system: true }],
  },
  {
    id: 1040, codeName: 'custom', code: '10-50', title: 'Vehicle crash', priority: 2, icon: 'car', origin: 'manual',
    coords: { x: -600, y: -520, z: 30 }, street: 'Del Perro Fwy, eastbound', jobs: ['leo', 'ems'], status: 'active', createdAt: now() - 243,
    description: 'Two vehicles, one driver trapped.', info: [], units: [u('COP4', now() - 230), u('MED1', now() - 200)], notes: [],
  },
  {
    id: 1039, codeName: '911call', code: '911', title: 'Emergency call', priority: 2, icon: 'phone', origin: '911',
    coords: { x: 300, y: 180, z: 30 }, street: 'Vinewood Blvd', jobs: ['leo'], status: 'active', createdAt: now() - 410,
    description: "Someone's smashing the windows of my car, he's still here.", caller: { name: 'Dana Cruz', phone: '555-0142' }, info: [], units: [], notes: [],
  },
  {
    id: 1038, codeName: 'vehicletheft', code: '10-16', title: 'Stolen vehicle', priority: 3, icon: 'car', origin: 'auto',
    coords: { x: 100, y: -880, z: 30 }, street: 'Pillbox Hill', jobs: ['leo'], status: 'active', createdAt: now() - 688,
    info: [{ label: 'Plate', value: '46EEK572' }, { label: 'Model', value: 'Sultan RS' }], units: [], notes: [],
  },
  {
    id: 1031, codeName: 'melee', code: '10-10', title: 'Fight in progress', priority: 2, icon: 'alert', origin: 'auto',
    coords: { x: -1200, y: -1500, z: 4 }, street: 'Vespucci Beach', jobs: ['leo'], status: 'closed', createdAt: now() - 3600, closedAt: now() - 3000, closedBy: '2-DAVID-7',
    info: [], units: [], notes: [{ at: now() - 3000, text: 'Closed by 2-DAVID-7', system: true }],
  },
];

function visible(dept) {
  if (dept === 'dispatch') return calls;
  const type = dept === 'ems' ? 'ems' : 'leo';
  return calls.filter((c) => c.jobs.includes(type));
}

function me(s) {
  if (s.dept === 'dispatch') return null;
  return units.find((x) => x.cid === (s.dept === 'ems' ? 'MED1' : 'COP1'));
}

export default function (reg, regCallback, s) {
  reg('dispatch.list', () => {
    if (s.dept === 'doj') return fail('not_allowed');
    const list = visible(s.dept);
    return { active: list.filter((c) => c.status !== 'closed'), closed: list.filter((c) => c.status === 'closed'), units, me: me(s) };
  });
  reg('dispatch.get', (d) => calls.find((c) => c.id === d.id) || fail('not_found'));
  reg('dispatch.attach', (d) => {
    const c = calls.find((x) => x.id === d.id);
    if (!c) return fail('not_found');
    const m = me(s);
    if (!c.units.some((x) => x.cid === m.cid)) c.units.push(u(m.cid, now()));
    c.notes.push({ at: now(), text: `${m.callsign} attached`, system: true });
    m.status = 'enroute';
    m.callId = c.id;
    push('units:update', m);
    return c;
  });
  reg('dispatch.detach', (d) => {
    const c = calls.find((x) => x.id === d.id);
    const m = me(s);
    c.units = c.units.filter((x) => x.cid !== m.cid);
    c.notes.push({ at: now(), text: `${m.callsign} detached`, system: true });
    m.status = 'available';
    m.callId = null;
    push('units:update', m);
    return c;
  });
  reg('dispatch.note', (d) => {
    const c = calls.find((x) => x.id === d.id);
    if (!String(d.text || '').trim()) return fail('bad_request');
    const m = me(s);
    c.notes.push({ at: now(), name: m.name, callsign: m.callsign, text: String(d.text).trim().slice(0, 250) });
    return c;
  });
  reg('dispatch.priority', (d) => {
    const c = calls.find((x) => x.id === d.id);
    c.priority = d.priority;
    c.notes.push({ at: now(), text: `Priority set to ${d.priority}`, system: true });
    return c;
  });
  reg('dispatch.close', (d) => {
    const c = calls.find((x) => x.id === d.id);
    c.status = 'closed';
    c.closedAt = now();
    c.notes.push({ at: now(), text: 'Closed', system: true });
    return c;
  });
  reg('dispatch.reopen', (d) => {
    const c = calls.find((x) => x.id === d.id);
    c.status = 'active';
    c.closedAt = null;
    return c;
  });
  reg('dispatch.assign', (d) => {
    const c = calls.find((x) => x.id === d.id);
    if (!c.units.some((x) => x.cid === d.cid)) c.units.push(u(d.cid, now()));
    const unit = units.find((x) => x.cid === d.cid);
    const job = unit.dept === 'ems' ? 'ems' : 'leo';
    if (!c.jobs.includes(job)) {
      c.jobs = [...c.jobs, job];
      c.notes.push({ at: now(), text: `${unit.callsign} added, so ${job === 'ems' ? 'EMS' : 'police'} can now see this call`, system: true });
    }
    unit.status = 'enroute';
    unit.callId = c.id;
    push('units:update', unit);
    return c;
  });
  reg('dispatch.unassign', (d) => {
    const c = calls.find((x) => x.id === d.id);
    c.units = c.units.filter((x) => x.cid !== d.cid);
    return c;
  });
  reg('dispatch.create', (d) => {
    if (!String(d.title || '').trim()) return fail('bad_request');
    const c = {
      id: Math.max(...calls.map((x) => x.id)) + 1, codeName: 'custom', code: d.code || '10-00', title: d.title, priority: d.priority || 2,
      description: d.description, coords: d.coords || { x: 0, y: 0, z: 0 }, street: 'Strawberry Ave', jobs: d.jobs?.length ? d.jobs : ['leo'],
      status: 'active', createdAt: now(), origin: 'manual', info: [], units: [], notes: [{ at: now(), text: 'Created by 1-ADAM-12', system: true }],
    };
    calls.unshift(c);
    return c;
  });
  reg('units.list', () => units);
  reg('radio.move', (d) => {
    const u = units.find((x) => x.cid === d.cid);
    if (!u) return fail('unit_unavailable');
    u.radio = d.channel;
    return { cid: d.cid, channel: d.channel };
  });
  reg('units.status', (d) => {
    const m = me(s);
    m.status = d.status;
    m.since = now();
    return m;
  });
  reg('units.setStatus', (d) => {
    const x = units.find((v) => v.cid === d.cid);
    x.status = d.status;
    x.since = now();
    return x;
  });
  regCallback('streets', (d) => {
    const out = {};
    for (const c of d.list || []) out[c.id] = 'Strawberry Ave';
    return out;
  });

  setTimeout(() => push('units:positions', Object.entries(positions).map(([cid, p]) => ({ cid, ...p }))), 300);
  setInterval(() => {
    for (const p of Object.values(positions)) {
      p.x += (Math.random() - 0.5) * 30;
      p.y += (Math.random() - 0.5) * 30;
    }
    push('units:positions', Object.entries(positions).map(([cid, p]) => ({ cid, ...p })));
  }, 3000);
}
