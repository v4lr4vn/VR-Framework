export const now = () => Math.floor(Date.now() / 1000);
const DAY = 86400;

export const jobs = {
  police: [
    { name: 'police', label: 'Law Enforcement', grades: [{ level: 0, name: 'Recruit' }, { level: 1, name: 'Officer' }, { level: 2, name: 'Sergeant' }, { level: 3, name: 'Lieutenant' }, { level: 4, name: 'Chief', isboss: true }] },
  ],
  ems: [
    { name: 'ambulance', label: 'EMS', grades: [{ level: 0, name: 'Recruit' }, { level: 1, name: 'Paramedic' }, { level: 2, name: 'Doctor' }, { level: 3, name: 'Surgeon' }, { level: 4, name: 'Chief', isboss: true }] },
  ],
  doj: [
    { name: 'judge', label: 'Judiciary', grades: [{ level: 0, name: 'Magistrate' }, { level: 1, name: 'Judge' }, { level: 2, name: 'Chief Justice', isboss: true }] },
    { name: 'lawyer', label: 'Defense Attorney', grades: [{ level: 0, name: 'Associate' }, { level: 1, name: 'Attorney' }, { level: 2, name: 'Senior Partner', isboss: true }] },
    { name: 'prosecutor', label: "District Attorney's Office", grades: [{ level: 0, name: 'Assistant DA' }, { level: 1, name: 'Deputy DA' }, { level: 2, name: 'District Attorney', isboss: true }] },
  ],
  dispatch: [
    { name: 'dispatch', label: 'Emergency Dispatch', grades: [{ level: 0, name: 'Trainee Dispatcher' }, { level: 1, name: 'Dispatcher' }, { level: 2, name: 'Senior Dispatcher' }, { level: 3, name: 'Dispatch Supervisor', isboss: true }] },
  ],
};

for (const list of Object.values(jobs)) for (const j of list) for (const g of j.grades) g.isboss = g.isboss === true;

export const divisions = {
  police: ['Patrol', 'Traffic', 'Detectives', 'Gang unit', 'SWAT', 'K9', 'Air support', 'Marine', 'FTO', 'Trainee'],
  ems: ['Paramedic', 'Fire rescue', 'Search and rescue', 'Air ambulance', 'Critical care', 'Trainee'],
  doj: ['Criminal court', 'Civil court', 'Prosecution', 'Public defense', 'Clerk'],
  dispatch: ['Police desk', 'EMS desk', 'Trainee'],
};

export const hireDivisions = { police: ['Trainee'], ems: [], doj: [], dispatch: ['Trainee'] };

export const deptType = { police: 'leo', ems: 'ems', doj: 'doj', dispatch: 'dispatch' };

function m(dept, cid, name, job, grade, callsign, opts = {}) {
  const j = jobs[dept].find((x) => x.name === job);
  const g = j.grades.find((x) => x.level === grade);
  return {
    cid, name, callsign: callsign || null, job, jobLabel: j.label, grade, gradeName: g.name, isboss: g.isboss,
    badge: opts.badge || null, divisions: opts.divisions || [], status: opts.status || 'active',
    online: opts.online ?? !!opts.onduty, onduty: !!opts.onduty, hiredAt: now() - (opts.hiredDays ?? 200) * DAY,
    notes: opts.notes || null, seed: opts.seed ?? cid.length * 7 + grade * 3, idle: opts.idle ?? 0,
  };
}

export const members = {
  police: [
    m('police', 'COP1', 'Rae Hale', 'police', 4, '1-ADAM-12', { badge: '0001', divisions: ['Patrol', 'Air support'], onduty: true, hiredDays: 900, seed: 11 }),
    m('police', 'COP6', 'Victor Dunn', 'police', 3, '1-LINCOLN-7', { badge: '0114', divisions: ['Detectives'], hiredDays: 640, seed: 4, idle: 1 }),
    m('police', 'COP8', 'Owen Marsh', 'police', 3, '1-LINCOLN-3', { badge: '0127', divisions: ['Patrol', 'SWAT'], onduty: true, hiredDays: 580, seed: 9 }),
    m('police', 'COP2', 'Marco Ortega', 'police', 2, '1-LINCOLN-4', { badge: '0233', divisions: ['Patrol', 'SWAT', 'K9'], onduty: true, hiredDays: 420, seed: 8, notes: 'Commendation for the Vinewood pursuit. Recommended for SWAT team lead.' }),
    m('police', 'COP7', 'Nadia Brooks', 'police', 2, '2-SAM-1', { badge: '0241', divisions: ['Traffic', 'FTO'], online: true, hiredDays: 400, seed: 6 }),
    m('police', 'COP11', 'Rosa Diaz', 'police', 1, '2-ADAM-9', { badge: '0318', divisions: ['Patrol', 'FTO'], onduty: true, hiredDays: 260, seed: 7 }),
    m('police', 'COP3', 'Dee Walsh', 'police', 1, '2-DAVID-7', { badge: '0322', divisions: ['Patrol'], onduty: true, hiredDays: 240, seed: 5 }),
    m('police', 'COP4', 'Ivan Kerr', 'police', 1, '1-KING-2', { badge: '0337', divisions: ['Gang unit'], onduty: true, hiredDays: 220, seed: 10 }),
    m('police', 'COP14', 'Ana Silva', 'police', 1, '2-DAVID-3', { badge: '0345', divisions: ['Traffic'], hiredDays: 190, seed: 3, idle: 2 }),
    m('police', 'COP15', 'Ben Hart', 'police', 1, '3-KING-11', { badge: '0352', divisions: ['Detectives'], hiredDays: 150, seed: 2, idle: 4 }),
    m('police', 'COP12', 'Tomas Reyes', 'police', 1, '2-ADAM-15', { badge: '0361', divisions: ['Marine'], status: 'loa', hiredDays: 130, seed: 1, idle: 12, notes: 'Leave of absence until the 28th, family reasons.' }),
    m('police', 'COP13', 'Kit Rowe', 'police', 1, '3-EDWARD-4', { badge: '0370', divisions: ['Patrol'], status: 'suspended', hiredDays: 110, seed: 0, idle: 6, notes: 'Suspended pending IA-0007.' }),
    m('police', 'COP5', 'Sara Lind', 'police', 0, '3-MARY-1', { badge: '0402', divisions: ['Trainee'], onduty: true, hiredDays: 21, seed: 6 }),
    m('police', 'COP9', 'Jon Pike', 'police', 0, '4-TOM-2', { badge: '0405', divisions: ['Trainee'], hiredDays: 14, seed: 4, idle: 1 }),
    m('police', 'COP10', 'Ivy Cole', 'police', 0, '4-TOM-5', { divisions: ['Trainee', 'Traffic'], hiredDays: 9, seed: 3, idle: 2 }),
    m('police', 'COP16', 'Mila Novak', 'police', 0, null, { divisions: ['Trainee'], hiredDays: 1, seed: 0, idle: 99 }),
  ],
  ems: [
    m('ems', 'MED1', 'Tess Moreau', 'ambulance', 4, 'MEDIC 3', { badge: 'M-01', divisions: ['Paramedic', 'Air ambulance'], onduty: true, hiredDays: 700, seed: 9 }),
    m('ems', 'MED3', 'Ruth Okafor', 'ambulance', 3, 'MEDIC 9', { badge: 'M-04', divisions: ['Critical care'], online: true, hiredDays: 520, seed: 6 }),
    m('ems', 'MED2', 'Owen Price', 'ambulance', 2, 'MEDIC 5', { badge: 'M-07', divisions: ['Paramedic'], onduty: true, hiredDays: 380, seed: 8 }),
    m('ems', 'MED6', 'Felix Moore', 'ambulance', 2, 'MEDIC 2', { badge: 'M-09', divisions: ['Fire rescue', 'Search and rescue'], hiredDays: 300, seed: 4, idle: 1 }),
    m('ems', 'MED4', 'Leo Brandt', 'ambulance', 1, 'MEDIC 11', { badge: 'M-12', divisions: ['Paramedic'], onduty: true, hiredDays: 160, seed: 7 }),
    m('ems', 'MED5', 'Hana Sato', 'ambulance', 1, 'MEDIC 14', { badge: 'M-15', divisions: ['Air ambulance'], hiredDays: 120, seed: 5, idle: 3 }),
    m('ems', 'MED8', 'Amir Haddad', 'ambulance', 1, 'MEDIC 7', { badge: 'M-16', divisions: ['Fire rescue'], status: 'loa', hiredDays: 100, seed: 1, idle: 9 }),
    m('ems', 'MED7', 'Grace Lowe', 'ambulance', 0, 'MEDIC 20', { divisions: ['Trainee'], hiredDays: 12, seed: 3, idle: 1 }),
    m('ems', 'MED9', 'Clara Vance', 'ambulance', 0, null, { divisions: ['Trainee'], hiredDays: 3, seed: 1, idle: 2 }),
  ],
  doj: [
    m('doj', 'JUD1', 'Harlan Price', 'judge', 2, null, { divisions: ['Criminal court'], onduty: true, hiredDays: 800, seed: 5 }),
    m('doj', 'JUD2', 'Miriam Cole', 'judge', 1, null, { divisions: ['Civil court'], hiredDays: 410, seed: 4, idle: 1 }),
    m('doj', 'JUD3', 'Paul Ashby', 'judge', 0, null, { divisions: ['Criminal court', 'Clerk'], hiredDays: 90, seed: 2, idle: 3 }),
    m('doj', 'DA1', 'Selena Ward', 'prosecutor', 2, null, { divisions: ['Prosecution'], onduty: true, hiredDays: 500, seed: 7 }),
    m('doj', 'DA2', 'Ken Mori', 'prosecutor', 1, null, { divisions: ['Prosecution'], hiredDays: 210, seed: 3, idle: 2 }),
    m('doj', 'LAW1', 'Iris Bell', 'lawyer', 1, null, { divisions: ['Public defense'], online: true, hiredDays: 180, seed: 6 }),
  ],
  dispatch: [
    m('dispatch', 'DSP1', 'Mara Quinn', 'dispatch', 3, 'DISPATCH 1', { divisions: ['Police desk', 'EMS desk'], onduty: true, hiredDays: 450, seed: 6 }),
    m('dispatch', 'DSP2', 'Theo Grant', 'dispatch', 1, 'DISPATCH 2', { divisions: ['EMS desk'], onduty: true, hiredDays: 120, seed: 4 }),
    m('dispatch', 'DSP3', 'Lena Fox', 'dispatch', 0, null, { divisions: ['Trainee'], online: true, hiredDays: 6, seed: 2 }),
  ],
};

export const meCid = { police: 'COP1', ems: 'MED1', doj: 'JUD1', dispatch: 'DSP1' };

export const civilians = [
  { cid: 'DCR40219', name: 'Dana Cruz', job: 'unemployed', jobLabel: 'Civilian', jobType: 'none' },
  { cid: 'CIV2210', name: 'Joel Ward', job: 'mechanic', jobLabel: 'Mechanic', jobType: 'none', gradeName: 'Apprentice' },
  { cid: 'CIV3317', name: 'Nadia Farouk', job: 'taxi', jobLabel: 'Taxi', jobType: 'none', gradeName: 'Driver' },
  { cid: 'MWB18823', name: 'Marcus Webb', job: 'unemployed', jobLabel: 'Civilian', jobType: 'none' },
  { cid: 'CIV5121', name: 'Elena Duarte', job: 'realestate', jobLabel: 'Real Estate', jobType: 'none', gradeName: 'Agent' },
  { cid: 'CIV6620', name: 'Dmitri Volkov', job: 'unemployed', jobLabel: 'Civilian', jobType: 'none' },
  { cid: 'CIV7012', name: 'Hannah Cross', job: 'reporter', jobLabel: 'Weazel News', jobType: 'none', gradeName: 'Journalist' },
  { cid: 'CIV8834', name: 'Dante Morales', job: 'unemployed', jobLabel: 'Civilian', jobType: 'none' },
];

function rng(seed) {
  let x = seed * 9301 + 49297;
  return () => {
    x = (x * 9301 + 49297) % 233280;
    return x / 233280;
  };
}

export function sessionsFor(member) {
  const r = rng(member.seed + 3);
  const out = [];
  const t = now();
  let id = 1;
  if (member.onduty) {
    const start = t - Math.floor(1800 + r() * 7200);
    out.push({ id: id++, startedAt: start, endedAt: null, seconds: t - start, running: true });
  }
  if (member.idle >= 99) return out;
  let day = member.idle;
  while (out.length < 20 && day < 32) {
    if (r() < 0.62 || day === member.idle) {
      const start = t - day * DAY - Math.floor(r() * 50000 + 7200);
      const len = Math.floor(3600 + r() * 14400);
      out.push({ id: id++, startedAt: start, endedAt: start + len, seconds: len, running: false });
    }
    day += 1;
  }
  return out;
}

export function hoursFor(sessions, days) {
  const since = now() - days * DAY;
  let s = 0;
  for (const x of sessions) {
    const end = x.endedAt || now();
    s += Math.max(0, end - Math.max(x.startedAt, since));
  }
  return Math.round((s / 3600) * 10) / 10;
}

export function findMember(dept, cid) {
  return members[dept].find((x) => x.cid === cid);
}

export function me(s) {
  return findMember(s.dept, meCid[s.dept]);
}

export const audit = { police: [], ems: [], doj: [] };
let auditId = 1000;

export function log(s, action, target, details) {
  const who = me(s);
  audit[s.dept].unshift({ id: ++auditId, at: now(), cid: who.cid, name: who.name, dept: s.dept, action, target, details });
}

export default function () {}
