// All phone state lives here, in one reactive object. Components read `phone` and call the functions below.
import { post } from './nui.js';
import { setLocale, t } from './i18n.js';
import { setSounds, setSoundPrefs, play } from './sfx.js';
import { initMedia } from './media.svelte.js';
import { comms, initComms, setVisible, onMessage, onNotice, backFromCall } from './comms.svelte.js';

const DEFAULT_SETTINGS = {
  theme: { accent: '#7a5cff', dark: false, scale: 0.85 },
  wallpaper: { home: 'aurora', lock: 'dusk' },
  lock: { showPreviews: true, clock: 'stack' },
  frame: { color: '#2b2a33' },
  general: { time24: true, timeSource: 'pc' },
  profile: { name: '' },
  quick: { airplane: false, bluetooth: false, silent: false, brightness: 1, audio: 'phone' },
  battery: { lowPower: false, autoLowPower: true, showPercent: true },
  perf: { reduceMotion: false },
  notify: { style: 'list', apps: {} },
  sound: { volume: 0.6, notifications: true, touch: true, ringtone: 'default' },
  health: { goal: 8000, imperial: false },
};

const DEFAULT_STATUS = {
  battery: 100,
  charging: false,
  powered: true,
  lowPower: false,
  signal: { level: 'full', bars: 4, service: true, airplane: false, carrier: '' },
};

export const phone = $state({
  visible: false, // the phone is out (the device is drawn)
  fold: 'open', // 'cover' | 'flex' | 'open'
  locked: true,
  lock: { enabled: false, length: 4 },
  lockUntil: 0, // timestamp (ms) until which PIN entry is blocked
  number: '',
  phoneId: '',
  settings: structuredClone(DEFAULT_SETTINGS),
  layout: { dock: [], items: [] },
  appDefs: {}, // id -> { id, label, category, ... }
  installed: [],
  features: {
    fold: { cover: true, flex: true, splitScreen: true, appContinuity: true },
    battery: { enabled: true },
    signal: { enabled: true },
    pinLengths: [4, 6],
  },
  locale: 'en',
  clock: { h: 12, m: 0, s: 0, dow: 1, day: 1, month: 1, year: 2026, weather: 'clear' },
  status: structuredClone(DEFAULT_STATUS), // battery and signal, worked out by the server
  booting: false, // the phone has power again and is starting up
  ringtones: [], // [{ id, label }] from config/phone.lua
  panel: false, // the quick panel is open
  notifications: [], // newest first
  toasts: [],
  app: null, // the open app. It stays open when the phone is folded or put away (app continuity)
  recents: [],
  focusMode: false, // a text box has focus
});

// A clock that ticks every few seconds, so "5m ago" labels stay fresh.
export const tick = $state({ now: Date.now() });

// Ticks every second so the clock on screen can follow the player's computer. It only runs while something reads it.
export const pcTick = $state({ now: Date.now() });

// ---- helpers

// Copies `patch` into `base`. FiveM sends an empty Lua table as [], so an empty list never replaces a section that is an object.
function merge(base, patch) {
  for (const key of Object.keys(patch ?? {})) {
    const value = patch[key];
    const here = base[key];
    const isObject = here && typeof here === 'object' && !Array.isArray(here);
    if (Array.isArray(value) && value.length === 0 && isObject) {
      base[key] = {};
    } else if (value && typeof value === 'object' && !Array.isArray(value) && isObject) {
      merge(here, value);
    } else {
      base[key] = value;
    }
  }
  return base;
}

const asArray = (value) => (Array.isArray(value) ? value : []);

// ---- opening and closing

export function openPhone(data) {
  phone.number = data.phone?.number ?? '';
  phone.phoneId = data.phone?.id ?? '';
  phone.settings = merge(structuredClone(DEFAULT_SETTINGS), data.settings);
  phone.layout = { dock: asArray(data.layout?.dock), items: asArray(data.layout?.items) };
  phone.appDefs = Object.fromEntries(asArray(data.apps).map((app) => [app.id, app]));
  phone.installed = asArray(data.installed);
  phone.ringtones = asArray(data.ringtones).filter((r) => r && typeof r.id === 'string');
  if (data.features) phone.features = merge(phone.features, data.features);
  phone.locale = data.locale ?? 'en';
  setLocale(phone.locale);
  setSounds(data.sounds);
  initComms(data);
  initMedia(data.features);
  setVisible(true);
  phone.booting = false;
  phone.status = merge(structuredClone(DEFAULT_STATUS), data.status);
  syncSound();

  phone.lock = { enabled: data.lock?.enabled === true, length: data.lock?.length || 4 };
  phone.lockUntil = data.lock?.lockedFor > 0 ? Date.now() + data.lock.lockedFor * 1000 : 0;
  phone.locked = data.lock?.locked === true || !phone.status.powered;

  phone.fold = foldAllowed(data.fold) ? data.fold : 'open';
  phone.visible = true;
  phone.panel = false;
  phone.focusMode = false;
  typingNow = false;

  if (!phone.status.powered) phone.app = null;
  if (data.openApp && phone.installed.includes(data.openApp)) openApp(data.openApp);
  // The phone remembers the open app, but the server forgot it while the phone was away.
  else if (phone.app) post('app', { id: phone.app });
}

// Called when the game says the phone is away (or the player pressed the close key).
export function hidePhone() {
  phone.visible = false;
  setVisible(false);
  phone.panel = false;
  phone.focusMode = false;
  typingNow = false;
}

// The player closed the phone from the screen.
export function closePhone() {
  hidePhone();
  post('close');
}

function foldAllowed(state) {
  return (state === 'cover' || state === 'flex' || state === 'open') && phone.features.fold[state] !== false;
}

export function setFold(state) {
  if (!foldAllowed(state) || state === phone.fold) return;
  phone.fold = state;
  play('hinge');
  post('fold', { state });
}

// ---- lock

export async function unlock(pin) {
  const result = await post('unlock', { pin });
  if (result?.ok) {
    phone.locked = false;
    phone.lockUntil = 0;
    play('lock');
  } else if (result?.lockedFor > 0) {
    phone.lockUntil = Date.now() + result.lockedFor * 1000;
  }
  return result ?? { ok: false, reason: 'timeout' };
}

// Without a PIN the lock screen is only a screen, so nothing needs asking.
export function unlockWithoutPin() {
  if (phone.lock.enabled) return;
  phone.locked = false;
}

export function lockPhone() {
  phone.locked = true;
  phone.panel = false;
  play('lock');
  if (phone.lock.enabled) post('lock');
}

// Used by the settings app after the PIN changed.
export function setLockState({ enabled, length }) {
  phone.lock = { enabled, length: length || phone.lock.length };
  if (!enabled) phone.lockUntil = 0;
}

// ---- apps and navigation

export function openApp(id) {
  if (!phone.installed.includes(id)) return;
  phone.app = id;
  phone.panel = false;
  phone.recents = [id, ...phone.recents.filter((r) => r !== id)].slice(0, 4);
  phone.notifications = phone.notifications.map((n) => (n.app === id ? { ...n, read: true } : n));
  post('app', { id });
}

export function goHome() {
  phone.panel = false;
  if (backFromCall()) return;
  if (phone.app === null) return;
  phone.app = null;
  post('app', { id: null });
}

let backHandler = null;

// An app can register what the back button does (return true when it handled it).
export function onBack(fn) {
  backHandler = fn;
  return () => {
    if (backHandler === fn) backHandler = null;
  };
}

export function goBack() {
  if (phone.panel) {
    phone.panel = false;
    return;
  }
  if (backFromCall()) return;
  if (backHandler && backHandler() === true) return;
  goHome();
}

// ---- the quick panel

export function togglePanel() {
  if (!phone.status.powered) return;
  phone.panel = !phone.panel;
  // The panel shows the same notifications, so waiting banners are not needed.
  if (phone.panel) phone.toasts = [];
}

export function closePanel() {
  phone.panel = false;
}

// ---- battery and signal (the server works these out and sends them)

export function setStatus(next) {
  if (!next || typeof next !== 'object') return;
  const wasOn = phone.status.powered;
  phone.status = merge(structuredClone($state.snapshot(phone.status)), next);

  if (wasOn && !phone.status.powered) {
    // A dead phone closes everything. It starts on the lock screen when it comes back.
    phone.panel = false;
    phone.app = null;
    phone.locked = true;
    phone.toasts = [];
  } else if (!wasOn && phone.status.powered) {
    phone.booting = true;
    setTimeout(() => (phone.booting = false), 1700);
  }
}

// A few settings also show in the status (Low Power Mode, airplane mode). The screen follows them at once,
// and the server's answer a moment later has the final word.
function mirrorStatus(patch) {
  if (typeof patch?.battery?.lowPower === 'boolean') phone.status.lowPower = patch.battery.lowPower;
  if (typeof patch?.quick?.airplane === 'boolean') {
    phone.status.signal.airplane = patch.quick.airplane;
    if (patch.quick.airplane) {
      phone.status.signal.bars = 0;
      phone.status.signal.service = false;
    }
  }
}

// The server changed a setting itself (Low Power Mode switching on at 20%).
export function applySettingsPatch(patch) {
  if (!patch || typeof patch !== 'object') return;
  merge(phone.settings, patch);
  mirrorStatus(patch);
}

// ---- settings and layout (changes show at once and are saved a moment later)

let pendingSettings = null;
let settingsTimer = 0;

export function saveSettings(patch) {
  merge(phone.settings, patch);
  mirrorStatus(patch);
  pendingSettings = merge(pendingSettings ?? {}, structuredClone(patch));
  clearTimeout(settingsTimer);
  settingsTimer = setTimeout(async () => {
    const send = pendingSettings;
    pendingSettings = null;
    await post('saveSettings', send);
  }, 250);
}

// Quick panel switches. Audio can only go to Bluetooth while Bluetooth is on.
export function setQuick(patch) {
  const next = { ...patch };
  if (next.bluetooth === false && phone.settings.quick.audio === 'bluetooth') next.audio = 'phone';
  saveSettings({ quick: next });
}

export function setLowPower(on) {
  saveSettings({ battery: { lowPower: on === true } });
}

export async function saveLayout(layout) {
  phone.layout = { dock: asArray(layout.dock), items: asArray(layout.items) };
  const result = await post('saveLayout', $state.snapshot(phone.layout));
  if (result?.ok && result.layout) {
    phone.layout = { dock: asArray(result.layout.dock), items: asArray(result.layout.items) };
  }
}

// The sound settings reach the sound player.
export function syncSound() {
  const s = phone.settings;
  setSoundPrefs({ volume: s.sound.volume, touch: s.sound.touch, silent: s.quick.silent });
}

// ---- notifications

// The phone's own notifications carry text keys (so they follow the language). Others carry words.
export const noteTitle = (n) => (n.titleKey ? t(n.titleKey, n.data) : n.title);
export const noteText = (n) => (n.messageKey ? t(n.messageKey, n.data) : n.message);

// Notifications the lock screen may show: the player can hide an app from it.
export const lockVisible = (list) => list.filter((n) => n.lock !== false);

// Notifications the player is already looking at (a text in the conversation that is open) make no noise and no banner.
const quiet = new Set();

// A new text from the game.
export function receiveMessage(m) {
  if (onMessage(m) && m?.id !== undefined) {
    quiet.add(`msg-${m.id}`);
    setTimeout(() => quiet.delete(`msg-${m.id}`), 8000);
  }
}

export function pushNotification(n) {
  if (!n || typeof n !== 'object') return;
  if (n.id && quiet.has(n.id)) {
    quiet.delete(n.id);
    return;
  }
  const item = {
    id: n.id ?? `n${Date.now()}`,
    app: n.app ?? 'system',
    title: n.title ?? '',
    message: n.message ?? '',
    titleKey: n.titleKey ?? '',
    messageKey: n.messageKey ?? '',
    data: n.data && typeof n.data === 'object' ? n.data : undefined,
    at: n.at ? n.at * 1000 : Date.now(),
    read: false,
    banner: n.banner !== false,
    lock: n.lock !== false,
  };
  phone.notifications = [item, ...phone.notifications.filter((x) => x.id !== item.id)].slice(0, 50);
  if (item.app === 'messages' || item.app === 'phone' || item.app === 'mail') onNotice(item);
  if (n.sound !== false) play('notify');

  const seen = phone.visible && !phone.locked && phone.app === item.app;
  if (seen) {
    phone.notifications = phone.notifications.map((x) => (x.id === item.id ? { ...x, read: true } : x));
    return;
  }
  // No banner when the player turned it off, when the quick panel already shows the list,
  // or when the lock screen is not allowed to show this app.
  if (!item.banner || (phone.panel && phone.visible)) return;
  if (phone.locked && !item.lock) return;

  const toast = { ...item, tid: `${item.id}-${Date.now()}` };
  phone.toasts = [toast, ...phone.toasts].slice(0, 3);
  setTimeout(() => dismissToast(toast.tid), 4800);
}

export function dismissToast(tid) {
  phone.toasts = phone.toasts.filter((x) => x.tid !== tid);
}

export function dismissNotification(id) {
  phone.notifications = phone.notifications.filter((n) => n.id !== id);
}

export function clearNotifications() {
  phone.notifications = [];
}

export function unreadFor(appId) {
  // The server counts these two (they are still right after the phone was away and notifications were lost).
  if (appId === 'messages') return comms.badges.messages;
  if (appId === 'phone') return comms.badges.phone;
  if (appId === 'mail') return comms.badges.mail;
  return phone.notifications.filter((n) => n.app === appId && !n.read).length;
}

// ---- clock

// The clock to show on screen: the player's computer or the game, whichever the setting says.
// The browser inside FiveM runs on the player's own computer, so `new Date()` is their local time.
// (Reminders, Calendar and Weather read `phone.clock` directly: they always use the game clock.)
export function shownClock() {
  if (phone.settings.general.timeSource === 'game') return phone.clock;
  const d = new Date(pcTick.now);
  return { ...phone.clock, h: d.getHours(), m: d.getMinutes(), s: d.getSeconds(), dow: d.getDay(), day: d.getDate(), month: d.getMonth() + 1, year: d.getFullYear() };
}

export function setClock(c) {
  if (c && typeof c === 'object') phone.clock = { ...phone.clock, ...c };
}

// ---- text boxes: while one has focus, the game must not treat keys as movement

// (A plain variable keeps track, so calling this from inside an $effect does not make the effect depend on the state.)
let typingNow = false;

export function setTyping(active) {
  if (typingNow === active) return;
  typingNow = active;
  phone.focusMode = active;
  post('inputFocus', { active });
}
