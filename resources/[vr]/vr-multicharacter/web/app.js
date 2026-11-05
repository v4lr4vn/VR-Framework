/* vr-multicharacter UI: character select, creation, delete and spawn choice. No libraries, no network. */
(function () {
  'use strict';

  var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vr-multicharacter';
  var DEMO = /[?&]demo\b/.test(location.search);
  var SVG = 'http://www.w3.org/2000/svg';
  var $ = function (id) { return document.getElementById(id); };
  var posted = (window.__posts = []);

  function post(name, data) {
    if (DEMO) { posted.push({ name: name, data: data || {} }); return; }
    fetch('https://' + RES + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  }

  function h(tag, attrs) {
    var e = document.createElement(tag);
    for (var k in attrs || {}) {
      var v = attrs[k];
      if (v == null || v === false) continue;
      if (k === 'class') e.className = v;
      else if (k === 'text') e.textContent = v;
      else if (k.indexOf('on') === 0) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? '' : v);
    }
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c == null || c === false) continue;
      e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    }
    return e;
  }
  function icon(name) {
    var s = document.createElementNS(SVG, 'svg');
    s.setAttribute('class', 'ic');
    var u = document.createElementNS(SVG, 'use');
    u.setAttribute('href', '#i-' + name);
    s.appendChild(u);
    return s;
  }
  function clear(e) { while (e.firstChild) e.removeChild(e.firstChild); }

  var money = new Intl.NumberFormat('en-US');
  function fmtMoney(n) { return '$' + money.format(Number(n) || 0); }
  function fmtDate(sec) {
    if (!sec) return '';
    try { return new Date(sec * 1000).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }); } catch (e) { return ''; }
  }
  function initials(first, last) {
    return ((first || '').charAt(0) + (last || '').charAt(0)).toUpperCase() || '?';
  }
  function fullName(c) {
    var ci = (c && c.charinfo) || {};
    return ((ci.firstname || '') + ' ' + (ci.lastname || '')).trim() || 'Unnamed';
  }
  function jobLabel(c) {
    var j = c && c.job;
    if (!j) return 'Unemployed';
    var g = j.grade && j.grade.name ? ' · ' + j.grade.name : '';
    return (j.label || j.name || 'Unemployed') + g;
  }

  /* ---------- state ---------- */
  var S = {
    view: 'none',
    slots: 5, chars: {}, cur: null, countries: [], customNat: false,
    limits: null, minAge: 18, canDelete: true,
    cam: 'body', gender: 0, cid: null,
    spawn: { options: [], sel: null, canChange: false },
  };
  var stage = $('stage');
  var body = document.body;
  var scale = 1;

  function fit() {
    scale = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
    stage.style.transform = 'scale(' + scale + ')';
  }
  window.addEventListener('resize', fit);
  fit();
  if (DEMO) body.classList.add('demo');

  var VIEWS = ['select', 'create', 'delete', 'spawn', 'loading'];
  function show(v, loadText) {
    S.view = v;
    body.className = (DEMO ? 'demo ' : '') + 'v-' + v;
    VIEWS.forEach(function (n) {
      var on = n === v || (v === 'delete' && n === 'select');
      var el = $('v-' + n);
      if (el.hidden === on) {
        el.hidden = !on;
        if (on) { el.classList.remove('fade'); void el.offsetWidth; el.classList.add('fade'); }
      }
    });
    if (v === 'loading') $('load-t').textContent = loadText || 'Retrieving your characters';
  }

  /* ---------- select ---------- */
  function sorted() {
    return Object.keys(S.chars).map(function (k) { return S.chars[k]; }).sort(function (a, b) { return a.cid - b.cid; });
  }
  function freeCid() {
    for (var i = 1; i <= S.slots; i++) if (!S.chars[i]) return i;
    return null;
  }
  function order() {
    var o = sorted().map(function (c) { return c.cid; });
    if (freeCid() != null) o.push('new');
    return o;
  }

  function cameraTools(root) {
    clear(root);
    function tool(label, on, fn, aria) {
      return h('button', { type: 'button', class: 'tool' + (on ? ' on' : ''), 'aria-label': aria || label, onclick: fn }, label);
    }
    var l = h('button', { type: 'button', class: 'tool', 'aria-label': 'Rotate left', onclick: function () { post('rotate', { deg: -35 }); } }, icon('left'));
    var r = h('button', { type: 'button', class: 'tool', 'aria-label': 'Rotate right', onclick: function () { post('rotate', { deg: 35 }); } }, icon('right'));
    var face = tool('Face', S.cam === 'face', function () { setCam('face'); }, 'Camera on face');
    var bodyB = tool('Body', S.cam === 'body', function () { setCam('body'); }, 'Camera on body');
    [l, face, bodyB, r].forEach(function (b) { root.appendChild(b); });
  }
  function setCam(v) {
    S.cam = v;
    post('camView', { view: v });
    cameraTools($('tools-select'));
    cameraTools($('tools-create'));
  }

  function renderSelect() {
    var chars = sorted();
    $('slotcount').textContent = chars.length + ' / ' + S.slots + ' SLOTS USED';
    var box = $('cards');
    clear(box);
    chars.forEach(function (c) {
      var ci = c.charinfo || {};
      var sub = jobLabel(c) + (c.lastPlayed ? ' · Last played ' + fmtDate(c.lastPlayed) : '');
      box.appendChild(h('button', { type: 'button', class: 'card' + (S.cur === c.cid ? ' sel' : ''), 'data-k': c.cid, onclick: function () { pick(c.cid); } },
        h('div', { class: 'avatar', text: initials(ci.firstname, ci.lastname) }),
        h('div', { class: 'who' }, h('div', { class: 'nm', text: fullName(c) }), h('div', { class: 'sub', text: sub })),
        h('div', { class: 'cid', text: String(c.citizenid || '') })));
    });
    var free = freeCid();
    if (free != null) {
      var left = S.slots - chars.length;
      box.appendChild(h('button', { type: 'button', class: 'card new' + (S.cur === 'new' ? ' sel' : ''), 'data-k': 'new', onclick: function () { pick('new'); } },
        h('div', { class: 'avatar' }, icon('plus')),
        h('div', { class: 'who' }, h('div', { class: 'nm', text: 'New character' }), h('div', { class: 'sub', text: left + (left === 1 ? ' slot free' : ' slots free') }))));
    }
    renderDetails();
    var sel = box.querySelector('.sel');
    if (sel && sel.scrollIntoView) sel.scrollIntoView({ block: 'nearest' });
  }

  function kv(label, value, cls) {
    return h('div', { class: 'kv' }, h('span', { text: label }), h('span', { class: cls || '', text: value }));
  }

  function renderDetails() {
    var d = $('details');
    clear(d);
    var c = S.cur !== 'new' ? S.chars[S.cur] : null;
    $('plate-name').textContent = c ? fullName(c) : '';
    $('plate-sub').textContent = c ? jobLabel(c).toUpperCase() : '';
    d.appendChild(h('div', { class: 'sec', text: c ? 'DETAILS' : 'NEW CHARACTER' }));
    if (c) {
      var ci = c.charinfo || {}, m = c.money || {};
      d.appendChild(h('div', { class: 'rows' },
        kv('Date of birth', ci.birthdate || '-', 'mono'),
        kv('Nationality', ci.nationality || '-'),
        kv('Phone', ci.phone || '-', 'mono'),
        kv('Job', jobLabel(c)),
        kv('Cash', fmtMoney(m.cash), 'mono ok'),
        kv('Bank', fmtMoney(m.bank), 'mono ok'),
        c.lastPlayed ? kv('Last played', fmtDate(c.lastPlayed), 'mono') : null));
      d.appendChild(h('div', { class: 'grow' }));
      d.appendChild(h('button', { type: 'button', class: 'btn primary', onclick: play }, icon('play'), 'PLAY'));
      if (S.canDelete) d.appendChild(h('button', { type: 'button', class: 'btn danger', onclick: askDelete }, icon('trash'), 'DELETE CHARACTER'));
    } else {
      d.appendChild(h('p', { class: 'empty-note', text: 'Pick a name, a face and a story. You can have ' + S.slots + ' characters and swap between them whenever you log in.' }));
      d.appendChild(h('div', { class: 'grow' }));
      d.appendChild(h('button', { type: 'button', class: 'btn primary', onclick: function () { openCreate(freeCid()); } }, icon('plus'), 'NEW CHARACTER'));
    }
  }

  function pick(key) {
    if (key === 'new') {
      S.cur = 'new';
      renderSelect();
      post('cDataPed', {});
      return;
    }
    if (S.cur === key) return;
    S.cur = key;
    renderSelect();
    post('cDataPed', { cData: S.chars[key] });
  }

  function play() {
    var c = S.chars[S.cur];
    if (!c) return;
    show('loading', 'Entering the city');
    post('selectCharacter', { cData: c });
  }

  function askDelete() {
    var c = S.chars[S.cur];
    if (!c) return;
    $('del-name').textContent = fullName(c);
    show('delete');
    $('del-no').focus();
  }
  $('del-no').addEventListener('click', function () { show('select'); });
  $('del-yes').addEventListener('click', function () {
    var c = S.chars[S.cur];
    show('loading', 'Removing character');
    if (c) post('removeCharacter', { citizenid: c.citizenid });
  });

  /* ---------- rotate by dragging the empty middle ---------- */
  function dragRotate(el) {
    var down = false, lastX = 0;
    el.addEventListener('pointerdown', function (e) { down = true; lastX = e.clientX; el.setPointerCapture(e.pointerId); });
    el.addEventListener('pointermove', function (e) {
      if (!down) return;
      var dx = (e.clientX - lastX) / scale;
      lastX = e.clientX;
      if (dx) post('rotate', { deg: dx * 0.6 });
    });
    function up(e) { down = false; try { el.releasePointerCapture(e.pointerId); } catch (x) {} }
    el.addEventListener('pointerup', up);
    el.addEventListener('pointercancel', up);
  }
  dragRotate($('drag'));
  dragRotate($('drag2'));

  /* ---------- create ---------- */
  var profRe = null;
  try {
    if (typeof profList !== 'undefined') {
      profRe = new RegExp('\\b(' + profList.map(function (w) { return String(w).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }).join('|') + ')\\b', 'i');
    }
  } catch (e) { profRe = null; }

  var nameRe = /^[A-Za-zÀ-ɏ][A-Za-zÀ-ɏ' -]*$/;

  function todayIso() {
    var d = new Date();
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
  }

  function natField() {
    var wrap = $('f-nat-wrap');
    var old = wrap.querySelector('#f-nat');
    if (old) wrap.removeChild(old);
    var el;
    if (S.customNat) {
      el = h('input', { id: 'f-nat', type: 'text', maxlength: '40' });
    } else {
      el = h('select', { id: 'f-nat' }, h('option', { value: '', text: 'Select a country' }));
      (S.countries || []).forEach(function (c) { el.appendChild(h('option', { value: c, text: c })); });
    }
    wrap.appendChild(el);
  }

  function setGender(g) {
    S.gender = g;
    Array.prototype.forEach.call($('f-gender').children, function (b) {
      b.classList.toggle('on', Number(b.getAttribute('data-g')) === g);
    });
  }

  function setHeightLabel(cm) {
    var inch = Math.round(cm / 2.54);
    $('f-height-v').textContent = Math.floor(inch / 12) + "'" + (inch % 12) + '" · ' + Math.round(cm) + ' cm';
  }

  function openCreate(cid) {
    if (cid == null) return;
    S.cid = cid;
    $('slotof').textContent = 'SLOT ' + cid + ' OF ' + S.slots;
    $('f-first').value = '';
    $('f-last').value = '';
    $('f-dob').value = '';
    $('f-dob').max = todayIso();
    $('f-age').textContent = '(' + S.minAge + '+)';
    natField();
    setGender(0);
    $('err').textContent = '';
    ['f-first', 'f-last', 'f-dob', 'f-nat'].forEach(function (id) { $(id).classList.remove('bad'); });
    var hw = $('height-wrap');
    hw.hidden = !S.limits;
    if (S.limits) {
      var r = $('f-height');
      r.min = S.limits.min; r.max = S.limits.max; r.value = S.limits.default;
      setHeightLabel(Number(r.value));
      post('previewHeight', { height: Number(r.value) });
    }
    S.cam = 'body';
    cameraTools($('tools-create'));
    cameraTools($('tools-select'));
    post('previewGender', { gender: 0 });
    post('camView', { view: 'body' });
    show('create');
    $('f-first').focus();
  }

  Array.prototype.forEach.call($('f-gender').children, function (b) {
    b.addEventListener('click', function () {
      var g = Number(b.getAttribute('data-g'));
      if (g === S.gender) return;
      setGender(g);
      post('previewGender', { gender: g });
      if (S.limits) post('previewHeight', { height: Number($('f-height').value) });
    });
  });
  $('f-height').addEventListener('input', function () {
    var v = Number(this.value);
    setHeightLabel(v);
    post('previewHeight', { height: v });
  });

  function fail(id, msg) {
    $('err').textContent = msg;
    var el = $(id);
    if (el) { el.classList.add('bad'); el.focus(); }
    return false;
  }
  function ageOf(iso) {
    var p = iso.split('-').map(Number);
    var t = new Date();
    var a = t.getFullYear() - p[0];
    if (t.getMonth() + 1 < p[1] || (t.getMonth() + 1 === p[1] && t.getDate() < p[2])) a--;
    return a;
  }

  function submit() {
    ['f-first', 'f-last', 'f-dob', 'f-nat'].forEach(function (id) { $(id).classList.remove('bad'); });
    $('err').textContent = '';
    var first = $('f-first').value.trim(), last = $('f-last').value.trim();
    var dob = $('f-dob').value, nat = $('f-nat').value.trim();

    if (!first) return fail('f-first', 'Enter a first name.');
    if (first.length < 2) return fail('f-first', 'First name must be at least 2 letters.');
    if (!nameRe.test(first)) return fail('f-first', 'Names can only use letters, spaces, apostrophes and hyphens.');
    if (!last) return fail('f-last', 'Enter a last name.');
    if (last.length < 2) return fail('f-last', 'Last name must be at least 2 letters.');
    if (!nameRe.test(last)) return fail('f-last', 'Names can only use letters, spaces, apostrophes and hyphens.');
    if (profRe && (profRe.test(first) || profRe.test(last))) return fail('f-first', 'That name is not allowed. Pick something else.');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dob)) return fail('f-dob', 'Enter your date of birth.');
    var p = dob.split('-').map(Number);
    if (p[0] < 1900 || p[0] > new Date().getFullYear() || isNaN(Date.parse(dob))) return fail('f-dob', 'That is not a valid date of birth.');
    if (ageOf(dob) < S.minAge) return fail('f-dob', 'Characters must be at least ' + S.minAge + ' years old.');
    if (!nat) return fail('f-nat', 'Choose a nationality.');
    if (profRe && profRe.test(nat)) return fail('f-nat', 'That nationality is not allowed.');

    show('loading', 'Creating your character');
    post('createNewCharacter', {
      firstname: first, lastname: last, nationality: nat, birthdate: dob,
      gender: S.gender, height: S.limits ? Number($('f-height').value) : undefined, cid: S.cid,
    });
  }
  $('b-create').addEventListener('click', submit);
  $('form').addEventListener('submit', function (e) { e.preventDefault(); submit(); });
  $('b-back').addEventListener('click', backToSelect);
  function backToSelect() {
    show('select');
    renderSelect();
    var c = S.chars[S.cur];
    post('cDataPed', c ? { cData: c } : {});
    post('camView', { view: S.cam });
  }

  /* ---------- spawn + MDT map ---------- */
  var M = { size: 1300, k: 1, tx: 0, ty: 0, cfg: { size: 8192, originX: 3753.6, originY: 5529.6, scaleX: 0.66304, scaleY: -0.656 }, anim: null, pts: {} };
  var mapEl = $('map'), wrap = $('mapwrap');
  var REGION = { l: 640, t: 150, r: 1840, b: 930 };

  function toPx(x, y) {
    var c = M.cfg;
    return { x: ((c.scaleX * x + c.originX) / c.size) * M.size, y: ((c.scaleY * y + c.originY) / c.size) * M.size };
  }
  function applyMap() {
    mapEl.style.transform = 'translate(' + M.tx + 'px,' + M.ty + 'px) scale(' + M.k + ')';
    mapEl.style.setProperty('--inv', String(1 / M.k));
    mapEl.classList.toggle('zoomed', M.k >= 1.3);
  }
  function viewTo(k, tx, ty, ms) {
    if (M.anim) cancelAnimationFrame(M.anim);
    if (!ms) { M.k = k; M.tx = tx; M.ty = ty; applyMap(); return; }
    var k0 = M.k, x0 = M.tx, y0 = M.ty, t0 = performance.now();
    (function step(now) {
      var t = Math.min(1, (now - t0) / ms), e = 1 - Math.pow(1 - t, 3);
      M.k = k0 + (k - k0) * e; M.tx = x0 + (tx - x0) * e; M.ty = y0 + (ty - y0) * e;
      applyMap();
      M.anim = t < 1 ? requestAnimationFrame(step) : null;
    })(t0);
  }
  function centerOn(px, py, k, ms) {
    var cx = (REGION.l + REGION.r) / 2, cy = (REGION.t + REGION.b) / 2;
    viewTo(k, cx - px * k, cy - py * k, ms);
  }
  function fitAll(ms) {
    var ids = Object.keys(M.pts);
    if (!ids.length) return centerOn(M.size / 2, M.size / 2, 0.8, ms);
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    ids.forEach(function (id) {
      var p = M.pts[id];
      x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y);
    });
    var w = Math.max(x1 - x0, 160), hgt = Math.max(y1 - y0, 160);
    var k = Math.min((REGION.r - REGION.l - 100) / w, (REGION.b - REGION.t - 90) / hgt);
    k = Math.max(0.5, Math.min(k, 2.4));
    centerOn((x0 + x1) / 2, (y0 + y1) / 2, k, ms);
  }
  function zoomAt(f, sx, sy) {
    var k = Math.max(0.5, Math.min(4, M.k * f));
    f = k / M.k;
    viewTo(k, sx - (sx - M.tx) * f, sy - (sy - M.ty) * f, 0);
  }
  function stagePoint(e) {
    var r = stage.getBoundingClientRect();
    return { x: (e.clientX - r.left) / scale, y: (e.clientY - r.top) / scale };
  }

  var pan = null;
  wrap.addEventListener('pointerdown', function (e) {
    if (e.target.closest && e.target.closest('.pin button')) return;
    pan = { x: e.clientX, y: e.clientY, tx: M.tx, ty: M.ty };
    if (M.anim) { cancelAnimationFrame(M.anim); M.anim = null; }
    wrap.classList.add('panning');
    wrap.setPointerCapture(e.pointerId);
  });
  wrap.addEventListener('pointermove', function (e) {
    if (!pan) return;
    M.tx = pan.tx + (e.clientX - pan.x) / scale;
    M.ty = pan.ty + (e.clientY - pan.y) / scale;
    applyMap();
  });
  function endPan(e) { pan = null; wrap.classList.remove('panning'); try { wrap.releasePointerCapture(e.pointerId); } catch (x) {} }
  wrap.addEventListener('pointerup', endPan);
  wrap.addEventListener('pointercancel', endPan);
  wrap.addEventListener('wheel', function (e) {
    e.preventDefault();
    var p = stagePoint(e);
    zoomAt(Math.pow(1.0016, -e.deltaY), p.x, p.y);
  }, { passive: false });
  $('z-in').addEventListener('click', function () { zoomAt(1.4, (REGION.l + REGION.r) / 2, (REGION.t + REGION.b) / 2); });
  $('z-out').addEventListener('click', function () { zoomAt(1 / 1.4, (REGION.l + REGION.r) / 2, (REGION.t + REGION.b) / 2); });
  $('z-fit').addEventListener('click', function () { fitAll(350); });

  var GROUP_ICON = { last: 'clock', home: 'home', work: 'work', city: 'pin' };
  var GROUP_NAME = { last: 'Continue', home: 'Home', work: 'Work', city: 'City' };

  function openSpawn(msg) {
    var opts = (msg.options || []).filter(function (o) { return o && o.id; });
    S.spawn.options = opts;
    S.spawn.canChange = !!msg.canChange;
    S.spawn.sel = null;
    if (msg.map) M.cfg = msg.map;
    var c = msg.char || {};
    $('who-n').textContent = c.name || '';
    $('who-c').textContent = c.citizenid || '';
    $('who-i').textContent = c.initials || '';
    $('h-back').hidden = !S.spawn.canChange;

    Array.prototype.slice.call(mapEl.querySelectorAll('.pin')).forEach(function (p) { p.parentNode.removeChild(p); });
    M.pts = {};
    opts.forEach(function (o) {
      if (typeof o.x !== 'number' || typeof o.y !== 'number') return;
      var p = toPx(o.x, o.y);
      M.pts[o.id] = p;
      var pin = h('div', { class: 'pin' + (p.x / M.size > 0.62 ? ' left' : ''), 'data-id': o.id, style: 'left:' + p.x + 'px;top:' + p.y + 'px' },
        h('span', { class: 'ring b' }), h('span', { class: 'ring' }),
        h('button', { type: 'button', 'aria-label': o.label, onclick: function () { choose(o.id, true); } }, h('i')),
        h('span', { class: 'lb', text: o.label }));
      mapEl.appendChild(pin);
    });

    var first = msg.selected && opts.some(function (o) { return o.id === msg.selected; }) ? msg.selected : (opts[0] && opts[0].id);
    show('spawn');
    renderSpawnList();
    fitAll(0);
    if (first) choose(first, false);
  }

  function renderSpawnList() {
    var box = $('rows');
    clear(box);
    var seen = {};
    S.spawn.options.forEach(function (o) {
      var g = o.group || 'THE CITY';
      if (!seen[g]) { seen[g] = true; box.appendChild(h('div', { class: 'grp', text: g })); }
      box.appendChild(h('button', { type: 'button', class: 'row' + (S.spawn.sel === o.id ? ' sel' : ''), 'data-id': o.id, onclick: function () { choose(o.id, true); } },
        icon(GROUP_ICON[o.kind] || 'pin'),
        h('span', { class: 't', text: o.label }),
        o.sub ? h('span', { class: 's', text: o.sub }) : null));
    });
  }

  function choose(id, focus) {
    var o = S.spawn.options.filter(function (x) { return x.id === id; })[0];
    if (!o) return;
    S.spawn.sel = id;
    Array.prototype.forEach.call($('rows').querySelectorAll('.row'), function (r) { r.classList.toggle('sel', r.getAttribute('data-id') === id); });
    Array.prototype.forEach.call(mapEl.querySelectorAll('.pin'), function (p) { p.classList.toggle('sel', p.getAttribute('data-id') === id); });
    var sel = $('rows').querySelector('.row.sel');
    if (sel && sel.scrollIntoView) sel.scrollIntoView({ block: 'nearest' });

    $('pk-t').textContent = o.label;
    $('pk-s').textContent = o.area || o.sub || '';
    var kvs = $('pk-kv');
    clear(kvs);
    kvs.appendChild(h('div', {}, h('span', { text: 'Spawn type' }), h('span', { text: GROUP_NAME[o.kind] || 'City' })));
    if (o.kind === 'last' && o.lastPlayed) kvs.appendChild(h('div', {}, h('span', { text: 'Last played' }), h('span', { class: 'mono', text: fmtDate(o.lastPlayed) })));
    if (o.inside) kvs.appendChild(h('div', {}, h('span', { text: 'Arrive' }), h('span', { text: 'Inside' })));

    var p = M.pts[id];
    if (focus && p) centerOn(p.x, p.y, Math.max(M.k, 1.5), 380);
    post('spawnPreview', { id: id });
  }

  function stepSpawn(d) {
    var ids = S.spawn.options.map(function (o) { return o.id; });
    if (!ids.length) return;
    var i = ids.indexOf(S.spawn.sel);
    choose(ids[(i + d + ids.length) % ids.length], true);
  }
  function doSpawn() {
    if (!S.spawn.sel) return;
    post('spawnConfirm', { id: S.spawn.sel });
    show('none');
  }
  $('b-spawn').addEventListener('click', doSpawn);

  /* ---------- keyboard ---------- */
  window.addEventListener('keydown', function (e) {
    var tag = (e.target && e.target.tagName) || '';
    var typing = tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA';
    var v = S.view;
    if (v === 'select') {
      var o = order(), i = o.indexOf(S.cur);
      if (e.key === 'ArrowDown' && o.length) { e.preventDefault(); pick(o[(i + 1) % o.length]); }
      else if (e.key === 'ArrowUp' && o.length) { e.preventDefault(); pick(o[(i - 1 + o.length) % o.length]); }
      else if (e.key === 'Enter') { e.preventDefault(); if (S.cur === 'new') openCreate(freeCid()); else play(); }
      else if ((e.key === 'n' || e.key === 'N') && !typing && freeCid() != null) { openCreate(freeCid()); }
    } else if (v === 'create') {
      if (e.key === 'Escape') backToSelect();
    } else if (v === 'delete') {
      if (e.key === 'Escape') show('select');
    } else if (v === 'spawn') {
      if (e.key === 'ArrowDown') { e.preventDefault(); stepSpawn(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); stepSpawn(-1); }
      else if (e.key === 'Enter') { e.preventDefault(); doSpawn(); }
      else if (e.key === 'Backspace' && S.spawn.canChange) { e.preventDefault(); post('backToSelect'); show('loading', 'Back to your characters'); }
    }
  });

  /* ---------- messages from the game ---------- */
  function onMessage(msg) {
    switch (msg.action) {
      case 'open':
        S.slots = Number(msg.slots) || 5;
        S.countries = msg.countries || [];
        S.customNat = !!msg.customNationality;
        S.limits = msg.heightLimits || null;
        S.canDelete = msg.enableDeleteButton !== false;
        S.minAge = Number(msg.minAge) || 18;
        $('tagline').textContent = msg.tagline || 'ValRavn';
        S.cam = 'body';
        cameraTools($('tools-select'));
        cameraTools($('tools-create'));
        show('loading', 'Retrieving your characters');
        post('setupCharacters');
        break;
      case 'characters':
        S.chars = {};
        (msg.characters || []).forEach(function (c) { if (c && c.cid) S.chars[c.cid] = c; });
        var list = sorted();
        if (S.cur == null || (S.cur !== 'new' && !S.chars[S.cur])) {
          if (list.length) {
            list.sort(function (a, b) { return (b.lastPlayed || 0) - (a.lastPlayed || 0); });
            S.cur = list[0].cid;
          } else {
            S.cur = 'new';
          }
        }
        show('select');
        renderSelect();
        post('removeBlur');
        post('cDataPed', S.cur !== 'new' ? { cData: S.chars[S.cur] } : {});
        break;
      case 'createFailed':
        show('create');
        $('err').textContent = msg.message || 'Could not create the character.';
        break;
      case 'spawn':
        openSpawn(msg);
        break;
      case 'close':
        S.cur = null;
        show('none');
        break;
    }
  }
  window.addEventListener('message', function (e) { if (e.data && e.data.action) onMessage(e.data); });

  /* ---------- browser preview (?demo&view=select|create|spawn) ---------- */
  window.__onMessage = onMessage;
  if (DEMO) {
    var view = (location.search.match(/view=(\w+)/) || [])[1] || 'select';
    var sample = [
      { citizenid: 'MHK31842', cid: 1, charinfo: { firstname: 'Marcus', lastname: 'Hale', birthdate: '1994-03-14', nationality: 'American', phone: '555-0142' }, money: { cash: 1250, bank: 18430 }, job: { label: 'Mechanic', grade: { name: 'Senior' } }, lastPlayed: 1793650000 },
      { citizenid: 'EVO22174', cid: 2, charinfo: { firstname: 'Elena', lastname: 'Voss', birthdate: '1991-07-02', nationality: 'British', phone: '555-0178' }, money: { cash: 300, bank: 9120 }, job: { label: 'Police Officer', grade: { name: 'Officer' } }, lastPlayed: 1793300000 },
      { citizenid: 'JRZ90512', cid: 3, charinfo: { firstname: 'Jonah', lastname: 'Reyes', birthdate: '1988-11-21', nationality: 'Mexican', phone: '555-0199' }, money: { cash: 80, bank: 52010 }, job: { label: 'Restaurant Owner' }, lastPlayed: 1792900000 },
    ];
    var countries = ['American', 'British', 'Canadian', 'Mexican'];
    onMessage({ action: 'open', slots: 5, countries: countries, heightLimits: { min: 107, max: 213, default: 175 }, minAge: 18, enableDeleteButton: true, tagline: 'The city never sleeps.' });
    onMessage({ action: 'characters', characters: sample });
    if (view === 'create') openCreate(4);
    if (view === 'delete') askDelete();
    if (view === 'spawn') {
      onMessage({ action: 'spawn', canChange: true, char: { name: 'Marcus Hale', citizenid: 'MHK31842', initials: 'MH' }, selected: 'last', options: [
        { id: 'last', kind: 'last', group: 'CONTINUE', label: 'Last location', sub: 'Vinewood · 2 Nov', area: 'Vinewood Boulevard, Los Santos', x: 300, y: 200, lastPlayed: 1793650000 },
        { id: 'house1', kind: 'home', group: 'YOURS', label: 'Home', sub: 'Eclipse Towers, Apt 4', x: -777, y: 312, inside: true },
        { id: 'job', kind: 'work', group: 'YOURS', label: 'Work', sub: 'LS Customs', x: -365, y: -130 },
        { id: 'p1', kind: 'city', group: 'THE CITY', label: 'Legion Square', x: 195, y: -934 },
        { id: 'p2', kind: 'city', group: 'THE CITY', label: 'Del Perro Pier', x: -1850, y: -1230 },
        { id: 'p3', kind: 'city', group: 'THE CITY', label: 'LS Airport', x: -1037, y: -2737 },
        { id: 'p4', kind: 'city', group: 'THE CITY', label: 'Sandy Shores', x: 1850, y: 3670 },
        { id: 'p5', kind: 'city', group: 'THE CITY', label: 'Paleto Bay', x: -150, y: 6400 },
      ] });
    }
  }
})();
