// Dates on the game's clock. A date is the text 'YYYY-MM-DD'.
// A stamp counts minutes since 2000-01-01 00:00. This does the same sums as the server (shared/util.lua) so both sides agree.
import { t } from './i18n.js';

export const pad = (n) => String(n).padStart(2, '0');
export const iso = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;

const leap = (y) => (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
export const daysIn = (y, m) => [31, leap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];

// { y, m, d } or null (only real dates from 2000 to 2100).
export function parse(text) {
  const x = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(text ?? ''));
  if (!x) return null;
  const y = +x[1], m = +x[2], d = +x[3];
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > daysIn(y, m)) return null;
  return { y, m, d };
}

// Days since 2000-01-01.
export function dayNumber(y, m, d) {
  if (m <= 2) y -= 1;
  const era = Math.floor(y / 400);
  const yoe = y - era * 400;
  const doy = Math.floor((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468 - 10957;
}

export function stamp(date, minute = 0) {
  const p = parse(date);
  return p ? dayNumber(p.y, p.m, p.d) * 1440 + minute : null;
}

// 0 = Sunday.
export function weekday(y, m, d) {
  return (((dayNumber(y, m, d) + 6) % 7) + 7) % 7; // 2000-01-01 was a Saturday (6)
}

export function addDays(text, n) {
  const p = parse(text);
  if (!p) return text;
  let { y, m, d } = p;
  d += n;
  while (d > daysIn(y, m)) {
    d -= daysIn(y, m);
    m += 1;
    if (m > 12) { m = 1; y += 1; }
  }
  while (d < 1) {
    m -= 1;
    if (m < 1) { m = 12; y -= 1; }
    d += daysIn(y, m);
  }
  return iso(Math.min(2100, Math.max(2000, y)), m, d);
}

export function addMonths(y, m, n) {
  const idx = y * 12 + (m - 1) + n;
  return { y: Math.floor(idx / 12), m: (idx % 12) + 1 };
}

// Rows of seven days for a month. Each cell: { date, day, inMonth }. weekStart: 0 = Sunday, 1 = Monday.
export function monthGrid(y, m, weekStart = 1) {
  const first = weekday(y, m, 1);
  const lead = (first - weekStart + 7) % 7;
  const total = Math.ceil((lead + daysIn(y, m)) / 7) * 7;
  const start = addDays(iso(y, m, 1), -lead);
  const cells = [];
  for (let i = 0; i < total; i++) {
    const date = addDays(start, i);
    const p = parse(date) ?? { y, m, d: 1 };
    cells.push({ date, day: p.d, inMonth: p.m === m && p.y === y });
  }
  const rows = [];
  for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
  return rows;
}

export const todayOf = (clock) => iso(clock.year, clock.month, clock.day);
export const nowStamp = (clock) => stamp(todayOf(clock), clock.h * 60 + clock.m);

// "09:30" or "9:30 AM".
export function timeText(minute, time24) {
  const h = Math.floor(minute / 60), m = minute % 60;
  if (time24) return `${pad(h)}:${pad(m)}`;
  return `${h % 12 || 12}:${pad(m)} ${h >= 12 ? 'PM' : 'AM'}`;
}

// "Thu 22 Oct" and "Thursday 22 October 2026".
export function dayText(text, long = false) {
  const p = parse(text);
  if (!p) return text;
  const dow = weekday(p.y, p.m, p.d);
  const day = t(`day.${dow}`);
  const month = t(`month.${p.m}`);
  return long ? `${day} ${p.d} ${month} ${p.y}` : `${day.slice(0, 3)} ${p.d} ${month.slice(0, 3)}`;
}

export function monthText(y, m) {
  return `${t(`month.${m}`)} ${y}`;
}
