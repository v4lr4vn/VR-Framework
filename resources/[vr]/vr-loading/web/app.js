(function () {
  'use strict';
  var C = window.LOADING_CONFIG || {};
  var $ = function (id) { return document.getElementById(id); };
  var el = function (tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
  var store = {
    get: function (k) { try { return window.localStorage.getItem('vrloading:' + k); } catch (e) { return null; } },
    set: function (k, v) { try { window.localStorage.setItem('vrloading:' + k, String(v)); } catch (e) {} }
  };

  /* ------------------------------------------------------------ text */
  var S = C.server || {};
  $('markName').textContent = S.name || 'VALRAVN';
  $('markSuffix').textContent = S.suffix || '';
  $('markTag').textContent = S.tagline || '';
  if (!S.tagline) document.querySelector('#markSub i').hidden = true;
  $('welcomeWord').textContent = C.welcome || 'Welcome';
  $('subtitle').textContent = C.subtitle || '';
  document.title = (S.name || 'Loading') + ' ' + (S.suffix || '');

  var handover = window.nuiHandoverData || {};
  var playerName = typeof handover.name === 'string' ? handover.name.slice(0, 32) : '';
  $('welcomeName').textContent = playerName;       // textContent: a hostile player name can't inject markup

  (C.news || []).slice(0, 4).forEach(function (n) {
    var li = el('li');
    li.appendChild(el('time', null, n.date || ''));
    var d = el('div');
    d.appendChild(el('b', null, n.title || ''));
    if (n.text) d.appendChild(el('p', null, n.text));
    li.appendChild(d);
    $('news').appendChild(li);
  });
  if (!(C.news || []).length) $('newsPanel').hidden = true;

  function fillList(id, panel, items, render) {
    if (!items || !items.length) return;
    items.forEach(function (it) { $(id).appendChild(render(it)); });
    $(panel).hidden = false;
  }
  fillList('rules', 'rulesPanel', C.rules, function (r) { return el('li', null, r); });
  fillList('staff', 'staffPanel', C.staff, function (s) { var li = el('li'); li.appendChild(el('b', null, s.name || '')); li.appendChild(el('span', null, s.role || '')); return li; });
  fillList('links', 'linksPanel', C.links, function (l) { var li = el('li'); li.appendChild(el('span', null, l.label || '')); li.appendChild(el('b', null, l.value || '')); return li; });

  /* ------------------------------------------------------------ tips */
  (function () {
    var tips = C.tips || [];
    if (!tips.length) return;
    var i = Math.floor(Math.random() * tips.length), box = $('tip');
    function show() {
      box.textContent = '';
      box.appendChild(el('b', null, 'TIP'));
      box.appendChild(document.createTextNode(tips[i]));
      box.classList.remove('out');
    }
    show();
    if (tips.length > 1) setInterval(function () {
      box.classList.add('out');
      setTimeout(function () { i = (i + 1) % tips.length; show(); }, 460);
    }, Math.max(3, C.tipSeconds || 7) * 1000);
  })();

  /* ------------------------------------------------------------ background */
  (function () {
    // Pictures and videos behind everything. An entry is a file name ('backgrounds/a.jpg', 'backgrounds/b.webm')
    // or { video: 'backgrounds/b.webm', poster: 'backgrounds/b.jpg' }. A clip that cannot play is skipped.
    var bgs = C.backgrounds || [], BS = C.backgroundStyle || {};
    var VIDEO = /\.(mp4|m4v|webm|ogv)(\?.*)?$/i;
    var slides = [];
    bgs.forEach(function (b) {
      var src = typeof b === 'string' ? b : (b && (b.video || b.image));
      if (!src) return;
      var d = el('div'), s = { d: d, v: null, dead: false };
      if ((b && b.video) || VIDEO.test(src)) {
        var v = document.createElement('video');
        v.muted = true; v.defaultMuted = true; v.playsInline = true; v.preload = 'auto';   // the music is the sound
        v.setAttribute('muted', ''); v.setAttribute('playsinline', '');
        if (b && b.poster) v.poster = b.poster;
        v.src = src;
        d.appendChild(v); s.v = v;
      } else {
        d.style.backgroundImage = 'url("' + src + '")';
      }
      slides.push(s);
      $('slides').appendChild(d);
    });
    if (slides.length) {
      document.body.classList.add('has-slides');
      if (BS.hideCity !== false) document.body.classList.add('no-city');
      if (typeof BS.dim === 'number') document.body.style.setProperty('--dim', Math.max(0, Math.min(0.9, BS.dim)));
      var cur = -1, timer = 0;
      var alone = function () { return slides.filter(function (s) { return !s.dead; }).length < 2; };
      var skip = function (s) {     // a picture or clip that will not load or play
        s.dead = true; s.d.classList.remove('on');
        if (slides.every(function (x) { return x.dead; })) { document.body.classList.remove('has-slides', 'no-city'); return; }
        if (slides[cur] === s) next();
      };
      var next = function () {
        clearTimeout(timer);
        for (var k = 1; k <= slides.length; k++) {
          var i = (cur + k) % slides.length;
          if (!slides[i].dead) return show(i);
        }
      };
      var show = function (i) {
        clearTimeout(timer);
        var old = cur >= 0 ? slides[cur] : null;
        if (old && old !== slides[i]) {
          old.d.classList.remove('on');
          if (old.v) setTimeout(function () { try { old.v.pause(); } catch (e) {} }, 2600);   // after the fade
        }
        cur = i;
        var s = slides[i];
        s.d.classList.add('on');
        if (s.v) {
          s.v.loop = alone();
          try { s.v.currentTime = 0; } catch (e) {}
          var p = s.v.play();
          if (p && p.catch) p.catch(function () { skip(s); });
          if (!alone()) timer = setTimeout(next, Math.max(5, BS.videoMaxSeconds || 40) * 1000);
        } else if (!alone()) {
          timer = setTimeout(next, Math.max(3, BS.imageSeconds || 9) * 1000);
        }
      };
      slides.forEach(function (s) {
        if (!s.v) return;
        s.v.addEventListener('ended', function () { if (slides[cur] === s && !alone()) next(); });
        s.v.addEventListener('error', function () { skip(s); });
      });
      show(0);
    }
    // night city: drawn once with a seeded generator, then animated with CSS only
    var seed = 20261102;
    function rnd() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; }
    var W = 1920, H = 480;
    function mk() { var c = document.createElement('canvas'); c.width = W; c.height = H; return c; }
    function layer(cls, canvas) {
      var d = el('div', cls);
      var a = canvas, b = mk(); b.getContext('2d').drawImage(a, 0, 0);
      d.appendChild(a); d.appendChild(b);
      $('city').appendChild(d);
    }
    var far = mk(), near = mk(), g1 = mk(), g2 = mk(), g3 = mk();
    var fx = far.getContext('2d'), nx = near.getContext('2d');
    var groups = [g1.getContext('2d'), g2.getContext('2d'), g3.getContext('2d')];
    function skyline(ctx, base, minH, maxH, minW, maxW, fill, windows, winAlpha) {
      var x = -10;
      while (x < W + 10) {
        var w = minW + rnd() * (maxW - minW), h = minH + rnd() * (maxH - minH);
        ctx.fillStyle = fill; ctx.fillRect(x, H - h, w, h);
        if (rnd() < .35) { ctx.fillRect(x + w * .3, H - h - 14 - rnd() * 22, w * .4, 18 + rnd() * 22); }   // rooftop block
        if (rnd() < .18) { ctx.fillStyle = fill; ctx.fillRect(x + w * .5 - 1, H - h - 46 - rnd() * 30, 2, 60); } // antenna
        if (windows) {
          for (var wy = H - h + 10; wy < H - 6; wy += 11) {
            for (var wx = x + 6; wx < x + w - 8; wx += 9) {
              if (rnd() < .22) {
                var g = windows[Math.floor(rnd() * windows.length)];
                g.fillStyle = rnd() < .8 ? 'rgba(245,165,36,' + winAlpha + ')' : 'rgba(180,210,255,' + (winAlpha * .8) + ')';
                g.fillRect(wx, wy, 4, 5);
              }
            }
          }
        }
        x += w + (rnd() < .3 ? 2 + rnd() * 10 : 0);
      }
    }
    skyline(fx, H, 90, 250, 40, 90, '#101826', null);
    skyline(nx, H, 120, 380, 54, 120, '#16202F', groups, .85);
    // street glow along the bottom
    var grd = nx.createLinearGradient(0, H - 40, 0, H); grd.addColorStop(0, 'rgba(245,165,36,0)'); grd.addColorStop(1, 'rgba(245,165,36,.16)');
    nx.fillStyle = grd; nx.fillRect(0, H - 40, W, 40);
    layer('layer far', far);
    layer('layer near', near);
    [g1, g2, g3].forEach(function (cv, i) {
      var d = el('div', 'glow' + (i === 1 ? ' b' : i === 2 ? ' c' : ''));
      var b = mk(); b.getContext('2d').drawImage(cv, 0, 0);
      d.appendChild(cv); d.appendChild(b); $('city').appendChild(d);
    });
  })();

  /* ------------------------------------------------------------ progress */
  var P = { target: 0, shown: 0, stage: 'Connecting', rounds: 0, dataCount: 0, dataSeen: 0, mapFrac: 0, mapSeen: false, done: false };
  var STAGES = {
    boot: 'Starting up', data: 'Reading game data', before: 'Preparing the world',
    map: 'Loading the map', after: 'Setting things up', session: 'Joining the city'
  };
  function bump(pct, label) {
    if (label) P.stage = label;
    if (pct > P.target) P.target = Math.min(pct, 99);
  }
  var handlers = {
    startInitFunctionOrder: function (d) {
      P.rounds++; P.initCount = d.count || 1; P.initIdx = 0;
      bump({ 1: 1, 2: 9, 3: 78, 4: 91 }[P.rounds] || 91, { 1: STAGES.boot, 2: STAGES.before, 3: STAGES.after, 4: STAGES.session }[P.rounds] || STAGES.session);
    },
    initFunctionInvoking: function (d) {
      var r = Math.min(P.rounds || 1, 4), span = { 1: [1, 8], 2: [9, 20], 3: [78, 91], 4: [91, 98] }[r];
      var f = Math.min(1, (d.idx || 0) / Math.max(1, P.initCount || 1));
      bump(span[0] + f * (span[1] - span[0]));
    },
    startDataFileEntries: function (d) { P.dataCount = d.count || 0; P.dataSeen = 0; bump(10, STAGES.data); },
    onDataFileEntry: function () {
      P.dataSeen++;
      if (P.dataCount) bump(20 + (P.dataSeen / P.dataCount) * 10, STAGES.data);
    },
    performMapLoadFunction: function () { P.mapSeen = true; bump(Math.max(P.target, 32), STAGES.map); },
    loadProgress: function (d) {
      var f = Math.max(0, Math.min(1, +d.loadFraction || 0));
      P.mapSeen = true; bump(32 + f * 46, STAGES.map);
    }
  };
  window.addEventListener('message', function (e) {
    var d = e.data; if (!d || typeof d !== 'object') return;
    var h = handlers[d.eventName]; if (h) { try { h(d); } catch (err) {} }
  });

  var t0 = Date.now(), fill = $('fill'), pctEl = $('pct'), stageEl = $('stageLabel'), clock = $('clock');
  function frame() {
    var now = Date.now();
    // creep a little between real events so the bar never looks frozen, but never to the end
    var ceiling = Math.min(98, P.target + 3.5);
    if (P.shown >= P.target - .05 && P.shown < ceiling) P.shown += .012;
    else if (P.shown < P.target) P.shown += Math.max(.05, (P.target - P.shown) * .07);
    var v = Math.min(99, P.shown);
    fill.style.width = v.toFixed(2) + '%';
    pctEl.textContent = Math.floor(v) + '%';
    stageEl.textContent = P.stage;
    var s = Math.floor((now - t0) / 1000);
    clock.textContent = ('0' + Math.floor(s / 60)).slice(-2) + ':' + ('0' + (s % 60)).slice(-2);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  /* ------------------------------------------------------------ music */
  (function () {
    var M = C.music || {}, tracks = (M.tracks || []);
    if (!M.enabled || !tracks.length) return;
    var audio = $('audio'), idx = Math.floor(Math.random() * tracks.length), vol = $('volume');
    var v = parseFloat(store.get('volume')); if (isNaN(v)) v = M.volume != null ? M.volume : .2;
    v = Math.max(0, Math.min(1, v));
    var wasPaused = store.get('paused') === '1';
    $('player').hidden = false;
    $('credit').textContent = M.credit || ''; if (!M.credit) $('credit').hidden = true;
    audio.volume = v; vol.value = Math.round(v * 100);
    function setPaused(p) { document.body.classList.toggle('paused', p); store.set('paused', p ? 1 : 0); }
    function load(i, autoplay) {
      idx = (i + tracks.length) % tracks.length;
      var t = tracks[idx];
      audio.src = t.file;
      $('npTitle').textContent = t.title || '';
      $('npArtist').textContent = t.artist || '';
      if (autoplay) { var p = audio.play(); if (p && p.catch) p.catch(function () { setPaused(true); }); setPaused(false); }
    }
    function toggle() {
      if (audio.paused) { var p = audio.play(); if (p && p.catch) p.catch(function () {}); setPaused(false); }
      else { audio.pause(); setPaused(true); }
    }
    function setVol(x) {
      x = Math.max(0, Math.min(1, x)); audio.volume = x; vol.value = Math.round(x * 100); store.set('volume', x);
    }
    audio.addEventListener('ended', function () { load(idx + 1, true); });
    var fails = 0;
    audio.addEventListener('playing', function () { fails = 0; });
    audio.addEventListener('error', function () { fails++; if (fails < tracks.length) load(idx + 1, true); else setPaused(true); });
    load(idx, !wasPaused); if (wasPaused) setPaused(true);
    $('play').addEventListener('click', toggle);
    $('next').addEventListener('click', function () { load(idx + 1, true); });
    $('prev').addEventListener('click', function () { load(idx - 1, true); });
    vol.addEventListener('input', function () { setVol(vol.value / 100); });
    window.addEventListener('keydown', function (e) {
      var k = e.key;
      if (k === ' ') { e.preventDefault(); toggle(); }
      else if (k === 'ArrowRight') load(idx + 1, true);
      else if (k === 'ArrowLeft') load(idx - 1, true);
      else if (k === 'ArrowUp') { e.preventDefault(); setVol(audio.volume + .05); }
      else if (k === 'ArrowDown') { e.preventDefault(); setVol(audio.volume - .05); }
    });
  })();

  /* ------------------------------------------------------------ preview in a browser */
  // Open web/index.html?demo to watch a pretend load. Inside the game this never runs.
  if (/[?&]demo\b/.test(window.location.search)) {
    var send = function (o, ms) { setTimeout(function () { window.dispatchEvent(new MessageEvent('message', { data: o })); }, ms); };
    var ms = 300;
    [1, 2].forEach(function (r) { send({ eventName: 'startInitFunctionOrder', type: r, count: 12 }, ms); for (var i = 1; i <= 12; i++) send({ eventName: 'initFunctionInvoking', idx: i }, ms += 180); });
    send({ eventName: 'startDataFileEntries', count: 40 }, ms += 200);
    for (var d = 1; d <= 40; d++) send({ eventName: 'onDataFileEntry' }, ms += 60);
    send({ eventName: 'performMapLoadFunction', idx: 1 }, ms += 200);
    for (var m = 0; m <= 20; m++) send({ eventName: 'loadProgress', loadFraction: m / 20 }, ms += 320);
    [3, 4].forEach(function (r) { send({ eventName: 'startInitFunctionOrder', type: r, count: 10 }, ms += 200); for (var i = 1; i <= 10; i++) send({ eventName: 'initFunctionInvoking', idx: i }, ms += 220); });
    if (!playerName) $('welcomeName').textContent = 'Preview';
  }
})();
