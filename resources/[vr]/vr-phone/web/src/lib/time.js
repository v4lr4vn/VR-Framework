import { t } from './i18n.js';

export const pad = (n) => String(n).padStart(2, '0');

// "14:05" or "2:05" (12 hour). Use ampm() for the AM / PM part.
export function clockText(c, time24) {
  if (time24) return `${pad(c.h)}:${pad(c.m)}`;
  return `${c.h % 12 || 12}:${pad(c.m)}`;
}

export function hoursText(c, time24) {
  return time24 ? pad(c.h) : String(c.h % 12 || 12);
}

export function ampm(c) {
  return c.h >= 12 ? 'PM' : 'AM';
}

// "Thursday, 22 October"
export function dateText(c, short = false) {
  const day = t(`day.${c.dow}`);
  const month = t(`month.${c.month}`);
  const dayName = short ? day.slice(0, 3) : day;
  const monthName = short ? month.slice(0, 3) : month;
  return `${dayName}, ${c.day} ${monthName}`;
}

// "now", "5m", "3h", "2d" from a millisecond timestamp
export function ago(ts, now) {
  const s = Math.max(0, Math.floor((now - ts) / 1000));
  if (s < 45) return t('time.now');
  const m = Math.round(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h`;
  return `${Math.round(h / 24)}d`;
}

// "1:05" or "12:34" or "1:02:03" from a number of seconds
export function durationText(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return h > 0 ? `${h}:${pad(m)}:${pad(s % 60)}` : `${m}:${pad(s % 60)}`;
}

// The time of day of a unix timestamp (seconds), in the player's own clock style. Messages and calls use real time.
export function stampTime(ts, time24) {
  const d = new Date(ts * 1000);
  const h = d.getHours();
  const m = pad(d.getMinutes());
  if (time24) return `${pad(h)}:${m}`;
  return `${h % 12 || 12}:${m} ${h >= 12 ? 'PM' : 'AM'}`;
}

// "Today", "Yesterday", or "Thu 22 Oct" for a unix timestamp (seconds)
export function stampDay(ts, nowMs) {
  const d = new Date(ts * 1000);
  const n = new Date(nowMs);
  const start = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const days = Math.round((start(n) - start(d)) / 86400000);
  if (days <= 0) return t('time.today');
  if (days === 1) return t('time.yesterday');
  return `${t(`day.${d.getDay()}`).slice(0, 3)} ${d.getDate()} ${t(`month.${d.getMonth() + 1}`).slice(0, 3)}`;
}
