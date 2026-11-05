// Things one app asks another app to do: message a number, add a number to the contacts.
import { openApp, phone } from './store.svelte.js';
import { comms } from './comms.svelte.js';

export function messageTo(number) {
  comms.target = number;
  if (phone.app === 'messages') return;
  openApp('messages');
}

export function addContact(number) {
  comms.draft = { number };
  if (phone.app === 'contacts') return;
  openApp('contacts');
}
