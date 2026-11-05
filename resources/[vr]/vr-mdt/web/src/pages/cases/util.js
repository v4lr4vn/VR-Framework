export const statuses = [
  { value: 'open', label: 'Open', tone: 'ok' },
  { value: 'cold', label: 'Cold', tone: 'info' },
  { value: 'closed', label: 'Closed', tone: 'muted' },
];

export function statusLabel(s) {
  return statuses.find((x) => x.value === s)?.label || s;
}

export function statusTone(s) {
  return statuses.find((x) => x.value === s)?.tone || 'muted';
}

export const caseRoles = [
  { value: 'suspect', label: 'Suspect' },
  { value: 'poi', label: 'Person of interest' },
  { value: 'victim', label: 'Victim' },
  { value: 'witness', label: 'Witness' },
];

export function caseRoleLabel(r) {
  return caseRoles.find((x) => x.value === r)?.label || r;
}
