(function () {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vr-djbooth';
    const $ = (id) => document.getElementById(id);

    const ICONS = {
        speaker: '<svg viewBox="0 0 24 24"><rect x="5" y="2" width="14" height="20" rx="2"/><circle cx="12" cy="14" r="4"/><circle cx="12" cy="6.5" r="1"/></svg>',
        radio: '<svg viewBox="0 0 24 24"><rect x="2" y="8" width="20" height="13" rx="2"/><path d="M6 8l12-5"/><circle cx="8" cy="14.5" r="2.5"/><path d="M14 13h4M14 16h4"/></svg>',
        car: '<svg viewBox="0 0 24 24"><path d="M5 17h14M5 17a2 2 0 1 1-4 0v-4l2-5a2 2 0 0 1 2-1.4h14A2 2 0 0 1 21 8l2 5v4a2 2 0 1 1-4 0"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>',
        close: '<svg viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg>',
        edit: '<svg viewBox="0 0 24 24"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>',
        play: '<svg viewBox="0 0 24 24"><path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5Z"/></svg>',
        pause: '<svg viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16" rx="1.2"/><rect x="14" y="4" width="4" height="16" rx="1.2"/></svg>',
        stop: '<svg viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>',
        skip: '<svg viewBox="0 0 24 24"><path d="M5 4l10 8-10 8V4Z"/><path d="M19 5v14"/></svg>',
        loop: '<svg viewBox="0 0 24 24"><path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/></svg>',
        shuffle: '<svg viewBox="0 0 24 24"><path d="M16 3h5v5"/><path d="M4 20 21 3"/><path d="M21 16v5h-5"/><path d="m15 15 6 6"/><path d="M4 4l5 5"/></svg>',
        plus: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
        trash: '<svg viewBox="0 0 24 24"><path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/></svg>',
        up: '<svg viewBox="0 0 24 24"><path d="m18 15-6-6-6 6"/></svg>',
        down: '<svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg>',
        playSmall: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7Z"/></svg>',
        volume: '<svg viewBox="0 0 24 24"><path d="M11 5 6 9H2v6h4l5 4V5Z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M19 5a10 10 0 0 1 0 14"/></svg>',
        mute: '<svg viewBox="0 0 24 24"><path d="M11 5 6 9H2v6h4l5 4V5Z"/><path d="m22 9-6 6M16 9l6 6"/></svg>',
        music: '<svg viewBox="0 0 24 24"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>',
        youtube: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="4"/><path d="m10 9 5 3-5 3Z"/></svg>',
        range: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="2"/><path d="M16.2 7.8a6 6 0 0 1 0 8.4M7.8 16.2a6 6 0 0 1 0-8.4"/><path d="M19.1 4.9a10 10 0 0 1 0 14.2M4.9 19.1a10 10 0 0 1 0-14.2"/></svg>',
        warning: '<svg viewBox="0 0 24 24"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/></svg>',
        link: '<svg viewBox="0 0 24 24"><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/></svg>',
    };

    let data = null;
    let receivedAt = 0;
    let tab = 'queue';
    let volumeDragging = false;
    let rangeDragging = false;
    let pendingConfirm = null;
    let distances = {};

    function post(name, body) {
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function act(action, payload) {
        return post('action', { action, data: payload || {} }).then((r) => {
            if (!r || !r.ok) toast('error', (r && r.error) || "That didn't work.");
            return r || {};
        });
    }

    function icon(el, name) { el.innerHTML = ICONS[name] || ''; }

    function fmt(sec) {
        sec = Math.max(0, Math.floor(Number(sec) || 0));
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
        return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
    }

    function hostOf(url) {
        try { return new URL(url).hostname.replace(/^www\./, ''); } catch (e) { return ''; }
    }

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }

    function iconButton(name, title, onClick, extra) {
        const b = el('button', 'icon-btn' + (extra ? ' ' + extra : ''));
        b.title = title;
        icon(b, name);
        b.addEventListener('click', (e) => { e.stopPropagation(); onClick(); });
        return b;
    }

    function toast(kind, text) {
        const t = el('div', 'toast' + (kind === 'success' ? ' success' : ''), text);
        $('toasts').appendChild(t);
        setTimeout(() => { t.classList.add('leave'); setTimeout(() => t.remove(), 220); }, 3200);
        while ($('toasts').children.length > 3) $('toasts').firstChild.remove();
    }

    function renderHead() {
        icon($('headIcon'), data.kind === 'vehicle' ? 'car' : data.kind === 'boombox' ? 'radio' : 'speaker');
        $('sysName').textContent = data.name || 'Sound system';
        $('renameBtn').hidden = !data.canRename || !$('nameInput').hidden;
        let sub;
        if (data.kind === 'speakers') {
            const n = (data.speakers || []).length;
            sub = `${data.place || ''} · ${n} speaker${n === 1 ? '' : 's'}`;
        } else if (data.kind === 'boombox') {
            sub = 'Boombox';
        } else {
            sub = 'Car sound system';
        }
        $('sysSub').textContent = sub;
    }

    function renderNow() {
        const now = data.now;
        const panel = $('panel');
        panel.classList.toggle('playing', !!now && !now.paused);
        const title = $('nowTitle'), meta = $('nowMeta');
        meta.textContent = '';
        if (!now) {
            title.textContent = 'Nothing playing';
            title.classList.add('idle');
            meta.textContent = (data.queue || []).length ? 'Press play to start the queue' : 'Add a song to get started';
        } else {
            title.textContent = now.title || 'Loading…';
            title.classList.remove('idle');
            if (now.duration === -1) meta.appendChild(el('span', 'badge', 'LIVE'));
            const source = now.kind === 'youtube' ? 'YouTube' : hostOf(now.url) || 'Audio link';
            meta.appendChild(document.createTextNode(now.paused ? `Paused · ${source}` : source));
        }
        icon($('playBtn'), now && !now.paused ? 'pause' : 'play');
        $('playBtn').title = now && !now.paused ? 'Pause' : 'Play';

        const loop = $('loopBtn');
        icon(loop, 'loop');
        loop.classList.toggle('on', data.loop !== 'off');
        if (data.loop === 'one') loop.appendChild(el('span', 'mini', '1'));
        loop.title = data.loop === 'off' ? 'Repeat: off' : data.loop === 'all' ? 'Repeat: queue' : 'Repeat: this song';
        $('shuffleBtn').classList.toggle('on', !!data.shuffle);
        $('shuffleBtn').title = data.shuffle ? 'Shuffle: on' : 'Shuffle: off';

        if (!volumeDragging) setVolumeUi(Math.round((Number(data.volume) || 0) * 100));
        const r = $('range');
        r.min = data.rangeMin || 5;
        r.max = data.rangeMax || 100;
        r.step = data.rangeStep || 5;
        if (!rangeDragging) setRangeUi(Math.round(Number(data.radius) || 0));
        $('rangeReset').hidden = data.range === undefined || data.range === null;
        updateProgress();
    }

    function setVolumeUi(v) {
        $('volume').value = v;
        $('volume').style.setProperty('--fill', `${v}%`);
        $('volValue').textContent = `${v}%`;
        icon($('volIcon'), v === 0 ? 'mute' : 'volume');
    }

    function setRangeUi(v) {
        const r = $('range');
        const min = Number(r.min) || 5, max = Number(r.max) || 100;
        r.value = v;
        r.style.setProperty('--fill', `${Math.max(0, Math.min(100, ((v - min) / (max - min)) * 100))}%`);
        $('rangeValue').textContent = `${v} m`;
    }

    function progressInfo() {
        const now = data && data.now;
        if (!now) return { cur: 0, dur: 0, live: false };
        const live = now.duration === -1;
        const real = window.DJAudio ? window.DJAudio.position(data.id) : null;
        let cur = Number(now.elapsed) || 0;
        if (!now.paused) cur += (performance.now() - receivedAt) / 1000;
        if (real && real.mode !== 'volume' && Math.abs(real.time - cur) < 4) cur = real.time;
        let dur = now.duration > 0 ? now.duration : (real && real.duration) || 0;
        return { cur, dur, live };
    }

    function updateProgress() {
        if (!data) return;
        const { cur, dur, live } = progressInfo();
        const p = $('progress');
        p.classList.toggle('locked', !dur || live);
        $('progressFill').style.width = dur > 0 ? `${Math.min(100, (cur / dur) * 100)}%` : (live ? '100%' : '0%');
        $('timeCur').textContent = data.now ? fmt(cur) : '0:00';
        $('timeDur').textContent = live ? 'Live' : dur > 0 ? fmt(dur) : (data.now ? '–:––' : '0:00');
    }

    function renderQueue() {
        const list = $('queue');
        list.textContent = '';
        const queue = data.queue || [];
        $('queueCount').textContent = queue.length ? String(queue.length) : '';
        $('queueEmpty').hidden = queue.length > 0;
        $('queueFoot').hidden = queue.length === 0;
        queue.forEach((t, i) => {
            const row = el('li', 'row');
            row.appendChild(el('span', 'idx', String(i + 1)));
            const ico = el('span', 'ico');
            icon(ico, t.kind === 'youtube' ? 'youtube' : 'music');
            row.appendChild(ico);
            const txt = el('div', 'txt');
            txt.appendChild(el('div', 't1', t.title || hostOf(t.url)));
            const bits = [];
            if (t.duration > 0) bits.push(fmt(t.duration));
            else if (t.duration === -1) bits.push('Live');
            if (t.by) bits.push(`added by ${t.by}`);
            txt.appendChild(el('div', 't2', bits.join(' · ') || hostOf(t.url)));
            row.appendChild(txt);
            const acts = el('div', 'acts');
            acts.appendChild(iconButton('playSmall', 'Play now', () => act('playNow', { trackId: t.id })));
            if (i > 0) acts.appendChild(iconButton('up', 'Move up', () => act('move', { trackId: t.id, dir: -1 })));
            if (i < queue.length - 1) acts.appendChild(iconButton('down', 'Move down', () => act('move', { trackId: t.id, dir: 1 })));
            acts.appendChild(iconButton('trash', 'Remove', () => act('remove', { trackId: t.id }), 'danger'));
            row.appendChild(acts);
            row.addEventListener('dblclick', () => act('playNow', { trackId: t.id }));
            list.appendChild(row);
        });
    }

    function speakerRow(s, button) {
        const row = el('li', 'row');
        const ico = el('span', 'ico');
        icon(ico, 'speaker');
        row.appendChild(ico);
        const txt = el('div', 'txt');
        txt.appendChild(el('div', 't1', s.label));
        const d = distances[s.id];
        txt.appendChild(el('div', 't2', d !== undefined && d >= 0 ? `${d} m away` : ' '));
        row.appendChild(txt);
        if (button) {
            const acts = el('div', 'acts always');
            acts.appendChild(button);
            row.appendChild(acts);
        }
        return row;
    }

    function pill(text, cls, onClick) {
        const b = el('button', 'pill-btn' + (cls ? ' ' + cls : ''), text);
        b.addEventListener('click', (e) => { e.stopPropagation(); onClick(); });
        return b;
    }

    function renderSpeakers() {
        const isGroup = data.kind === 'speakers';
        $('tabs').hidden = !isGroup;
        if (!isGroup && tab === 'speakers') setTab('queue');
        if (!isGroup) return;
        const speakers = data.speakers || [];
        $('speakerCount').textContent = String(speakers.length);
        const list = $('speakers');
        list.textContent = '';
        speakers.forEach((s) => {
            list.appendChild(speakerRow(s, speakers.length > 1 ? pill('Unlink', 'ghost', () => act('unlink', { speakerId: s.id })) : null));
        });
        const near = $('nearby');
        near.textContent = '';
        (data.nearby || []).forEach((s) => near.appendChild(speakerRow(s, pill('Link', '', () => act('link', { speakerId: s.id })))));
        $('nearbyEmpty').hidden = (data.nearby || []).length > 0;
        $('linkHint').textContent = `within ${Math.round(Number(data.linkRange) || 20)} m`;
    }

    function render() {
        if (!data) return;
        renderHead();
        renderNow();
        renderQueue();
        renderSpeakers();
        $('vehicleFoot').hidden = !data.canUninstall;
        $('addBtn').disabled = (data.queue || []).length >= (data.maxQueue || 50);
    }

    function setTab(name) {
        tab = name;
        document.querySelectorAll('.tab-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
        $('tab-queue').hidden = name !== 'queue';
        $('tab-speakers').hidden = name !== 'speakers';
        if (name === 'speakers') refreshDistances();
    }

    function refreshDistances() {
        if (!data || data.kind !== 'speakers') return;
        const all = (data.speakers || []).concat(data.nearby || []);
        if (!all.length) return;
        post('distances', { points: all.map((s) => ({ x: s.x, y: s.y, z: s.z })) }).then((r) => {
            const list = (r && r.list) || [];
            all.forEach((s, i) => { distances[s.id] = list[i]; });
            if (tab === 'speakers') renderSpeakers();
        });
    }

    function open(payload, first) {
        const changedSystem = !data || data.id !== payload.id;
        data = payload;
        receivedAt = performance.now();
        if (changedSystem) {
            distances = {};
            $('toasts').textContent = '';
            cancelRename();
            setTab('queue');
            $('addUrl').value = '';
        }
        $('panel').hidden = false;
        render();
        if (first) setTimeout(() => $('addUrl').focus(), 50);
    }

    function close(notify) {
        if (!data && $('panel').hidden) return;
        data = null;
        $('panel').hidden = true;
        $('toasts').textContent = '';
        cancelRename();
        if (notify) post('close');
    }

    function startRename() {
        if (!data || !data.canRename) return;
        const input = $('nameInput');
        input.value = data.name || '';
        input.hidden = false;
        $('sysName').hidden = true;
        $('renameBtn').hidden = true;
        input.focus();
        input.select();
    }

    function cancelRename() {
        $('nameInput').hidden = true;
        $('sysName').hidden = false;
        if (data) $('renameBtn').hidden = !data.canRename;
    }

    function saveRename() {
        const name = $('nameInput').value.trim();
        cancelRename();
        if (name && data && name !== data.name) act('rename', { name });
    }

    function confirmClick(button, label, confirmLabel, fn) {
        button.addEventListener('click', () => {
            if (pendingConfirm === button) {
                pendingConfirm = null;
                button.textContent = label;
                button.classList.remove('confirm');
                return fn();
            }
            pendingConfirm = button;
            button.textContent = confirmLabel;
            button.classList.add('confirm');
            setTimeout(() => {
                if (pendingConfirm === button) {
                    pendingConfirm = null;
                    button.textContent = label;
                    button.classList.remove('confirm');
                }
            }, 3000);
        });
    }

    icon($('closeBtn'), 'close');
    icon($('renameBtn'), 'edit');
    icon($('stopBtn'), 'stop');
    icon($('skipBtn'), 'skip');
    icon($('shuffleBtn'), 'shuffle');
    icon($('addBtn'), 'plus');
    icon($('rangeIcon'), 'range');
    icon($('confirmIcon'), 'warning');

    $('closeBtn').addEventListener('click', () => close(true));
    $('renameBtn').addEventListener('click', startRename);
    $('sysName').addEventListener('dblclick', startRename);
    $('nameInput').addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); saveRename(); }
        if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); cancelRename(); }
    });
    $('nameInput').addEventListener('blur', () => { if (!$('nameInput').hidden) saveRename(); });

    $('playBtn').addEventListener('click', () => {
        if (!data) return;
        act(data.now && !data.now.paused ? 'pause' : 'play');
    });
    $('stopBtn').addEventListener('click', () => act('stop'));
    $('skipBtn').addEventListener('click', () => act('skip'));
    $('loopBtn').addEventListener('click', () => {
        if (!data) return;
        const next = data.loop === 'off' ? 'all' : data.loop === 'all' ? 'one' : 'off';
        act('loop', { mode: next });
    });
    $('shuffleBtn').addEventListener('click', () => { if (data) act('shuffle', { on: !data.shuffle }); });

    $('volume').addEventListener('input', (e) => { volumeDragging = true; setVolumeUi(Number(e.target.value)); });
    $('volume').addEventListener('change', (e) => {
        volumeDragging = false;
        act('volume', { value: Number(e.target.value) / 100 });
    });

    $('range').addEventListener('input', (e) => { rangeDragging = true; setRangeUi(Number(e.target.value)); });
    $('range').addEventListener('change', (e) => {
        rangeDragging = false;
        act('range', { value: Number(e.target.value) });
    });
    $('rangeReset').addEventListener('click', () => act('range', { reset: true }));

    $('progressTrack').addEventListener('click', (e) => {
        if (!data || !data.now) return;
        const { dur, live } = progressInfo();
        if (!dur || live) return;
        const r = e.currentTarget.getBoundingClientRect();
        const frac = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
        act('seek', { time: frac * dur });
    });

    $('addForm').addEventListener('submit', (e) => {
        e.preventDefault();
        const url = $('addUrl').value.trim();
        if (!url) return;
        $('addBtn').disabled = true;
        act('add', { url }).then((r) => {
            $('addBtn').disabled = false;
            if (r.ok) {
                $('addUrl').value = '';
                toast('success', 'Added to the queue.');
            }
        });
    });

    document.querySelectorAll('.tab-btn').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));

    confirmClick($('clearBtn'), 'Clear queue', 'Click again to clear', () => act('clear'));
    confirmClick($('uninstallBtn'), 'Remove sound system', 'Click again to remove it', () => act('uninstall').then((r) => { if (r.ok) close(true); }));

    function showConfirm(msg) {
        $('confirmTitle').textContent = msg.title || '';
        $('confirmText').textContent = msg.text || '';
        $('confirmYes').textContent = msg.yes || 'Yes';
        $('confirmNo').textContent = msg.no || 'Cancel';
        document.querySelector('.confirm-card').classList.toggle('danger', !!msg.danger);
        $('confirm').hidden = false;
        $('confirmNo').focus();
    }

    function answer(yes) {
        if ($('confirm').hidden) return;
        $('confirm').hidden = true;
        post('confirm', { yes });
    }

    $('confirmYes').addEventListener('click', () => answer(true));
    $('confirmNo').addEventListener('click', () => answer(false));
    $('confirm').addEventListener('click', (e) => { if (e.target === $('confirm')) answer(false); });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !$('confirm').hidden) { e.preventDefault(); answer(false); return; }
        if (e.key === 'Escape' && data && $('nameInput').hidden) { e.preventDefault(); close(true); }
    });

    setInterval(updateProgress, 250);
    setInterval(() => { if (data && tab === 'speakers') refreshDistances(); }, 2000);

    function placement(msg) {
        const box = $('placement');
        const link = $('placeLink');
        if (!msg.show) { box.hidden = true; link.hidden = true; return; }
        link.hidden = !msg.valid || !msg.info;
        link.className = 'place-link ' + (['ok', 'far', 'new'].includes(msg.infoKind) ? msg.infoKind : '');
        $('placeLinkText').textContent = msg.info || '';
        box.hidden = false;
        box.classList.toggle('valid', !!msg.valid);
        $('placeLabel').textContent = msg.label || '';
        $('placeReason').textContent = msg.valid ? '' : (msg.reason || 'Look at a surface');
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || typeof msg.action !== 'string') return;
        switch (msg.action) {
            case 'panel':
                if (msg.data && (msg.open || (data && data.id === msg.data.id))) open(msg.data, msg.open);
                break;
            case 'closePanel': close(false); break;
            case 'toast': if (data) toast(msg.kind, msg.text); break;
            case 'placement': placement(msg); break;
            case 'confirm': showConfirm(msg); break;
        }
    });
})();
