export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export const day = (t) => {
  const d = new Date((Number(t) || 0) * 1000);
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
};

export const timeLeft = (t, now = Date.now() / 1000) => {
  const s = Math.round(Number(t) - now);
  const a = Math.abs(s);
  const days = Math.floor(a / 86400);
  const text = days >= 1 ? `${days} day${days === 1 ? '' : 's'}` : a >= 3600 ? `${Math.floor(a / 3600)}h` : `${Math.max(1, Math.floor(a / 60))}m`;
  return s > 0 ? `${text} left` : `Expired ${text} ago`;
};

export const wait = (s) => {
  s = Math.max(0, Math.round(Number(s) || 0));
  if (s >= 60) return `${Math.ceil(s / 60)} min`;
  return `${s} s`;
};

export const STATUS = {
  active: { label: 'Active', tone: 'ok', icon: 'fa-circle-check' },
  expired: { label: 'Expired', tone: 'warn', icon: 'fa-clock' },
  revoked: { label: 'Revoked', tone: 'danger', icon: 'fa-ban' },
};

export const ERR = {
  not_ready: 'City Hall is not open yet, try again in a moment',
  no_character: 'Choose a character first',
  too_far: 'You walked away from the desk',
  slow_down: 'Slow down a little',
  bad_request: 'Something went wrong, try again',
  failed: 'Something went wrong, try again',
  disabled: 'That service is closed',
  no_money: "You can't afford that",
  not_entitled: 'You do not hold that licence',
  carrying: 'You already have one on you',
  cooldown: 'Please wait a little before asking again',
  no_room: 'You have no room to carry it',
  no_such_job: 'That job is not available right now',
  already: 'You already work there',
  job_limit: 'You already hold too many jobs. Quit one first.',
  not_held: 'You do not hold that job',
  bad_name: 'Pick a business name of at least 3 characters',
  name_taken: 'Another business already uses that name',
  limit: 'You already hold the most business licences allowed',
  not_found: 'That licence was not found',
  too_early: 'It is too early to renew this licence',
  revoked: 'This licence was revoked. Contact the council.',
  not_active: 'Only an active licence can be reprinted',
  no_such_type: 'That licence type is no longer offered',
};

export const errorText = (code) => ERR[code] || ERR.failed;
