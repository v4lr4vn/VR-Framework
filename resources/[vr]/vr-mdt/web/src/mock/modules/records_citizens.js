import { fail } from '../index.js';
import {
  people, person, vehicles, weapons, warrants, bolos, inmates, reportsFor, sentencesFor, propertiesFor, licenceLabels,
  publicPerson, hasActiveWarrant, images, portrait, hexId, placardFor, matches, me, now,
} from './records_data.js';

const flagOptions = ['Armed and dangerous', 'Gang affiliated', 'Known to flee', 'Mental health concern', 'Violent towards officers', 'Parolee'];

function summary(p) {
  return { cid: p.cid, name: p.name, dob: p.dob, phone: p.phone, gender: p.gender, mugshot: p.mugshot, flags: [...p.flags], hasWarrant: hasActiveWarrant(p.cid) };
}

function search(q, limit) {
  const term = String(q || '').trim().toLowerCase();
  if (term.length < 2) return [];
  return people.filter((p) => matches(p.name, term) || matches(p.cid, term) || matches(p.phone, term)).slice(0, limit).sort((a, b) => a.name.localeCompare(b.name));
}

function canTouch(s, perm) {
  if (s.dept !== 'police') return false;
  if (!s.boss && perm.includes('manage')) return false;
  return true;
}

let shots = 0;

export default function (reg, regCallback, s) {
  reg('people.search', (d) => search(d.q, d.limit || 20).map((p) => ({ cid: p.cid, name: p.name, dob: p.dob, phone: p.phone, gender: p.gender, job: p.job, jobLabel: p.jobLabel })));
  reg('citizens.search', (d) => {
    if (s.dept === 'ems') return fail('not_allowed');
    if (typeof d.q !== 'string') return fail('bad_request');
    return search(d.q, 30).map(summary);
  });
  reg('citizens.recent', () => {
    if (s.dept === 'ems') return fail('not_allowed');
    return people.filter((p) => p.updatedAt).sort((a, b) => b.updatedAt - a.updatedAt).slice(0, 12).map(summary);
  });
  reg('citizens.get', (d) => {
    const p = person(d.cid);
    if (!p) return fail('not_found');
    const prison = inmates.find((i) => i.cid === p.cid);
    return {
      ...publicPerson(p),
      licences: Object.entries(licenceLabels).map(([key, label]) => ({ key, label, value: p.licences[key] === true })).sort((a, b) => a.label.localeCompare(b.label)),
      fingerprint: p.fingerprint,
      bloodtype: p.bloodtype,
      mugshot: p.mugshot,
      notes: p.notes,
      flags: [...p.flags],
      updatedAt: p.updatedAt,
      updatedBy: p.updatedBy,
      properties: propertiesFor[p.cid] || [],
      vehicles: vehicles.filter((v) => v.ownerCid === p.cid).map((v) => ({ plate: v.plate, model: v.model, label: v.label, garage: v.garage, state: v.state, flags: [...v.flags] })),
      weapons: weapons.filter((w) => w.ownerCid === p.cid).map((w) => ({ serial: w.serial, item: w.item, label: w.label, registeredAt: w.registeredAt, flags: [...w.flags] })),
      warrants: warrants.filter((w) => w.cid === p.cid).sort((a, b) => b.id - a.id),
      bolos: bolos.filter((b) => b.cid === p.cid && b.status === 'active'),
      prison: prison ? { months: prison.months, remaining: prison.remaining, monthsLeft: Math.ceil(prison.remaining / 60), since: prison.since, reason: prison.reason, online: prison.online, reportId: prison.reportId } : null,
      reports: reportsFor[p.cid] || [],
      sentences: sentencesFor[p.cid] || [],
    };
  });
  reg('citizens.notes', (d) => {
    if (!canTouch(s, 'records.edit')) return fail('not_allowed');
    const p = person(d.cid);
    if (!p) return fail('not_found');
    if (typeof d.notes !== 'string') return fail('bad_request');
    p.notes = d.notes.trim().slice(0, 4000);
    p.updatedBy = me(s.dept).name;
    p.updatedAt = now();
    return { notes: p.notes, updatedAt: p.updatedAt, updatedBy: p.updatedBy };
  });
  reg('citizens.flags', (d) => {
    if (!canTouch(s, 'records.edit')) return fail('not_allowed');
    const p = person(d.cid);
    if (!p) return fail('not_found');
    if (!Array.isArray(d.flags) || d.flags.some((f) => !flagOptions.includes(f))) return fail('bad_request');
    p.flags = [...new Set(d.flags)];
    p.updatedBy = me(s.dept).name;
    p.updatedAt = now();
    return { flags: p.flags, updatedAt: p.updatedAt, updatedBy: p.updatedBy };
  });
  reg('citizens.licence', (d) => {
    if (!canTouch(s, 'licences.edit')) return fail('not_allowed');
    const p = person(d.cid);
    if (!p) return fail('not_found');
    if (!licenceLabels[d.licence] || typeof d.value !== 'boolean') return fail('bad_request');
    p.licences[d.licence] = d.value;
    return { key: d.licence, label: licenceLabels[d.licence], value: d.value };
  });
  reg('citizens.mugshot', (d) => {
    if (!canTouch(s, 'mugshots.take')) return fail('not_allowed');
    const p = person(d.cid);
    if (!p) return fail('not_found');
    if (!images.has(d.imageId)) return fail('not_found');
    p.mugshot = d.imageId;
    p.updatedBy = me(s.dept).name;
    p.updatedAt = now();
    return { mugshot: p.mugshot, updatedAt: p.updatedAt, updatedBy: p.updatedBy };
  });
  reg('mugshots.target', (d) => {
    const p = person(d.cid);
    if (!p) return fail('bad_request');
    if (!p.online) return fail('not_online');
    return { src: 12, countdown: 3, fov: 38 };
  });
  regCallback('image', (d) => {
    const id = String(d.id || '');
    if (!/^[0-9a-f]{32}$/.test(id)) return { ok: false, error: 'bad_request' };
    return { ok: true, data: portrait(id) };
  });
  regCallback('capture', async (d) => {
    await new Promise((r) => setTimeout(r, 500));
    if (d.kind === 'mugshot') {
      const p = person(d.cid);
      if (!p) return { ok: false, error: 'bad_request' };
      if (!p.online) return { ok: false, error: 'not_online' };
    }
    shots += 1;
    const id = hexId(`shot-${d.kind}-${d.cid || ''}-${shots}-${Date.now()}`);
    images.add(id);
    if (d.cid) placardFor(id, d.cid);
    return { ok: true, data: { id, url: portrait(id) } };
  });
}
