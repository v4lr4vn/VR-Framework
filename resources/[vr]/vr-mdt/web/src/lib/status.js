const tones = {
  available: 'ok',
  enroute: 'accent',
  onscene: 'info',
  transport: 'info',
  busy: 'muted',
  break: 'muted',
};

export function statusTone(id) {
  return tones[id] || 'muted';
}

export function priorityTone(p) {
  return p === 1 ? 'p1' : p === 2 ? 'p2' : 'p3';
}

export function deptTone(dept) {
  return dept === 'ems' ? 'ems' : dept === 'doj' ? 'doj' : 'info';
}
