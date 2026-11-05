// A fake server for contacts, texts, calls and voicemail, for trying the screens in a normal browser.
// Sam answers calls, Mum does not (so you can try voicemail), and Mum texts back.
//   ?incoming=1        Sam calls you after 2 seconds       ?incoming=unknown   a number you do not know calls
//   ?call=active       start already in a call with Sam    ?empty=1            no contacts, texts or calls
import { dispatch } from '../lib/nui.js';

const params = new URLSearchParams(location.search);
const ME = '555-0142';
const KEYS = { answer: 'Y', hangup: 'U' };
const now = () => Math.floor(Date.now() / 1000);
const empty = params.get('empty') === '1';

const db = {
  contacts: empty
    ? []
    : [
        { id: 1, name: 'Mum', number: '555-0101', favourite: true, blocked: false },
        { id: 2, name: 'Sam', number: '555-0202', favourite: true, blocked: false },
        { id: 3, name: 'Alex Reed', number: '555-0303', favourite: false, blocked: false },
        { id: 4, name: 'Dr Patel', number: '555-0404', favourite: false, blocked: false },
        { id: 5, name: 'Spam Caller', number: '555-0666', favourite: false, blocked: true },
      ],
  nextContact: 6,
  msgs: {}, // number -> [{ id, mine, body, at }]
  unread: {}, // number -> count
  nextMsg: 100,
  calls: [],
  nextCall: 1,
  voicemail: [],
  nextVoicemail: 1,
};

if (!empty) {
  const t = now();
  db.msgs['555-0101'] = [
    { id: 1, mine: false, body: 'Are you coming for tea later?', at: t - 7200 },
    { id: 2, mine: true, body: 'Yes! What time?', at: t - 7100 },
    { id: 3, mine: false, body: 'About six. Bring milk please', at: t - 7000 },
  ];
  db.msgs['555-0202'] = [
    { id: 4, mine: false, body: 'Stream starts at 8?', at: t - 90000 },
    { id: 5, mine: true, body: 'Yep, see you there', at: t - 89000 },
  ];
  db.msgs['555-0909'] = [{ id: 6, mine: false, body: 'Your parcel is at the depot.', at: t - 600 }];
  db.unread['555-0909'] = 1;
  db.calls = [
    { id: 3, number: '555-0303', outgoing: false, result: 'missed', duration: 0, seen: false, at: t - 1500 },
    { id: 2, number: '555-0202', outgoing: true, result: 'answered', duration: 184, seen: true, at: t - 9000 },
    { id: 1, number: '555-0101', outgoing: false, result: 'answered', duration: 61, seen: true, at: t - 90000 },
  ];
  db.nextCall = 4;
  db.voicemail = [{ id: 1, from: '555-0404', body: 'Hello, this is Dr Patel\'s office. Please call us back about your appointment.', heard: false, at: t - 3000 }];
  db.nextVoicemail = 2;
}

const nameOf = (n) => db.contacts.find((c) => c.number === n)?.name;
const digits = (n) => String(n ?? '').replace(/\D/g, '');

// Like the server: only numbers that look like numbers, and 7 digits get the format.
function normal(raw) {
  const s = String(raw ?? '').replace(/\s+/g, '');
  if (!/^\+?[\d-]+$/.test(s) || s.length < 3 || s.length > 20) return null;
  if (/^\d{7}$/.test(s)) return `${s.slice(0, 3)}-${s.slice(3)}`;
  return s;
}

function badges() {
  const messages = Object.values(db.unread).reduce((a, b) => a + b, 0);
  return { messages, phone: db.calls.filter((c) => !c.seen && c.result === 'missed').length + db.voicemail.filter((v) => !v.heard).length };
}

export function commsPayload() {
  return {
    contacts: db.contacts,
    badges: badges(),
    calls: { answerKey: KEYS.answer, hangupKey: KEYS.hangup, voicemail: true, maxLength: 500 },
  };
}

// ---- calls

let live = null; // { id, number, state, timers: [] }
const later = (ms, fn) => {
  const id = setTimeout(fn, ms);
  live?.timers.push(id);
};

function send(data) {
  dispatch('call', { keys: KEYS, ...data });
}

function log(number, outgoing, result, duration, seen = true) {
  db.calls.unshift({ id: db.nextCall++, number, outgoing, result, duration, seen, at: now() });
}

function finish(reason) {
  if (!live) return;
  const c = live;
  live = null;
  c.timers.forEach(clearTimeout);
  const answered = c.answeredAt != null;
  const duration = answered ? Math.round((Date.now() - c.answeredAt) / 1000) : 0;
  if (c.outgoing) log(c.number, true, answered ? 'answered' : reason === 'declined' ? 'declined' : 'unanswered', duration);
  else log(c.number, false, answered ? 'answered' : reason === 'declined' ? 'declined' : 'missed', duration, answered || reason === 'declined');
  send({ id: c.id, state: 'ended', reason, duration });
}

function startIncoming(number) {
  if (live) return;
  live = { id: db.nextCall++, number, outgoing: false, timers: [] };
  send({ id: live.id, state: 'incoming', number, name: nameOf(number), silent: false });
  later(20000, () => finish('missed'));
}

function startOutgoing(number) {
  live = { id: db.nextCall++, number, outgoing: true, timers: [] };
  send({ id: live.id, state: 'calling', number, name: nameOf(number) });
  if (number === '555-0101') {
    // Mum does not pick up: after a few seconds the caller may leave a message.
    later(3500, () => {
      if (!live) return;
      live.state = 'voicemail';
      send({ id: live.id, state: 'voicemail', number, name: nameOf(number) });
    });
  } else {
    later(2200, () => {
      if (!live) return;
      live.answeredAt = Date.now();
      live.state = 'active';
      send({ id: live.id, state: 'active', number, name: nameOf(number), elapsed: 0 });
    });
  }
}

if (params.get('incoming') === '1') setTimeout(() => startIncoming('555-0202'), 2000);
if (params.get('incoming') === 'unknown') setTimeout(() => startIncoming('555-0777'), 2000);
if (params.get('call') === 'active') {
  setTimeout(() => {
    live = { id: db.nextCall++, number: '555-0202', outgoing: true, timers: [], answeredAt: Date.now() - 42000, state: 'active' };
    send({ id: live.id, state: 'active', number: '555-0202', name: 'Sam', elapsed: 42 });
  }, 600);
}

// ---- the handlers

export async function commsHandle(name, data) {
  switch (name) {
    case 'badges':
      return { ok: true, badges: badges() };

    case 'contactsList':
      return { ok: true, contacts: db.contacts };
    case 'contactsSave': {
      const nm = String(data.name ?? '').trim().slice(0, 40);
      const num = normal(data.number);
      if (!nm) return { ok: false, reason: 'invalid_name' };
      if (!num) return { ok: false, reason: 'invalid_number' };
      const clash = db.contacts.find((c) => digits(c.number) === digits(num) && c.id !== data.id);
      if (clash) return { ok: false, reason: 'duplicate' };
      let c = db.contacts.find((x) => x.id === data.id);
      if (c) Object.assign(c, { name: nm, number: num, favourite: data.favourite === true, blocked: data.blocked === true });
      else {
        c = { id: db.nextContact++, name: nm, number: num, favourite: data.favourite === true, blocked: data.blocked === true };
        db.contacts.push(c);
      }
      db.contacts.sort((a, b) => a.name.localeCompare(b.name));
      return { ok: true, contact: { ...c } };
    }
    case 'contactsRemove': {
      const before = db.contacts.length;
      db.contacts = db.contacts.filter((c) => c.id !== data.id);
      return { ok: db.contacts.length < before };
    }

    case 'threads': {
      const out = [];
      for (const [number, list] of Object.entries(db.msgs)) {
        const last = list[list.length - 1];
        if (!last) continue;
        out.push({ number, body: last.body.slice(0, 120), at: last.at, mine: last.mine, unread: db.unread[number] ?? 0, id: last.id });
      }
      out.sort((a, b) => b.id - a.id);
      return { ok: true, threads: out };
    }
    case 'history': {
      const list = db.msgs[normal(data.number)] ?? [];
      const before = data.before ?? Infinity;
      const older = list.filter((m) => m.id < before);
      const page = older.slice(-40);
      return { ok: true, messages: page, more: older.length > 40 };
    }
    case 'sendMessage': {
      const num = normal(data.number);
      const body = String(data.body ?? '').trim().slice(0, 500);
      if (!num) return { ok: false, reason: 'invalid_number' };
      if (num === ME) return { ok: false, reason: 'self' };
      if (!body) return { ok: false, reason: 'invalid_body' };
      const m = { id: db.nextMsg++, mine: true, body, at: now() };
      (db.msgs[num] ??= []).push(m);
      // Mum answers, to show a text arriving.
      if (num === '555-0101') {
        setTimeout(() => {
          const reply = { id: db.nextMsg++, mine: false, body: 'Lovely, see you soon x', at: now() };
          db.msgs[num].push(reply);
          db.unread[num] = (db.unread[num] ?? 0) + 1;
          dispatch('message', { id: reply.id, from: num, body: reply.body, at: reply.at });
          dispatch('notify', { id: `msg-${reply.id}`, app: 'messages', title: 'Mum', message: reply.body, at: reply.at, banner: true, lock: true, sound: true });
        }, 2500);
      }
      return { ok: true, message: m };
    }
    case 'markRead':
      delete db.unread[normal(data.number)];
      return { ok: true, badges: badges() };
    case 'deleteThread':
      delete db.msgs[normal(data.number)];
      delete db.unread[normal(data.number)];
      return { ok: true, badges: badges() };

    case 'recentCalls':
      return { ok: true, calls: db.calls.slice(0, 60) };
    case 'callsSeen':
      db.calls.forEach((c) => (c.seen = true));
      return { ok: true, badges: badges() };
    case 'callsClear':
      db.calls = [];
      return { ok: true, badges: badges() };

    case 'startCall': {
      const num = normal(data.number);
      if (!num) return { ok: false, reason: 'invalid_number' };
      if (num === ME) return { ok: false, reason: 'self' };
      if (live) return { ok: false, reason: 'in_call' };
      if (db.contacts.find((c) => c.number === num)?.blocked) return { ok: true, id: 0, state: 'calling' };
      if (num === '555-0888') return { ok: false, reason: 'not_in_service' };
      startOutgoing(num);
      return { ok: true, id: live.id, state: 'calling' };
    }
    case 'answerCall': {
      if (!live || live.id !== data.id || live.outgoing || live.answeredAt) return { ok: false, reason: 'no_call' };
      live.timers.forEach(clearTimeout);
      live.answeredAt = Date.now();
      live.state = 'active';
      send({ id: live.id, state: 'active', number: live.number, name: nameOf(live.number), elapsed: 0 });
      return { ok: true };
    }
    case 'endCall': {
      if (!live || live.id !== data.id) return { ok: false, reason: 'no_call' };
      const reason = live.answeredAt ? 'hangup' : live.outgoing ? (live.state === 'voicemail' ? 'no_answer' : 'cancelled') : 'declined';
      finish(reason);
      return { ok: true };
    }
    case 'leaveVoicemail': {
      if (!live || live.id !== data.id || live.state !== 'voicemail') return { ok: false, reason: 'no_call' };
      if (!String(data.body ?? '').trim()) return { ok: false, reason: 'empty' };
      finish('voicemail_sent');
      return { ok: true };
    }

    case 'voicemailList':
      return { ok: true, voicemail: db.voicemail };
    case 'voicemailHeard': {
      const v = db.voicemail.find((x) => x.id === data.id);
      if (v) v.heard = true;
      return { ok: true, badges: badges() };
    }
    case 'voicemailRemove':
      db.voicemail = db.voicemail.filter((v) => v.id !== data.id);
      return { ok: true, badges: badges() };
  }
  return undefined;
}
