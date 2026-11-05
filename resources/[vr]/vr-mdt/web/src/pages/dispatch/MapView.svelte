<script>
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';
  import IconButton from '../../components/IconButton.svelte';
  import { session, dispatch } from '../../lib/state.svelte.js';
  import { priorityTone, statusTone } from '../../lib/status.js';

  let { selectedId = null, onselect, focus = null, onpick = null } = $props();

  let el;
  let map;
  let callLayer;
  let unitLayer;
  const callMarkers = new Map();
  const unitMarkers = new Map();
  let showCalls = $state(true);
  let showUnits = $state(true);
  let followed = false;

  function crs() {
    const m = session.map || { originX: 3753.6, originY: 5529.6, scaleX: 0.66304, scaleY: -0.656 };
    return L.extend({}, L.CRS.Simple, {
      transformation: new L.Transformation(m.scaleX / 32, m.originX / 32, m.scaleY / 32, m.originY / 32),
    });
  }

  const toLatLng = (c) => L.latLng(c.y, c.x);

  function callIcon(call, selected) {
    const tone = priorityTone(call.priority);
    return L.divIcon({
      className: '',
      html: `<div class="mk-call ${tone}${selected ? ' sel' : ''}${call.status === 'closed' ? ' closed' : ''}"><span></span></div>`,
      iconSize: [34, 34],
      iconAnchor: [17, 17],
    });
  }

  function unitIcon(unit, isMe) {
    const tone = unit.dept === 'ems' ? 'ems' : statusTone(unit.status);
    const label = String(unit.callsign || unit.name || '').replace(/[<>&"]/g, '');
    return L.divIcon({
      className: '',
      html: `<div class="mk-unit ${tone}${isMe ? ' me' : ''}"><span class="sq"></span><span class="lb">${label}</span></div>`,
      iconSize: [0, 0],
      iconAnchor: [6, 6],
    });
  }

  $effect(() => {
    map = L.map(el, {
      crs: crs(),
      minZoom: 1,
      maxZoom: 7,
      zoomControl: false,
      attributionControl: false,
      zoomSnap: 0.5,
      wheelPxPerZoomLevel: 90,
      preferCanvas: false,
    });
    const max = 8192;
    const bounds = L.latLngBounds(map.unproject([0, max], 5), map.unproject([max, 0], 5));
    L.tileLayer('tiles/{z}/{x}/{y}.jpg', { minZoom: 1, maxZoom: 7, maxNativeZoom: 5, minNativeZoom: 0, noWrap: true, bounds, tileSize: 256, keepBuffer: 4 }).addTo(map);
    map.setMaxBounds(bounds.pad(0.2));
    callLayer = L.layerGroup().addTo(map);
    unitLayer = L.layerGroup().addTo(map);
    map.setView(L.latLng(-900, -200), 3);
    map.on('contextmenu', (e) => {
      if (onpick) onpick({ x: Math.round(e.latlng.lng * 10) / 10, y: Math.round(e.latlng.lat * 10) / 10 });
    });
    return () => {
      map.remove();
      map = null;
      callMarkers.clear();
      unitMarkers.clear();
    };
  });

  $effect(() => {
    if (!map) return;
    const list = showCalls ? [...dispatch.calls] : [];
    const seen = new Set();
    for (const call of list) {
      seen.add(call.id);
      const sel = call.id === selectedId;
      let m = callMarkers.get(call.id);
      if (!m) {
        m = L.marker(toLatLng(call.coords), { icon: callIcon(call, sel), zIndexOffset: sel ? 1000 : 500 - call.priority * 100, keyboard: false });
        m.on('click', () => onselect?.(call.id));
        m.addTo(callLayer);
        callMarkers.set(call.id, m);
      } else {
        m.setLatLng(toLatLng(call.coords));
        m.setIcon(callIcon(call, sel));
        m.setZIndexOffset(sel ? 1000 : 500 - call.priority * 100);
      }
    }
    for (const [id, m] of callMarkers) {
      if (!seen.has(id)) {
        callLayer.removeLayer(m);
        callMarkers.delete(id);
      }
    }
  });

  $effect(() => {
    if (!map) return;
    const positions = dispatch.positions;
    const units = showUnits ? dispatch.units : [];
    const myCid = session.me?.cid;
    const seen = new Set();
    for (const u of units) {
      const p = positions[u.cid];
      if (!p) continue;
      seen.add(u.cid);
      const isMe = u.cid === myCid;
      let m = unitMarkers.get(u.cid);
      if (!m) {
        m = L.marker(L.latLng(p.y, p.x), { icon: unitIcon(u, isMe), zIndexOffset: isMe ? 2000 : 1500, keyboard: false, interactive: false });
        m.addTo(unitLayer);
        m._key = `${u.status}|${u.callsign}|${u.dept}`;
        unitMarkers.set(u.cid, m);
      } else {
        m.setLatLng(L.latLng(p.y, p.x));
        const key = `${u.status}|${u.callsign}|${u.dept}`;
        if (m._key !== key) {
          m.setIcon(unitIcon(u, isMe));
          m._key = key;
        }
      }
    }
    for (const [cid, m] of unitMarkers) {
      if (!seen.has(cid)) {
        unitLayer.removeLayer(m);
        unitMarkers.delete(cid);
      }
    }
    const me = myCid && positions[myCid];
    if (me && !followed && !focus) {
      followed = true;
      map.setView(L.latLng(me.y, me.x), 4);
    }
  });

  $effect(() => {
    if (map && focus) map.flyTo(L.latLng(focus.y, focus.x), Math.max(map.getZoom(), 4.5), { duration: 0.5 });
  });

  function centreOnMe() {
    const me = session.me && dispatch.positions[session.me.cid];
    if (me && map) map.flyTo(L.latLng(me.y, me.x), 5, { duration: 0.5 });
  }
</script>

<section class="map" aria-label="Map">
  <div class="leaf" bind:this={el}></div>
  <div class="filters">
    <button type="button" class="chip" class:on={showCalls} aria-pressed={showCalls} onclick={() => (showCalls = !showCalls)}>Calls</button>
    <button type="button" class="chip" class:on={showUnits} aria-pressed={showUnits} onclick={() => (showUnits = !showUnits)}>Units</button>
  </div>
  <div class="zoom">
    <IconButton icon="target" label="Centre on me" size={36} onclick={centreOnMe} />
    <IconButton icon="plus" label="Zoom in" size={36} onclick={() => map?.zoomIn()} />
    <IconButton icon="minus" label="Zoom out" size={36} onclick={() => map?.zoomOut()} />
  </div>
</section>

<style>
  .map { position: relative; flex: 1; min-width: 0; background: #070A10; overflow: hidden; isolation: isolate; z-index: 0; }
  .leaf { position: absolute; inset: 0; }
  .filters { position: absolute; left: 14px; top: 14px; display: flex; gap: 8px; z-index: 500; }
  .chip { height: 32px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.92); color: var(--muted); font-size: 13px; font-weight: 600; }
  .chip.on { color: var(--text); border-color: var(--line-3); }
  .zoom { position: absolute; right: 14px; bottom: 14px; display: flex; flex-direction: column; gap: 2px; padding: 3px; border-radius: var(--radius); border: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.92); z-index: 500; }
  :global(.mk-call) { position: relative; width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; border: 2px solid; cursor: pointer; transition: transform 0.15s; }
  :global(.mk-call span) { width: 10px; height: 10px; border-radius: 50%; }
  :global(.mk-call.p1) { border-color: var(--p1); background: rgba(255, 90, 82, 0.2); }
  :global(.mk-call.p1 span) { background: var(--p1); }
  :global(.mk-call.p2) { border-color: var(--p2); background: rgba(245, 165, 36, 0.18); }
  :global(.mk-call.p2 span) { background: var(--p2); }
  :global(.mk-call.p3) { border-color: var(--p3); background: rgba(90, 169, 255, 0.18); }
  :global(.mk-call.p3 span) { background: var(--p3); }
  :global(.mk-call.sel) { transform: scale(1.25); box-shadow: 0 0 0 6px rgba(255, 255, 255, 0.08); }
  :global(.mk-call.p1:not(.closed)::after) { content: ''; position: absolute; width: 34px; height: 34px; border-radius: 50%; border: 2px solid var(--p1); animation: mkpulse 1.6s ease-out infinite; }
  @keyframes -global-mkpulse { from { transform: scale(1); opacity: 0.8; } to { transform: scale(2.2); opacity: 0; } }
  :global(.mk-unit) { display: flex; align-items: center; gap: 6px; white-space: nowrap; pointer-events: none; }
  :global(.mk-unit .sq) { width: 12px; height: 12px; border-radius: 3px; border: 2px solid #0A0E14; flex: none; }
  :global(.mk-unit .lb) { font-family: var(--mono); font-size: 11px; color: var(--text); background: rgba(10, 14, 20, 0.85); padding: 1px 5px; border-radius: 3px; }
  :global(.mk-unit.ok .sq) { background: var(--ok); }
  :global(.mk-unit.accent .sq) { background: var(--accent); }
  :global(.mk-unit.info .sq) { background: var(--info); }
  :global(.mk-unit.muted .sq) { background: var(--muted); }
  :global(.mk-unit.ems .sq) { background: var(--ems); }
  :global(.mk-unit.me .sq) { box-shadow: 0 0 0 3px rgba(245, 165, 36, 0.45); }
  :global(.mk-unit.me .lb) { color: var(--accent); }
</style>
