import { api, on, onMessage, callback } from './nui.js';
import { errorText } from './lang.js';

export const clock = $state({ now: Math.floor(Date.now() / 1000), offset: 0 });

setInterval(() => {
  clock.now = Math.floor(Date.now() / 1000) + clock.offset;
}, 1000);

export const session = $state({
  ready: false,
  error: null,
  me: null,
  dept: null,
  perms: [],
  statuses: [],
  map: null,
  flags: [],
  licences: {},
});

export function can(perm) {
  if (!perm) return true;
  if (Array.isArray(perm)) return perm.some((p) => session.perms.includes(p));
  return session.perms.includes(perm);
}

export const ui = $state({
  open: false,
  console: false,
  hidden: false,
  route: { page: 'dispatch', params: {} },
  history: [],
  search: '',
});

export function go(page, params = {}) {
  const current = ui.route;
  if (current.page === page && JSON.stringify(current.params) === JSON.stringify(params)) return;
  ui.history = [...ui.history.slice(-30), { page: current.page, params: { ...current.params } }];
  ui.route = { page, params };
}

export function back(fallback = 'dispatch') {
  const prev = ui.history[ui.history.length - 1];
  ui.history = ui.history.slice(0, -1);
  ui.route = prev || { page: fallback, params: {} };
}

export const toasts = $state({ list: [] });
let toastId = 0;

export function toast(text, kind = 'info', ms = 3500) {
  const id = ++toastId;
  toasts.list = [...toasts.list.slice(-3), { id, text, kind }];
  setTimeout(() => {
    toasts.list = toasts.list.filter((t) => t.id !== id);
  }, ms);
}

export async function request(action, data = {}, opts = {}) {
  const res = await api(action, data);
  if (!res.ok && !opts.quiet) toast(errorText(res.error), 'error');
  if (res.ok && opts.success) toast(opts.success, 'ok');
  return res;
}

export async function loadSession() {
  session.error = null;
  const res = await api('session.get', {});
  if (!res.ok) {
    session.ready = false;
    session.error = res.error || 'server_error';
    return res;
  }
  Object.assign(session, res.data, { ready: true, error: null });
  if (res.data.serverTime) {
    clock.offset = res.data.serverTime - Math.floor(Date.now() / 1000);
    clock.now = res.data.serverTime;
  }
  return res;
}

export function close() {
  ui.open = false;
  callback('close', {});
}

export const dispatch = $state({
  loaded: false,
  calls: [],
  closed: [],
  units: [],
  positions: {},
  me: null,
  selected: null,
  streets: {},
});

function sortCalls(list) {
  return list.sort((a, b) => a.priority - b.priority || b.createdAt - a.createdAt);
}

export function upsertCall(call) {
  if (!call || !call.id) return;
  const active = dispatch.calls.filter((c) => c.id !== call.id);
  const closed = dispatch.closed.filter((c) => c.id !== call.id);
  if (call.status === 'closed') {
    dispatch.calls = active;
    dispatch.closed = [call, ...closed].slice(0, 30);
  } else {
    dispatch.calls = sortCalls([...active, call]);
    dispatch.closed = closed;
  }
}

export function removeCall(id) {
  dispatch.calls = dispatch.calls.filter((c) => c.id !== id);
  dispatch.closed = dispatch.closed.filter((c) => c.id !== id);
  if (dispatch.selected === id) dispatch.selected = null;
}

export function upsertUnit(unit) {
  if (!unit || !unit.cid) return;
  const rest = dispatch.units.filter((u) => u.cid !== unit.cid);
  dispatch.units = [...rest, unit].sort((a, b) => (a.dept === b.dept ? String(a.callsign || a.name).localeCompare(String(b.callsign || b.name)) : a.dept > b.dept ? -1 : 1));
  if (session.me && unit.cid === session.me.cid) dispatch.me = unit;
}

export function removeUnit(cid) {
  dispatch.units = dispatch.units.filter((u) => u.cid !== cid);
  const p = { ...dispatch.positions };
  delete p[cid];
  dispatch.positions = p;
}

export async function loadDispatch() {
  const res = await api('dispatch.list', {});
  if (!res.ok) return res;
  dispatch.calls = sortCalls(res.data.active || []);
  dispatch.closed = res.data.closed || [];
  dispatch.units = res.data.units || [];
  dispatch.me = res.data.me || null;
  dispatch.loaded = true;
  fillStreets([...dispatch.calls, ...dispatch.closed]);
  return res;
}

export async function fillStreets(calls) {
  const missing = calls.filter((c) => !c.street && !dispatch.streets[c.id]);
  if (!missing.length) return;
  const res = await callback('streets', { list: missing.map((c) => ({ id: c.id, x: c.coords.x, y: c.coords.y, z: c.coords.z })) });
  if (res && typeof res === 'object') dispatch.streets = { ...dispatch.streets, ...res };
}

export function streetOf(call) {
  return call.street || dispatch.streets[call.id] || 'Unknown location';
}

on('dispatch:call', (call) => {
  upsertCall(call);
  fillStreets([call]);
});
on('dispatch:remove', (p) => removeCall(p.id));
on('units:update', (u) => upsertUnit(u));
on('units:remove', (p) => removeUnit(p.cid));
on('units:positions', (list) => {
  const next = {};
  for (const p of list || []) next[p.cid] = p;
  dispatch.positions = next;
});

onMessage('open', (msg) => {
  ui.open = true;
  ui.hidden = false;
  ui.console = msg.console === true;
  if (msg.page) ui.route = { page: msg.page, params: msg.params || {} };
  loadSession().then((res) => {
    if (res.ok && ['police', 'ems', 'dispatch'].includes(session.dept?.id)) loadDispatch();
    if (res.ok && ((session.dept?.id === 'dispatch' && can('radio.multi')) || isUnit())) loadRadio();
  });
});

export const isUnit = () => ['police', 'ems'].includes(session.dept?.id);

const radioNames = {};
const radioAsked = {};

export const radio = $state({
  loaded: false,
  mode: 'unit',
  members: [],
  voice: true,
  channels: [],
  listen: [],
  transmit: 0,
  defaults: { listen: [], transmit: 0 },
  talking: {},
  last: {},
  self: false,
  ptt: false,
});

export async function loadRadio() {
  const res = await api('radio.state', {});
  if (!res.ok) return res;
  radio.voice = res.data.voice !== false;
  radio.channels = res.data.channels || [];
  radio.listen = res.data.listen || [];
  radio.transmit = res.data.transmit || 0;
  radio.defaults = res.data.defaults || radio.defaults;
  radio.mode = res.data.mode || 'unit';
  radio.members = res.data.members || [];
  for (const m of radio.members) if (m && m.src != null && m.name) radioNames[m.src] = m.name;
  radio.loaded = true;
  return res;
}

export async function joinChannel(id) {
  const res = await callback('radio', { op: 'join', id });
  if (res && res.ok) {
    radio.transmit = id;
    setTimeout(loadRadio, 400);
  } else {
    toast("Couldn't join that channel.", 'error');
  }
  return res;
}

export async function leaveChannel() {
  const res = await callback('radio', { op: 'leave' });
  if (res && res.ok) {
    radio.transmit = 0;
    radio.members = [];
  }
  return res;
}

export async function moveUnit(u, channel) {
  const c = radio.channels.find((x) => x.id === channel);
  const who = u.callsign || u.name;
  const res = await request('radio.move', { cid: u.cid, channel }, { success: channel ? `${who} moved to CH ${channel}${c ? ` · ${c.label}` : ''}` : `${who} taken off the radio` });
  if (res.ok) upsertUnit({ ...u, radio: channel });
  return res;
}

let membersTimer = null;
function reloadMembers() {
  if (!radio.loaded || radio.mode !== 'unit') return;
  clearTimeout(membersTimer);
  membersTimer = setTimeout(loadRadio, 300);
}

export async function setListen(list) {
  const res = await request('radio.listen', { channels: list });
  if (res.ok) radio.listen = res.data.listen || [];
  return res;
}

export async function setTransmit(id) {
  const res = await callback('radio', { op: 'transmit', id });
  if (res && res.ok) radio.transmit = res.transmit ?? id;
  else toast("Couldn't switch the transmit channel.", 'error');
  return res;
}

export function ptt(down) {
  if (radio.ptt === down) return;
  radio.ptt = down;
  callback('radio', { op: 'ptt', down });
}


export function talkerName(src) {
  return radioNames[src] || 'Unit';
}

async function lookupTalker(src, ch) {
  const now = Date.now();
  if (radioNames[src] || (radioAsked[src] && now - radioAsked[src] < 15000)) return;
  radioAsked[src] = now;
  const res = await api('radio.who', { ids: [src] });
  const name = res.ok && res.data ? res.data[String(src)] : null;
  if (!name) return;
  radioNames[src] = name;
  const list = radio.talking[ch];
  if (list && list[src]) radio.talking = { ...radio.talking, [ch]: { ...list, [src]: name } };
  const last = radio.last[ch];
  if (last && last.src === src) radio.last = { ...radio.last, [ch]: { ...last, name } };
}

on('radio:talk', (p) => {
  if (!p || p.channel == null || p.src == null) return;
  const ch = String(p.channel);
  const list = { ...(radio.talking[ch] || {}) };
  if (p.talking) {
    list[p.src] = talkerName(p.src);
    radio.last = { ...radio.last, [ch]: { src: p.src, name: list[p.src], at: Date.now() } };
    if (!radioNames[p.src]) lookupTalker(p.src, ch);
  } else {
    delete list[p.src];
  }
  radio.talking = { ...radio.talking, [ch]: list };
});

on('radio:self', (p) => {
  radio.self = !!(p && p.talking);
});

on('radio:tx', (p) => {
  radio.transmit = (p && p.channel) || 0;
  if (!radio.transmit) radio.members = [];
  reloadMembers();
});

on('radio:members', () => reloadMembers());

on('radio:reset', () => {
  radio.listen = [];
  radio.talking = {};
});

onMessage('close', () => {
  ui.open = false;
  ui.hidden = false;
});

onMessage('hide', () => {
  ui.hidden = true;
});

onMessage('show', () => {
  ui.hidden = false;
});
