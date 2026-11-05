import { fail } from '../index.js';
import { weapons, weaponFlags, person, publicPerson, matches, me, now } from './records_data.js';

function normal(serial) {
  return String(serial || '').trim().toUpperCase();
}

function row(w) {
  const owner = w.ownerCid ? person(w.ownerCid) : null;
  return { serial: w.serial, item: w.item, label: w.label, owner: owner?.name || null, ownerCid: w.ownerCid, registeredAt: w.registeredAt, source: w.source, flags: [...w.flags] };
}

export default function (reg, regCallback, s) {
  reg('weapons.search', (d) => {
    if (typeof d.q !== 'string') return fail('bad_request');
    const q = d.q.trim();
    if (q.length < 2) return [];
    return weapons.filter((w) => matches(w.serial, q) || matches(w.label, q) || matches(person(w.ownerCid)?.name, q)).slice(0, 30).map(row);
  });
  reg('weapons.recent', () => [...weapons].sort((a, b) => b.registeredAt - a.registeredAt).slice(0, 12).map(row));
  reg('weapons.get', (d) => {
    const w = weapons.find((x) => x.serial === normal(d.serial));
    if (!w) return fail('not_found');
    const owner = w.ownerCid ? person(w.ownerCid) : null;
    return {
      ...row(w),
      notes: w.notes,
      updatedAt: w.updatedAt || null,
      updatedBy: w.updatedBy || null,
      flagOptions: weaponFlags,
      ownerProfile: owner ? { ...publicPerson(owner), mugshot: owner.mugshot, flags: [...owner.flags], weaponLicence: owner.licences.weapon === true } : null,
    };
  });
  reg('weapons.flags', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const w = weapons.find((x) => x.serial === normal(d.serial));
    if (!w) return fail('not_found');
    if (!Array.isArray(d.flags) || d.flags.some((f) => !weaponFlags.includes(f))) return fail('bad_request');
    w.flags = [...new Set(d.flags)];
    w.updatedBy = me(s.dept).name;
    w.updatedAt = now();
    return { flags: w.flags, updatedAt: w.updatedAt, updatedBy: w.updatedBy };
  });
  reg('weapons.notes', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const w = weapons.find((x) => x.serial === normal(d.serial));
    if (!w) return fail('not_found');
    w.notes = String(d.notes || '').trim().slice(0, 4000);
    w.updatedBy = me(s.dept).name;
    w.updatedAt = now();
    return { notes: w.notes, updatedAt: w.updatedAt, updatedBy: w.updatedBy };
  });
  reg('weapons.register', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const serial = normal(d.serial);
    if (!/^[A-Z0-9-]{4,32}$/.test(serial) || !String(d.label || '').trim()) return fail('bad_request');
    if (weapons.some((w) => w.serial === serial)) return fail('already_exists');
    if (d.cid && !person(d.cid)) return fail('not_found');
    const w = { serial, item: null, label: String(d.label).trim().slice(0, 64), ownerCid: d.cid || null, registeredAt: now(), source: 'manual', flags: [], notes: '' };
    weapons.unshift(w);
    return row(w);
  });
}
