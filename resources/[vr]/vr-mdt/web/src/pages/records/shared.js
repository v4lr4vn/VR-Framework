const flagTones = {
  'Armed and dangerous': 'danger',
  'Violent towards officers': 'danger',
  'Gang affiliated': 'accent',
  'Known to flee': 'accent',
  'Mental health concern': 'info',
  Parolee: 'info',
  Stolen: 'danger',
  BOLO: 'accent',
  Impounded: 'info',
  'Suspended registration': 'p2',
  'Used in crime': 'danger',
};

export function flagTone(flag) {
  return flagTones[flag] || 'muted';
}

const warrantTones = { pending: 'accent', active: 'danger', served: 'ok', denied: 'muted', revoked: 'muted', expired: 'muted' };
const warrantLabels = { pending: 'Pending', active: 'Active', served: 'Served', denied: 'Denied', revoked: 'Revoked', expired: 'Expired' };

export function warrantTone(status) {
  return warrantTones[status] || 'muted';
}

export function warrantLabel(status) {
  return warrantLabels[status] || status;
}

const vehicleStates = { 0: 'Out', 1: 'In garage', 2: 'Impounded' };

export function vehicleState(n) {
  return vehicleStates[n] ?? 'Unknown';
}

export function vehicleStateTone(n) {
  return n === 2 ? 'danger' : n === 0 ? 'info' : 'muted';
}

export function genderLabel(g) {
  if (g === 0 || g === '0') return 'Male';
  if (g === 1 || g === '1') return 'Female';
  return typeof g === 'string' && g ? g : '';
}

export function clockText(seconds) {
  const s = Math.max(0, Math.floor(seconds || 0));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  const mm = String(m).padStart(2, '0');
  const ss = String(r).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

export function chargeText(c) {
  return c.count > 1 ? `${c.title} ×${c.count}` : c.title;
}

export const boloKinds = [
  { id: 'person', label: 'Person', icon: 'person' },
  { id: 'vehicle', label: 'Vehicle', icon: 'car' },
  { id: 'other', label: 'Other', icon: 'tag' },
];

export function boloIcon(kind) {
  return boloKinds.find((k) => k.id === kind)?.icon || 'tag';
}

export const remembered = { citizens: '', vehicles: '', weapons: '' };

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function dobText(dob) {
  const m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(String(dob || ''));
  if (!m) return String(dob || '');
  return `${Number(m[3])} ${monthNames[Number(m[2]) - 1] || m[2]} ${m[1]}`;
}
