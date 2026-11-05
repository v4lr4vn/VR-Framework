import { api, on } from '../../lib/nui.js';

export const penal = $state({ loaded: false, loading: false, error: null, categories: [], all: false, version: 0 });

let byId = new Map();
let pending = null;

function index() {
  byId = new Map();
  for (const cat of penal.categories) for (const c of cat.charges) byId.set(c.id, c);
}

export function loadPenal(all = false, force = false) {
  if (!force && penal.loaded && penal.all === all) return Promise.resolve({ ok: true });
  if (pending && !force) return pending;
  penal.loading = true;
  pending = api('penal.list', { all }).then((res) => {
    pending = null;
    penal.loading = false;
    if (res.ok) {
      penal.categories = res.data.categories || [];
      penal.all = res.data.all === true;
      penal.loaded = true;
      penal.error = null;
      penal.version += 1;
      index();
    } else {
      penal.error = res.error;
    }
    return res;
  });
  return pending;
}

export function chargeById(id) {
  return byId.get(id) || null;
}

export function flatCharges() {
  const out = [];
  for (const cat of penal.categories) for (const c of cat.charges) out.push(c);
  return out;
}

on('penal:changed', () => {
  if (penal.loaded) loadPenal(penal.all, true);
});
