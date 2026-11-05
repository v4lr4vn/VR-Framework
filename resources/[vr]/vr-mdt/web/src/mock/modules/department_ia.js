import { fail } from '../index.js';
import { push } from '../state.js';
import { now, members, me, log } from './department_data.js';

const H = 3600;
const D = 86400;
const labels = { open: 'Open', investigating: 'Investigating', sustained: 'Sustained', not_sustained: 'Not sustained', exonerated: 'Exonerated', unfounded: 'Unfounded', closed: 'Closed' };

let noteId = 1;
let fileId = 20;

function n(at, author, text, system = false) {
  return { id: noteId++, authorCid: null, authorName: author, at, text, system };
}

function seed() {
  const t = now();
  const f = (id, subjectCid, subjectName, complainant, summary, status, assigned, created, updated, timeline, extra = {}) => ({
    id, subjectCid, subjectName, complainant, summary, status, assignedCid: assigned?.[0] || null, assignedName: assigned?.[1] || null,
    findings: extra.findings || null, createdByCid: 'COP6', createdByName: extra.by || 'Victor Dunn', createdAt: t - created, updatedAt: t - updated,
    closedAt: extra.closed ? t - extra.closed : null, timeline,
  });
  return [
    f(14, 'COP13', 'Kit Rowe', 'Dana Cruz, citizen', 'Complainant says Officer Rowe pushed her against the patrol car during a traffic stop on Grove St and refused to give his badge number. Happened around 22:40. Her passenger recorded part of it on a phone.', 'investigating', ['COP6', 'Victor Dunn'], 2 * D, 3 * H, [
      n(t - 2 * D, 'Victor Dunn', 'File opened', true),
      n(t - 2 * D + 600, 'Victor Dunn', 'Assigned to 1-LINCOLN-7 Victor Dunn', true),
      n(t - 2 * D + 4000, 'Victor Dunn', 'Requested bodycam footage for 3-EDWARD-4 from 22:30 to 23:00.'),
      n(t - D, 'Victor Dunn', 'Interviewed the complainant at Mission Row. Consistent with her written statement. Passenger video received, 41 seconds, shows the push.'),
      n(t - 3 * H, 'Rae Hale', 'Officer Rowe suspended pending the outcome. Interview set for Thursday with union rep present.'),
    ]),
    f(15, 'COP4', 'Ivan Kerr', 'Anonymous', 'Anonymous tip that a gang unit officer is passing BOLO information to the Ballas. No names given beyond "the K9 guy on nights".', 'open', null, 9 * H, 9 * H, [
      n(t - 9 * H, 'Rae Hale', 'File opened', true),
    ], { by: 'Rae Hale' }),
    f(12, 'COP14', 'Ana Silva', 'Sgt. Nadia Brooks', 'Unauthorised pursuit through the Vinewood festival area against standing orders. Two civilian vehicles damaged.', 'investigating', ['COP8', 'Owen Marsh'], 6 * D, D, [
      n(t - 6 * D, 'Nadia Brooks', 'File opened', true),
      n(t - 6 * D + 300, 'Rae Hale', 'Assigned to 1-LINCOLN-3 Owen Marsh', true),
      n(t - 4 * D, 'Owen Marsh', 'Dashcam and radio log pulled. Pursuit lasted 6 minutes, no supervisor authorisation on the radio.'),
      n(t - D, 'Owen Marsh', 'Waiting on the damage report from the city.'),
    ]),
    f(9, 'COP3', 'Dee Walsh', 'Marcus Webb, citizen', 'Says his car was searched without consent or cause during a stop on Strawberry Ave.', 'exonerated', ['COP6', 'Victor Dunn'], 21 * D, 15 * D, [
      n(t - 21 * D, 'Victor Dunn', 'File opened', true),
      n(t - 20 * D, 'Victor Dunn', 'Bodycam shows the driver consenting to the search on camera.'),
      n(t - 15 * D, 'Victor Dunn', 'Closed as Exonerated', true),
    ], { findings: 'Bodycam footage shows clear verbal consent at 14:02:31. Search was lawful and within policy. Complainant informed by phone.', closed: 15 * D }),
    f(7, 'COP12', 'Tomas Reyes', 'Lt. Victor Dunn', 'Three missed shifts without notice in one week.', 'sustained', ['COP8', 'Owen Marsh'], 30 * D, 25 * D, [
      n(t - 30 * D, 'Victor Dunn', 'File opened', true),
      n(t - 27 * D, 'Owen Marsh', 'Officer admits the missed shifts. Family reasons, did not tell a supervisor.'),
      n(t - 25 * D, 'Owen Marsh', 'Closed as Sustained', true),
    ], { findings: 'Policy 2.4 broken. Written warning. Officer placed on approved leave of absence for family reasons from the 28th.', closed: 25 * D }),
    f(5, 'COP8', 'Owen Marsh', 'Ben Hart', 'Allegation of falsified overtime on the festival detail.', 'investigating', ['COP1', 'Rae Hale'], 3 * D, 2 * D, [n(t - 3 * D, 'Rae Hale', 'File opened', true)]),
  ];
}

export default function (reg, regCallback, s) {
  const files = seed();

  function visible() {
    const self = me(s);
    return files.filter((f) => f.subjectCid !== self.cid);
  }

  function shape(f) {
    const m = members.police.find((x) => x.cid === f.subjectCid);
    return {
      ...f,
      notes: f.timeline.length,
      subject: m ? { cid: m.cid, name: m.name, callsign: m.callsign, gradeName: m.gradeName, online: m.online, member: true } : { cid: f.subjectCid, name: f.subjectName, member: false },
    };
  }

  function find(id) {
    return visible().find((f) => f.id === Number(id));
  }

  function touch(f, text, system) {
    f.timeline.push(n(now(), me(s).name, text, system));
    f.updatedAt = now();
    push('ia:changed', { id: f.id });
  }

  reg('ia.list', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const q = String(d.q || '').trim().toLowerCase().replace(/^#/, '');
    const active = (f) => f.status === 'open' || f.status === 'investigating';
    let list = visible();
    const counts = { active: list.filter(active).length, resolved: list.filter((f) => !active(f)).length };
    if (d.status === 'active') list = list.filter(active);
    else if (d.status === 'resolved') list = list.filter((f) => !active(f));
    if (q) list = list.filter((f) => `${f.subjectName} ${f.complainant} ${f.assignedName || ''}`.toLowerCase().includes(q) || String(f.id) === q.replace(/^ia-0*/, ''));
    list = list.sort((a, b) => Number(active(b)) - Number(active(a)) || b.updatedAt - a.updatedAt);
    return { items: list.map((f) => ({ ...f, notes: f.timeline.filter((x) => !x.system).length, timeline: undefined, findings: undefined })), page: 1, more: false, counts };
  });

  reg('ia.get', (d) => {
    const f = find(d.id);
    return f ? shape(f) : fail('not_found');
  });

  reg('ia.investigators', () => members.police.filter((m) => m.grade >= 3).map((m) => ({ cid: m.cid, name: m.name, callsign: m.callsign, gradeName: m.gradeName })));

  reg('ia.save', (d) => {
    if (!s.boss) return fail('not_allowed');
    const summary = String(d.summary || '').trim();
    if (summary.length < 3) return fail('bad_request');
    if (d.id) {
      const f = find(d.id);
      if (!f) return fail('not_found');
      const before = f.status;
      Object.assign(f, { summary, complainant: String(d.complainant || '').trim() || null });
      if (d.status && d.status !== before) {
        f.status = d.status;
        f.closedAt = null;
        touch(f, `Reopened as ${labels[d.status]}`, true);
      } else touch(f, 'Details edited', true);
      log(s, 'ia.edit', f.id, { subject: f.subjectName, status: f.status, from: before });
      return shape(f);
    }
    const m = members.police.find((x) => x.cid === d.subjectCid);
    if (!m) return fail('not_found');
    if (m.cid === me(s).cid) return fail('cant_self');
    const t = now();
    const f = { id: ++fileId, subjectCid: m.cid, subjectName: m.name, complainant: String(d.complainant || '').trim() || null, summary, status: 'open', assignedCid: null, assignedName: null, findings: null, createdByCid: me(s).cid, createdByName: me(s).name, createdAt: t, updatedAt: t, closedAt: null, timeline: [n(t, me(s).name, 'File opened', true)] };
    files.push(f);
    log(s, 'ia.create', f.id, { subject: m.name, subjectCid: m.cid });
    push('ia:changed', { id: f.id });
    return shape(f);
  });

  reg('ia.note', (d) => {
    if (!s.boss) return fail('not_allowed');
    const f = find(d.id);
    if (!f) return fail('not_found');
    const text = String(d.text || '').trim();
    if (!text) return fail('bad_request');
    touch(f, text, false);
    log(s, 'ia.note', f.id, { subject: f.subjectName, length: text.length });
    return shape(f);
  });

  reg('ia.assign', (d) => {
    if (!s.boss) return fail('not_allowed');
    const f = find(d.id);
    if (!f) return fail('not_found');
    const m = d.cid ? members.police.find((x) => x.cid === d.cid) : null;
    if (d.cid && (!m || m.cid === f.subjectCid)) return fail('cant_assign');
    f.assignedCid = m?.cid || null;
    f.assignedName = m?.name || null;
    if (m && f.status === 'open') f.status = 'investigating';
    touch(f, m ? `Assigned to ${m.callsign ? `${m.callsign} ` : ''}${m.name}` : 'Unassigned', true);
    log(s, 'ia.assign', f.id, { subject: f.subjectName, to: m?.name || null });
    return shape(f);
  });

  reg('ia.close', (d) => {
    if (!s.boss) return fail('not_allowed');
    const f = find(d.id);
    if (!f) return fail('not_found');
    if (!labels[d.outcome] || ['open', 'investigating'].includes(d.outcome) || String(d.findings || '').trim().length < 3) return fail('bad_request');
    const before = f.status;
    Object.assign(f, { status: d.outcome, findings: String(d.findings).trim(), closedAt: now() });
    touch(f, `Closed as ${labels[d.outcome]}`, true);
    log(s, 'ia.close', f.id, { subject: f.subjectName, outcome: d.outcome, from: before });
    return shape(f);
  });
}
