import { fail } from '../index.js';
import { push } from '../state.js';
import { inmates, released, person, me, now } from './records_data.js';

const PER_MONTH = 60;
const loadedAt = now();

function left(i) {
  const base = i.base ?? loadedAt;
  return i.online ? Math.max(0, i.remaining - (now() - base)) : i.remaining;
}

function view(i) {
  const remaining = left(i);
  return { ...i, remaining, monthsLeft: Math.ceil(remaining / PER_MONTH), mugshot: person(i.cid)?.mugshot || null };
}

export default function (reg, regCallback, s) {
  reg('prison.list', () => {
    if (s.dept !== 'police') return fail('not_allowed');
    return {
      inmates: inmates.map(view).sort((a, b) => a.remaining - b.remaining),
      released: released.map((r) => ({ ...r, mugshot: person(r.cid)?.mugshot || null })),
      secondsPerMonth: PER_MONTH,
      maxMonths: 300,
      serverTime: now(),
    };
  });
  reg('prison.release', (d) => {
    if (s.dept !== 'police' || !s.boss) return fail('not_allowed');
    const idx = inmates.findIndex((i) => i.cid === d.cid);
    if (idx < 0) return fail('not_in_prison');
    const [i] = inmates.splice(idx, 1);
    const reason = `Released early by ${me(s.dept).name}${d.reason ? `: ${d.reason}` : ''}`;
    released.unshift({ cid: i.cid, name: i.name, months: i.months, reason: i.reason, by_name: i.byName, started_at: i.since, released_at: now(), release_reason: reason });
    push('prison:changed', { cid: i.cid });
    return { cid: i.cid };
  });
  reg('prison.adjust', (d) => {
    if (s.dept !== 'police' || !s.boss) return fail('not_allowed');
    const i = inmates.find((x) => x.cid === d.cid);
    if (!i) return fail('not_in_prison');
    const months = Number(d.months);
    if (!Number.isInteger(months) || months < 1 || months > 300) return fail('bad_request');
    i.remaining = months * PER_MONTH;
    i.base = now();
    if (months > i.months) i.months = months;
    push('prison:changed', { cid: i.cid });
    return view(i);
  });

  const params = new URLSearchParams(window.location.search);
  if (params.get('jailed') === '1') {
    setTimeout(() => window.postMessage({ type: 'prison', active: true, seconds: 1022, months: 24, left: 18, reason: 'Assault with a deadly weapon, resisting arrest' }, '*'), 200);
  }
}
