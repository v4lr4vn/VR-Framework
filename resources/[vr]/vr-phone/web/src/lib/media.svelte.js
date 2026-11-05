// Photos, albums and nearby share. The server keeps all of it; this file keeps what the screen is showing.
//
// It does not import the phone store (the store imports apps that import this file), so anything it needs from the phone is passed in.
import { post } from './nui.js';
import { t } from './i18n.js';

export const media = $state({
  view: 'all', // 'all' | 'favourites' | 'albums' | 'deleted' | 'album'
  album: null, // the id of the album that is open
  items: [],
  more: false,
  loaded: false,
  loading: false,
  albums: [],
  stats: { photos: 0, bytes: 0, deleted: 0, max: 120 },
  limits: { maxWidth: 960, quality: 0.72, thumbWidth: 200, pageSize: 24, keepDeletedDays: 30, timerSeconds: [3, 10] },
  last: null, // the newest photo's thumbnail, for the corner of the camera
  rev: 0, // bumped when a photo is added, so an open Gallery knows to reload
});

const asArray = (value) => (Array.isArray(value) ? value : []);

export function initMedia(features) {
  const m = features?.media;
  if (m) {
    media.limits = {
      maxWidth: Number(m.maxWidth) || 960,
      quality: Math.min(0.95, Math.max(0.3, Number(m.quality) || 0.72)),
      thumbWidth: Number(m.thumbWidth) || 200,
      pageSize: Number(m.pageSize) || 24,
      keepDeletedDays: Number(m.keepDeletedDays) || 30,
      timerSeconds: asArray(m.timerSeconds).length ? asArray(m.timerSeconds) : [3, 10],
    };
    if (Number(m.maxPhotos)) media.stats.max = Number(m.maxPhotos);
  }
  media.items = [];
  media.loaded = false;
  media.view = 'all';
  media.album = null;
  media.last = null;
  media.albums = [];
}

// The words for a reason from the server. Photo and share reasons have their own text, because 'full' and 'duplicate'
// mean something else in Contacts. Anything else falls back to the general messages.
export const mediaError = (reason, scope = 'media') => {
  for (const key of [`${scope}.err.${reason}`, `err.${reason}`]) {
    const text = t(key);
    if (text !== key) return text;
  }
  return t('err.timeout');
};

// ---- the lists

function query() {
  if (media.view === 'albums') return null;
  return { view: media.view, album: media.album };
}

export async function loadPhotos(reset = true) {
  const q = query();
  if (!q || media.loading) return;
  media.loading = true;
  const before = reset ? undefined : media.items[media.items.length - 1]?.id;
  const view = media.view;
  const album = media.album;
  const r = await post('mediaList', { ...q, before });
  media.loading = false;
  // The player may have moved to another tab while this was loading.
  if (view !== media.view || album !== media.album) return;
  if (!r?.ok) return;
  media.items = reset ? asArray(r.items) : [...media.items, ...asArray(r.items)];
  media.more = r.more === true;
  media.loaded = true;
  if (reset && view === 'all' && media.items[0]) media.last = media.items[0].thumb;
}

export async function loadStats() {
  const r = await post('mediaStats');
  if (r?.ok) {
    media.stats = { ...media.stats, ...r.stats };
    media.albums = asArray(r.albums);
  }
}

export function showView(view, album = null) {
  media.view = view;
  media.album = album;
  media.items = [];
  media.more = false;
  media.loaded = false;
  if (view === 'albums') loadStats();
  else loadPhotos(true);
}

// ---- looking at one photo

const full = new Map(); // id -> picture (the last few that were opened)

export async function fetchPhoto(id) {
  if (full.has(id)) return full.get(id);
  const r = await post('mediaGet', { id });
  if (!r?.ok) return null;
  full.set(id, r.photo);
  if (full.size > 8) full.delete(full.keys().next().value);
  return r.photo;
}

// ---- changing photos

export async function editPhotos(action, ids = [], extra = {}) {
  const r = await post('mediaEdit', { action, ids, ...extra });
  if (r?.ok) {
    if (action === 'trash' || action === 'erase' || action === 'empty') for (const id of ids) full.delete(id);
    await Promise.all([loadPhotos(true), loadStats()]);
  }
  return r ?? { ok: false, reason: 'timeout' };
}

export async function albumAction(data) {
  const r = await post('mediaAlbum', data);
  if (r?.ok) await loadStats();
  return r ?? { ok: false, reason: 'timeout' };
}

// ---- taking a photo

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('image'));
    img.src = src;
  });
}

function scaled(img, width, quality) {
  const w = Math.min(width, img.naturalWidth);
  const h = Math.max(1, Math.round((img.naturalHeight * w) / img.naturalWidth));
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  canvas.getContext('2d').drawImage(img, 0, 0, w, h);
  return { uri: canvas.toDataURL('image/jpeg', quality), width: w, height: h };
}

// Shrinks a picture from the game to a size worth keeping: { data, thumb, width, height }.
export async function shrink(source) {
  const img = await loadImage(source);
  const main = scaled(img, media.limits.maxWidth, media.limits.quality);
  const thumb = scaled(img, media.limits.thumbWidth, 0.6);
  return { data: main.uri, thumb: thumb.uri, width: main.width, height: main.height };
}

// Shrinks a camera picture and sends it to the server. Returns { ok, photo } or { ok: false, reason }.
export async function savePhoto(source) {
  let picture;
  try {
    picture = await shrink(source);
  } catch {
    return { ok: false, reason: 'invalid_image' };
  }
  const r = await post('mediaUpload', picture);
  if (r?.ok && r.photo) {
    media.last = r.photo.thumb;
    media.rev += 1;
    media.stats.photos += 1;
  }
  return r ?? { ok: false, reason: 'timeout' };
}

// ---- nearby share

export const share = $state({
  picker: null, // { kind: 'photo' | 'contact', ids: [], label } while the player is choosing who to send to
  people: [],
  bluetooth: true,
  loading: false,
  sending: null, // { id, name } while waiting for the answer
  error: '',
  incoming: [], // requests from other players: { id, name, kind, count, preview, until }
});

let nearTimer = 0;

export function startShare(kind, ids, label = '') {
  const list = asArray(ids);
  if (!list.length) return;
  share.picker = { kind, ids: list, label };
  share.error = '';
  share.people = [];
  refreshNearby();
}

export function cancelPicker() {
  share.picker = null;
  clearTimeout(nearTimer);
}

export async function refreshNearby() {
  if (!share.picker) return;
  share.loading = true;
  const r = await post('shareNearby');
  share.loading = false;
  if (!share.picker) return;
  if (r?.ok) {
    share.people = asArray(r.people);
    share.bluetooth = r.bluetooth !== false;
  }
  clearTimeout(nearTimer);
  // Keep looking while the sheet is open: people walk up and away.
  nearTimer = setTimeout(refreshNearby, 3000);
}

export async function sendShare(target) {
  if (!share.picker || share.sending) return;
  const p = share.picker;
  share.error = '';
  const r = await post('shareSend', { target: target.id, kind: p.kind, ids: p.ids });
  if (!r?.ok) {
    share.error = mediaError(r?.reason, 'share');
    refreshNearby();
    return;
  }
  clearTimeout(nearTimer);
  share.picker = null;
  share.sending = { id: r.id, name: target.name };
}

export async function cancelSending() {
  const s = share.sending;
  share.sending = null;
  if (s) await post('shareCancel', { id: s.id });
}

// A request from another player.
export function onShareIncoming(req) {
  if (!req || typeof req.id !== 'string') return;
  const until = Date.now() + (Number(req.seconds) || 60) * 1000;
  share.incoming = [...share.incoming.filter((x) => x.id !== req.id), { ...req, until }];
}

export async function respondShare(id, accept) {
  const req = share.incoming.find((x) => x.id === id);
  share.incoming = share.incoming.filter((x) => x.id !== id);
  if (!req) return { ok: false };
  const r = await post('shareRespond', { id, accept });
  if (r?.ok && accept) {
    media.rev += 1;
    if (req.kind === 'photo') loadStats();
  }
  return r ?? { ok: false, reason: 'timeout' };
}

// The other player's answer to a request this player sent.
export function onShareResult(result) {
  if (share.sending && share.sending.id === result?.id) share.sending = null;
}

export function onShareClosed(result) {
  share.incoming = share.incoming.filter((x) => x.id !== result?.id);
}

export function dropExpired(now) {
  if (share.incoming.some((x) => x.until < now)) share.incoming = share.incoming.filter((x) => x.until >= now);
}
