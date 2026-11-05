// A fake server for Notes, Reminders, Calendar and Mail, for trying the screens in a normal browser.
//   ?mail=in      start signed in to Mail (you@ravenmail.io, with a few messages)     (otherwise Mail starts signed out)
//   ?notes=0 ?reminders=0 ?events=0   start with none
//   Sign in with sam@ravenmail.io / secret1. The recovery code for sam is ABCD-2345-WXYZ.
import { dispatch } from '../lib/nui.js';

const params = new URLSearchParams(location.search);
const now = () => Math.floor(Date.now() / 1000);
const pad = (n) => String(n).padStart(2, '0');
const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};
const shift = (days) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

export function organiserFeatures() {
  return {
    notes: { max: 100, titleLength: 80, bodyLength: 4000 },
    planner: { remindChoices: [0, 5, 15, 30, 60, 1440] },
    weather: { place: 'Los Santos', fahrenheit: false, base: { clear: 21, cloud: 17, rain: 13, storm: 12, fog: 11, snow: -1 }, daySwing: 5 },
    mail: { domain: 'ravenmail.io', subjectLength: 100, bodyLength: 4000, pageSize: 5, keepTrashDays: 30 },
  };
}

// ---- notes
const notes = [];
let nextNote = 1;
if (params.get('notes') !== '0') {
  notes.push(
    { id: nextNote++, title: 'Shopping', body: 'Milk\nEggs\nBread\nCoffee beans', pinned: true, at: now() - 7200 },
    { id: nextNote++, title: 'Plate number', body: 'The blue Sultan: 42ABC123', pinned: false, at: now() - 90000 },
    { id: nextNote++, title: 'Ideas for the weekend', body: 'Fishing at the pier, then the car meet at 9.', pinned: false, at: now() - 300000 },
  );
}
const noteHead = (n) => ({ id: n.id, title: n.title, pinned: n.pinned, at: n.at, preview: n.body.replace(/\s+/g, ' ').slice(0, 90) });

// ---- reminders and events
const reminders = [];
let nextRem = 1;
if (params.get('reminders') !== '0') {
  reminders.push(
    { id: nextRem++, title: 'Call Mum', note: 'About Sunday', date: today(), minute: 17 * 60 + 30, done: false },
    { id: nextRem++, title: 'Pay the garage', note: null, date: shift(-1), minute: null, done: false },
    { id: nextRem++, title: 'Renew the licence', note: null, date: shift(6), minute: 10 * 60, done: false },
    { id: nextRem++, title: 'Buy milk', note: null, date: null, minute: null, done: false },
    { id: nextRem++, title: 'Wash the car', note: null, date: shift(-3), minute: null, done: true },
  );
}
const events = [];
let nextEv = 1;
if (params.get('events') !== '0') {
  events.push(
    { id: nextEv++, title: 'Court hearing', place: 'Courthouse', note: 'Bring the papers', date: today(), minute: 14 * 60, length: 60, colour: 1, remind: 30 },
    { id: nextEv++, title: 'Car meet', place: 'Vinewood Hills', note: null, date: today(), minute: 21 * 60, length: 120, colour: 2, remind: null },
    { id: nextEv++, title: "Sam's birthday", place: null, note: null, date: shift(3), minute: null, length: null, colour: 5, remind: 0 },
    { id: nextEv++, title: 'Dentist', place: 'Mission Row', note: null, date: shift(11), minute: 9 * 60 + 30, length: 30, colour: 4, remind: 60 },
  );
}

const planOk = (text) => text && String(text).trim();

// ---- mail
const accounts = { 'sam@ravenmail.io': { password: 'secret1', name: 'Sam', code: 'ABCD2345WXYZ', fails: 0 } };
let me = null;
let mails = [];
let nextMail = 1;
const mailCounts = () => ({
  inbox: mails.filter((m) => m.folder === 'inbox').length,
  unread: mails.filter((m) => m.folder === 'inbox' && !m.read).length,
  sent: mails.filter((m) => m.folder === 'sent').length,
  trash: mails.filter((m) => m.folder === 'trash').length,
});
const mailHead = (m) => ({ id: m.id, from: m.from, fromName: m.fromName, to: m.to, subject: m.subject, preview: m.body.replace(/\s+/g, ' ').slice(0, 90), read: m.read, starred: m.starred, at: m.at, was: m.was });

function seedMail() {
  const t = now();
  const add = (o) => mails.unshift({ id: nextMail++, folder: 'inbox', read: false, starred: false, to: me.address, was: null, ...o });
  add({ from: 'noreply@ravenmail.io', fromName: 'Raven Mail', subject: 'Welcome to Raven Mail', body: 'Your address is ready. Write to anyone with a ravenmail.io address.', read: true, at: t - 900000 });
  add({ from: 'sam@ravenmail.io', fromName: 'Sam', subject: 'Car meet on Friday?', body: 'Hey,\n\nAre you coming to the car meet on Friday? Bring the Sultan.\n\nSam', at: t - 7200 });
  add({ from: 'courier@ravenmail.io', fromName: 'Courier', subject: 'Your parcel is out for delivery', body: 'Parcel #4821 will reach you today between 12:00 and 16:00.', at: t - 3600 });
  for (let i = 1; i <= 6; i++) add({ from: 'news@ravenmail.io', fromName: 'Los Santos Daily', subject: `Daily digest ${i}`, body: `Today's headlines, edition ${i}.`, read: true, at: t - 100000 - i * 1000 });
}

if (params.get('mail') === 'in') {
  me = { id: 1, address: 'you@ravenmail.io', name: 'You' };
  seedMail();
}

const lockMsg = (a) => ({ ok: false, reason: 'locked', seconds: 60 });

export async function organiserHandle(name, data) {
  switch (name) {
    // notes
    case 'noteList':
      return { ok: true, notes: [...notes].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.at - a.at).map(noteHead) };
    case 'noteGet': {
      const n = notes.find((x) => x.id === data.id);
      return n ? { ok: true, note: { ...n } } : { ok: false, reason: 'not_found' };
    }
    case 'noteSave': {
      const body = String(data.body ?? '').trim();
      let title = String(data.title ?? '').trim();
      if (!title && body) title = body.split('\n')[0].slice(0, 60);
      if (!title && !body) return { ok: false, reason: 'empty' };
      title = title || 'Note';
      if (data.id !== undefined) {
        const n = notes.find((x) => x.id === data.id);
        if (!n) return { ok: false, reason: 'not_found' };
        Object.assign(n, { title, body, at: now() });
        return { ok: true, note: { ...n } };
      }
      const n = { id: nextNote++, title, body, pinned: false, at: now() };
      notes.push(n);
      return { ok: true, note: { ...n } };
    }
    case 'notePin': {
      const n = notes.find((x) => x.id === data.id);
      if (n) n.pinned = data.on === true;
      return { ok: !!n };
    }
    case 'noteRemove': {
      const i = notes.findIndex((x) => x.id === data.id);
      if (i >= 0) notes.splice(i, 1);
      return { ok: i >= 0 };
    }

    // reminders
    case 'remList':
      return { ok: true, reminders: [...reminders].sort((a, b) => Number(a.done) - Number(b.done) || (a.date ?? '9999').localeCompare(b.date ?? '9999') || (a.minute ?? 0) - (b.minute ?? 0)) };
    case 'remSave': {
      if (!planOk(data.title)) return { ok: false, reason: 'empty' };
      const r = { title: String(data.title).trim(), note: data.note ? String(data.note).trim() : null, date: data.date || null, minute: data.date && data.minute !== undefined ? data.minute : null };
      if (data.id !== undefined) {
        const x = reminders.find((q) => q.id === data.id);
        if (!x) return { ok: false, reason: 'not_found' };
        Object.assign(x, r);
        return { ok: true, reminder: { ...x } };
      }
      const x = { id: nextRem++, done: false, ...r };
      reminders.push(x);
      return { ok: true, reminder: { ...x } };
    }
    case 'remDone': {
      const x = reminders.find((q) => q.id === data.id);
      if (x) x.done = data.done === true;
      return { ok: !!x };
    }
    case 'remRemove': {
      if (data.clearDone) {
        for (let i = reminders.length - 1; i >= 0; i--) if (reminders[i].done) reminders.splice(i, 1);
        return { ok: true };
      }
      const i = reminders.findIndex((q) => q.id === data.id);
      if (i >= 0) reminders.splice(i, 1);
      return { ok: i >= 0 };
    }

    // calendar
    case 'calList':
      return { ok: true, events: events.filter((e) => e.date >= data.from && e.date <= data.to).sort((a, b) => a.date.localeCompare(b.date) || (a.minute ?? -1) - (b.minute ?? -1)) };
    case 'calSave': {
      if (!planOk(data.title)) return { ok: false, reason: 'empty' };
      const e = {
        title: String(data.title).trim(), place: data.place ? String(data.place).trim() : null, note: data.note ? String(data.note).trim() : null, date: data.date,
        minute: data.minute ?? null, length: data.minute !== undefined ? data.length ?? null : null, colour: data.colour ?? 0, remind: data.remind ?? null,
      };
      if (data.id !== undefined) {
        const x = events.find((q) => q.id === data.id);
        if (!x) return { ok: false, reason: 'not_found' };
        Object.assign(x, e);
        return { ok: true, event: { ...x } };
      }
      const x = { id: nextEv++, ...e };
      events.push(x);
      return { ok: true, event: { ...x } };
    }
    case 'calRemove': {
      const i = events.findIndex((q) => q.id === data.id);
      if (i >= 0) events.splice(i, 1);
      return { ok: i >= 0 };
    }

    // mail
    case 'mailState':
      return me ? { ok: true, account: me, counts: mailCounts() } : { ok: true, account: null };
    case 'mailCreate': {
      const part = String(data.address ?? '').toLowerCase().trim();
      if (!/^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$/.test(part)) return { ok: false, reason: 'invalid_address' };
      if (['admin', 'support', 'mail'].includes(part)) return { ok: false, reason: 'reserved' };
      const address = `${part}@ravenmail.io`;
      if (accounts[address] || address === 'you@ravenmail.io') return { ok: false, reason: 'taken' };
      if (String(data.password ?? '').length < 6) return { ok: false, reason: 'weak_password' };
      accounts[address] = { password: data.password, name: data.name || null, code: 'QWER5678TYUI', fails: 0 };
      me = { id: 9, address, name: data.name || null };
      mails = [];
      return { ok: true, account: me, recovery: 'QWER-5678-TYUI', counts: mailCounts() };
    }
    case 'mailLogin': {
      const address = `${String(data.address ?? '').toLowerCase().replace(/@.*$/, '').trim()}@ravenmail.io`;
      const a = accounts[address];
      if (!a) return { ok: false, reason: 'wrong' };
      if (a.fails >= 5) return lockMsg(a);
      if (a.password !== data.password) {
        a.fails++;
        return a.fails >= 5 ? lockMsg(a) : { ok: false, reason: 'wrong' };
      }
      a.fails = 0;
      me = { id: 2, address, name: a.name };
      mails = [];
      seedMail();
      return { ok: true, account: me, counts: mailCounts() };
    }
    case 'mailReset': {
      const address = `${String(data.address ?? '').toLowerCase().replace(/@.*$/, '').trim()}@ravenmail.io`;
      const a = accounts[address];
      if (!a || String(data.code ?? '').replace(/[\s-]/g, '').toUpperCase() !== a.code) return { ok: false, reason: 'wrong' };
      if (String(data.password ?? '').length < 6) return { ok: false, reason: 'weak_password' };
      a.password = data.password;
      a.code = 'NEWC2345CODE';
      me = { id: 2, address, name: a.name };
      mails = [];
      seedMail();
      return { ok: true, account: me, recovery: 'NEWC-2345-CODE', counts: mailCounts() };
    }
    case 'mailLogout':
      me = null;
      return { ok: true };
    case 'mailPassword': {
      const a = accounts[me?.address];
      if (a && a.password !== data.old) return { ok: false, reason: 'wrong' };
      if (String(data.new ?? '').length < 6) return { ok: false, reason: 'weak_password' };
      if (a) a.password = data.new;
      return { ok: true };
    }
    case 'mailList': {
      if (!me) return { ok: false, reason: 'no_account' };
      let rows = mails.filter((m) => (data.folder === 'starred' ? m.starred && m.folder !== 'trash' : m.folder === data.folder));
      rows = rows.sort((a, b) => b.at - a.at || b.id - a.id);
      if (data.before) { const i = rows.findIndex((m) => m.id === data.before); if (i >= 0) rows = rows.slice(i + 1); }
      const page = rows.slice(0, 5);
      return { ok: true, messages: page.map(mailHead), more: rows.length > page.length, counts: mailCounts() };
    }
    case 'mailGet': {
      const m = mails.find((x) => x.id === data.id);
      if (!m) return { ok: false, reason: 'not_found' };
      m.read = true;
      return { ok: true, message: { ...mailHead(m), body: m.body, folder: m.folder }, counts: mailCounts() };
    }
    case 'mailSend': {
      if (!me) return { ok: false, reason: 'no_account' };
      const to = `${String(data.to ?? '').toLowerCase().replace(/@.*$/, '').trim()}@ravenmail.io`;
      if (!/^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]@ravenmail\.io$/.test(to)) return { ok: false, reason: 'invalid_address' };
      if (!accounts[to] && to !== me.address && to !== 'you@ravenmail.io') return { ok: false, reason: 'no_such_account' };
      if (!planOk(data.subject) && !planOk(data.body)) return { ok: false, reason: 'empty' };
      mails.unshift({ id: nextMail++, folder: 'sent', read: true, starred: false, from: me.address, fromName: me.name, to, subject: String(data.subject || '(no subject)').trim(), body: String(data.body ?? '').trim(), at: now(), was: null });
      return { ok: true, counts: mailCounts() };
    }
    case 'mailEdit': {
      const ids = new Set(data.ids ?? []);
      const sel = mails.filter((m) => ids.has(m.id));
      if (data.action === 'read') sel.forEach((m) => (m.read = data.on === true));
      else if (data.action === 'star') sel.forEach((m) => (m.starred = data.on === true));
      else if (data.action === 'trash') sel.forEach((m) => { m.was = m.folder; m.folder = 'trash'; });
      else if (data.action === 'restore') sel.forEach((m) => { m.folder = m.was ?? 'inbox'; m.was = null; });
      else if (data.action === 'erase') mails = mails.filter((m) => !(ids.has(m.id) && m.folder === 'trash'));
      else if (data.action === 'empty') mails = mails.filter((m) => m.folder !== 'trash');
      else return { ok: false, reason: 'invalid' };
      return { ok: true, counts: mailCounts() };
    }
  }
  return undefined;
}
