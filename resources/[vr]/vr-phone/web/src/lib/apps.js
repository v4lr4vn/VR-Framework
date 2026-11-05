// How each built-in app looks, and where its code lives.
//
// To add an app screen: write a Svelte component, then add one line to `loaders`.
// The import() makes the build put that app in its own file, so the phone only downloads it
// the first time it is opened. Apps without a loader open a "coming soon" page.
//
// Apps added by other scripts (custom app API, a later build step) bring their own colour and icon.
import { phone } from './store.svelte.js';
import { t } from './i18n.js';

export const appMeta = {
  phone: { color: '#27a869', glyph: 'phone' },
  messages: { color: '#3b82f6', glyph: 'message' },
  contacts: { color: '#8b7f72', glyph: 'contacts' },
  camera: { color: '#2b2a33', glyph: 'camera' },
  gallery: { color: '#f0a22e', glyph: 'gallery' },
  mail: { color: '#4f7df0', glyph: 'mail' },
  maps: { color: '#1fa596', glyph: 'maps' },
  music: { color: '#e5484d', glyph: 'music' },
  notes: { color: '#f2c230', glyph: 'notes' },
  calendar: { color: '#ec5b5b', glyph: 'calendar' },
  reminders: { color: '#7a5cff', glyph: 'reminders' },
  clock: { color: '#1f2430', glyph: 'clock' },
  calculator: { color: '#5b6270', glyph: 'calculator' },
  weather: { color: '#3aa0e8', glyph: 'weather' },
  wallet: { color: '#1b8f6c', glyph: 'wallet' },
  health: { color: '#e8527a', glyph: 'health' },
  settings: { color: '#6b7280', glyph: 'settings' },
  system: { color: '#475569', glyph: 'power' },
  store: { color: '#4668f0', glyph: 'store' },
  lens: { color: '#d6409f', glyph: 'lens' },
  saga: { color: '#2189d9', glyph: 'saga' },
  hearth: { color: '#f06a35', glyph: 'hearth' },
  pulse: { color: '#111827', glyph: 'pulse' },
  freyja: { color: '#ff4d7e', glyph: 'freyja' },
  veil: { color: '#6d4aff', glyph: 'veil' },
  watch: { color: '#e11d48', glyph: 'watch' },
  bazaar: { color: '#14a38b', glyph: 'bazaar' },
  noticeboard: { color: '#c98a2b', glyph: 'noticeboard' },
  garage: { color: '#475569', glyph: 'garage' },
  jobs: { color: '#7c5a3a', glyph: 'jobs' },
};

export const loaders = {
  phone: () => import('../apps/phone/Phone.svelte'),
  messages: () => import('../apps/messages/Messages.svelte'),
  contacts: () => import('../apps/contacts/Contacts.svelte'),
  settings: () => import('../apps/settings/Settings.svelte'),
  clock: () => import('../apps/clock/Clock.svelte'),
  camera: () => import('../apps/camera/Camera.svelte'),
  gallery: () => import('../apps/gallery/Gallery.svelte'),
  notes: () => import('../apps/notes/Notes.svelte'),
  reminders: () => import('../apps/reminders/Reminders.svelte'),
  calendar: () => import('../apps/calendar/Calendar.svelte'),
  calculator: () => import('../apps/calculator/Calculator.svelte'),
  weather: () => import('../apps/weather/Weather.svelte'),
  mail: () => import('../apps/mail/Mail.svelte'),
  wallet: () => import('../apps/wallet/Wallet.svelte'),
  maps: () => import('../apps/maps/Maps.svelte'),
  health: () => import('../apps/health/Health.svelte'),
};

// Apps that fill the whole game view instead of the phone's screen. The phone body hides while one of them is open.
export const fullscreenApps = new Set(['camera']);

export function metaFor(id, def) {
  return appMeta[id] ?? { color: def?.color ?? '#7a5cff', glyph: def?.glyph ?? 'grid' };
}

export function isReady(id) {
  return Object.prototype.hasOwnProperty.call(loaders, id);
}

// The name shown under an icon: from the language file when there is one, otherwise the app's own label.
export function appLabel(id) {
  const key = `app.${id}`;
  const text = t(key);
  return text !== key ? text : phone.appDefs[id]?.label ?? id;
}
