// A fake game, for working on the screen in a normal browser (npm run dev). It is never part of the build.
//
//   http://localhost:5173/?fold=cover|flex|open   start in this fold state
//   http://localhost:5173/?locked=1               start locked (PIN is 1234)
//   http://localhost:5173/?pin=0                  start with no PIN set
//   http://localhost:5173/?battery=15             start with this much battery (0 = empty)
//   http://localhost:5173/?charging=1             start on a charger
//   http://localhost:5173/?drain=1                battery goes down 2% every 3 seconds (or up, when charging)
//   http://localhost:5173/?signal=none|low|full   signal zone
//   http://localhost:5173/?airplane=1             start in airplane mode
//   http://localhost:5173/?ringtones=1            give the Sounds page some ringtones
//   http://localhost:5173/?style=list|stack|count notification style
//   http://localhost:5173/?many=1                 send a few more notifications (to try stack and count)
//   ?incoming=1|unknown, ?call=active, ?empty=1   see src/dev/comms-mock.js (calls, texts, contacts)
//   F1                                            take the phone out or put it away
import { installMock, dispatch } from '../lib/nui.js';
import { phone } from '../lib/store.svelte.js';
import { commsHandle, commsPayload } from './comms-mock.js';
import { mediaHandle, mediaPayload } from './media-mock.js';
import { organiserHandle, organiserFeatures } from './organiser-mock.js';
import { utilityHandle, utilityFeatures } from './utility-mock.js';

const params = new URLSearchParams(location.search);

const APPS = [
  ['phone', 'Phone', 'Core', true], ['messages', 'Messages', 'Core', true], ['contacts', 'Contacts', 'Core', true],
  ['camera', 'Camera', 'Core', true], ['gallery', 'Gallery', 'Core', true], ['mail', 'Mail', 'Core', true],
  ['maps', 'Maps', 'Core', true], ['music', 'Music', 'Core', true], ['notes', 'Notes', 'Core', true],
  ['calendar', 'Calendar', 'Core', true], ['reminders', 'Reminders', 'Core', true], ['clock', 'Clock', 'Core', true],
  ['calculator', 'Calculator', 'Core', true], ['weather', 'Weather', 'Core', true], ['wallet', 'Wallet', 'Core', true],
  ['health', 'Health', 'Core', true], ['settings', 'Settings', 'Core', true], ['store', 'App Store', 'Core', true],
  ['lens', 'Lens', 'Social', false], ['saga', 'Saga', 'Social', false], ['hearth', 'Hearth', 'Social', false],
  ['pulse', 'Pulse', 'Social', false], ['freyja', 'Freyja', 'Social', false], ['veil', 'Veil', 'Social', false],
  ['watch', 'Watch', 'Social', false], ['bazaar', 'Bazaar', 'Services', false], ['noticeboard', 'Notice Board', 'Services', false],
  ['garage', 'Garage', 'Services', false], ['jobs', 'Jobs', 'Services', false],
].map(([id, label, category, preinstalled]) => ({ id, label, category, preinstalled }));

const installed = APPS.filter((a) => a.preinstalled).map((a) => a.id);

const db = {
  pin: params.get('pin') === '0' ? null : '1234',
  fails: 0,
  lockedUntil: 0,
  settings: {},
  layout: {
    dock: ['phone', 'messages', 'camera', 'settings'],
    items: installed.filter((id) => !['phone', 'messages', 'camera', 'settings'].includes(id)),
  },
};

const lockouts = { 5: 30, 6: 60, 7: 300, 8: 900 };

function lockedFor() {
  return Math.max(0, Math.ceil((db.lockedUntil - Date.now()) / 1000));
}

function merge(base, patch) {
  for (const k of Object.keys(patch || {})) {
    if (patch[k] && typeof patch[k] === 'object' && !Array.isArray(patch[k])) merge((base[k] ??= {}), patch[k]);
    else base[k] = patch[k];
  }
  return base;
}

function checkPin(pin) {
  if (!db.pin) return { ok: true };
  const wait = lockedFor();
  if (wait > 0) return { ok: false, reason: 'locked', lockedFor: wait };
  if (pin === db.pin) {
    db.fails = 0;
    return { ok: true };
  }
  db.fails += 1;
  const seconds = Object.keys(lockouts).reduce((s, n) => (db.fails >= Number(n) ? lockouts[n] : s), 0);
  if (seconds) db.lockedUntil = Date.now() + seconds * 1000;
  return { ok: false, reason: seconds ? 'locked' : 'wrong', lockedFor: seconds };
}

// ---- battery and signal (the real server works these out. This is a rough copy so the screen can be tried)

const sim = {
  battery: Number.isFinite(Number(params.get('battery'))) && params.get('battery') !== null ? Number(params.get('battery')) : 87,
  charging: params.get('charging') === '1',
  drain: params.get('drain') === '1',
  signal: ['full', 'low', 'none'].includes(params.get('signal')) ? params.get('signal') : 'full',
};
sim.powered = sim.battery >= 2;
if (params.get('airplane') === '1') db.settings.quick = { airplane: true };
if (['list', 'stack', 'count'].includes(params.get('style'))) db.settings.notify = { style: params.get('style') };

function snapshot() {
  const airplane = db.settings.quick?.airplane === true;
  const bars = airplane ? 0 : { full: 4, low: 1, none: 0 }[sim.signal];
  return {
    battery: Math.round(sim.battery),
    charging: sim.charging,
    powered: sim.powered,
    lowPower: db.settings.battery?.lowPower === true,
    signal: { level: airplane ? 'none' : sim.signal, bars, service: !airplane && sim.signal !== 'none', airplane, carrier: 'Raven Mobile' },
  };
}

function pushStatus() {
  dispatch('status', snapshot());
}

function systemNote(title, message, level) {
  dispatch('notify', { id: `battery-${title}`, app: 'system', titleKey: title, messageKey: message, data: { level }, at: Math.floor(Date.now() / 1000), banner: true, lock: true, sound: true });
}

setInterval(() => {
  if (!sim.drain && !sim.charging) return;
  const before = sim.battery;
  sim.battery = Math.max(0, Math.min(100, before + (sim.charging ? 2 : -2)));
  if (!sim.powered && sim.battery >= 2) sim.powered = true;
  if (sim.powered && sim.battery <= 0) sim.powered = false;
  if (!sim.charging && before > 20 && sim.battery <= 20) {
    const auto = db.settings.battery?.autoLowPower !== false && !db.settings.battery?.lowPower;
    if (auto) {
      merge(db.settings, { battery: { lowPower: true } });
      dispatch('settings', { battery: { lowPower: true } });
    }
    systemNote('battery.low', auto ? 'battery.lowOn' : 'battery.lowOnly', Math.round(sim.battery));
  } else if (!sim.charging && before > 10 && sim.battery <= 10) {
    systemNote('battery.critical', 'battery.criticalText', Math.round(sim.battery));
  }
  pushStatus();
}, 3000);

installMock(async (name, data) => {
  await new Promise((r) => setTimeout(r, 60));
  switch (name) {
    case 'unlock':
      return checkPin(data.pin);
    case 'lock':
      return true;
    case 'setPin': {
      if (!/^\d{4}$|^\d{6}$/.test(String(data.pin))) return { ok: false, reason: 'invalid_pin' };
      if (db.pin) {
        const r = checkPin(data.old);
        if (!r.ok) return r;
      }
      db.pin = data.pin;
      return { ok: true, length: data.pin.length };
    }
    case 'removePin': {
      const r = checkPin(data.pin);
      if (!r.ok) return r;
      db.pin = null;
      return { ok: true };
    }
    case 'saveSettings':
      merge(db.settings, data);
      pushStatus();
      return { ok: true, settings: db.settings };
    case 'batteryUsage':
      return {
        ok: true,
        usage: [
          { app: 'standby', percent: 3.4 },
          { app: 'home', percent: 2.1 },
          { app: 'maps', percent: 1.2 },
          { app: 'music', percent: 0.6 },
          { app: 'clock', percent: 0.2 },
        ],
      };
    case 'saveLayout':
      db.layout = data;
      return { ok: true, layout: data };
    default: {
      let r = await commsHandle(name, data);
      if (r === undefined) r = await mediaHandle(name, data);
      if (r === undefined) r = await organiserHandle(name, data);
      if (r === undefined) r = await utilityHandle(name, data);
      return r === undefined ? 1 : r;
    }
  }
});

function clockSnapshot() {
  const d = new Date();
  // ?gamehour=3 makes the game clock differ from the computer's, to try the clock source setting.
  const gh = params.get('gamehour');
  if (gh !== null) d.setHours(Number(gh), 17, 0);
  return { h: d.getHours(), m: d.getMinutes(), s: d.getSeconds(), dow: d.getDay(), day: d.getDate(), month: d.getMonth() + 1, year: d.getFullYear(), weather: params.get('weather') || 'rain', nextWeather: params.get('next') || 'clear', wind: 4.6, rain: 0.35 };
}

function openPayload() {
  const fold = ['cover', 'flex', 'open'].includes(params.get('fold')) ? params.get('fold') : 'open';
  return {
    phone: { id: 'own:dev', number: '555-0142' },
    // The real server sends an empty table as [], so the screen has to cope with that.
    settings: { ...db.settings, notify: { style: 'list', apps: [], ...(db.settings.notify ?? {}) } },
    status: snapshot(),
    ringtones: params.get('ringtones') === '1' ? [{ id: 'classic', label: 'Classic' }, { id: 'chime', label: 'Chime' }, { id: 'pulse', label: 'Pulse' }] : [],
    layout: db.layout,
    apps: APPS,
    installed,
    lock: {
      enabled: db.pin !== null,
      length: db.pin ? db.pin.length : 4,
      locked: db.pin !== null && params.get('locked') === '1',
      lockedFor: lockedFor(),
    },
    features: { fold: { cover: true, flex: true, splitScreen: true, appContinuity: true }, battery: { enabled: true }, signal: { enabled: true }, pinLengths: [4, 6], calls: commsPayload().calls, media: mediaPayload(), share: { range: 10 }, ...organiserFeatures(), ...utilityFeatures() },
    contacts: commsPayload().contacts,
    badges: commsPayload().badges,
    sounds: {},
    fold,
    locale: 'en',
    openApp: params.get('app') || undefined,
  };
}

dispatch('clock', clockSnapshot());
setInterval(() => dispatch('clock', clockSnapshot()), 1000);
dispatch('open', openPayload());

if (params.get('many') === '1') {
  const now = Math.floor(Date.now() / 1000);
  setTimeout(() => {
    dispatch('notify', { id: 'm2', app: 'messages', title: 'Mum', message: 'Bring milk please', at: now - 90 });
    dispatch('notify', { id: 'm3', app: 'messages', title: 'Sam', message: 'Stream starts at 8?', at: now - 60 });
    dispatch('notify', { id: 'w1', app: 'weather', title: 'Rain soon', message: 'Showers from 4pm.', at: now - 45 });
  }, 2200);
}

if (params.get('notify') !== '0') {
  setTimeout(() => dispatch('notify', { id: 'm1', app: 'messages', title: 'Mum', message: 'Are you coming for tea later?', at: Math.floor(Date.now() / 1000) - 120 }), 1200);
  setTimeout(() => dispatch('notify', { id: 'e1', app: 'mail', title: 'Parcel update', message: 'Your parcel is out for delivery.', at: Math.floor(Date.now() / 1000) - 30 }), 1800);
}

window.addEventListener('keydown', (e) => {
  if (e.key !== 'F1') return;
  e.preventDefault();
  if (phone.visible) dispatch('close');
  else dispatch('open', openPayload());
});
