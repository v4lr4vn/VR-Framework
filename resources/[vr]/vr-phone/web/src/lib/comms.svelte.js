// Contacts, texts, calls and voicemail. The server keeps all of it; this file keeps what the screen is showing.
//
// It does not import the phone store (the store imports this file), so anything it needs from the phone is passed in.
import { post } from './nui.js';
import { t } from './i18n.js';
import { play, startRing, stopRing } from './sfx.js';

export const comms = $state({
  contacts: [],
  badges: { messages: 0, phone: 0, mail: 0 }, // the numbers on the app icons
  threads: [],
  threadsLoaded: false,
  convos: {}, // number -> { messages, more, loaded }
  open: null, // the conversation being looked at
  recents: [],
  recentsLoaded: false,
  voicemail: [],
  voicemailLoaded: false,
  // Bumped when something new arrives, so an open app knows to fetch its list again.
  rev: { threads: 0, recents: 0, voicemail: 0, mail: 0 },
  call: null, // { id, state, number, name, since, minimized, reason, duration, keys }
  now: Date.now(), // ticks once a second while a call is going
  draft: null, // a contact another app wants to add: { number }
  target: null, // a number another app wants the Messages app to open
  visible: false, // the phone screen is showing
});

const asArray = (value) => (Array.isArray(value) ? value : []);
const countsOf = (b) => ({ messages: Number(b?.messages) || 0, phone: Number(b?.phone) || 0, mail: Number(b?.mail) || 0 });

// ---- starting up

export function initComms(data) {
  comms.contacts = asArray(data.contacts);
  comms.badges = countsOf(data.badges);
  comms.threadsLoaded = false;
  comms.recentsLoaded = false;
  comms.voicemailLoaded = false;
  comms.convos = {};
  comms.open = null;
  comms.draft = null;
  comms.target = null;
}

export function setVisible(on) {
  comms.visible = on === true;
  if (!on) comms.open = null;
}

// The text for a reason the server gave. Unknown reasons say the phone did not answer.
export function errorText(reason) {
  const key = `err.${reason}`;
  const text = t(key);
  return text === key ? t('err.timeout') : text;
}

let badgeTimer = 0;
export function refreshBadges() {
  clearTimeout(badgeTimer);
  badgeTimer = setTimeout(async () => {
    const r = await post('badges');
    if (r?.ok && r.badges) comms.badges = countsOf(r.badges);
  }, 250);
}

function takeBadges(r) {
  if (r?.badges) comms.badges = countsOf(r.badges);
}

// ---- numbers and names

// Only the digits, so "555 0142" and "555-0142" match.
export const digitsOf = (n) => String(n ?? '').replace(/\D/g, '');

export function contactFor(number) {
  if (!number) return null;
  const d = digitsOf(number);
  return comms.contacts.find((c) => c.number === number || (d && digitsOf(c.number) === d)) ?? null;
}

export const nameFor = (number) => contactFor(number)?.name ?? '';
export const labelFor = (number) => nameFor(number) || number;

// ---- contacts

function sortContacts(list) {
  return [...list].sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
}

export async function reloadContacts() {
  const r = await post('contactsList');
  if (r?.ok) comms.contacts = asArray(r.contacts);
}

// data: { id?, name, number, favourite?, blocked? }
export async function saveContact(data) {
  const r = await post('contactsSave', data);
  if (r?.ok && r.contact) {
    comms.contacts = sortContacts([...comms.contacts.filter((c) => c.id !== r.contact.id), r.contact]);
    // Names show on the lists, so they are fetched again with the new names in mind.
    comms.rev.threads++;
    comms.rev.recents++;
  }
  return r ?? { ok: false, reason: 'timeout' };
}

export async function removeContact(id) {
  const r = await post('contactsRemove', { id });
  if (r?.ok) comms.contacts = comms.contacts.filter((c) => c.id !== id);
  return r ?? { ok: false, reason: 'timeout' };
}

// ---- messages

export async function loadThreads(force = false) {
  if (comms.threadsLoaded && !force) return;
  const r = await post('threads');
  if (r?.ok) {
    comms.threads = asArray(r.threads);
    comms.threadsLoaded = true;
  }
}

function upsertThread(number, patch) {
  const rest = comms.threads.filter((x) => x.number !== number);
  const old = comms.threads.find((x) => x.number === number);
  comms.threads = [{ number, body: '', at: 0, mine: false, unread: 0, id: 0, ...old, ...patch }, ...rest];
}

function mergeById(list, extra) {
  const seen = new Set(list.map((m) => m.id));
  const out = [...list];
  for (const m of extra) if (!seen.has(m.id)) out.push(m);
  return out.sort((a, b) => a.id - b.id);
}

const waiting = {}; // texts that arrived while the conversation was still loading

export async function openConversation(number) {
  comms.open = number;
  waiting[number] = [];
  if (!comms.convos[number]) comms.convos[number] = { messages: [], more: false, loaded: false };
  const r = await post('history', { number });
  if (r?.ok) {
    comms.convos[number] = {
      messages: mergeById(asArray(r.messages), waiting[number] ?? []),
      more: r.more === true,
      loaded: true,
    };
  }
  delete waiting[number];
  if (comms.open === number) readThread(number);
}

export function closeConversation() {
  comms.open = null;
}

export async function loadOlder(number) {
  const c = comms.convos[number];
  if (!c || !c.more || c.messages.length === 0) return;
  const r = await post('history', { number, before: c.messages[0].id });
  if (r?.ok) {
    comms.convos[number] = { messages: mergeById(asArray(r.messages), c.messages), more: r.more === true, loaded: true };
  }
}

export async function readThread(number) {
  const th = comms.threads.find((x) => x.number === number);
  if (th && th.unread > 0) upsertThreadKeepOrder(number, { unread: 0 });
  const r = await post('markRead', { number });
  takeBadges(r);
}

function upsertThreadKeepOrder(number, patch) {
  comms.threads = comms.threads.map((x) => (x.number === number ? { ...x, ...patch } : x));
}

export async function sendText(number, body) {
  const r = await post('sendMessage', { number, body });
  if (!r?.ok || !r.message) return r ?? { ok: false, reason: 'timeout' };
  const m = r.message;
  const c = comms.convos[number];
  if (c?.loaded) comms.convos[number] = { ...c, messages: mergeById(c.messages, [m]) };
  upsertThread(number, { body: m.body.slice(0, 120), at: m.at, mine: true, unread: 0, id: m.id });
  return r;
}

export async function removeThread(number) {
  const r = await post('deleteThread', { number });
  if (r?.ok) {
    comms.threads = comms.threads.filter((x) => x.number !== number);
    delete comms.convos[number];
    if (comms.open === number) comms.open = null;
    takeBadges(r);
  }
  return r ?? { ok: false, reason: 'timeout' };
}

// A text arrived while the screen was loaded: m = { id, from, body, at }.
// Returns true when the player is looking at that conversation right now (so no banner is needed).
export function onMessage(m) {
  if (!m || typeof m !== 'object' || !m.from) return false;
  const viewing = comms.visible && comms.open === m.from;
  const msg = { id: m.id, mine: false, body: m.body, at: m.at };

  const c = comms.convos[m.from];
  if (c?.loaded) comms.convos[m.from] = { ...c, messages: mergeById(c.messages, [msg]) };
  else if (waiting[m.from]) waiting[m.from].push(msg);

  if (comms.threadsLoaded) {
    const old = comms.threads.find((x) => x.number === m.from);
    upsertThread(m.from, { body: String(m.body ?? '').slice(0, 120), at: m.at, mine: false, id: m.id, unread: viewing ? 0 : (old?.unread ?? 0) + 1 });
  } else {
    comms.rev.threads++;
  }

  if (viewing) readThread(m.from);
  else {
    comms.badges.messages += 1;
    refreshBadges();
  }
  return viewing;
}

// ---- calls and voicemail lists

export async function loadRecents(force = false) {
  if (comms.recentsLoaded && !force) return;
  const r = await post('recentCalls');
  if (r?.ok) {
    comms.recents = asArray(r.calls);
    comms.recentsLoaded = true;
  }
}

// The Phone app was opened: missed calls are no longer new.
export async function markCallsSeen() {
  if (!comms.recents.some((c) => !c.seen)) return;
  const r = await post('callsSeen');
  if (r?.ok) {
    takeBadges(r);
    comms.recents = comms.recents.map((c) => ({ ...c, seen: true }));
  }
}

export async function clearRecents() {
  const r = await post('callsClear');
  if (r?.ok) {
    comms.recents = [];
    takeBadges(r);
  }
  return r ?? { ok: false, reason: 'timeout' };
}

export async function loadVoicemail(force = false) {
  if (comms.voicemailLoaded && !force) return;
  const r = await post('voicemailList');
  if (r?.ok) {
    comms.voicemail = asArray(r.voicemail);
    comms.voicemailLoaded = true;
  }
}

export async function heardVoicemail(id) {
  const item = comms.voicemail.find((v) => v.id === id);
  if (!item || item.heard) return;
  comms.voicemail = comms.voicemail.map((v) => (v.id === id ? { ...v, heard: true } : v));
  takeBadges(await post('voicemailHeard', { id }));
}

export async function removeVoicemail(id) {
  const r = await post('voicemailRemove', { id });
  if (r?.ok) {
    comms.voicemail = comms.voicemail.filter((v) => v.id !== id);
    takeBadges(r);
  }
  return r ?? { ok: false, reason: 'timeout' };
}

// A notification from the Messages or Phone app arrived. It may have waited for signal, so the lists are checked again.
export function onNotice(n) {
  if (n.app === 'messages') comms.rev.threads++;
  if (n.app === 'mail') comms.rev.mail++;
  if (n.app === 'phone') {
    comms.rev.recents++;
    comms.rev.voicemail++;
  }
  refreshBadges();
}

// ---- the call that is going on

let clockId = 0;
function runClock(on) {
  if (on && !clockId) {
    comms.now = Date.now();
    clockId = setInterval(() => (comms.now = Date.now()), 1000);
  } else if (!on && clockId) {
    clearInterval(clockId);
    clockId = 0;
  }
}

let clearId = 0;
function endLater(id, ms) {
  clearTimeout(clearId);
  clearId = setTimeout(() => {
    if (comms.call && comms.call.id === id && comms.call.state === 'ended') comms.call = null;
  }, ms);
}

export function clearCall() {
  stopRing();
  runClock(false);
  clearTimeout(clearId);
  comms.call = null;
}

// Every call message from the game: { id, state, number?, name?, silent?, ring?, volume?, elapsed?, reason?, duration?, keys? }
export function onCall(c) {
  if (!c || typeof c !== 'object' || typeof c.state !== 'string') return;
  const cur = comms.call;

  if (c.state === 'ended') {
    stopRing();
    if (!cur) return;
    // The last message of an older call must not close a newer one.
    if (c.id !== undefined && c.id !== cur.id) return;
    comms.call = { ...cur, state: 'ended', reason: c.reason ?? 'hangup', duration: Number(c.duration) || 0, minimized: false };
    runClock(false);
    play('ended');
    endLater(cur.id, c.reason === 'voicemail_sent' ? 1800 : 2600);
    comms.rev.recents++;
    refreshBadges();
    return;
  }

  const same = cur && cur.id === c.id ? cur : null;
  clearTimeout(clearId);
  comms.call = {
    id: c.id,
    state: c.state,
    number: c.number ?? same?.number ?? '',
    name: c.name ?? same?.name ?? '',
    since: same?.since ?? 0,
    minimized: same && same.state === c.state ? same.minimized : false,
    reason: '',
    duration: 0,
    keys: c.keys ?? same?.keys ?? { answer: 'Y', hangup: 'U' },
  };
  if (c.state === 'active') comms.call.since = Date.now() - (Number(c.elapsed) || 0) * 1000;

  if (c.state === 'incoming' && c.silent !== true && !same) startRing(c.ring, c.volume);
  else if (c.state !== 'incoming') stopRing();

  runClock(c.state === 'active' || c.state === 'calling');
}

export const callName = (call) => (call ? call.name || nameFor(call.number) || call.number : '');

// How long the active call has gone on, in seconds.
export const callSeconds = (call) => (call && call.state === 'active' ? Math.max(0, (comms.now - call.since) / 1000) : 0);

export function minimizeCall(on = true) {
  if (comms.call && ['active', 'calling', 'voicemail'].includes(comms.call.state)) comms.call.minimized = on;
}

// The server answers with ok or a reason. The call itself changes when the server's message arrives.
export async function dial(number) {
  if (comms.call) return { ok: false, reason: 'in_call' };
  const r = await post('startCall', { number });
  return r ?? { ok: false, reason: 'timeout' };
}

export async function answerCall() {
  const c = comms.call;
  if (!c || c.state !== 'incoming') return { ok: false, reason: 'no_call' };
  stopRing();
  const r = await post('answerCall', { id: c.id });
  if (r && r.ok === false && r.reason === 'no_call') clearCall();
  return r ?? { ok: false, reason: 'timeout' };
}

// Hang up, decline or cancel, whichever fits.
export async function hangUp() {
  const c = comms.call;
  if (!c) return { ok: false, reason: 'no_call' };
  if (c.state === 'ended') {
    clearCall();
    return { ok: true };
  }
  stopRing();
  const r = await post('endCall', { id: c.id });
  // The server does not know this call any more, so it will not send an ending. Close it here.
  if (!r || (r.ok === false && (r.reason === 'no_call' || r.reason === 'no_session'))) clearCall();
  return r ?? { ok: false, reason: 'timeout' };
}

export async function sendVoicemail(body) {
  const c = comms.call;
  if (!c || c.state !== 'voicemail') return { ok: false, reason: 'no_call' };
  const r = await post('leaveVoicemail', { id: c.id, body });
  return r ?? { ok: false, reason: 'timeout' };
}

// The back button, the home pill and Esc while a call is on the screen.
// A call that is going on is put in the corner. A ringing call cannot be put aside (answer or decline it).
// Returns true when it handled the press.
export function backFromCall() {
  const c = comms.call;
  if (!c || c.minimized || c.state === 'incoming') return false;
  if (c.state === 'ended') clearCall();
  else c.minimized = true;
  return true;
}
