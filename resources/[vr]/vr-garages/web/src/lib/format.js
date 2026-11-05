export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;

export const miles = (metres) => {
  const m = (Number(metres) || 0) / 1609.34;
  return `${m < 10 ? m.toFixed(1) : Math.round(m).toLocaleString('en-US')} mi`;
};

const pad = (n) => String(n).padStart(2, '0');

export const until = (t, now = Date.now() / 1000) => {
  const s = Math.round(t - now);
  if (s <= 0) return 'now';
  if (s < 3600) return `in ${Math.max(1, Math.floor(s / 60))}m`;
  return `in ${Math.floor(s / 3600)}h ${pad(Math.floor((s % 3600) / 60))}m`;
};

export const ago = (t, now = Date.now() / 1000) => {
  const s = Math.max(0, Math.round(now - t));
  if (s < 3600) return `${Math.max(1, Math.floor(s / 60))}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
};

export const STATUS = {
  stored: { label: 'Parked', tone: 'ok', icon: 'fa-square-parking' },
  out: { label: 'Out', tone: 'info', icon: 'fa-road' },
  lost: { label: 'Not recovered', tone: 'warn', icon: 'fa-circle-question' },
  impounded: { label: 'Impounded', tone: 'danger', icon: 'fa-truck-ramp-box' },
  held: { label: 'Held by bank', tone: 'danger', icon: 'fa-building-columns' },
};

export const ERR = {
  no_garage: 'This garage no longer exists',
  no_access: 'You cannot use this garage',
  too_far: 'You walked away from the garage',
  no_vehicle: 'Vehicle not found',
  not_yours: 'This is not your vehicle',
  wrong_category: 'That vehicle cannot be kept here',
  out: 'That vehicle is already out',
  lost: 'Recover it from the impound lot',
  impounded: 'It is at the impound lot',
  held: 'The bank is holding this vehicle',
  no_money: "You can't afford that",
  no_space: 'Every spot is blocked. Move the cars out of the way.',
  spawn_failed: 'The vehicle could not be brought out, try again',
  busy: 'Please wait a moment',
  not_boss: 'Only a boss can do that',
  must_be_stored: 'Park the vehicle first',
  not_ready: 'It cannot be released yet',
  slow_down: 'Slow down a little',
  failed: 'Something went wrong, try again',
  low_grade: 'Your rank is too low for that vehicle',
  limit: 'You already have a job vehicle out. Park it first.',
  job_garage: 'Job vehicles go back to their own job garage',
  job_only: 'Job garages only hand out job vehicles. Personal cars go in a public garage.',
};

export const errorText = (code) => ERR[code] || ERR.failed;
