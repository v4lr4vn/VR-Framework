export const statusLabels = {
  filed: 'Filed',
  scheduled: 'Scheduled',
  in_session: 'In session',
  verdict: 'Verdict',
  closed: 'Closed',
  dismissed: 'Dismissed',
};

const statusTones = {
  filed: 'muted',
  scheduled: 'info',
  in_session: 'accent',
  verdict: 'doj',
  closed: 'ok',
  dismissed: 'muted',
};

export const verdictLabels = {
  guilty: 'Guilty',
  not_guilty: 'Not guilty',
  dismissed: 'Dismissed',
  plea: 'Plea agreement',
};

const verdictTones = {
  guilty: 'danger',
  not_guilty: 'ok',
  dismissed: 'muted',
  plea: 'accent',
};

export const roleLabels = {
  judge: 'Presiding judge',
  prosecutor: 'Prosecution',
  defense: 'Defense',
};

export function statusTone(s) {
  return statusTones[s] || 'muted';
}

export function verdictTone(v) {
  return verdictTones[v] || 'muted';
}

const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function hearingParts(unix, now = Math.floor(Date.now() / 1000)) {
  if (!unix) return null;
  const d = new Date(unix * 1000);
  const today = new Date(now * 1000);
  const start = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime() / 1000;
  const diff = Math.floor((unix - start) / 86400);
  const rel = diff === 0 ? 'Today' : diff === 1 ? 'Tomorrow' : diff > 1 && diff < 7 ? `In ${diff} days` : null;
  return {
    day: days[d.getDay()],
    date: `${d.getDate()} ${months[d.getMonth()]}`,
    time: `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`,
    rel,
  };
}

export function toInputs(unix) {
  const d = unix ? new Date(unix * 1000) : new Date(Date.now() + 86400000);
  if (!unix) d.setHours(10, 0, 0, 0);
  const p = (n) => String(n).padStart(2, '0');
  return { date: `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`, time: `${p(d.getHours())}:${p(d.getMinutes())}` };
}

export function fromInputs(date, time) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '') || !/^\d{2}:\d{2}$/.test(time || '')) return null;
  const [y, m, d] = date.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  const t = new Date(y, m - 1, d, hh, mm, 0, 0).getTime();
  return Number.isNaN(t) ? null : Math.floor(t / 1000);
}
