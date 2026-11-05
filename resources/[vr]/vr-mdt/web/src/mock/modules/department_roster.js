import { fail } from '../index.js';
import { push } from '../state.js';
import { now, jobs, divisions, hireDivisions, members, civilians, deptType, sessionsFor, hoursFor, findMember, me, log } from './department_data.js';

const sessionCache = new Map();

function sessions(member) {
  if (!sessionCache.has(member.cid)) sessionCache.set(member.cid, sessionsFor(member));
  return sessionCache.get(member.cid);
}

function lastSeen(member) {
  if (member.onduty) return now();
  const s = sessions(member).find((x) => !x.running);
  return s ? s.endedAt : null;
}

function row(member) {
  const { notes, seed, idle, ...rest } = member;
  return { ...rest, hours7: hoursFor(sessions(member), 7), lastSeen: lastSeen(member) };
}

function outranks(s, target) {
  const self = me(s);
  if (self.isboss) return true;
  return target.grade < self.grade;
}

function detail(s, member) {
  const self = me(s);
  const manage = s.boss;
  const isSelf = member.cid === self.cid;
  const list = sessions(member);
  return {
    ...row(member),
    hours30: hoursFor(list, 30),
    sessions: list,
    notes: manage ? member.notes : null,
    can: {
      identity: manage && (isSelf || outranks(s, member)),
      edit: manage && (isSelf ? self.isboss : outranks(s, member)),
      rank: manage && !isSelf && outranks(s, member),
      fire: manage && !isSelf && outranks(s, member),
    },
  };
}

function changed(cid) {
  push('roster:changed', { cid });
}

function sortMembers(list) {
  return list.sort((a, b) => b.grade - a.grade || a.name.localeCompare(b.name));
}

function gradeOf(dept, job, level) {
  return jobs[dept].find((j) => j.name === job)?.grades.find((g) => g.level === level);
}

export default function (reg, regCallback, s) {
  reg('roster.list', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    const list = members[s.dept].filter((x) => !q || `${x.name} ${x.callsign || ''} ${x.badge || ''} ${x.cid}`.toLowerCase().includes(q));
    return sortMembers(list.map(row));
  });

  reg('roster.meta', () => ({
    divisions: divisions[s.dept],
    statuses: ['active', 'loa', 'suspended'],
    jobs: jobs[s.dept],
    maxDivisions: 8,
    hireDivisions: hireDivisions[s.dept],
    traineeDivision: s.dept === 'police' ? 'Trainee' : undefined,
  }));

  reg('roster.get', (d) => {
    const x = findMember(s.dept, d.cid);
    return x ? detail(s, x) : fail('not_found');
  });

  function write(d, perm, fn) {
    if (!s.boss) return fail('not_allowed');
    const x = findMember(s.dept, d.cid);
    if (!x) return fail('not_found');
    const out = fn(x);
    if (out && out.__error) return out;
    changed(x.cid);
    return detail(s, x);
  }

  reg('roster.setCallsign', (d) => write(d, 'roster.manage', (x) => {
    const v = String(d.callsign || '').trim().toUpperCase();
    if (v && !/^[A-Z0-9 -]{2,16}$/.test(v)) return fail('bad_request');
    if (v && members[s.dept].some((o) => o.cid !== x.cid && (o.callsign || '').toUpperCase() === v)) return fail('callsign_taken');
    log(s, 'roster.callsign', x.cid, { name: x.name, from: x.callsign, to: v || null });
    x.callsign = v || null;
  }));

  reg('roster.badge', (d) => write(d, 'roster.manage', (x) => {
    const v = String(d.badge || '').trim().toUpperCase();
    if (v && !/^[A-Z0-9-]{1,12}$/.test(v)) return fail('bad_request');
    if (v && members[s.dept].some((o) => o.cid !== x.cid && o.badge === v)) return fail('badge_taken');
    log(s, 'roster.badge', x.cid, { name: x.name, from: x.badge, to: v || null });
    x.badge = v || null;
  }));

  reg('roster.setGrade', (d) => write(d, 'roster.manage', (x) => {
    const g = gradeOf(s.dept, x.job, Number(d.grade));
    if (!g) return fail('bad_request');
    if (x.cid === me(s).cid) return fail('cant_self');
    log(s, 'roster.grade', x.cid, { name: x.name, job: x.job, from: x.grade, to: g.level, rank: g.name });
    x.grade = g.level;
    x.gradeName = g.name;
    x.isboss = g.isboss;
  }));

  reg('roster.divisions', (d) => write(d, 'roster.manage', (x) => {
    const list = (d.divisions || []).filter((v) => divisions[s.dept].includes(v));
    if (list.length !== (d.divisions || []).length) return fail('bad_request');
    const ordered = divisions[s.dept].filter((v) => list.includes(v));
    log(s, 'roster.divisions', x.cid, { name: x.name, from: x.divisions, to: ordered });
    x.divisions = ordered;
  }));

  reg('roster.notes', (d) => write(d, 'roster.manage', (x) => {
    x.notes = String(d.notes || '').trim() || null;
    log(s, 'roster.notes', x.cid, { name: x.name, length: (x.notes || '').length });
  }));

  reg('roster.status', (d) => write(d, 'roster.manage', (x) => {
    if (!['active', 'loa', 'suspended'].includes(d.status)) return fail('bad_request');
    log(s, 'roster.status', x.cid, { name: x.name, from: x.status, to: d.status });
    x.status = d.status;
  }));

  reg('roster.fire', (d) => {
    if (!s.boss) return fail('not_allowed');
    const x = findMember(s.dept, d.cid);
    if (!x) return fail('not_found');
    if (x.cid === me(s).cid) return fail('cant_self');
    if (String(d.reason || '').trim().length < 3) return fail('bad_request');
    members[s.dept] = members[s.dept].filter((o) => o.cid !== x.cid);
    civilians.push({ cid: x.cid, name: x.name, job: 'unemployed', jobLabel: 'Civilian', jobType: 'none' });
    log(s, 'roster.fire', x.cid, { name: x.name, job: x.job, rank: x.gradeName, reason: d.reason });
    changed(x.cid);
    return { cid: x.cid };
  });

  reg('roster.hire', (d) => {
    if (!s.boss) return fail('not_allowed');
    const g = gradeOf(s.dept, d.job, Number(d.grade));
    if (!g) return fail('bad_request');
    const c = civilians.find((x) => x.cid === d.cid);
    if (!c) return findMember(s.dept, d.cid) ? fail('already_member') : fail('not_found');
    civilians.splice(civilians.indexOf(c), 1);
    const j = jobs[s.dept].find((x) => x.name === d.job);
    const x = { cid: c.cid, name: c.name, callsign: null, job: j.name, jobLabel: j.label, grade: g.level, gradeName: g.name, isboss: g.isboss, badge: null, divisions: [...hireDivisions[s.dept]], status: 'active', online: false, onduty: false, hiredAt: now(), notes: null, seed: 1, idle: 99 };
    members[s.dept].push(x);
    log(s, 'roster.hire', x.cid, { name: x.name, job: x.job, grade: g.level, rank: g.name, from: c.job });
    changed(x.cid);
    return detail(s, x);
  });

  reg('people.search', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    if (q.length < 2) return [];
    const staff = Object.entries(members).flatMap(([dept, list]) => list.map((x) => ({ cid: x.cid, name: x.name, job: x.job, jobLabel: x.jobLabel, jobType: deptType[dept], gradeName: x.gradeName })));
    return [...civilians, ...staff].filter((p) => `${p.name} ${p.cid}`.toLowerCase().includes(q)).sort((a, b) => a.name.localeCompare(b.name)).slice(0, 20);
  });

  reg('people.staff', (d) => {
    const dept = d.dept || s.dept;
    const q = String(d.q || '').trim().toLowerCase();
    return sortMembers((members[dept] || []).filter((x) => !q || `${x.name} ${x.callsign || ''}`.toLowerCase().includes(q)).map((x) => ({ cid: x.cid, name: x.name, callsign: x.callsign, job: x.job, jobLabel: x.jobLabel, grade: x.grade, gradeName: x.gradeName, online: x.online, onduty: x.onduty })));
  });

  setTimeout(() => {
    const x = (members[s.dept] || []).find((v) => !v.onduty && v.status === 'active' && v.online);
    if (x) {
      x.onduty = true;
      push('roster:duty', { cid: x.cid, onduty: true });
    }
  }, 4000);
}
