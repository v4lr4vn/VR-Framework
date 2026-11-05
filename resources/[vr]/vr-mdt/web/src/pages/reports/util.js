export const reportTypes = [
  { value: 'incident', label: 'Incident' },
  { value: 'arrest', label: 'Arrest' },
  { value: 'traffic', label: 'Traffic' },
  { value: 'use_of_force', label: 'Use of force' },
  { value: 'investigation', label: 'Investigation' },
  { value: 'other', label: 'Other' },
];

const typeTones = { incident: 'info', arrest: 'p1', traffic: 'accent', use_of_force: 'danger', investigation: 'doj', other: 'muted' };

export function typeLabel(t) {
  return reportTypes.find((x) => x.value === t)?.label || t;
}

export function typeTone(t) {
  return typeTones[t] || 'muted';
}

export const classes = [
  { value: 'infraction', label: 'Infraction', short: 'INF' },
  { value: 'misdemeanor', label: 'Misdemeanor', short: 'MISD' },
  { value: 'felony', label: 'Felony', short: 'FEL' },
];

const classRank = { infraction: 1, misdemeanor: 2, felony: 3 };
const classTones = { infraction: 'muted', misdemeanor: 'accent', felony: 'p1' };

export function classLabel(c) {
  return classes.find((x) => x.value === c)?.label || c;
}

export function classShort(c) {
  return classes.find((x) => x.value === c)?.short || '';
}

export function classTone(c) {
  return classTones[c] || 'muted';
}

export const roles = [
  { value: 'suspect', label: 'Suspect' },
  { value: 'victim', label: 'Victim' },
  { value: 'witness', label: 'Witness' },
  { value: 'other', label: 'Other' },
];

export function roleLabel(r) {
  if (r === 'officer') return 'Officer';
  if (r === 'poi') return 'Person of interest';
  return roles.find((x) => x.value === r)?.label || r;
}

export function totals(items, lookup) {
  const out = { fine: 0, months: 0, points: 0, class: null };
  for (const e of items || []) {
    const c = lookup ? lookup(e.id) : e;
    if (!c) continue;
    const n = Number(e.count) || 1;
    out.fine += (c.fine || 0) * n;
    out.months += (c.months || 0) * n;
    out.points += (c.points || 0) * n;
    if ((classRank[c.class] || 0) > (classRank[out.class] || 0)) out.class = c.class;
  }
  return out;
}

export function jail(months) {
  if (!months) return '—';
  return months === 1 ? '1 month' : `${months} months`;
}

export function officerLabel(o) {
  if (!o) return '';
  return [o.callsign, o.name].filter(Boolean).join(' ');
}

export function plateOk(value) {
  const v = String(value || '').trim().toUpperCase();
  return v.length >= 1 && v.length <= 8 && /^[A-Z0-9 ]+$/.test(v) ? v : null;
}
