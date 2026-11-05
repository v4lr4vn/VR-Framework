import { fail } from '../index.js';
import { push } from '../state.js';
import { now, me, log } from './department_data.js';

const H = 3600;
const D = 86400;

function seed() {
  const t = now();
  const p = (id, title, body, author, ago, opts = {}) => ({
    id, title, body, pinned: !!opts.pinned, authorCid: null, authorName: author,
    createdAt: t - ago, updatedAt: t - (opts.edited ?? ago), expiresAt: opts.expires ? t + opts.expires : null,
  });
  return {
    police: [
      p(44, 'Bodycams on for every stop', 'Effective immediately, every unit on patrol records from the moment a stop is initiated until the subject is released or booked.\n\nMissing footage will be treated as a policy violation and referred to Internal Affairs. If your camera fails, call it in on the radio and log it in your report.', 'Rae Hale', 2 * D, { pinned: true, edited: 2 * D - 1800 }),
      p(43, 'Pursuit policy, section 4 updated', 'Air support now has primary on any pursuit lasting longer than four minutes. Ground units back off to visual distance once Air 1 calls the eye.\n\nRead the full section before your next shift. Sergeants will go over it at briefing.', 'Victor Dunn', 4 * D, { pinned: true }),
      p(42, 'Range qualification Friday 18:00', 'Pistol and rifle qualification at the Paleto range. Bring your own ammo from the armory, sign it out with a sergeant. Recruits must pass before their phase 2 evaluation.', 'Nadia Brooks', 5 * H, { expires: 3 * D }),
      p(41, 'Vehicle 14 out of service', 'Brakes are gone on unit 14 (Buffalo). It is parked at Mission Row bay 3. Do not take it out until the mechanic signs it off.', 'Marco Ortega', 9 * H, { expires: 20 * H }),
      p(40, 'Welcome Mila Novak', 'Please welcome Recruit Mila Novak to the department. She starts field training this week with Officer Diaz.', 'Rae Hale', 1 * D),
      p(39, 'Gang unit briefing notes', 'Ballas activity is up around Grove and Davis. Expect retaliation after last night\'s shooting. Two-officer units only south of the freeway after dark.\n\nIntel requests go to Sergeant Ortega or the gang unit channel.\nKnown vehicles:\n- Dark green Buccaneer, partial plate 46E\n- Purple Chino, no plate\n- Grey Emperor with a cracked windshield\n\nDo not engage alone. Call for backup and wait.', 'Ivan Kerr', 3 * D),
      p(37, 'Overtime sign-up for the Vinewood festival', 'We need eight officers for traffic control on Saturday from 14:00 to 22:00. Put your callsign on the sheet in the briefing room by Thursday.', 'Owen Marsh', 6 * D),
    ],
    ems: [
      p(12, 'New trauma protocol', 'Tourniquets go on first, questions later. Updated card is in every ambulance glovebox. Doctors will run refreshers on Wednesday.', 'Tess Moreau', 1 * D, { pinned: true }),
      p(11, 'Ambulance 3 restocked', 'All kits are full again. Please log what you use in the supply book so we can keep up.', 'Owen Price', 6 * H, { expires: 2 * D }),
      p(10, 'Helicopter training slots', 'Two seats available on the air ambulance course next week. Ask Ruth Okafor.', 'Ruth Okafor', 3 * D),
    ],
    doj: [
      p(7, 'Court closed Monday', 'Public holiday. Urgent warrants go to the on-call judge through the MDT as usual.', 'Harlan Price', 17 * H, { pinned: true, expires: 4 * D }),
      p(6, 'Filing deadlines', 'Motions for next week\'s docket are due by Thursday 17:00. Late filings will be pushed to the following session.', 'Selena Ward', 2 * D),
    ],
  };
}

export default function (reg, regCallback, s) {
  const posts = seed();
  let nextId = 100;

  function sorted() {
    const t = now();
    return posts[s.dept].filter((p) => !p.expiresAt || p.expiresAt > t).sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.createdAt - a.createdAt);
  }

  reg('bulletin.list', (d) => {
    const page = Math.max(1, Number(d.page) || 1);
    const list = sorted();
    return { items: list.slice((page - 1) * 20, page * 20), page, more: list.length > page * 20 };
  });

  reg('bulletin.save', (d) => {
    if (!s.boss) return fail('not_allowed');
    const title = String(d.title || '').trim();
    const body = String(d.body || '').trim();
    if (title.length < 3 || !body) return fail('bad_request');
    const t = now();
    const expires = d.expiresDays ? t + Number(d.expiresDays) * 86400 : null;
    if (d.id) {
      const p = posts[s.dept].find((x) => x.id === d.id);
      if (!p) return fail('not_found');
      Object.assign(p, { title, body, pinned: !!d.pinned, updatedAt: t, expiresAt: d.keepExpiry ? p.expiresAt : expires });
      log(s, 'bulletin.edit', p.id, { title, pinned: !!d.pinned, author: p.authorName });
      push('bulletin:changed', { id: p.id, action: 'edit' });
      return p;
    }
    const p = { id: nextId++, title, body, pinned: !!d.pinned, authorCid: me(s).cid, authorName: me(s).name, createdAt: t, updatedAt: t, expiresAt: expires };
    posts[s.dept].push(p);
    log(s, 'bulletin.create', p.id, { title, pinned: p.pinned });
    push('bulletin:changed', { id: p.id, action: 'create' });
    return p;
  });

  reg('bulletin.delete', (d) => {
    if (!s.boss) return fail('not_allowed');
    const p = posts[s.dept].find((x) => x.id === d.id);
    if (!p) return fail('not_found');
    posts[s.dept] = posts[s.dept].filter((x) => x !== p);
    log(s, 'bulletin.delete', p.id, { title: p.title, author: p.authorName });
    push('bulletin:changed', { id: p.id, action: 'delete' });
    return { id: p.id };
  });
}
