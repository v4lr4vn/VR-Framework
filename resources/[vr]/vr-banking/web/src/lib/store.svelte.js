import { call } from './api.js';
import { errorText } from './errors.js';

export const app = $state({
  visible: false,
  mode: null,
  data: {},
  overview: null,
  view: 'account',
  accountId: null,
  busy: false,
  toast: null,
  stamp: 0,
});

let toastTimer;

export function toast(text, kind = 'ok') {
  clearTimeout(toastTimer);
  app.toast = { text, kind, id: Date.now() };
  toastTimer = setTimeout(() => (app.toast = null), 3600);
}

export async function refresh() {
  const r = await call('overview');
  if (!r.ok) {
    toast(errorText(r.error), 'err');
    return null;
  }
  app.overview = r.data;
  const ids = r.data.accounts.map((a) => a.id);
  if (!ids.includes(app.accountId)) app.accountId = ids[0] ?? null;
  app.stamp += 1;
  return r.data;
}

export async function act(action, data, success) {
  if (app.busy) return { ok: false, error: 'busy' };
  app.busy = true;
  const r = await call(action, data);
  app.busy = false;
  if (!r.ok) {
    toast(errorText(r.error), 'err');
    return r;
  }
  if (success) toast(typeof success === 'function' ? success(r.data) : success, 'ok');
  if (app.mode === 'bank') await refresh();
  return r;
}

export function go(view, accountId) {
  app.view = view;
  if (accountId != null) app.accountId = accountId;
}
