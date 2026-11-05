import { fail } from '../index.js';
import { vehicles, vehicleFlags, person, publicPerson, bolos, matches, me, now } from './records_data.js';

const reportsForPlate = {
  '46EEK572': [
    { id: 1041, title: 'Fleeca bank robbery, Great Ocean Hwy', type: 'incident', created_at: now() - 6 * 3600 },
    { id: 1036, title: 'Stolen vehicle, Legion Square', type: 'incident', created_at: now() - 26 * 3600 },
  ],
  '12WEB881': [{ id: 1031, title: 'Reckless driving on the Del Perro freeway', type: 'traffic', created_at: now() - 2 * 86400 }],
};

function normal(plate) {
  return String(plate || '').trim().toUpperCase();
}

function row(v) {
  const owner = v.ownerCid ? person(v.ownerCid) : null;
  return { plate: v.plate, model: v.model, label: v.label, owner: owner?.name || null, ownerCid: v.ownerCid, flags: [...v.flags], unregistered: !v.model || undefined };
}

function find(plate) {
  return vehicles.find((v) => v.plate === normal(plate));
}

function profileOf(plate) {
  let v = find(plate);
  if (!v) {
    v = { plate: normal(plate), model: null, label: null, ownerCid: null, garage: null, state: null, flags: [], notes: '' };
    vehicles.push(v);
  }
  return v;
}

export default function (reg, regCallback, s) {
  reg('vehicles.search', (d) => {
    if (typeof d.q !== 'string') return fail('bad_request');
    const q = d.q.trim();
    if (q.length < 2) return [];
    return vehicles.filter((v) => (v.model || v.flags.length || v.notes) && (matches(v.plate, q) || matches(v.label, q) || matches(v.model, q))).slice(0, 30).map(row);
  });
  reg('vehicles.recent', () => vehicles.filter((v) => v.flags.length).sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0)).slice(0, 12).map(row));
  reg('vehicles.get', (d) => {
    const plate = normal(d.plate);
    if (!/^[A-Z0-9 ]{1,8}$/.test(plate)) return fail('bad_request');
    const v = find(plate);
    const owner = v?.ownerCid ? person(v.ownerCid) : null;
    return {
      plate,
      registered: !!v?.model,
      model: v?.model || null,
      label: v?.label || null,
      garage: v?.garage || null,
      state: v?.state ?? null,
      notes: v?.notes || '',
      flags: v ? [...v.flags] : [],
      updatedAt: v?.updatedAt || null,
      updatedBy: v?.updatedBy || null,
      flagOptions: vehicleFlags,
      owner: owner ? { ...publicPerson(owner), mugshot: owner.mugshot, flags: [...owner.flags] } : null,
      bolos: bolos.filter((b) => b.plate === plate && b.status === 'active'),
      reports: reportsForPlate[plate] || [],
    };
  });
  reg('vehicles.flags', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    if (!Array.isArray(d.flags) || d.flags.some((f) => !vehicleFlags.includes(f))) return fail('bad_request');
    const v = profileOf(d.plate);
    v.flags = [...new Set(d.flags)];
    v.updatedBy = me(s.dept).name;
    v.updatedAt = now();
    return { flags: v.flags, updatedAt: v.updatedAt, updatedBy: v.updatedBy };
  });
  reg('vehicles.notes', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    if (typeof d.notes !== 'string') return fail('bad_request');
    const v = profileOf(d.plate);
    v.notes = d.notes.trim().slice(0, 4000);
    v.updatedBy = me(s.dept).name;
    v.updatedAt = now();
    return { notes: v.notes, updatedAt: v.updatedAt, updatedBy: v.updatedBy };
  });
}
