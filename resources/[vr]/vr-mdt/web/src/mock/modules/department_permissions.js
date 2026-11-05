import { fail } from '../index.js';
import { now, jobs, me, audit, log } from './department_data.js';

const list = [
  ['dispatch.manage', 'all', 'Dispatch', 'Run dispatch: assign units, change priority, close calls', 2],
  ['bulletin.post', 'all', 'Department', 'Post and pin bulletins', 2],
  ['roster.view', 'all', 'Department', 'See the roster', 0],
  ['roster.manage', 'all', 'Department', 'Hire, fire, promote, set callsigns and divisions', 3],
  ['permissions.manage', 'all', 'Department', 'Change what each rank can do', null],
  ['records.view', 'police', 'Records', 'Look up citizens, vehicles and weapons', 0],
  ['records.edit', 'police', 'Records', 'Edit notes and flags on records', 0],
  ['licences.edit', 'police', 'Records', 'Grant and revoke licences', 2],
  ['mugshots.take', 'police', 'Records', 'Take mugshots', 0],
  ['warrants.create', 'police', 'Warrants', 'Request warrants', 0],
  ['bolos.manage', 'police', 'Warrants', 'Create and close BOLOs', 0],
  ['reports.create', 'police', 'Reports', 'Write reports', 0],
  ['reports.edit_any', 'police', 'Reports', "Edit other officers' reports", 2],
  ['reports.delete', 'police', 'Reports', 'Delete reports', 3],
  ['sentencing.apply', 'police', 'Reports', 'Apply fines and jail time', 0],
  ['cases.view', 'police', 'Cases', 'See cases and evidence', 0],
  ['cases.manage', 'police', 'Cases', 'Open, edit and close cases', 1],
  ['evidence.manage', 'police', 'Cases', 'Add and remove evidence', 0],
  ['penal.manage', 'police', 'Penal code', 'Edit charges, fines and jail times', 3],
  ['prison.manage', 'police', 'Prison', 'Release inmates and change sentences', 2],
  ['ia.view', 'police', 'Internal Affairs', 'See Internal Affairs files', 3],
  ['ia.manage', 'police', 'Internal Affairs', 'Open and work Internal Affairs files', 3],
  ['fto.view', 'police', 'Training', 'See trainee evaluations', 1],
  ['fto.manage', 'police', 'Training', 'Write evaluations and sign off trainees', 1],
  ['cameras.view', 'police', 'Cameras', 'Watch security cameras', 0],
  ['cameras.manage', 'police', 'Cameras', 'Add and remove security cameras', 3],
  ['bodycams.view', 'police', 'Cameras', "Watch officers' bodycams", 2],
  ['patients.view', 'ems', 'Patients', 'See patient records', 0],
  ['patients.edit', 'ems', 'Patients', 'Edit patient records', 0],
  ['medreports.create', 'ems', 'Patients', 'Write medical reports', 0],
  ['medreports.edit_any', 'ems', 'Patients', "Edit other medics' reports", 2],
  ['court.view', 'doj', 'Court', 'See court cases', 0],
  ['court.manage', 'doj', 'Court', 'File, schedule and rule on court cases', 1],
  ['warrants.approve', 'doj', 'Court', 'Approve and deny warrants', 1],
  ['records.view', 'doj', 'Records', 'Look up citizens, vehicles and weapons', 0],
  ['reports.view', 'doj', 'Records', 'Read police reports', 0],
  ['cases.view', 'doj', 'Records', 'See cases and evidence', 0],
].map(([key, dept, group, label, grade]) => ({ key, dept, group, label, grade }));

const overrides = {
  'police:2:prison.manage': false,
  'police:2:cameras.manage': true,
  'police:1:bolos.manage': false,
  'police:3:permissions.manage': true,
  'ambulance:1:medreports.edit_any': true,
  'judge:0:warrants.approve': true,
};

function keys(dept) {
  return list.filter((p) => p.dept === 'all' || p.dept === dept);
}

function matrix(s, jobName) {
  const job = jobs[s.dept].find((j) => j.name === jobName) || jobs[s.dept][0];
  const self = me(s);
  const grades = job.grades.map((g) => ({ level: g.level, name: g.name, isboss: g.isboss, mine: self.job === job.name && self.grade === g.level, changes: 0 }));
  const groups = [];
  for (const p of keys(s.dept)) {
    const cells = job.grades.map((g, i) => {
      const def = g.isboss || (p.grade !== null && g.level >= p.grade);
      const o = overrides[`${job.name}:${g.level}:${p.key}`];
      const overridden = !g.isboss && o !== undefined && o !== def;
      if (overridden) grades[i].changes += 1;
      return { allowed: g.isboss ? true : o !== undefined ? o : def, default: def, overridden, locked: g.isboss };
    });
    let group = groups.find((x) => x.name === p.group);
    if (!group) groups.push((group = { name: p.group, perms: [] }));
    group.perms.push({ key: p.key, label: p.label, cells });
  }
  return { jobs: jobs[s.dept].map((j) => ({ name: j.name, label: j.label })), job: job.name, jobLabel: job.label, grades, groups };
}

function seedAudit() {
  const t = now();
  const rows = {
    police: [
      [300, 'Owen Marsh', 'roster.callsign', 'COP11', { name: 'Rosa Diaz', from: '2-ADAM-19', to: '2-ADAM-9' }],
      [1800, 'Rae Hale', 'permissions.set', 'police:2', { perm: 'cameras.manage', allowed: true, rank: 'Sergeant' }],
      [2400, 'Nadia Brooks', 'bulletin.create', '41', { title: 'Range day Friday', pinned: false }],
      [3600, 'Rosa Diaz', 'fto.evaluate', 'COP5', { name: 'Sara Lind', phase: 2, score: 3.83, recommendation: 'continue' }],
      [5400, 'Rae Hale', 'roster.hire', 'COP16', { name: 'Mila Novak', job: 'police', grade: 0, rank: 'Recruit', from: 'unemployed' }],
      [7200, 'Owen Marsh', 'roster.divisions', 'COP2', { name: 'Marco Ortega', from: ['Patrol', 'K9'], to: ['Patrol', 'SWAT', 'K9'] }],
      [9000, 'Victor Dunn', 'ia.assign', '12', { subject: 'Kit Rowe', to: 'Victor Dunn' }],
      [10800, 'Rae Hale', 'roster.status', 'COP13', { name: 'Kit Rowe', from: 'active', to: 'suspended' }],
      [14400, 'Rae Hale', 'roster.grade', 'COP2', { name: 'Marco Ortega', job: 'police', from: 1, to: 2, rank: 'Sergeant' }],
      [18000, 'Owen Marsh', 'roster.fire', 'CIV9921', { name: 'Glen Hayes', job: 'police', grade: 0, rank: 'Recruit', reason: 'Failed probation, three missed shifts' }],
      [21600, 'Rae Hale', 'permissions.set', 'police:1', { perm: 'bolos.manage', allowed: false, rank: 'Officer' }],
      [36000, 'Nadia Brooks', 'bulletin.delete', '38', { title: 'Vehicle 14 out of service', author: 'Nadia Brooks' }],
      [43200, 'Rosa Diaz', 'fto.signoff', 'COP3', { name: 'Dee Walsh', from: ['Trainee'], to: ['Patrol'] }],
      [86400, 'Rae Hale', 'roster.status', 'COP12', { name: 'Tomas Reyes', from: 'active', to: 'loa' }],
      [90000, 'Victor Dunn', 'ia.create', '12', { subject: 'Kit Rowe', subjectCid: 'COP13' }],
      [100000, 'Owen Marsh', 'roster.badge', 'COP5', { name: 'Sara Lind', from: null, to: '0402' }],
      [130000, 'Rae Hale', 'permissions.set', 'police:3', { perm: 'permissions.manage', allowed: true, rank: 'Lieutenant' }],
      [170000, 'Marco Ortega', 'dispatch.close', '1031', null],
    ],
    ems: [
      [900, 'Tess Moreau', 'roster.divisions', 'MED6', { name: 'Felix Moore', from: ['Fire rescue'], to: ['Fire rescue', 'Search and rescue'] }],
      [7200, 'Tess Moreau', 'permissions.set', 'ambulance:1', { perm: 'medreports.edit_any', allowed: true, rank: 'Paramedic' }],
      [30000, 'Ruth Okafor', 'roster.hire', 'MED9', { name: 'Clara Vance', job: 'ambulance', grade: 0, rank: 'Recruit', from: 'unemployed' }],
      [90000, 'Tess Moreau', 'roster.status', 'MED8', { name: 'Amir Haddad', from: 'active', to: 'loa' }],
    ],
    doj: [
      [5000, 'Harlan Price', 'permissions.set', 'judge:0', { perm: 'warrants.approve', allowed: true, rank: 'Magistrate' }],
      [60000, 'Harlan Price', 'bulletin.create', '7', { title: 'Court closed Monday', pinned: true }],
    ],
  };
  let id = 900;
  for (const [dept, entries] of Object.entries(rows)) {
    for (const [ago, name, action, target, details] of entries) {
      audit[dept].push({ id: id--, at: t - ago, cid: null, name, dept, action, target, details });
    }
  }
}

export default function (reg, regCallback, s) {
  seedAudit();

  reg('permissions.get', (d) => {
    if (!s.boss) return fail('not_allowed');
    if (d.job && !jobs[s.dept].some((j) => j.name === d.job)) return fail('bad_request');
    return matrix(s, d.job || me(s).job);
  });

  reg('permissions.set', (d) => {
    if (!s.boss) return fail('not_allowed');
    const job = jobs[s.dept].find((j) => j.name === d.job);
    const g = job?.grades.find((x) => x.level === d.grade);
    if (!g || typeof d.allowed !== 'boolean') return fail('bad_request');
    if (g.isboss) return fail('locked');
    overrides[`${job.name}:${g.level}:${d.perm}`] = d.allowed;
    log(s, 'permissions.set', `${job.name}:${g.level}`, { perm: d.perm, allowed: d.allowed, rank: g.name });
    return matrix(s, job.name);
  });

  reg('permissions.reset', (d) => {
    if (!s.boss) return fail('not_allowed');
    const job = jobs[s.dept].find((j) => j.name === d.job);
    const g = job?.grades.find((x) => x.level === d.grade);
    if (!g) return fail('bad_request');
    if (g.isboss) return fail('locked');
    for (const k of Object.keys(overrides)) if (k.startsWith(`${job.name}:${g.level}:`)) delete overrides[k];
    log(s, 'permissions.reset', `${job.name}:${g.level}`, { rank: g.name });
    return matrix(s, job.name);
  });

  reg('audit.list', (d) => {
    if (!s.boss) return fail('not_allowed');
    const q = String(d.q || '').trim().toLowerCase();
    const page = Math.max(1, Number(d.page) || 1);
    const rows = audit[s.dept].filter((r) => !q || `${r.name} ${r.action} ${r.target}`.toLowerCase().includes(q));
    return rows.slice((page - 1) * 50, page * 50);
  });

}
