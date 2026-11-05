const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vr-hud';

export function post(name, data = {}) {
  return fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

export function on(handler) {
  const fn = (e) => handler(e.data);
  window.addEventListener('message', fn);
  return () => window.removeEventListener('message', fn);
}
