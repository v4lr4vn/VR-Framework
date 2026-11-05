export const resource = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : 'vr-inventory';

export const isGame = typeof window.GetParentResourceName === 'function';

export const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    })
        .then((r) => r.json())
        .catch(() => null);
