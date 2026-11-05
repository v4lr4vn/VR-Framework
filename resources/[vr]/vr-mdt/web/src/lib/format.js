import { clock } from './state.svelte.js';

export function ago(unix, now = clock.now) {
  if (!unix) return '';
  const s = Math.max(0, Math.floor(now - unix));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}:${String(s % 60).padStart(2, '0')}`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ${m % 60}m`;
  return `${Math.floor(h / 24)}d`;
}

export function agoWords(unix, now = clock.now) {
  if (!unix) return '';
  const s = Math.max(0, Math.floor(now - unix));
  if (s < 45) return 'just now';
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} h ago`;
  const d = Math.round(h / 24);
  if (d < 30) return `${d} d ago`;
  return date(unix);
}

export function time(unix) {
  if (!unix) return '';
  const d = new Date(unix * 1000);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function date(unix) {
  if (!unix) return '';
  const d = new Date(unix * 1000);
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

export function dateTime(unix) {
  if (!unix) return '';
  return `${date(unix)}, ${time(unix)}`;
}

export function money(n) {
  return `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;
}

export function months_(n) {
  n = Number(n) || 0;
  return n === 1 ? '1 month' : `${n} months`;
}

export function distance(a, b) {
  if (!a || !b) return null;
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

export function metres(m) {
  if (m == null) return '';
  if (m < 1000) return `${Math.round(m / 10) * 10} m`;
  return `${(m / 1000).toFixed(1)} km`;
}

export function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
}

export function age(birthdate, now = clock.now) {
  if (!birthdate) return null;
  const b = new Date(birthdate);
  if (Number.isNaN(b.getTime())) return null;
  const n = new Date(now * 1000);
  let a = n.getFullYear() - b.getFullYear();
  if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a -= 1;
  return a;
}
