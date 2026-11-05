import { isGame, post } from './nui.js';
import { mockCall } from './mock.js';

export async function call(action, data = {}) {
  if (!isGame) return mockCall(action, data);
  const res = await post('api', { action, data });
  return res && typeof res === 'object' ? res : { ok: false, error: 'failed' };
}

export function close() {
  if (isGame) post('close');
}

export function trace(data) {
  if (isGame) post('trace', data);
}
