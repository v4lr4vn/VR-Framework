export const groups = {
  police: ['Operations', 'Records', 'Department'],
  ems: ['Operations', 'Patients', 'Department'],
  doj: ['Court', 'Records', 'Department'],
  dispatch: ['Operations', 'Records', 'Department'],
};

export const routes = [
  { id: 'dispatch', label: 'Dispatch', icon: 'radio', group: 'Operations', depts: ['police', 'ems', 'dispatch'] },
  { id: 'radio', label: 'Radio', icon: 'headphones', group: 'Operations', depts: ['dispatch', 'police', 'ems'] },
  { id: 'units', label: 'Units', icon: 'units', group: 'Operations', depts: ['police', 'ems', 'dispatch'] },
  { id: 'bulletin', label: 'Bulletin', icon: 'bulletin', group: { police: 'Operations', ems: 'Operations', doj: 'Department', dispatch: 'Operations' }, depts: ['police', 'ems', 'doj', 'dispatch'] },
  { id: 'court', label: 'Court cases', icon: 'court', group: 'Court', depts: ['doj'], perm: 'court.view' },
  { id: 'warrants', label: 'Warrants & BOLOs', icon: 'alert', group: { police: 'Records', doj: 'Court', dispatch: 'Records' }, depts: ['police', 'doj', 'dispatch'] },
  { id: 'citizens', label: 'Citizens', icon: 'person', group: 'Records', depts: ['police', 'doj', 'dispatch'], perm: 'records.view' },
  { id: 'vehicles', label: 'Vehicles', icon: 'car', group: 'Records', depts: ['police', 'doj', 'dispatch'], perm: 'records.view' },
  { id: 'weapons', label: 'Weapons', icon: 'crosshair', group: 'Records', depts: ['police', 'doj'], perm: 'records.view' },
  { id: 'reports', label: 'Reports', icon: 'report', group: 'Records', depts: ['police', 'doj', 'dispatch'], perm: ['reports.create', 'reports.view'] },
  { id: 'cases', label: 'Cases & Evidence', icon: 'folder', group: 'Records', depts: ['police', 'doj', 'dispatch'], perm: 'cases.view' },
  { id: 'penal', label: 'Penal Code', icon: 'scale', group: 'Records', depts: ['police', 'doj'] },
  { id: 'prison', label: 'Prison', icon: 'lock', group: 'Records', depts: ['police'] },
  { id: 'patients', label: 'Patients', icon: 'heart', group: 'Patients', depts: ['ems'], perm: 'patients.view' },
  { id: 'medreports', label: 'Medical reports', icon: 'report', group: 'Patients', depts: ['ems'], perm: 'medreports.create' },
  { id: 'roster', label: 'Roster', icon: 'list', group: 'Department', depts: ['police', 'ems', 'doj', 'dispatch'], perm: 'roster.view' },
  { id: 'fto', label: 'Training', icon: 'grad', group: 'Department', depts: ['police'], perm: 'fto.view' },
  { id: 'ia', label: 'Internal Affairs', icon: 'shieldcheck', group: 'Department', depts: ['police'], perm: 'ia.view' },
  { id: 'cameras', label: 'Cameras & Bodycams', icon: 'camera', group: 'Department', depts: ['police'], perm: ['cameras.view', 'bodycams.view'] },
];

export function groupOf(route, dept) {
  return typeof route.group === 'string' ? route.group : route.group[dept];
}
