export const isGame = typeof window.GetParentResourceName === 'function';

export const resource = isGame ? window.GetParentResourceName() : 'vr-garages';

export const post = (name, data = {}) =>
  fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
    .then((r) => r.json())
    .catch(() => null);
