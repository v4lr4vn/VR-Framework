import { callback } from './nui.js';

const cache = new Map();

export function imageUrl(id) {
  if (!id) return Promise.resolve(null);
  if (!cache.has(id)) {
    const p = callback('image', { id }).then((res) => (res && res.ok ? res.data : null));
    cache.set(id, p);
    p.then((v) => { if (!v) cache.delete(id); });
  }
  return cache.get(id);
}

export function rememberImage(id, dataUrl) {
  if (id && dataUrl) cache.set(id, Promise.resolve(dataUrl));
}
