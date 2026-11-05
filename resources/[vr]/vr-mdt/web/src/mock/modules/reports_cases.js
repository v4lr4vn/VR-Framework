import { fail } from '../index.js';
import { push } from '../state.js';
import { reports, setLookups } from './reports_reports.js';
import { officers, personByCid, mockCan, meOf } from './reports_people.js';
import { mockPhoto, dropPhoto } from './reports_media.js';

const now = () => Math.floor(Date.now() / 1000);
const H = 3600;
const D = 86400;
const PAGE = 25;

let evidenceSeq = 7000;
let personSeq = 100;

function officer(cid) {
  const o = officers.find((x) => x.cid === cid);
  return { cid: o.cid, name: o.name, callsign: o.callsign };
}

function who(cid) {
  const o = officers.find((x) => x.cid === cid);
  return `${o.callsign} ${o.name}`;
}

function evidence(caseId, kind, title, o = {}) {
  return {
    id: ++evidenceSeq,
    caseId,
    reportId: o.reportId || null,
    kind,
    title,
    description: o.description || null,
    imageId: kind === 'photo' ? mockPhoto(o.scene) : null,
    location: o.location || null,
    collectedBy: { cid: o.by || 'COP7', name: who(o.by || 'COP7') },
    createdAt: now() - (o.ago || D),
  };
}

function casePerson(cidOrName, role) {
  const known = personByCid(cidOrName);
  return { id: ++personSeq, cid: known ? cidOrName : null, name: known ? known.name : cidOrName, role };
}

export const cases = [
  {
    id: 311, title: 'Grove St shootings', status: 'open', lead: officer('COP7'), createdBy: officer('COP7'), createdAt: now() - 6 * D, updatedAt: now() - 26 * H,
    summary: 'Three drive-by shootings on Grove St and Forum Dr between 3 and 10 October. Each time a green two-door sedan was seen leaving at speed. The 9mm casings from all three scenes look like they came from the same pistol.\n\nNext steps: compare the casings with the pistol seized on report #2110, trace the green Sultan RS (46EEK572) and take a formal statement from Bobby Lang.',
    people: [casePerson('DCR40219', 'poi'), casePerson('Driver of a green two-door sedan', 'suspect'), casePerson('LNG8890', 'witness'), casePerson('Residents of 1104 Grove St', 'victim')],
    officers: [officer('COP7'), officer('COP3'), officer('COP4')],
    evidence: [],
  },
  {
    id: 312, title: 'Innocence Blvd robberies', status: 'open', lead: officer('COP2'), createdBy: officer('COP2'), createdAt: now() - 3 * D, updatedAt: now() - 30 * 60,
    summary: 'Two armed robberies of the 24/7 on Innocence Blvd in a week, both by a man in a black ski mask with a pistol. Tyrell Banks was arrested after the second (report #2114). Check whether he matches the first robbery on 4 October.',
    people: [casePerson('TBK77204', 'suspect'), casePerson('HRZ88402', 'victim'), casePerson('KMR4456', 'witness')],
    officers: [officer('COP2'), officer('COP1')],
    evidence: [],
  },
  {
    id: 313, title: 'Mirror Park burglaries', status: 'cold', lead: officer('COP7'), createdBy: officer('COP7'), createdAt: now() - 21 * D, updatedAt: now() - 4 * D,
    summary: 'Five break-ins at empty homes in Mirror Park since September. Jack Whitlow was caught at one of them but denies the others. No forensic link yet.',
    people: [casePerson('WTL1904', 'suspect')],
    officers: [officer('COP7')],
    evidence: [],
  },
  {
    id: 314, title: 'Missing person: Priya Shah', status: 'open', lead: officer('COP7'), createdBy: officer('COP5'), createdAt: now() - 6 * D, updatedAt: now() - 2 * D,
    summary: 'Priya Shah, 30, has not been seen since leaving the Tequi-la-la on Thursday night. Phone has been off since 01:40.',
    people: [casePerson('SHA7731', 'victim'), casePerson('OKF8812', 'witness')],
    officers: [officer('COP7'), officer('COP5')],
    evidence: [],
  },
  {
    id: 309, title: 'Forum Dr narcotics ring', status: 'closed', lead: officer('COP1'), createdBy: officer('COP1'), createdAt: now() - 30 * D, updatedAt: now() - 30 * H,
    summary: 'Street-level pill sales on Forum Dr traced to Victor Pollack. Closed after his arrest and sentencing on report #2110.',
    people: [casePerson('PLK3301', 'suspect')],
    officers: [officer('COP1'), officer('COP4')],
    evidence: [],
  },
  {
    id: 305, title: 'Vespucci jewellery heist', status: 'closed', lead: officer('COP6'), createdBy: officer('COP6'), createdAt: now() - 60 * D, updatedAt: now() - 41 * D,
    summary: 'Smash and grab at Vangelico. All four suspects sentenced by the court. Recovered jewellery returned to the store.',
    people: [],
    officers: [officer('COP6')],
    evidence: [],
  },
];

const byId = (id) => cases.find((c) => c.id === id);

byId(311).evidence.push(
  evidence(311, 'note', 'Statement: Bobby Lang', { description: 'Heard four or five shots at about 23:40. Saw a green two-door car with tinted windows drive off towards Forum Dr. Could not see the driver. Thinks the car had a loud exhaust.', location: 'Grove St', by: 'COP3', ago: 25 * H }),
  evidence(311, 'item', '9mm casings x3, bagged', { description: 'Bag GS-0311-01. Sent to ballistics on 11 October.', location: 'Grove St, outside 1104', by: 'COP7', ago: 26 * H, reportId: 2111 }),
  evidence(311, 'photo', 'Casings marked 1 to 3', { scene: 'casings', location: 'Grove St, outside 1104', by: 'COP7', ago: 26 * H, reportId: 2111 }),
  evidence(311, 'photo', 'Bullet strikes on 1104 Grove St', { scene: 'wall', location: 'Grove St', by: 'COP7', ago: 26 * H }),
  evidence(311, 'photo', 'Green Sultan RS on Forum Dr', { scene: 'sedan', description: 'Taken during the stop on report #2113. Same model and colour the witnesses describe.', location: 'Del Perro Pier car park', by: 'COP3', ago: 3 * H }),
);
byId(312).evidence.push(
  evidence(312, 'photo', 'CCTV, register camera', { scene: 'cctv', description: 'Suspect points a pistol at the clerk at 02:14:33.', location: '24/7 Innocence Blvd', by: 'COP2', ago: 30 * 60, reportId: 2114 }),
  evidence(312, 'photo', 'Ski mask under the passenger seat', { scene: 'mask', location: 'Elgin Ave car wash', by: 'COP1', ago: 25 * 60, reportId: 2114 }),
  evidence(312, 'item', 'Black ski mask', { description: 'Locker shelf B. Hair samples requested.', by: 'COP1', ago: 20 * 60 }),
);
byId(313).evidence.push(evidence(313, 'note', 'Pawn shop check', { description: 'None of the stolen jewellery has turned up at pawn shops in the city.', by: 'COP7', ago: 5 * D }));
byId(309).evidence.push(
  evidence(309, 'photo', 'Pills from the centre console', { scene: 'bag', location: 'Forum Dr', by: 'COP1', ago: 30 * H, reportId: 2110 }),
  evidence(309, 'photo', 'Pistol from the glovebox', { scene: 'pistol', location: 'Forum Dr', by: 'COP1', ago: 30 * H, reportId: 2110 }),
  evidence(309, 'item', '42 pills in a sealed bag', { description: 'Weighed and logged, 18 g.', by: 'COP1', ago: 29 * H }),
);

const loose = [];

function allEvidence() {
  return [...cases.flatMap((c) => c.evidence), ...loose];
}

setLookups({
  caseOf: (id) => byId(id),
  evidenceCount: (reportId) => allEvidence().filter((e) => e.reportId === reportId).length,
});

function header(c) {
  return { id: c.id, title: c.title, status: c.status, lead: c.lead, createdBy: c.createdBy, createdAt: c.createdAt, updatedAt: c.updatedAt, reports: reports.filter((r) => r.caseId === c.id).length, evidence: c.evidence.length };
}

function full(s, c) {
  return {
    ...header(c),
    summary: c.summary,
    people: c.people,
    officers: c.officers,
    reports: reports.filter((r) => r.caseId === c.id).sort((a, b) => b.id - a.id).map((r) => ({ id: r.id, title: r.title, type: r.type, createdAt: r.createdAt, author: { name: r.author.name, callsign: r.author.callsign }, locked: r.locked })),
    evidence: [...c.evidence].sort((a, b) => b.id - a.id),
    can: { manage: mockCan(s, 'cases.manage'), evidence: mockCan(s, 'evidence.manage'), reports: mockCan(s, 'reports.create') || mockCan(s, 'reports.view') },
  };
}

function changed(id) {
  push('cases:changed', { id });
}

export default function (reg, regCallback, s) {
  reg('cases.list', (d) => {
    if (!mockCan(s, 'cases.view')) return fail('not_allowed');
    const q = String(d.q || '').trim().toLowerCase();
    const num = q.match(/^#?(\d+)$/);
    const list = cases
      .filter((c) => !d.status || c.status === d.status)
      .filter((c) => !q || (num && c.id === Number(num[1])) || c.title.toLowerCase().includes(q) || (c.lead?.name || '').toLowerCase().includes(q) || c.people.some((p) => p.name.toLowerCase().includes(q)))
      .sort((a, b) => b.updatedAt - a.updatedAt);
    const pages = Math.max(1, Math.ceil(list.length / PAGE));
    const page = Math.min(Math.max(1, Number(d.page) || 1), pages);
    return { items: list.slice((page - 1) * PAGE, page * PAGE).map(header), total: list.length, page, pages, pageSize: PAGE };
  });

  reg('cases.get', (d) => {
    if (!mockCan(s, 'cases.view')) return fail('not_allowed');
    const c = byId(Number(d.id));
    return c ? full(s, c) : fail('not_found');
  });

  reg('cases.save', (d) => {
    if (!mockCan(s, 'cases.manage')) return fail('not_allowed');
    const title = String(d.title || '').trim();
    if (title.length < 3) return fail('bad_request');
    let c = d.id ? byId(d.id) : null;
    if (d.id && !c) return fail('not_found');
    for (const cid of d.officers || []) if (!officers.some((o) => o.cid === cid)) return fail('not_officer');
    if (d.leadCid && !officers.some((o) => o.cid === d.leadCid)) return fail('not_officer');
    const me = meOf(s);
    const fields = {
      title,
      summary: d.summary || '',
      status: d.status || c?.status || 'open',
      lead: d.leadCid ? officer(d.leadCid) : c ? null : officer(me.cid),
      people: (d.people || []).map((p) => {
        const known = p.cid ? personByCid(p.cid) : null;
        return { id: ++personSeq, cid: p.cid || null, name: known ? known.name : p.name, role: p.role };
      }),
      officers: (d.officers || []).map(officer),
      updatedAt: now(),
    };
    if (c) Object.assign(c, fields);
    else {
      c = { id: Math.max(...cases.map((x) => x.id)) + 1, createdBy: officer(me.cid), createdAt: now(), evidence: [], ...fields };
      cases.unshift(c);
    }
    changed(c.id);
    return full(s, c);
  });

  reg('cases.link', (d) => {
    if (!mockCan(s, 'cases.manage')) return fail('not_allowed');
    const c = byId(d.caseId);
    const r = reports.find((x) => x.id === d.reportId);
    if (!c || !r) return fail('not_found');
    r.caseId = c.id;
    c.updatedAt = now();
    changed(c.id);
    push('reports:changed', { id: r.id });
    return full(s, c);
  });

  reg('cases.unlink', (d) => {
    if (!mockCan(s, 'cases.manage')) return fail('not_allowed');
    const r = reports.find((x) => x.id === d.reportId);
    if (!r) return fail('not_found');
    if (d.caseId && r.caseId !== d.caseId) return fail('not_linked');
    const c = byId(r.caseId);
    r.caseId = null;
    changed(c?.id);
    push('reports:changed', { id: r.id });
    return c ? full(s, c) : { unlinked: true };
  });

  reg('cases.close', (d) => {
    if (!mockCan(s, 'cases.manage')) return fail('not_allowed');
    const c = byId(d.id);
    if (!c) return fail('not_found');
    c.status = d.status || 'closed';
    c.updatedAt = now();
    changed(c.id);
    return full(s, c);
  });

  reg('evidence.list', (d) => {
    if (d.caseId) return byId(d.caseId)?.evidence || [];
    return allEvidence().filter((e) => e.reportId === d.reportId);
  });

  reg('evidence.add', (d) => {
    if (!mockCan(s, 'evidence.manage')) return fail('not_allowed');
    if (!['photo', 'note', 'item'].includes(d.kind)) return fail('bad_request');
    const title = String(d.title || '').trim() || (d.kind === 'photo' ? 'Photograph' : '');
    if (title.length < 2) return fail('bad_request');
    if (d.kind === 'photo' && !d.imageId) return fail('bad_request');
    const c = d.caseId ? byId(d.caseId) : null;
    if (d.caseId && !c) return fail('unknown_case');
    const me = meOf(s);
    const e = { id: ++evidenceSeq, caseId: c?.id || null, reportId: d.reportId || null, kind: d.kind, title, description: d.description || null, imageId: d.imageId || null, location: d.location || null, collectedBy: { cid: me.cid, name: `${me.callsign} ${me.name}` }, createdAt: now() };
    if (c) {
      c.evidence.push(e);
      c.updatedAt = now();
      changed(c.id);
    } else loose.push(e);
    push('evidence:changed', { caseId: e.caseId, reportId: e.reportId });
    return e;
  });

  reg('evidence.update', (d) => {
    if (!mockCan(s, 'evidence.manage')) return fail('not_allowed');
    const e = allEvidence().find((x) => x.id === d.id);
    if (!e) return fail('not_found');
    if (d.title !== undefined) {
      const t = String(d.title || '').trim();
      if (t.length < 2) return fail('bad_request');
      e.title = t;
    }
    if (d.description !== undefined) e.description = d.description || null;
    if (d.location !== undefined) e.location = d.location || null;
    push('evidence:changed', { caseId: e.caseId, reportId: e.reportId });
    return e;
  });

  reg('evidence.remove', (d) => {
    if (!mockCan(s, 'evidence.manage')) return fail('not_allowed');
    for (const list of [...cases.map((c) => c.evidence), loose]) {
      const i = list.findIndex((x) => x.id === d.id);
      if (i >= 0) {
        const [e] = list.splice(i, 1);
        if (e.imageId) dropPhoto(e.imageId);
        push('evidence:changed', { caseId: e.caseId, reportId: e.reportId });
        return { removed: true };
      }
    }
    return fail('not_found');
  });

  reg('evidence.locker', (d) => {
    if (!mockCan(s, 'evidence.manage')) return fail('not_allowed');
    if (!byId(d.caseId)) return fail('not_found');
    return { id: `mdt_case_${d.caseId}`, label: `Case #${d.caseId} evidence` };
  });

  regCallback('openStash', () => ({ ok: true }));
  regCallback('evidenceHere', () => ({ ok: true, data: { street: 'Grove St, Davis' } }));
}
