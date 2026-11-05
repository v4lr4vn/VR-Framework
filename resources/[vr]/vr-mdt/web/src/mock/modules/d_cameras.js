import { fail } from '../index.js';
import { push } from '../state.js';

const now = () => Math.floor(Date.now() / 1000);
const limits = { yaw: 60, pitch: 30, fovMin: 15, fovMax: 90, pitchMin: -70, pitchMax: 25 };

let nextId = 13;
const cameras = [
  { id: 1, label: 'Legion Square north-east', location: 'Downtown', x: 228.4, y: -889.6, z: 36.2, heading: 145, pitch: -18, fov: 62 },
  { id: 2, label: 'Fleeca Legion Square entrance', location: 'Downtown', x: 161.2, y: -1050.8, z: 33.9, heading: 45, pitch: -16, fov: 55 },
  { id: 3, label: 'Mission Row PD front steps', location: 'Downtown', x: 409.5, y: -990.4, z: 35.1, heading: 290, pitch: -14, fov: 60 },
  { id: 4, label: 'Pillbox Hill Medical entrance', location: 'Downtown', x: 281.6, y: -571.3, z: 48, heading: 227, pitch: -20, fov: 58 },
  { id: 5, label: 'Vinewood Blvd walk of fame', location: 'Vinewood', x: 330.2, y: 175.4, z: 109.3, heading: 90, pitch: -12, fov: 65 },
  { id: 6, label: 'Pacific Standard Bank front', location: 'Vinewood', x: 239.8, y: 203.7, z: 111, heading: 30, pitch: -15, fov: 60 },
  { id: 7, label: 'Vespucci Beach boardwalk', location: 'Vespucci & Del Perro', x: -1195, y: -1490, z: 8.6, heading: 153, pitch: -12, fov: 65 },
  { id: 8, label: 'Del Perro Pier entrance', location: 'Vespucci & Del Perro', x: -1630, y: -1005, z: 18, heading: 158, pitch: -10, fov: 62 },
  { id: 9, label: 'LSIA departures', location: 'LSIA', x: -1050, y: -2715, z: 25, heading: 210, pitch: -15, fov: 60 },
  { id: 10, label: 'Grove Street cul-de-sac', location: 'South Los Santos', x: 85, y: -1905, z: 26, heading: 197, pitch: -18, fov: 62 },
  { id: 11, label: 'Sandy Shores sheriff office', location: 'Blaine County', x: 1866, y: 3672, z: 39, heading: 43, pitch: -16, fov: 60 },
  { id: 12, label: 'Paleto Bay main street', location: 'Blaine County', x: -150, y: 6300, z: 37, heading: 135, pitch: -12, fov: 65 },
].map((c) => ({ ...c, createdAt: now() - 40 * 86400 }));

const officers = [
  { cid: 'COP2', name: 'Marco Ortega', callsign: '1-LINCOLN-4', gradeName: 'Sergeant', status: 'enroute', callId: 1042 },
  { cid: 'COP3', name: 'Dee Walsh', callsign: '2-DAVID-7', gradeName: 'Officer', status: 'available' },
  { cid: 'COP4', name: 'Ivan Kerr', callsign: '1-KING-2', gradeName: 'Officer', status: 'onscene', callId: 1040 },
  { cid: 'COP5', name: 'Sara Lind', callsign: '3-MARY-1', gradeName: 'Recruit', status: 'available' },
  { cid: 'COP6', name: 'Gabe Holt', callsign: '2-EDWARD-3', gradeName: 'Corporal', status: 'busy' },
];

let viewing = null;

function stopViewing() {
  if (!viewing) return;
  viewing = null;
  window.postMessage({ type: 'camera', show: false }, '*');
  window.postMessage({ type: 'show' }, '*');
}

function showCamera(id, list) {
  const c = cameras.find((x) => x.id === id);
  if (!c) return;
  const ids = list?.length ? list : cameras.map((x) => x.id);
  viewing = { mode: 'cctv', id, list: ids };
  window.postMessage({ type: 'camera', show: true, mode: 'cctv', id: c.id, label: c.label, location: c.location, index: ids.indexOf(id) + 1, count: ids.length, zoom: Math.round((90 / c.fov) * 10) / 10 }, '*');
}

window.addEventListener('keydown', (e) => {
  if (!viewing) return;
  if (e.key === 'Backspace' || e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    stopViewing();
  } else if (viewing.mode === 'cctv' && (e.key === 'a' || e.key === 'd')) {
    const i = viewing.list.indexOf(viewing.id);
    const next = viewing.list[(i + (e.key === 'd' ? 1 : -1) + viewing.list.length) % viewing.list.length];
    showCamera(next, viewing.list);
  }
}, true);

export default function (reg, regCallback, s) {
  reg('cameras.list', () => (s.dept === 'police' ? { cameras, canManage: s.boss, limits } : fail('not_allowed')));
  reg('cameras.view', (d) => {
    const c = cameras.find((x) => x.id === Number(d.id));
    return c ? { ...c, limits } : fail('not_found');
  });
  reg('cameras.add', (d) => {
    if (!s.boss) return fail('not_allowed');
    const label = String(d.label || '').trim();
    const location = String(d.location || '').trim();
    if (label.length < 2 || location.length < 2) return fail('bad_request');
    const pitch = d.pitch == null ? -15 : Number(d.pitch);
    const fov = d.fov == null ? 60 : Number(d.fov);
    if (!(pitch >= limits.pitchMin && pitch <= limits.pitchMax) || !(fov >= limits.fovMin && fov <= limits.fovMax)) return fail('bad_request');
    nextId += 1;
    const c = { id: nextId, label, location, x: 412.33, y: -978.12, z: 31.4, heading: 87.5, pitch, fov, createdBy: 'COP1', createdAt: now() };
    cameras.push(c);
    push('cameras:changed', { id: c.id });
    return c;
  });
  reg('cameras.remove', (d) => {
    if (!s.boss) return fail('not_allowed');
    const i = cameras.findIndex((c) => c.id === Number(d.id));
    if (i < 0) return fail('not_found');
    cameras.splice(i, 1);
    push('cameras:changed', { id: Number(d.id), removed: true });
    return { id: Number(d.id) };
  });
  reg('bodycams.list', () => (s.dept === 'police' ? officers : fail('not_allowed')));
  reg('bodycams.start', (d) => {
    const o = officers.find((x) => x.cid === d.cid);
    if (!o) return fail('unit_unavailable');
    return { cid: o.cid, name: o.name, callsign: o.callsign, serverId: 12, coords: { x: 150, y: -1000, z: 29 }, heading: 90, refresh: 1000 };
  });
  reg('bodycams.pos', () => ({ coords: { x: 150, y: -1000, z: 29 }, heading: 90, serverId: 12 }));
  reg('bodycams.stop', () => true);

  regCallback('viewCamera', (d) => {
    const c = cameras.find((x) => x.id === Number(d.id));
    if (!c) return { ok: false, error: 'not_found' };
    if (viewing) return { ok: false, error: 'busy' };
    window.postMessage({ type: 'hide' }, '*');
    showCamera(c.id, d.list);
    return { ok: true };
  });
  regCallback('viewBodycam', (d) => {
    const o = officers.find((x) => x.cid === d.cid);
    if (!o) return { ok: false, error: 'unit_unavailable' };
    if (viewing) return { ok: false, error: 'busy' };
    viewing = { mode: 'bodycam', cid: o.cid };
    window.postMessage({ type: 'hide' }, '*');
    window.postMessage({ type: 'camera', show: true, mode: 'bodycam', id: o.cid, label: o.callsign, location: o.name, live: true }, '*');
    return { ok: true };
  });
}
