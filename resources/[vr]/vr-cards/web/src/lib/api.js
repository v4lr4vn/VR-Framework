import { isGame, post } from './nui.js';
import { mockCall } from './mock.js';

export async function call(action, data = {}) {
  if (!isGame) return mockCall(action, data);
  const r = await post('api', { action, data });
  return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
}

export async function nui(name, data = {}) {
  if (!isGame) return mockCall(`nui:${name}`, data);
  return post(name, data);
}

export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;
export const pad = (n, l = 3) => String(Number(n) || 0).padStart(l, '0');

const ERR = {
  no_pack: 'That pack is gone',
  no_room: 'Make room in your pockets first',
  no_card: 'You do not have that card any more',
  no_binder: 'You need the binder on you',
  too_far: 'Head back to the card shop',
  no_money: 'Not enough money',
  bad_count: 'Pick how many you want',
  bad_cards: 'Pick the cards first',
  already_graded: 'That card is already graded',
  nothing_ready: 'Nothing is ready to collect yet',
  slot_taken: 'That pocket is taken',
  empty_slot: 'That pocket is empty',
  bad_slot: 'Pick a pocket',
  bad_title: 'Give the binder a name',
  slow_down: 'Slow down a little',
  failed: 'Something went wrong, try again',
};

export const errorText = (code) => ERR[code] || ERR.failed;
