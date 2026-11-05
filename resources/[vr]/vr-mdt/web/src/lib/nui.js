const loadMock = import.meta.env.DEV || import.meta.env.VITE_MOCK === '1' ? () => import('../mock/index.js') : null;

export const inGame = typeof window.GetParentResourceName === 'function';
const resource = inGame ? window.GetParentResourceName() : 'vr-mdt';

const pushListeners = new Map();
const messageListeners = new Map();

function emit(map, key, payload) {
  const list = map.get(key);
  if (!list) return;
  for (const fn of [...list]) {
    try {
      fn(payload);
    } catch (err) {
      console.error(err);
    }
  }
}

function subscribe(map, key, fn) {
  if (!map.has(key)) map.set(key, new Set());
  map.get(key).add(fn);
  return () => map.get(key)?.delete(fn);
}

export function on(name, fn) {
  return subscribe(pushListeners, name, fn);
}

export function onMessage(type, fn) {
  return subscribe(messageListeners, type, fn);
}

export function dispatchLocal(message) {
  if (!message || typeof message !== 'object') return;
  if (message.type === 'push') emit(pushListeners, message.name, message.payload);
  else emit(messageListeners, message.type, message);
}

window.addEventListener('message', (event) => dispatchLocal(event.data));

export async function callback(name, data = {}) {
  if (!inGame) {
    const m = await loadMock?.();
    return m ? m.mockCallback(name, data) : null;
  }
  try {
    const res = await fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return await res.json();
  } catch {
    return null;
  }
}

export async function api(action, data = {}) {
  if (!inGame) {
    const m = await loadMock?.();
    return m ? m.mockRequest(action, data) : { ok: false, error: 'server_error' };
  }
  const res = await callback('req', { action, data });
  if (!res || typeof res !== 'object') return { ok: false, error: 'server_error' };
  return res;
}
