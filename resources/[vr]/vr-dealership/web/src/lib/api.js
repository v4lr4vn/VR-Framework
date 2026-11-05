import { isGame, post } from './nui.js';
import { mockCall, mockStats } from './mock.js';

export async function call(action, data = {}) {
  if (!isGame) return mockCall(action, data);
  const r = await post('api', { action, data });
  return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
}

export async function stats(models) {
  if (!isGame) return mockStats(models);
  return (await post('stats', { models })) || {};
}

export const nui = (name, data) => (isGame ? post(name, data) : Promise.resolve(true));

export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;

const ERR = {
  too_far: 'Get closer to the desk',
  not_sold_here: 'That vehicle is not sold here',
  staff_on_duty: 'A salesperson is on duty. Ask them for a deal.',
  no_money: "You can't afford that",
  not_boss: 'Only a boss can buy for the company',
  no_finance: 'Finance is not available right now',
  declined: 'Finance declined',
  too_large: 'That is more than the bank will lend you. Put more down.',
  too_small: 'There is nothing left to finance',
  max_loans: 'You already have the most car finance the bank allows',
  in_collections: 'Clear your debt with the bank first',
  disabled: 'Finance is not available right now',
  failed: 'Something went wrong, try again',
  no_garages: 'The garage system is offline',
  already_driving: 'You are already on a test drive',
  cooldown: 'Wait a moment before the next test drive',
  spot_blocked: 'Something is blocking the test drive spot',
  spawn_failed: 'The car could not be brought round, try again',
  not_staff: 'Clock in for sales first',
  no_customer: 'Pick a customer',
  bad_price: 'That price is outside what you can offer',
  no_offer: 'That offer is gone',
  expired: 'The offer expired',
  no_seller: 'The salesperson is no longer available',
  not_allowed: 'You cannot change the display',
  bad_slot: 'Pick a display spot',
  slow_down: 'Slow down a little',
};

export const errorText = (code) => ERR[code] || ERR.failed;
export const reasonText = (code) => ERR[code] || code;
