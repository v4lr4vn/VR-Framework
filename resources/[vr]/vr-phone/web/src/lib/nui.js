// The bridge to the game. Inside FiveM, `post` calls the Lua client. In a normal browser (npm run dev)
// there is no game, so a fake client from src/dev/mock.js answers instead.

export const inGame = typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function';
const resource = inGame ? window.GetParentResourceName() : 'vr-phone';

let mock = null;
export function installMock(fn) {
  mock = fn;
}

export async function post(name, data = {}) {
  if (!inGame) return mock ? mock(name, data) : null;
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

// Messages from Lua (SendNUIMessage) arrive as { action, data }.
const handlers = {};

export function on(action, fn) {
  handlers[action] = fn;
}

// Takes a handler away again (an app that listens only while it is open).
export function off(action, fn) {
  if (!fn || handlers[action] === fn) delete handlers[action];
}

export function dispatch(action, data) {
  const fn = handlers[action];
  if (fn) fn(data);
}

if (typeof window !== 'undefined') {
  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg && typeof msg.action === 'string') dispatch(msg.action, msg.data);
  });
}
