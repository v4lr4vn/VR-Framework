import { fail } from '../index.js';
import { push } from '../state.js';
import { mockCan, meOf } from './reports_people.js';

const seed = [
  { name: "Traffic", charges: [
    ["Speeding", "infraction", 250, 0, 1, "Driving above the posted speed limit by up to 30 mph."],
    ["Excessive speeding", "misdemeanor", 750, 0, 3, "Driving more than 30 mph above the posted speed limit."],
    ["Running a red light or stop sign", "infraction", 200, 0, 1, "Failing to stop at a red signal or a stop sign."],
    ["Illegal parking", "infraction", 100, 0, 0, "Parking in a prohibited, obstructive or reserved space."],
    ["Failure to yield to an emergency vehicle", "infraction", 400, 0, 2, "Not pulling over for an emergency vehicle using lights and siren."],
    ["Driving without a valid licence", "misdemeanor", 750, 0, 2, "Operating a motor vehicle without a valid driver licence."],
    ["Reckless driving", "misdemeanor", 1200, 5, 4, "Driving with wilful disregard for the safety of people or property."],
    ["Driving under the influence", "misdemeanor", 2000, 10, 4, "Operating a vehicle while impaired by alcohol or drugs."],
    ["Hit and run", "felony", 3000, 15, 4, "Leaving the scene of a collision involving injury or damage without stopping."],
    ["Felony evading", "felony", 4000, 20, 5, "Fleeing from police in a vehicle after being signalled to stop."],
  ] },
  { name: "Property", charges: [
    ["Trespassing", "misdemeanor", 500, 0, 0, "Entering or staying on property after being told to leave, or where entry is posted as forbidden."],
    ["Vandalism", "misdemeanor", 750, 5, 0, "Wilfully damaging or defacing property that belongs to someone else."],
    ["Petty theft", "misdemeanor", 500, 5, 0, "Taking property worth less than $1,000."],
    ["Possession of stolen property", "misdemeanor", 1000, 10, 0, "Knowingly holding property that was stolen."],
    ["Grand theft", "felony", 2000, 15, 0, "Taking property worth $1,000 or more."],
    ["Grand theft auto", "felony", 3000, 20, 0, "Taking a motor vehicle without the owner's consent."],
    ["Burglary", "felony", 3500, 25, 0, "Entering a building or vehicle with intent to commit theft or another felony."],
    ["Robbery", "felony", 5000, 30, 0, "Taking property from a person by force or fear."],
    ["Armed robbery", "felony", 8000, 45, 0, "Robbery committed with a firearm or another deadly weapon."],
    ["Robbery of a financial institution", "felony", 15000, 60, 0, "Robbing a bank, vault or armoured cash transport."],
    ["Arson", "felony", 6000, 35, 0, "Wilfully setting fire to a structure, vehicle or land."],
  ] },
  { name: "Violence", charges: [
    ["Assault", "misdemeanor", 1000, 10, 0, "Attempting or threatening to cause bodily harm to another person."],
    ["Battery", "misdemeanor", 1500, 12, 0, "Unlawful use of force or violence on another person."],
    ["Assault with a deadly weapon", "felony", 5000, 30, 0, "Assault using a weapon or force likely to cause great bodily injury."],
    ["Assault on a public servant", "felony", 6000, 35, 0, "Assaulting an on-duty officer, medic, firefighter or other public servant."],
    ["Kidnapping", "felony", 8000, 45, 0, "Moving or holding a person against their will by force or fear."],
    ["Vehicular manslaughter", "felony", 8000, 40, 6, "Causing a death through negligent or unlawful driving."],
    ["Manslaughter", "felony", 12000, 60, 0, "Unlawfully killing a person without intent to kill."],
    ["Attempted murder", "felony", 15000, 75, 0, "Trying to kill another person with intent."],
    ["Murder", "felony", 25000, 120, 0, "Unlawfully killing another person with intent."],
    ["Murder of a public servant", "felony", 35000, 150, 0, "Killing an on-duty public servant."],
  ] },
  { name: "Weapons", charges: [
    ["Brandishing a weapon", "misdemeanor", 1000, 10, 0, "Drawing or showing a weapon in a threatening way."],
    ["Carrying a firearm without a licence", "misdemeanor", 2000, 15, 0, "Carrying a legal firearm without a valid weapon licence."],
    ["Discharging a firearm in public", "felony", 3000, 20, 0, "Firing a weapon in a public place without lawful reason."],
    ["Possession of a prohibited weapon", "felony", 5000, 30, 0, "Holding a weapon civilians may not own, such as a sawn-off shotgun or a suppressor."],
    ["Possession of a firearm by a prohibited person", "felony", 6000, 30, 0, "Holding a firearm after a felony conviction or while barred by court order."],
    ["Possession of an automatic firearm", "felony", 10000, 45, 0, "Holding a fully automatic firearm."],
    ["Weapons trafficking", "felony", 15000, 60, 0, "Selling, moving or supplying firearms or ammunition illegally."],
  ] },
  { name: "Narcotics", charges: [
    ["Possession of drug paraphernalia", "infraction", 250, 0, 0, "Holding equipment used to take or prepare illegal drugs."],
    ["Possession of a controlled substance", "misdemeanor", 1000, 5, 0, "Holding a small personal amount of an illegal drug."],
    ["Possession with intent to distribute", "felony", 5000, 25, 0, "Holding drugs in a quantity or packaging that shows intent to sell."],
    ["Sale of a controlled substance", "felony", 6000, 30, 0, "Selling or offering to sell an illegal drug."],
    ["Manufacturing a controlled substance", "felony", 10000, 45, 0, "Cooking, growing or processing illegal drugs."],
    ["Drug trafficking", "felony", 15000, 60, 0, "Moving large quantities of illegal drugs for distribution."],
  ] },
  { name: "Public order", charges: [
    ["Jaywalking", "infraction", 100, 0, 0, "Crossing a road away from a crossing or against the signal."],
    ["Public intoxication", "infraction", 300, 0, 0, "Being drunk or high in public and unable to care for yourself."],
    ["Disturbing the peace", "infraction", 350, 0, 0, "Unreasonable noise, challenges to fight or offensive conduct in public."],
    ["Indecent exposure", "misdemeanor", 750, 5, 0, "Exposing yourself in public where it is likely to offend."],
    ["Harassment", "misdemeanor", 1000, 8, 0, "Repeated conduct that alarms, torments or threatens another person."],
    ["Inciting a riot", "felony", 4000, 20, 0, "Urging a group to violence or destruction of property."],
  ] },
  { name: "Obstruction & government", charges: [
    ["Failure to identify", "infraction", 500, 0, 0, "Refusing to give your name to an officer while lawfully detained."],
    ["Evading on foot", "misdemeanor", 800, 5, 0, "Running from an officer after being told to stop."],
    ["Resisting arrest", "misdemeanor", 1000, 8, 0, "Physically resisting or delaying an officer making a lawful arrest."],
    ["Obstruction of justice", "misdemeanor", 1500, 10, 0, "Hindering an investigation, hiding evidence or helping a suspect avoid arrest."],
    ["False report to emergency services", "misdemeanor", 1500, 5, 0, "Knowingly reporting a false emergency or crime."],
    ["Contempt of court", "misdemeanor", 2000, 10, 0, "Disobeying or disrespecting the court during proceedings."],
    ["Impersonating a public servant", "felony", 5000, 25, 0, "Pretending to be a police officer, medic or government official."],
    ["Escape from custody", "felony", 5000, 30, 0, "Escaping or trying to escape from police custody or prison."],
    ["Perjury", "felony", 6000, 30, 0, "Knowingly lying under oath."],
    ["Bribery of a public official", "felony", 8000, 30, 0, "Offering money or favours to influence a public official."],
  ] },
];

const day = 86400;
const now = () => Math.floor(Date.now() / 1000);

export const penal = { categories: [], charges: [] };

let catSeq = 0;
let chargeSeq = 0;

seed.forEach((cat, ci) => {
  const id = ++catSeq;
  penal.categories.push({ id, name: cat.name, sort: (ci + 1) * 10 });
  cat.charges.forEach((c, i) => {
    penal.charges.push({ id: ++chargeSeq, categoryId: id, title: c[0], class: c[1], fine: c[2], months: c[3], points: c[4], description: c[5], sort: (i + 1) * 10, active: true, updatedAt: now() - 40 * day, updatedBy: 'System' });
  });
});

const publicOrder = penal.categories.find((c) => c.name === 'Public order');
penal.charges.push({ id: ++chargeSeq, categoryId: publicOrder.id, title: 'Loitering', class: 'infraction', fine: 150, months: 0, points: 0, description: 'Lingering in a public place with no apparent purpose. Retired in favour of trespassing.', sort: 5, active: false, updatedAt: now() - 6 * day, updatedBy: '2-EDWARD-5 Owen Brandt' });

const classRank = { infraction: 1, misdemeanor: 2, felony: 3 };
let referenced = () => false;

export function setReferenceCheck(fn) {
  referenced = fn;
}

export function chargeByTitle(title) {
  return penal.charges.find((c) => c.title === title) || null;
}

export function chargeById(id) {
  return penal.charges.find((c) => c.id === id) || null;
}

function categoryName(id) {
  return penal.categories.find((c) => c.id === id)?.name;
}

function row(c) {
  return { ...c, category: categoryName(c.categoryId) };
}

export function expand(list) {
  const out = [];
  for (const e of list || []) {
    const c = chargeById(e.id);
    if (c) out.push({ id: c.id, title: c.title, class: c.class, category: categoryName(c.categoryId), fine: c.fine, months: c.months, points: c.points, active: c.active, count: e.count || 1 });
  }
  return out;
}

export function sum(items) {
  const t = { fine: 0, months: 0, points: 0, class: null };
  for (const e of items || []) {
    t.fine += e.fine * e.count;
    t.months += e.months * e.count;
    t.points += (e.points || 0) * e.count;
    if ((classRank[e.class] || 0) > (classRank[t.class] || 0)) t.class = e.class;
  }
  t.months = Math.min(t.months, 300);
  return t;
}

export function list(all) {
  return [...penal.categories]
    .sort((a, b) => a.sort - b.sort || a.id - b.id)
    .map((cat) => ({
      ...cat,
      charges: penal.charges
        .filter((c) => c.categoryId === cat.id && (all || c.active))
        .sort((a, b) => a.sort - b.sort || a.title.localeCompare(b.title))
        .map(row),
    }))
    .filter((cat) => all || cat.charges.length);
}

function changed() {
  push('penal:changed', { at: now() });
}

function str(v, max, min = 1) {
  if (typeof v !== 'string' && typeof v !== 'number') return null;
  const s = String(v).replace(/\s+/g, ' ').trim().slice(0, max);
  return s.length >= min ? s : null;
}

function int(v, min, max) {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
}

export default function (reg, regCallback, s) {
  const manager = () => mockCan(s, 'penal.manage');

  reg('penal.list', (d) => {
    if (s.dept === 'ems') return fail('not_allowed');
    const all = d.all === true && manager();
    return { categories: list(all), classes: ['infraction', 'misdemeanor', 'felony'], all };
  });

  reg('penal.categorySave', (d) => {
    if (!manager()) return fail('not_allowed');
    const name = str(d.name, 48, 2);
    if (!name) return fail('bad_request');
    if (penal.categories.some((c) => c.id !== d.id && c.name.toLowerCase() === name.toLowerCase())) return fail('already_exists');
    let cat = d.id ? penal.categories.find((c) => c.id === d.id) : null;
    if (d.id && !cat) return fail('not_found');
    if (cat) cat.name = name;
    else {
      cat = { id: ++catSeq, name, sort: Math.max(0, ...penal.categories.map((c) => c.sort)) + 10 };
      penal.categories.push(cat);
    }
    changed();
    return { ...cat, count: penal.charges.filter((c) => c.categoryId === cat.id).length };
  });

  reg('penal.categoryDelete', (d) => {
    if (!manager()) return fail('not_allowed');
    const i = penal.categories.findIndex((c) => c.id === d.id);
    if (i < 0) return fail('not_found');
    if (penal.charges.some((c) => c.categoryId === d.id)) return fail('category_not_empty');
    penal.categories.splice(i, 1);
    changed();
    return { deleted: true };
  });

  reg('penal.chargeSave', (d) => {
    if (!manager()) return fail('not_allowed');
    const title = str(d.title, 96, 3);
    const cls = ['infraction', 'misdemeanor', 'felony'].includes(d.class) ? d.class : null;
    const fine = int(d.fine, 0, 1000000);
    const months = int(d.months ?? 0, 0, 300);
    const points = int(d.points ?? 0, 0, 20);
    if (!title || !cls || fine == null || months == null || points == null) return fail('bad_request');
    if (cls === 'infraction' && months > 0) return fail('infraction_no_jail');
    if (!penal.categories.some((c) => c.id === d.category)) return fail('unknown_category');
    if (penal.charges.some((c) => c.id !== d.id && c.categoryId === d.category && c.title.toLowerCase() === title.toLowerCase())) return fail('already_exists');
    const me = meOf(s);
    const fields = { categoryId: d.category, title, class: cls, fine, months, points, description: str(d.description, 1000) || null, active: d.active !== false, updatedAt: now(), updatedBy: `${me.callsign} ${me.name}` };
    let c = d.id ? chargeById(d.id) : null;
    if (d.id && !c) return fail('not_found');
    if (c) Object.assign(c, fields);
    else {
      c = { id: ++chargeSeq, sort: Math.max(0, ...penal.charges.filter((x) => x.categoryId === d.category).map((x) => x.sort)) + 10, ...fields };
      penal.charges.push(c);
    }
    changed();
    return row(c);
  });

  reg('penal.chargeDelete', (d) => {
    if (!manager()) return fail('not_allowed');
    const c = chargeById(d.id);
    if (!c) return fail('not_found');
    changed();
    if (referenced(c.id)) {
      c.active = false;
      c.updatedAt = now();
      return { deactivated: true, charge: row(c) };
    }
    penal.charges.splice(penal.charges.indexOf(c), 1);
    return { deleted: true };
  });

  reg('penal.reorder', (d) => {
    if (!manager()) return fail('not_allowed');
    (d.categories || []).forEach((id, i) => {
      const c = penal.categories.find((x) => x.id === id);
      if (c) c.sort = (i + 1) * 10;
    });
    (d.charges || []).forEach((id, i) => {
      const c = chargeById(id);
      if (c) c.sort = (i + 1) * 10;
    });
    changed();
    return { categories: list(true) };
  });
}
