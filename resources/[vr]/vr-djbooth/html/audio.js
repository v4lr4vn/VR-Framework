(function () {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vr-djbooth';
    const holder = document.getElementById('players');

    let occlusion = {
        room: { cutoff: 2600, gain: 0.85, ytGain: 0.75 },
        outside: { cutoff: 650, gain: 0.75, ytGain: 0.35 },
        vehicle: { cutoff: 900, gain: 0.8, ytGain: 0.45 },
    };
    let masterVolume = 0.6;

    const systems = {};
    const players = {};
    let audible = {};
    let listener = null;

    let ctx = null;
    let master = null;

    function post(name, data) {
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function audioContext() {
        if (!ctx) {
            ctx = new (window.AudioContext || window.webkitAudioContext)();
            const comp = ctx.createDynamicsCompressor();
            comp.threshold.value = -6;
            comp.ratio.value = 4;
            master = ctx.createGain();
            master.connect(comp);
            comp.connect(ctx.destination);
        }
        if (ctx.state === 'suspended') ctx.resume().catch(() => {});
        return ctx;
    }

    function expectedTime(entry) {
        const now = entry.state.now;
        if (!now) return 0;
        let t = Number(now.elapsed) || 0;
        if (!now.paused) t += (performance.now() - entry.receivedAt) / 1000;
        return Math.max(0, t);
    }

    function youtubeId(url) {
        const m = String(url).match(/(?:[?&]v=|youtu\.be\/|\/embed\/|\/shorts\/|\/live\/)([A-Za-z0-9_-]{6,20})/);
        return m ? m[1] : null;
    }

    let ytState = 'none';
    const ytWaiting = [];
    function withYouTube(fn) {
        if (ytState === 'ready') return fn();
        ytWaiting.push(fn);
        if (ytState === 'none') {
            ytState = 'loading';
            window.onYouTubeIframeAPIReady = () => {
                ytState = 'ready';
                while (ytWaiting.length) ytWaiting.shift()();
            };
            const s = document.createElement('script');
            s.src = 'https://www.youtube.com/iframe_api';
            s.onerror = () => { ytState = 'none'; ytWaiting.length = 0; };
            document.head.appendChild(s);
        }
    }

    function destroy(id) {
        const p = players[id];
        if (!p) return;
        delete players[id];
        p.dead = true;
        if (p.yt) { try { p.yt.destroy(); } catch (e) { } }
        if (p.box && p.box.parentNode) p.box.parentNode.removeChild(p.box);
        teardownElement(p);
    }

    function teardownElement(p) {
        for (const sid in p.nodes) disconnectNode(p.nodes[sid]);
        p.nodes = {};
        if (p.source) { try { p.source.disconnect(); } catch (e) { } p.source = null; }
        if (p.sysGain) { try { p.sysGain.disconnect(); } catch (e) { } p.sysGain = null; }
        if (p.el) {
            try { p.el.pause(); } catch (e) { }
            p.el.removeAttribute('src');
            try { p.el.load(); } catch (e) { }
            p.el = null;
        }
    }

    function disconnectNode(n) {
        for (const k of ['panner', 'filter', 'gain']) {
            try { n[k].disconnect(); } catch (e) { }
        }
    }

    function fail(p, code) {
        if (p.dead) return;
        post('error', { system: p.id, trackId: p.trackId, code: String(code) });
        const entry = systems[p.id];
        if (entry) entry.failedTrack = p.trackId;
        destroy(p.id);
    }

    function ended(p) {
        if (p.dead || p.endedSent) return;
        p.endedSent = true;
        post('ended', { system: p.id, trackId: p.trackId });
    }

    function createAudio(p, withCors) {
        const a = new Audio();
        a.preload = 'auto';
        if (withCors) a.crossOrigin = 'anonymous';
        p.el = a;
        p.mode = withCors ? 'web' : 'volume';
        a.addEventListener('loadedmetadata', () => {
            if (p.dead || p.el !== a) return;
            p.ready = true;
            sync(p, true);
            applyPlayState(p);
        });
        a.addEventListener('playing', () => { p.played = true; });
        a.addEventListener('ended', () => { if (p.el === a) ended(p); });
        a.addEventListener('error', () => {
            if (p.dead || p.el !== a) return;
            if (withCors && !p.played) {
                teardownElement(p);
                return createAudio(p, false);
            }
            fail(p, a.error ? a.error.code : 'audio');
        });
        if (withCors) {
            const c = audioContext();
            p.source = c.createMediaElementSource(a);
            p.sysGain = c.createGain();
            p.sysGain.gain.value = 0;
            p.sysGain.connect(master);
        } else {
            a.volume = 0;
        }
        a.src = p.url;
    }

    function createYouTube(p, videoId) {
        p.mode = 'youtube';
        p.box = document.createElement('div');
        p.box.id = `yt_${String(p.id).replace(/[^A-Za-z0-9_-]/g, '')}_${p.trackId}`;
        holder.appendChild(p.box);
        withYouTube(() => {
            if (p.dead) return;
            const entry = systems[p.id];
            p.yt = new YT.Player(p.box.id, {
                width: 320, height: 180, videoId,
                playerVars: {
                    autoplay: 1, controls: 0, disablekb: 1, fs: 0, iv_load_policy: 3, modestbranding: 1, playsinline: 1, rel: 0,
                    start: Math.floor(entry ? expectedTime(entry) : 0),
                },
                events: {
                    onReady: () => {
                        if (p.dead) return;
                        p.ready = true;
                        try { p.yt.setVolume(0); } catch (e) { }
                        p.volume = -1;
                        sync(p, true);
                        applyPlayState(p);
                    },
                    onStateChange: (e) => {
                        if (p.dead) return;
                        if (e.data === YT.PlayerState.PLAYING) p.played = true;
                        if (e.data === YT.PlayerState.ENDED) ended(p);
                    },
                    onError: (e) => fail(p, e.data),
                },
            });
        });
    }

    function create(id, entry) {
        const now = entry.state.now;
        const p = { id, trackId: now.trackId, url: now.url, kind: now.kind, nodes: {}, lastHeard: performance.now(), volume: -1 };
        players[id] = p;
        const vid = now.kind === 'youtube' ? youtubeId(now.url) : null;
        if (vid) createYouTube(p, vid); else createAudio(p, true);
        return p;
    }

    function currentTime(p) {
        if (p.mode === 'youtube') { try { return p.yt.getCurrentTime() || 0; } catch (e) { return 0; } }
        return p.el ? p.el.currentTime || 0 : 0;
    }

    function seek(p, t) {
        if (p.mode === 'youtube') { try { p.yt.seekTo(t, true); } catch (e) { } return; }
        if (p.el && isFinite(p.el.duration)) {
            try { p.el.currentTime = Math.min(t, Math.max(0, p.el.duration - 0.5)); } catch (e) { }
        }
    }

    function sync(p, force) {
        const entry = systems[p.id];
        if (!entry || !entry.state.now || !p.ready) return;
        if (entry.state.now.duration === -1) return;
        const want = expectedTime(entry);
        if (force || Math.abs(currentTime(p) - want) > 2.5) seek(p, want);
    }

    function applyPlayState(p) {
        const entry = systems[p.id];
        if (!entry || !entry.state.now || !p.ready) return;
        const paused = entry.state.now.paused;
        if (p.mode === 'youtube') {
            try { if (paused) p.yt.pauseVideo(); else p.yt.playVideo(); } catch (e) { }
        } else if (p.el) {
            if (paused) p.el.pause();
            else if (p.el.paused) p.el.play().catch(() => { p.retryPlay = true; });
        }
    }

    function linear(d, r) {
        if (d <= 1) return 1;
        if (d >= r) return 0;
        return 1 - (d - 1) / (r - 1);
    }

    function occlusionFor(o) {
        if (o === 1) return occlusion.room;
        if (o === 2) return occlusion.outside;
        if (o === 3) return occlusion.vehicle;
        return null;
    }

    function setParam(param, value) {
        if (!ctx) return;
        param.setTargetAtTime(value, ctx.currentTime, 0.12);
    }

    function updateListener() {
        if (!ctx || !listener) return;
        const [x, y, z] = listener.p;
        const [fx, fy, fz] = listener.f;
        const L = ctx.listener;
        if (L.positionX) {
            setParam(L.positionX, x); setParam(L.positionY, z); setParam(L.positionZ, -y);
            setParam(L.forwardX, fx); setParam(L.forwardY, fz); setParam(L.forwardZ, -fy);
            setParam(L.upX, 0); setParam(L.upY, 1); setParam(L.upZ, 0);
        } else {
            L.setPosition(x, z, -y);
            L.setOrientation(fx, fz, -fy, 0, 1, 0);
        }
    }

    function speakerNode(p, s) {
        let n = p.nodes[s.id];
        if (!n) {
            const panner = ctx.createPanner();
            panner.panningModel = 'equalpower';
            panner.distanceModel = 'linear';
            panner.refDistance = 1;
            panner.rolloffFactor = 1;
            const filter = ctx.createBiquadFilter();
            filter.type = 'lowpass';
            filter.frequency.value = 22000;
            const gain = ctx.createGain();
            p.source.connect(panner);
            panner.connect(filter);
            filter.connect(gain);
            gain.connect(p.sysGain);
            n = p.nodes[s.id] = { panner, filter, gain };
        }
        n.panner.maxDistance = Math.max(2, s.r);
        if (n.panner.positionX) {
            setParam(n.panner.positionX, s.x); setParam(n.panner.positionY, s.z); setParam(n.panner.positionZ, -s.y);
        } else {
            n.panner.setPosition(s.x, s.z, -s.y);
        }
        return n;
    }

    function mix(p, entry, speakers) {
        const vol = Math.max(0, Math.min(1, Number(entry.state.volume) || 0)) * masterVolume;
        const lp = listener ? listener.p : [0, 0, 0];
        let keep = 1;
        let sum = 0;
        const seen = {};

        for (const s of speakers) {
            const d = Math.hypot(s.x - lp[0], s.y - lp[1], s.z - lp[2]);
            const occ = occlusionFor(s.o);
            const g = linear(d, s.r);
            if (p.mode === 'web') {
                const n = speakerNode(p, s);
                seen[s.id] = true;
                const og = occ ? occ.gain : 1;
                setParam(n.filter.frequency, occ ? occ.cutoff : 22000);
                setParam(n.gain.gain, og);
                keep *= 1 - Math.min(1, g * og);
                sum += g * og;
            } else {
                const og = occ ? occ.ytGain : 1;
                keep *= 1 - Math.min(1, g * og);
            }
        }
        const total = 1 - keep;

        if (p.mode === 'web') {
            for (const sid in p.nodes) {
                if (!seen[sid]) { disconnectNode(p.nodes[sid]); delete p.nodes[sid]; }
            }
            setParam(p.sysGain.gain, sum > 0 ? vol * total / sum : 0);
            return;
        }
        const level = vol * total;
        if (Math.abs(level - p.volume) < 0.005) return;
        if (p.mode === 'youtube') {
            if (!p.ready) return;
            try { p.yt.setVolume(Math.round(level * 100)); } catch (e) { return; }
        } else if (p.el) {
            p.el.volume = Math.max(0, Math.min(1, level));
        }
        p.volume = level;
    }

    function setSystem(state) {
        if (!state || state.id === undefined) return;
        const id = String(state.id);
        const prev = systems[id];
        systems[id] = { state, receivedAt: performance.now(), failedTrack: prev ? prev.failedTrack : undefined };
        const p = players[id];
        if (!p) return;
        if (!state.now || state.now.trackId !== p.trackId) return destroy(id);
        const prevNow = prev && prev.state.now;
        if (!prevNow || prevNow.paused !== state.now.paused || Math.abs((prevNow.elapsed || 0) - (state.now.elapsed || 0)) > 0.5) {
            sync(p, true);
            applyPlayState(p);
        }
    }

    function tick(msg) {
        if (msg.l) listener = msg.l;
        audible = msg.s || {};
        updateListener();
        const t = performance.now();
        for (const id in audible) {
            const entry = systems[id];
            if (!entry || !entry.state.now) continue;
            let p = players[id];
            if (p && p.trackId !== entry.state.now.trackId) { destroy(id); p = null; }
            if (!p) {
                if (entry.failedTrack === entry.state.now.trackId) continue;
                p = create(id, entry);
            }
            p.lastHeard = t;
            if (p.retryPlay) { p.retryPlay = false; applyPlayState(p); }
            mix(p, entry, audible[id]);
        }
        for (const id in players) {
            if (!audible[id] && t - players[id].lastHeard > 4000) destroy(id);
        }
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || typeof msg.action !== 'string') return;
        switch (msg.action) {
            case 'config':
                if (msg.occlusion) occlusion = msg.occlusion;
                if (typeof msg.master === 'number') masterVolume = msg.master;
                break;
            case 'systems':
                for (const id in systems) {
                    if (!(msg.list || []).some((s) => String(s.id) === id)) { destroy(id); delete systems[id]; }
                }
                (msg.list || []).forEach(setSystem);
                break;
            case 'system': setSystem(msg.data); break;
            case 'systemRemoved':
                destroy(String(msg.id));
                delete systems[String(msg.id)];
                break;
            case 'tick': tick(msg); break;
        }
    });

    setInterval(() => {
        const list = [];
        for (const id in players) {
            const p = players[id];
            if (!p.ready || p.dead) continue;
            sync(p, false);
            let title = '', duration = 0;
            if (p.mode === 'youtube') {
                try {
                    const data = p.yt.getVideoData ? p.yt.getVideoData() : null;
                    title = (data && data.title) || '';
                    duration = data && data.isLive ? -1 : (p.yt.getDuration() || 0);
                } catch (e) { continue; }
            } else if (p.el) {
                duration = isFinite(p.el.duration) ? p.el.duration : (p.el.duration === Infinity ? -1 : 0);
            }
            if (title || duration) list.push({ system: id, trackId: p.trackId, title, duration });
        }
        if (list.length) post('info', { list });
    }, 2000);

    window.DJAudio = {
        position(id) {
            const p = players[String(id)];
            if (!p || !p.ready) return null;
            let duration = 0;
            if (p.mode === 'youtube') { try { duration = p.yt.getDuration() || 0; } catch (e) { } }
            else if (p.el && isFinite(p.el.duration)) duration = p.el.duration;
            return { time: currentTime(p), duration, mode: p.mode };
        },
        expected(id) {
            const entry = systems[String(id)];
            return entry ? expectedTime(entry) : 0;
        },
        _debug: { players, systems },
    };
})();
