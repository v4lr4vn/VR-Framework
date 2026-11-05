export const memberStatus = {
  active: { label: 'Active', tone: 'ok' },
  loa: { label: 'Leave of absence', short: 'Leave', tone: 'p2' },
  suspended: { label: 'Suspended', tone: 'danger' },
};

export function statusLabel(id, short = false) {
  const s = memberStatus[id];
  if (!s) return id;
  return short && s.short ? s.short : s.label;
}

export function statusTone(id) {
  return memberStatus[id]?.tone || 'muted';
}

export const recommendations = [
  { id: 'continue', label: 'Continue', long: 'Continue to the next phase', tone: 'ok' },
  { id: 'extend', label: 'Extend phase', long: 'Extend the current phase', tone: 'p2' },
  { id: 'release', label: 'Release', long: 'Release from the program', tone: 'danger' },
  { id: 'signoff', label: 'Ready for sign-off', long: 'Ready to work solo', tone: 'info' },
];

export function recommendation(id) {
  return recommendations.find((r) => r.id === id) || { id, label: id, tone: 'muted' };
}

export const ratingWords = ['', 'Unacceptable', 'Needs work', 'Acceptable', 'Good', 'Superior'];

export function scoreTone(v) {
  if (v == null) return 'muted';
  if (v >= 4) return 'ok';
  if (v >= 3) return 'info';
  if (v >= 2) return 'p2';
  return 'danger';
}

export const iaStatus = {
  open: { label: 'Open', tone: 'p2' },
  investigating: { label: 'Investigating', tone: 'info' },
  sustained: { label: 'Sustained', tone: 'danger' },
  not_sustained: { label: 'Not sustained', tone: 'muted' },
  exonerated: { label: 'Exonerated', tone: 'ok' },
  unfounded: { label: 'Unfounded', tone: 'muted' },
  closed: { label: 'Closed', tone: 'muted' },
};

export const iaOutcomes = [
  { id: 'sustained', label: 'Sustained', hint: 'The allegation happened and broke policy.' },
  { id: 'not_sustained', label: 'Not sustained', hint: 'Not enough evidence either way.' },
  { id: 'exonerated', label: 'Exonerated', hint: 'It happened but was lawful and within policy.' },
  { id: 'unfounded', label: 'Unfounded', hint: "It didn't happen." },
  { id: 'closed', label: 'Closed', hint: 'Withdrawn or closed for another reason.' },
];

export function iaActive(status) {
  return status === 'open' || status === 'investigating';
}

export function fileNo(id) {
  return `IA-${String(id).padStart(4, '0')}`;
}

const auditNames = {
  'roster.hire': 'Hired',
  'roster.fire': 'Let go',
  'roster.grade': 'Rank changed',
  'roster.callsign': 'Callsign changed',
  'roster.badge': 'Badge changed',
  'roster.divisions': 'Divisions changed',
  'roster.notes': 'Notes edited',
  'roster.status': 'Status changed',
  'permissions.set': 'Permission changed',
  'permissions.reset': 'Permissions reset',
  'bulletin.create': 'Bulletin posted',
  'bulletin.edit': 'Bulletin edited',
  'bulletin.delete': 'Bulletin deleted',
  'fto.evaluate': 'Trainee evaluated',
  'fto.signoff': 'Trainee signed off',
  'ia.create': 'IA file opened',
  'ia.edit': 'IA file edited',
  'ia.note': 'IA note added',
  'ia.assign': 'IA file assigned',
  'ia.close': 'IA file closed',
  'dispatch.assign': 'Unit assigned',
  'dispatch.unassign': 'Unit removed',
  'dispatch.close': 'Call closed',
  'dispatch.reopen': 'Call reopened',
  'dispatch.create': 'Call created',
  'units.setStatus': 'Unit status set',
};

export function auditName(action) {
  return auditNames[action] || action;
}

export function auditTone(action) {
  if (action === 'roster.fire' || action.endsWith('.delete')) return 'danger';
  if (action.startsWith('permissions.')) return 'accent';
  if (action === 'roster.hire') return 'ok';
  if (action.startsWith('ia.')) return 'doj';
  return 'muted';
}

export function hours(h) {
  const n = Number(h) || 0;
  return n >= 100 ? `${Math.round(n)} h` : `${n.toFixed(1)} h`;
}

export function duration(seconds) {
  const s = Math.max(0, Math.floor(Number(seconds) || 0));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h === 0) return `${m}m`;
  return `${h}h ${String(m).padStart(2, '0')}m`;
}

export function inDays(unix, now) {
  const s = unix - now;
  if (s <= 0) return 'now';
  const h = Math.round(s / 3600);
  if (h < 24) return `${Math.max(1, h)} h`;
  return `${Math.round(h / 24)} d`;
}
