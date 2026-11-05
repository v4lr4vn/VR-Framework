import { fail } from '../index.js';
import { push } from '../state.js';
import { warrants, bolos, person, vehicles, me, matches, now } from './records_data.js';

const HISTORY = ['served', 'denied', 'revoked', 'expired'];
const params = new URLSearchParams(window.location.search);

function shape(w) {
  const status = w.status === 'active' && w.expires_at <= now() ? 'expired' : w.status;
  return { ...w, status, charges: w.charges.map((c) => ({ ...c })) };
}

function decide(s) {
  if (s.dept === 'doj') return { canDecide: true, fallback: false };
  if (s.dept === 'police' && s.boss && params.get('fallback') === '1') return { canDecide: true, fallback: true };
  return { canDecide: false, fallback: false };
}

function changed(w, action) {
  push('warrants:changed', { id: w.id, cid: w.cid, status: w.status, action });
}

export default function (reg, regCallback, s) {
  reg('warrants.list', (d) => {
    if (s.dept === 'ems') return fail('not_allowed');
    const status = d.status || 'all';
    let list = warrants.map(shape);
    if (status === 'pending' || status === 'active') list = list.filter((w) => w.status === status);
    else if (status === 'history') list = list.filter((w) => HISTORY.includes(w.status));
    if (d.q) list = list.filter((w) => matches(w.name, d.q) || matches(w.reason, d.q) || w.cid === String(d.q).toUpperCase());
    list.sort((a, b) => (status === 'active' ? a.expires_at - b.expires_at : b.id - a.id));
    const all = warrants.map(shape);
    return {
      items: list,
      more: false,
      page: 1,
      counts: { pending: all.filter((w) => w.status === 'pending').length, active: all.filter((w) => w.status === 'active').length },
      days: 7,
      ...decide(s),
    };
  });
  reg('warrants.get', (d) => {
    const w = warrants.find((x) => x.id === Number(d.id));
    return w ? shape(w) : fail('not_found');
  });
  reg('warrants.create', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const p = person(d.cid);
    if (!p) return fail('not_found');
    if (String(d.reason || '').trim().length < 3) return fail('bad_request');
    const m = me(s.dept);
    const w = {
      id: Math.max(...warrants.map((x) => x.id)) + 1, cid: p.cid, name: p.name, reason: String(d.reason).trim(),
      charges: (d.charges || []).map((c) => ({ title: c.title, count: c.count || 1 })), report_id: d.reportId || null, status: 'pending',
      created_by_cid: m.cid, created_by_name: m.name, created_at: now(),
    };
    warrants.unshift(w);
    changed(w, 'created');
    return shape(w);
  });
  reg('warrants.decide', (d) => {
    if (!decide(s).canDecide) return fail('not_allowed');
    const w = warrants.find((x) => x.id === Number(d.id));
    if (!w) return fail('not_found');
    if (w.status !== 'pending') return fail('not_pending');
    if (!d.approve && !String(d.note || '').trim()) return fail('note_required');
    const m = me(s.dept);
    Object.assign(w, { status: d.approve ? 'active' : 'denied', approved_by_cid: m.cid, approved_by_name: m.name, decision_note: d.note || null, decided_at: now() });
    if (d.approve) w.expires_at = now() + 7 * 86400;
    changed(w, d.approve ? 'approved' : 'denied');
    return shape(w);
  });
  reg('warrants.serve', (d) => {
    if (s.dept !== 'police') return fail('not_allowed');
    const w = warrants.find((x) => x.id === Number(d.id));
    if (!w) return fail('not_found');
    if (shape(w).status !== 'active') return fail('not_active');
    Object.assign(w, { status: 'served', served_at: now(), closed_by_name: me(s.dept).name });
    changed(w, 'served');
    return shape(w);
  });
  reg('warrants.revoke', (d) => {
    const w = warrants.find((x) => x.id === Number(d.id));
    if (!w) return fail('not_found');
    const st = shape(w).status;
    if (st !== 'pending' && st !== 'active') return fail('not_active');
    Object.assign(w, { status: 'revoked', closed_by_name: me(s.dept).name, decision_note: d.note || w.decision_note, decided_at: w.decided_at || now() });
    changed(w, 'revoked');
    return shape(w);
  });
  reg('bolos.list', (d) => {
    if (s.dept === 'ems') return fail('not_allowed');
    const status = d.status || 'active';
    const items = bolos.filter((b) => b.status === status).sort((a, b) => (status === 'closed' ? (b.closed_at || 0) - (a.closed_at || 0) : b.id - a.id));
    return { items, more: false, page: 1 };
  });
  reg('bolos.create', (d) => {
    if (s.dept !== 'police' || !s.boss) return fail('not_allowed');
    if (!['person', 'vehicle', 'other'].includes(d.kind) || String(d.title || '').trim().length < 3) return fail('bad_request');
    const p = d.kind === 'person' && d.cid ? person(d.cid) : null;
    const plate = d.kind === 'vehicle' && d.plate ? String(d.plate).trim().toUpperCase() : null;
    const v = plate ? vehicles.find((x) => x.plate === plate) : null;
    const b = {
      id: Math.max(...bolos.map((x) => x.id)) + 1, kind: d.kind, title: String(d.title).trim(), details: d.details || null,
      subject: d.subject || p?.name || (plate ? (v?.label ? `${v.label} ${plate}` : plate) : null), plate, cid: p?.cid || null,
      status: 'active', created_by_name: me(s.dept).name, created_at: now(),
    };
    bolos.unshift(b);
    push('bolos:changed', { id: b.id, status: b.status, action: 'created' });
    return b;
  });
  reg('bolos.close', (d) => {
    if (s.dept !== 'police' || !s.boss) return fail('not_allowed');
    const b = bolos.find((x) => x.id === Number(d.id));
    if (!b) return fail('not_found');
    if (b.status !== 'active') return fail('not_active');
    Object.assign(b, { status: 'closed', closed_at: now(), closed_by_name: me(s.dept).name });
    push('bolos:changed', { id: b.id, status: b.status, action: 'closed' });
    return b;
  });
}
