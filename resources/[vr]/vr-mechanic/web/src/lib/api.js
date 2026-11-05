import { isGame, post } from './nui.js';
import { mockCall, mockWheels } from './mock.js';

export async function call(action, data = {}) {
  if (!isGame) return mockCall(action, data);
  const r = await post('api', { action, data });
  return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
}

export async function nui(name, data = {}) {
  if (!isGame) {
    if (name === 'tuneWheels') return mockWheels(data.type);
    return true;
  }
  return post(name, data);
}

export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;

export const clone = (v) => (v === undefined ? v : JSON.parse(JSON.stringify(v)));

export const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

export const hex = (rgb) => (Array.isArray(rgb) ? `#${rgb.map((n) => Math.max(0, Math.min(255, n | 0)).toString(16).padStart(2, '0')).join('')}` : '#000000');

export const rgbOf = (h) => {
  const m = /^#?([0-9a-f]{6})$/i.exec((h || '').trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};

const ERR = {
  not_mechanic: 'Clock in at a workshop first',
  no_vehicle: 'The vehicle is gone',
  too_far: 'Get closer',
  in_vehicle: 'Get out of the vehicle first',
  no_item: 'You do not have the part for that',
  not_needed: 'That does not need fixing',
  not_in_workshop: 'Bring the vehicle into your workshop',
  bad_changes: 'Something in the order is not valid',
  nothing_to_do: 'Pick something to fit first',
  nothing_to_bill: 'There is nothing to charge for',
  no_customer: 'Pick a customer',
  bad_amount: 'Enter a valid amount',
  customer_busy: 'That person already has a bill open',
  bill_pending: 'Wait for your last bill to be answered',
  no_bill: 'That bill is gone',
  expired: 'The bill expired',
  no_mechanic: 'The mechanic is no longer available',
  no_money: 'Not enough money',
  not_allowed: 'You cannot use the company account',
  no_company_money: 'The company account is short',
  bad_item: 'That part is not sold here',
  bad_count: 'Pick how many you need',
  cant_carry: 'You cannot carry that',
  slow_down: 'Slow down a little',
  failed: 'Something went wrong, try again',
  not_your_vehicle: 'You can only order work for your own vehicle',
  too_many_orders: 'You already have the most open orders allowed',
  no_order: 'That order no longer exists',
  not_yours: 'This order is for someone else',
  car_not_here: 'Bring the car to the workshop and stand next to it',
  customer_away: 'The customer needs to be at the workshop to pay',
  not_paid: 'The order has not been paid yet',
  already_done: 'That part is already fitted',
  cannot_cancel: 'This order can no longer be cancelled',
  bad_status: 'This order is not waiting for a bill',
};

export const errorText = (code) => ERR[code] || ERR.failed;
