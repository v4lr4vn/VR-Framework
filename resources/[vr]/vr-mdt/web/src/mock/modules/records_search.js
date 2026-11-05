import { fail } from '../index.js';
import { people, vehicles, weapons, person, matches } from './records_data.js';

const reports = [
  { id: 1043, title: 'Stop on Forum Drive, stolen SMG recovered', type: 'arrest', created_at: Math.floor(Date.now() / 1000) - 1500 },
  { id: 1041, title: 'Fleeca bank robbery, Great Ocean Hwy', type: 'incident', created_at: Math.floor(Date.now() / 1000) - 21600 },
  { id: 1040, title: 'Hit and run on Vespucci Blvd', type: 'traffic', created_at: Math.floor(Date.now() / 1000) - 7200 },
];

export default function (reg, regCallback, s) {
  reg('search.global', (d) => {
    if (typeof d.q !== 'string') return fail('bad_request');
    const q = d.q.trim();
    const empty = { citizens: [], vehicles: [], weapons: [], reports: [] };
    if (q.length < 2) return empty;
    const records = s.dept !== 'ems';
    const citizens = people.filter((p) => matches(p.name, q) || matches(p.cid, q) || matches(p.phone, q)).slice(0, 5)
      .map((p) => ({ cid: p.cid, name: p.name, dob: p.dob, mugshot: records ? p.mugshot : null }));
    if (!records) return { ...empty, citizens };
    return {
      citizens,
      vehicles: vehicles.filter((v) => matches(v.plate, q)).slice(0, 5).map((v) => ({ plate: v.plate, model: v.model, label: v.label, owner: person(v.ownerCid)?.name || null, ownerCid: v.ownerCid, flags: [...v.flags] })),
      weapons: weapons.filter((w) => matches(w.serial, q)).slice(0, 5).map((w) => ({ serial: w.serial, label: w.label, owner: person(w.ownerCid)?.name || null, ownerCid: w.ownerCid, flags: [...w.flags] })),
      reports: reports.filter((r) => matches(r.title, q) || String(r.id).includes(q)).slice(0, 5),
    };
  });
}
