// A fake server for photos, albums, the camera and nearby share, for trying the screens in a normal browser.
//   ?photos=0   no photos      ?share=incoming   a nearby player sends you a photo after 3 seconds
import { dispatch } from '../lib/nui.js';

const params = new URLSearchParams(location.search);
const now = () => Math.floor(Date.now() / 1000);
const MAX = 120;

function picture(w, h, hue, label) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  const sky = g.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, `hsl(${hue} 70% 62%)`);
  sky.addColorStop(0.6, `hsl(${(hue + 40) % 360} 60% 78%)`);
  sky.addColorStop(0.6, `hsl(${(hue + 120) % 360} 35% 32%)`);
  sky.addColorStop(1, `hsl(${(hue + 120) % 360} 40% 22%)`);
  g.fillStyle = sky;
  g.fillRect(0, 0, w, h);
  g.fillStyle = 'rgba(255,255,255,.9)';
  g.beginPath();
  g.arc(w * 0.72, h * 0.22, h * 0.09, 0, 7);
  g.fill();
  g.fillStyle = 'rgba(0,0,0,.45)';
  g.font = `${Math.round(h / 9)}px sans-serif`;
  g.fillText(label, w * 0.06, h * 0.9);
  return c.toDataURL('image/jpeg', 0.7);
}

const db = {
  photos: [],
  albums: [{ id: 1, name: 'Holiday', count: 0 }],
  nextPhoto: 1,
  nextAlbum: 2,
};

function addPhoto(hue, label, extra = {}) {
  const p = { id: db.nextPhoto++, kind: 'photo', hue, label, width: 640, height: 480, favourite: false, album: null, deleted: 0, source: 'camera', at: now() - (30 - db.nextPhoto) * 3600, ...extra };
  p.full = picture(640, 480, hue, label);
  p.thumb = picture(120, 90, hue, '');
  db.photos.push(p);
  return p;
}

if (params.get('photos') !== '0') {
  for (let i = 0; i < 14; i++) addPhoto((i * 47) % 360, `Photo ${i + 1}`);
  db.photos[2].favourite = true;
  db.photos[5].favourite = true;
  db.photos[3].album = 1;
  db.photos[4].album = 1;
  db.photos[9].deleted = now() - 86400;
}

const pub = (p) => ({ id: p.id, kind: p.kind, thumb: p.thumb, width: p.width, height: p.height, favourite: p.favourite, album: p.album, source: p.source, at: p.at, deleted: p.deleted });
const live = () => db.photos.filter((p) => !p.deleted);
const albums = () => db.albums.map((a) => ({ ...a, count: live().filter((p) => p.album === a.id).length }));
const stats = () => ({ photos: live().length, bytes: live().length * 38000, deleted: db.photos.filter((p) => p.deleted).length, max: MAX });

export function mediaPayload() {
  return { maxPhotos: MAX, maxWidth: 960, quality: 0.72, thumbWidth: 200, pageSize: 6, keepDeletedDays: 30, timerSeconds: [3, 10] };
}

// ---- the camera: a stand-in for the game's picture
let side = 'back';
let timerIndex = 0;
let cameraOn = false;

function count(n, then) {
  if (n <= 0) return then();
  dispatch('cameraCount', n);
  setTimeout(() => count(n - 1, then), 1000);
}

function shoot() {
  const secs = [0, 3, 10][timerIndex];
  count(secs, () => {
    dispatch('cameraCount', 0);
    dispatch('cameraHide', true);
    setTimeout(() => {
      dispatch('cameraHide', false);
      dispatch('cameraShot', picture(1280, 720, Math.floor(Math.random() * 360), side));
    }, 150);
  });
}

// ---- share
const people = [
  { id: 7, name: 'Sam', distance: 2.1 },
  { id: 9, name: 'Alex Reed', distance: 6.4 },
];
let pending = null;

if (params.get('share') === 'incoming') {
  setTimeout(() => dispatch('share', { id: 'req1', name: 'Sam', kind: 'photo', count: 1, preview: picture(120, 90, 200, ''), seconds: 60 }), 3000);
}

export async function mediaHandle(name, data) {
  switch (name) {
    case 'cameraStart':
      cameraOn = true;
      side = 'back';
      timerIndex = 0;
      return { ok: true, side, zoom: 30 };
    case 'cameraShoot':
      if (cameraOn) shoot();
      return 1;
    case 'cameraFlip':
      side = side === 'back' ? 'front' : 'back';
      return { front: side === 'front' };
    case 'cameraTimer':
      timerIndex = (timerIndex + 1) % 3;
      return { seconds: [0, 3, 10][timerIndex] };
    case 'cameraStop':
      cameraOn = false;
      return 1;

    case 'mediaUpload': {
      if (live().length >= MAX) return { ok: false, reason: 'full' };
      const p = addPhoto(Math.floor(Math.random() * 360), 'New', { full: data.data, thumb: data.thumb, at: now() });
      p.full = data.data;
      p.thumb = data.thumb;
      return { ok: true, photo: pub(p) };
    }
    case 'mediaList': {
      let rows = db.photos.filter((p) => (data.view === 'deleted' ? p.deleted : !p.deleted));
      if (data.view === 'favourites') rows = rows.filter((p) => p.favourite);
      if (data.view === 'album') rows = rows.filter((p) => p.album === data.album);
      rows = rows.sort((a, b) => b.id - a.id);
      if (data.before) rows = rows.filter((p) => p.id < data.before);
      const page = rows.slice(0, 6);
      return { ok: true, items: page.map(pub), more: rows.length > page.length };
    }
    case 'mediaGet': {
      const p = db.photos.find((x) => x.id === data.id);
      return p ? { ok: true, photo: { id: p.id, image: p.full, width: p.width, height: p.height, source: p.source, at: p.at } } : { ok: false, reason: 'not_found' };
    }
    case 'mediaStats':
      return { ok: true, stats: stats(), albums: albums() };
    case 'mediaAlbum': {
      if (data.action === 'create') {
        if (db.albums.some((a) => a.name === data.name)) return { ok: false, reason: 'duplicate' };
        const a = { id: db.nextAlbum++, name: data.name, count: 0 };
        db.albums.push(a);
        return { ok: true, album: a };
      }
      if (data.action === 'rename') {
        const a = db.albums.find((x) => x.id === data.id);
        if (a) a.name = data.name;
        return { ok: !!a };
      }
      if (data.action === 'remove') {
        db.albums = db.albums.filter((a) => a.id !== data.id);
        db.photos.forEach((p) => p.album === data.id && (p.album = null));
        return { ok: true };
      }
      return { ok: false, reason: 'invalid' };
    }
    case 'mediaEdit': {
      const ids = new Set(data.ids ?? []);
      const sel = db.photos.filter((p) => ids.has(p.id));
      if (data.action === 'favourite') sel.forEach((p) => (p.favourite = data.on === true));
      else if (data.action === 'trash') sel.forEach((p) => (p.deleted = now()));
      else if (data.action === 'restore') sel.forEach((p) => (p.deleted = 0));
      else if (data.action === 'erase') db.photos = db.photos.filter((p) => !ids.has(p.id));
      else if (data.action === 'empty') db.photos = db.photos.filter((p) => !p.deleted);
      else if (data.action === 'album') sel.forEach((p) => (p.album = data.album ?? null));
      else return { ok: false, reason: 'invalid' };
      return { ok: true, changed: sel.length };
    }

    case 'shareNearby':
      return { ok: true, people, bluetooth: params.get('bluetooth') !== '0' };
    case 'shareSend': {
      if (params.get('bluetooth') === '0') return { ok: false, reason: 'bluetooth_off' };
      pending = { id: 'out1' };
      setTimeout(() => {
        if (!pending) return;
        dispatch('shareResult', { id: 'out1', state: 'accepted', count: data.ids.length, name: 'Sam' });
        pending = null;
      }, 2500);
      return { ok: true, id: 'out1' };
    }
    case 'shareRespond':
      return { ok: true };
    case 'shareCancel':
      pending = null;
      return { ok: true };
  }
  return undefined;
}
