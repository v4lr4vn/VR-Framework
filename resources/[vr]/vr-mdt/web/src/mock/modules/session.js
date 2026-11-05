import { fail } from '../index.js';

const perms = {
  police: ['dispatch.manage', 'bulletin.post', 'roster.view', 'roster.manage', 'permissions.manage', 'records.view', 'records.edit', 'licences.edit', 'mugshots.take', 'warrants.create', 'bolos.manage', 'reports.create', 'reports.edit_any', 'reports.delete', 'sentencing.apply', 'cases.view', 'cases.manage', 'evidence.manage', 'penal.manage', 'prison.manage', 'ia.view', 'ia.manage', 'fto.view', 'fto.manage', 'cameras.view', 'cameras.manage', 'bodycams.view'],
  ems: ['dispatch.manage', 'bulletin.post', 'roster.view', 'roster.manage', 'permissions.manage', 'patients.view', 'patients.edit', 'medreports.create', 'medreports.edit_any'],
  doj: ['bulletin.post', 'roster.view', 'roster.manage', 'permissions.manage', 'court.view', 'court.manage', 'warrants.approve', 'records.view', 'reports.view', 'cases.view'],
  dispatch: ['dispatch.manage', 'radio.multi', 'bulletin.post', 'roster.view', 'roster.manage', 'permissions.manage', 'records.view', 'bolos.manage', 'reports.view', 'cases.view'],
};

const depts = {
  police: { id: 'police', label: 'Los Santos Police Department', short: 'LSPD', type: 'leo', color: '#5AA9FF' },
  ems: { id: 'ems', label: 'Los Santos Medical Services', short: 'LSMS', type: 'ems', color: '#FF6F91' },
  doj: { id: 'doj', label: 'San Andreas Department of Justice', short: 'DOJ', type: 'doj', color: '#B79CFF' },
  dispatch: { id: 'dispatch', label: 'San Andreas Emergency Dispatch', short: 'DISPATCH', type: 'dispatch', color: '#3DD68C' },
};

const people = {
  police: { cid: 'COP1', name: 'Rae Hale', callsign: '1-ADAM-12', job: 'police', jobLabel: 'Law Enforcement', grade: 4, gradeName: 'Chief', isboss: true },
  ems: { cid: 'MED1', name: 'Tess Moreau', callsign: 'MEDIC 3', job: 'ambulance', jobLabel: 'EMS', grade: 4, gradeName: 'Chief', isboss: true },
  doj: { cid: 'JUD1', name: 'Harlan Price', callsign: null, job: 'judge', jobLabel: 'Judiciary', grade: 2, gradeName: 'Chief Justice', isboss: true },
  dispatch: { cid: 'DSP1', name: 'Mara Quinn', callsign: 'DISPATCH 1', job: 'dispatch', jobLabel: 'Emergency Dispatch', grade: 3, gradeName: 'Dispatch Supervisor', isboss: true, console: true },
};

export default function (reg, regCallback, s) {
  reg('session.get', () => (new URLSearchParams(window.location.search).get('sessionerr') ? fail(new URLSearchParams(window.location.search).get('sessionerr')) : {
    me: people[s.dept],
    dept: depts[s.dept],
    perms: s.boss ? perms[s.dept] : perms[s.dept].filter((p) => !p.includes('manage') && p !== 'reports.delete'),
    statuses: [
      { id: 'available', label: 'Available', code: '10-8', color: 'ok' },
      { id: 'enroute', label: 'En route', code: '10-76', color: 'accent' },
      { id: 'onscene', label: 'On scene', code: '10-97', color: 'info' },
      { id: 'busy', label: 'Busy', code: '10-6', color: 'muted' },
      { id: 'transport', label: 'Transporting', code: '10-15', color: 'info' },
      { id: 'break', label: 'On break', code: '10-7', color: 'muted' },
    ],
    map: { size: 8192, originX: 3753.6, originY: 5529.6, scaleX: 0.66304, scaleY: -0.656 },
    flags: ['Armed and dangerous', 'Gang affiliated', 'Known to flee', 'Mental health concern', 'Violent towards officers', 'Parolee'],
    licences: { driver: 'Driver licence', weapon: 'Weapon licence', business: 'Business licence', pilot: 'Pilot licence', hunting: 'Hunting licence', fishing: 'Fishing licence' },
    serverTime: s.now(),
  }));
  regCallback('close', () => ({ ok: true }));
  regCallback('waypoint', () => ({ ok: true }));
  regCallback('getWaypoint', () => ({ x: 300, y: -600, z: 30 }));
  const radio = { listen: [1, 5], transmit: 1 };
  const channels = [
    { id: 1, label: 'LSPD Main', dept: 'police' }, { id: 2, label: 'LSPD Tac 1', dept: 'police' }, { id: 3, label: 'LSPD Tac 2', dept: 'police' },
    { id: 5, label: 'EMS Main', dept: 'ems' }, { id: 6, label: 'EMS Tac', dept: 'ems' }, { id: 9, label: 'Interop', dept: 'all' },
  ];
  const unitRadio = { transmit: s.dept === 'ems' ? 5 : 1 };
  const members = {
    1: [{ src: 4, name: '1-ADAM-12', dept: 'police' }, { src: 5, name: '1-KING-2', dept: 'police' }, { src: 6, name: '1-LINCOLN-4', dept: 'police' }, { src: 9, name: 'DISPATCH 1', dept: 'dispatch' }],
    2: [{ src: 8, name: '2-DAVID-7', dept: 'police' }],
    5: [{ src: 7, name: 'MEDIC 3', dept: 'ems' }, { src: 10, name: 'MEDIC 5', dept: 'ems' }, { src: 9, name: 'DISPATCH 1', dept: 'dispatch' }],
  };
  reg('radio.state', () => {
    if (s.dept === 'dispatch') return { mode: 'console', voice: true, channels, listen: radio.listen, transmit: radio.transmit, defaults: { listen: [1, 5], transmit: 1 }, members: [] };
    if (s.dept !== 'police' && s.dept !== 'ems') return fail('not_allowed');
    const mine = channels.filter((c) => c.dept === s.dept || c.dept === 'all');
    return { mode: 'unit', voice: true, channels: mine, transmit: unitRadio.transmit, listen: [], members: members[unitRadio.transmit] || [] };
  });
  reg('radio.who', (d) => { const names = { 4: '1-ADAM-12', 7: 'MEDIC 3' }; const out = {}; for (const id of d.ids || []) if (names[id]) out[String(id)] = names[id]; return out; });
  reg('radio.listen', (d) => { radio.listen = (d.channels || []).filter((x) => channels.some((c) => c.id === x)); return { listen: radio.listen }; });
  regCallback('radio', (d) => {
    if (d.op === 'transmit') { radio.transmit = d.id; return { ok: true, transmit: d.id }; }
    if (d.op === 'join') { unitRadio.transmit = d.id; return { ok: true, transmit: d.id }; }
    if (d.op === 'leave') { unitRadio.transmit = 0; return { ok: true, transmit: 0 }; }
    return { ok: true };
  });
}
