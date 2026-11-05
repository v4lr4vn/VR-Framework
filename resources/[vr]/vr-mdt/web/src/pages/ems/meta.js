export const types = [
  { value: 'treatment', label: 'Treatment' },
  { value: 'transport', label: 'Transport' },
  { value: 'checkup', label: 'Check-up' },
  { value: 'death', label: 'Death' },
  { value: 'other', label: 'Other' },
];

export const outcomes = [
  { value: 'treated_released', label: 'Treated and released' },
  { value: 'transported', label: 'Transported' },
  { value: 'admitted', label: 'Admitted' },
  { value: 'refused', label: 'Refused care' },
  { value: 'deceased', label: 'Deceased' },
];

export const regions = {
  head: 'Head',
  neck: 'Neck',
  chest: 'Chest',
  abdomen: 'Abdomen',
  back: 'Back',
  left_arm: 'Left arm',
  right_arm: 'Right arm',
  left_leg: 'Left leg',
  right_leg: 'Right leg',
};

export const kinds = [
  { value: 'gunshot', label: 'Gunshot' },
  { value: 'stab', label: 'Stab' },
  { value: 'fracture', label: 'Fracture' },
  { value: 'burn', label: 'Burn' },
  { value: 'laceration', label: 'Laceration' },
  { value: 'blunt', label: 'Blunt trauma' },
  { value: 'other', label: 'Other' },
];

export const severities = [
  { value: 'minor', label: 'Minor' },
  { value: 'moderate', label: 'Moderate' },
  { value: 'severe', label: 'Severe' },
  { value: 'critical', label: 'Critical' },
];

const rank = { minor: 1, moderate: 2, severe: 3, critical: 4 };

export function labelOf(list, value) {
  return list.find((x) => x.value === value)?.label || value || '';
}

export function typeTone(t) {
  return t === 'death' ? 'danger' : t === 'transport' ? 'info' : t === 'checkup' ? 'ok' : t === 'treatment' ? 'ems' : 'muted';
}

export function outcomeTone(o) {
  return o === 'deceased' ? 'danger' : o === 'admitted' ? 'accent' : o === 'transported' ? 'info' : o === 'treated_released' ? 'ok' : 'muted';
}

export function severityTone(s) {
  return s === 'critical' ? 'p1' : s === 'severe' ? 'danger' : s === 'moderate' ? 'accent' : 'info';
}

export function worst(list) {
  let best = null;
  for (const i of list) if (!best || rank[i.severity] > rank[best]) best = i.severity;
  return best;
}

export function ageOf(dob) {
  if (!dob) return null;
  const b = new Date(dob);
  if (Number.isNaN(b.getTime())) return null;
  const n = new Date();
  let a = n.getFullYear() - b.getFullYear();
  if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a -= 1;
  return a;
}
