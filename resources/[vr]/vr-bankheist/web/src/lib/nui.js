export const isGame = typeof window.GetParentResourceName === 'function';

export const resource = isGame ? window.GetParentResourceName() : 'vr-bankheist';

export const post = (name, data = {}) =>
  !isGame ? Promise.resolve(null) : fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
    .then((r) => r.json())
    .catch(() => null);
