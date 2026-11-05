<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { glyphPath } from '../../lib/glyphs.js';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { t } from '../../lib/i18n.js';
  import { CATEGORIES, COLOR, ICONS, bearingTo, compassPoint, distance, distanceText, glyphOf, gridStep, minutes, projection, radiusFor, ZOOM_STEPS } from './model.js';

  // A radar-style map: a grid, the places from the config, the player's own saved places and the player. It is north-up and
  // centred on the player until the map is dragged. The game's own map and GPS route are set from here with a waypoint.
  const cfg = $derived(phone.features?.maps ?? {});
  const atlas = $derived(cfg.atlas ?? null);

  let me = $state(null); // { x, y, z, bearing, street, zone, postal, speed, driving, waypoint }
  let catalog = $state([]);
  let saved = $state([]);
  let loaded = $state(false);
  let view = $state('map'); // narrow screens show either the map or the list
  let query = $state('');
  let filter = $state('all');
  let cx = $state(0);
  let cy = $state(0);
  let zoom = $state(1);
  let follow = $state(true);
  let selected = $state(null); // { key, name, x, y, z, icon, category, savedId? }
  let naming = $state(false);
  let draftName = $state('');
  let draftIcon = $state('pin');
  let error = $state('');
  let busy = $state(false);
  let width = $state(300);
  let height = $state(300);
  let centred = false;

  const radius = $derived(radiusFor(zoom, cfg.range ?? 250));
  const proj = $derived(projection({ cx, cy, width, height, radius }));
  const step = $derived(gridStep(proj.ppm));

  const gridX = $derived.by(() => {
    const out = [];
    const from = Math.floor(proj.wx(0) / step) * step;
    const to = proj.wx(width);
    for (let w = from; w <= to; w += step) out.push({ w, s: proj.x(w) });
    return out;
  });
  const gridY = $derived.by(() => {
    const out = [];
    const from = Math.floor(proj.wy(height) / step) * step;
    const to = proj.wy(0);
    for (let w = from; w <= to; w += step) out.push({ w, s: proj.y(w) });
    return out;
  });

  // Everything the map and the list can show.
  const everything = $derived([
    ...saved.map((p) => ({ ...p, key: `s${p.id}`, savedId: p.id, category: 'saved' })),
    ...catalog.map((p) => ({ ...p, key: p.id })),
  ]);

  function near(p) {
    return me ? distance(me, p) : 0;
  }

  const listed = $derived.by(() => {
    const q = query.trim().toLowerCase();
    return everything
      .filter((p) => (filter === 'all' || p.category === filter) && (!q || p.name.toLowerCase().includes(q)))
      .sort((a, b) => near(a) - near(b));
  });
  const savedShown = $derived(listed.filter((p) => p.savedId));
  const catalogShown = $derived(listed.filter((p) => !p.savedId));

  const goal = $derived(me?.waypoint ?? null);
  const goalFar = $derived(goal && me ? distance(me, goal) : 0);

  async function loadState() {
    const r = await post('mapsState');
    if (r?.ok) {
      catalog = r.catalog ?? [];
      saved = r.saved ?? [];
    }
    loaded = true;
  }

  async function poll() {
    const r = await post('mapsPos');
    if (!r || typeof r.x !== 'number') return;
    me = r;
    if (follow || !centred) {
      cx = r.x;
      cy = r.y;
      centred = true;
    }
  }

  onMount(() => {
    loadState();
    poll();
    const timer = setInterval(poll, 700);
    return () => clearInterval(timer);
  });

  $effect(() => {
    return onBack(() => {
      if (naming) {
        naming = false;
        return true;
      }
      if (selected) {
        selected = null;
        return true;
      }
      if (phone.fold === 'cover' && view === 'list') {
        view = 'map';
        return true;
      }
      return false;
    });
  });

  // ---- moving the map

  let drag = null;
  function down(e) {
    e.currentTarget.setPointerCapture?.(e.pointerId);
    drag = { x: e.clientX, y: e.clientY, cx, cy, moved: false };
  }
  function move(e) {
    if (!drag) return;
    const dx = e.clientX - drag.x;
    const dy = e.clientY - drag.y;
    if (!drag.moved && Math.hypot(dx, dy) < 5) return;
    drag.moved = true;
    follow = false;
    cx = drag.cx - dx / proj.ppm;
    cy = drag.cy + dy / proj.ppm;
  }
  function up(e) {
    const d = drag;
    drag = null;
    if (!d || d.moved) return;
    // A tap: a marker if one is close, otherwise a dropped pin.
    const box = e.currentTarget.getBoundingClientRect();
    const sx = e.clientX - box.left;
    const sy = e.clientY - box.top;
    let best = null;
    let bestD = 22;
    for (const p of everything) {
      const dd = Math.hypot(proj.x(p.x) - sx, proj.y(p.y) - sy);
      if (dd < bestD) {
        best = p;
        bestD = dd;
      }
    }
    naming = false;
    if (best) pick(best, false);
    else selected = { key: 'pin', name: t('maps.pin'), x: proj.wx(sx), y: proj.wy(sy), z: 0, icon: 'pin', category: 'pin' };
  }
  function wheel(e) {
    e.preventDefault();
    setZoom(zoom + (e.deltaY > 0 ? 1 : -1));
  }
  function setZoom(z) {
    zoom = Math.max(0, Math.min(ZOOM_STEPS - 1, z));
  }
  function locate() {
    follow = true;
    if (me) {
      cx = me.x;
      cy = me.y;
    }
  }

  function pick(p, centre = true) {
    selected = p;
    naming = false;
    error = '';
    if (centre) {
      follow = false;
      cx = p.x;
      cy = p.y;
      view = 'map';
    }
  }

  // ---- GPS and saving

  async function go() {
    if (!selected || busy) return;
    busy = true;
    const r = await post('mapsGo', { x: selected.x, y: selected.y });
    busy = false;
    if (r?.ok && me) me = { ...me, waypoint: r.waypoint ?? { x: selected.x, y: selected.y } };
  }

  async function stop() {
    const r = await post('mapsStop');
    if (r?.ok && me) me = { ...me, waypoint: null };
  }

  function startSave() {
    if (!selected) return;
    naming = true;
    draftName = selected.category === 'pin' ? '' : selected.name;
    draftIcon = ICONS.includes(selected.icon) ? selected.icon : 'pin';
    error = '';
  }

  async function saveHere() {
    // The "save my place" button in the list header.
    if (!me) return;
    selected = { key: 'pin', name: t('maps.here'), x: me.x, y: me.y, z: me.z, icon: 'pin', category: 'pin' };
    view = 'map';
    startSave();
  }

  async function commitSave() {
    if (!selected || busy || !draftName.trim()) return;
    busy = true;
    error = '';
    const r = await post('mapsSave', { name: draftName.trim(), x: selected.x, y: selected.y, z: selected.z ?? 0, icon: draftIcon });
    busy = false;
    if (!r?.ok) {
      error = scopedError(r?.reason, 'maps');
      return;
    }
    naming = false;
    selected = null;
    await loadState();
  }

  async function removeSaved() {
    if (!selected?.savedId) return;
    const r = await post('mapsRemove', { id: selected.savedId });
    if (r?.ok) {
      selected = null;
      loadState();
    } else error = scopedError(r?.reason, 'maps');
  }

  const dot = (p) => COLOR[p.category] ?? COLOR.places;
  const markerShown = (p) => proj.x(p.x) > -20 && proj.x(p.x) < width + 20 && proj.y(p.y) > -20 && proj.y(p.y) < height + 20;
</script>

{#snippet where()}
  <div class="ap-head">
    <h2>{t('app.maps')}</h2>
    <div class="ap-tools">
      <button class="ap-plus" onclick={saveHere} aria-label={t('maps.saveHere')} title={t('maps.saveHere')}><Glyph name="plus" size={22} stroke={2.4} /></button>
    </div>
  </div>
  <label class="ap-search">
    <Glyph name="search" size={18} />
    <input type="text" bind:value={query} placeholder={t('maps.search')} maxlength="40" />
  </label>
  <div class="ap-chips cats">
    {#each ['all', ...CATEGORIES, 'saved'] as c (c)}
      <button class="ap-chip" class:on={filter === c} onclick={() => (filter = c)}>{t(`maps.cat.${c}`)}</button>
    {/each}
  </div>

  {#if goal}
    <button class="ap-row gps" onclick={() => pick({ key: 'goal', name: t('maps.waypoint'), x: goal.x, y: goal.y, z: 0, icon: 'pin', category: 'pin' })}>
      <span class="ico on"><Glyph name="flag" size={18} stroke={2} /></span>
      <span class="txt">
        <span class="ttl">{t('maps.gpsOn')}</span>
        <span class="sub">{distanceText(goalFar)} · {t('maps.drive', { n: minutes(goalFar, 'drive') })}</span>
      </span>
    </button>
  {/if}

  {#if !loaded}
    <p class="ap-empty">{t('common.loading')}</p>
  {:else if listed.length === 0}
    <p class="ap-empty">{t('maps.noMatch')}</p>
  {:else}
    {#if savedShown.length}
      <div class="ap-label first">{t('maps.saved')}</div>
      <ul class="ap-list">
        {#each savedShown as p (p.key)}
          <li>
            <button class="ap-row" onclick={() => pick(p)}>
              <span class="ico" style:background={dot(p)}><Glyph name={glyphOf(p.icon)} size={17} stroke={2} /></span>
              <span class="txt"><span class="ttl">{p.name}</span><span class="sub">{distanceText(near(p))}</span></span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
    {#if catalogShown.length}
      <div class="ap-label" class:first={!savedShown.length}>{t('maps.nearby')}</div>
      <ul class="ap-list">
        {#each catalogShown as p (p.key)}
          <li>
            <button class="ap-row" onclick={() => pick(p)}>
              <span class="ico" style:background={dot(p)}><Glyph name={glyphOf(p.icon)} size={17} stroke={2} /></span>
              <span class="txt"><span class="ttl">{p.name}</span><span class="sub">{distanceText(near(p))} · {t(`maps.cat.${p.category}`)}</span></span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  {/if}
{/snippet}

{#snippet board()}
  <div class="board">
    <div
      class="map"
      role="application"
      aria-label={t('app.maps')}
      bind:clientWidth={width}
      bind:clientHeight={height}
      onpointerdown={down}
      onpointermove={move}
      onpointerup={up}
      onpointercancel={() => (drag = null)}
      onwheel={wheel}
    >
      <svg {width} {height} viewBox="0 0 {width} {height}">
        {#if atlas}
          <image href={atlas.file} x={proj.x(atlas.minX)} y={proj.y(atlas.maxY)} width={(atlas.maxX - atlas.minX) * proj.ppm} height={(atlas.maxY - atlas.minY) * proj.ppm} preserveAspectRatio="none" />
        {/if}
        <g class="grid">
          {#each gridX as g (g.w)}
            <line x1={g.s} y1="0" x2={g.s} y2={height} class:major={g.w % (step * 5) === 0} />
          {/each}
          {#each gridY as g (g.w)}
            <line x1="0" y1={g.s} x2={width} y2={g.s} class:major={g.w % (step * 5) === 0} />
          {/each}
        </g>

        {#if me}
          <circle class="ring" cx={proj.x(me.x)} cy={proj.y(me.y)} r={100 * proj.ppm} />
        {/if}
        {#if me && goal}
          <line class="route" x1={proj.x(me.x)} y1={proj.y(me.y)} x2={proj.x(goal.x)} y2={proj.y(goal.y)} />
        {/if}

        {#each everything as p (p.key)}
          {#if markerShown(p)}
            <g class="mark" class:sel={selected?.key === p.key} transform="translate({proj.x(p.x)} {proj.y(p.y)})">
              <circle r="13" fill={dot(p)} />
              <svg x="-8" y="-8" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{@html glyphPath(glyphOf(p.icon))}</svg>
            </g>
          {/if}
        {/each}

        {#if selected && selected.category === 'pin'}
          <g transform="translate({proj.x(selected.x)} {proj.y(selected.y)})" class="drop">
            <path d="M0 0 C -9 -12 -9 -22 0 -22 C 9 -22 9 -12 0 0z" fill="#e5484d" />
            <circle cy="-15" r="3" fill="#fff" />
          </g>
        {/if}
        {#if goal}
          <g transform="translate({proj.x(goal.x)} {proj.y(goal.y)})" class="flagm">
            <path d="M0 0V-26" stroke="#111" stroke-width="2" />
            <path d="M0 -26h16l-4 5 4 5H0z" fill="#e5484d" />
          </g>
        {/if}
        {#if me}
          <g transform="translate({proj.x(me.x)} {proj.y(me.y)}) rotate({me.bearing})" class="you">
            <circle r="16" class="halo" />
            <path d="M0 -12 L8 9 L0 5 L-8 9z" />
          </g>
        {/if}
      </svg>

      {#if !me}<div class="locating">{t('maps.locating')}</div>{/if}
    </div>

    <div class="info">
      <div class="street">{me?.street || me?.zone || t('maps.locating')}</div>
      <div class="zone">
        {#if me?.street && me?.zone}{me.zone}{/if}
        {#if me?.postal}<span> · {t('maps.postal', { code: me.postal })}</span>{/if}
      </div>
      {#if me}<div class="zone">{compassPoint(me.bearing)} · {Math.round(me.speed)} km/h</div>{/if}
    </div>

    <div class="tools">
      <button class="tool" onclick={() => setZoom(zoom - 1)} aria-label={t('maps.zoomIn')} disabled={zoom <= 0}><Glyph name="plus" size={20} stroke={2.4} /></button>
      <button class="tool" onclick={() => setZoom(zoom + 1)} aria-label={t('maps.zoomOut')} disabled={zoom >= ZOOM_STEPS - 1}><Glyph name="minus" size={20} stroke={2.4} /></button>
      <button class="tool" class:on={follow} onclick={locate} aria-label={t('maps.locate')}><Glyph name="locate" size={20} stroke={2} /></button>
      {#if phone.fold === 'cover'}
        <button class="tool" onclick={() => (view = 'list')} aria-label={t('maps.places')}><Glyph name="gridlines" size={20} stroke={2} /></button>
      {/if}
    </div>

    {#if selected}
      <div class="sheet">
        {#if naming}
          <div class="ap-form">
            <label>
              <span>{t('maps.name')}</span>
              <input type="text" bind:value={draftName} maxlength={cfg.nameLength ?? 40} placeholder={t('maps.namePlaceholder')} />
            </label>
            <div class="icons">
              {#each ICONS as ic (ic)}
                <button class="ic" class:on={draftIcon === ic} onclick={() => (draftIcon = ic)} aria-label={ic}><Glyph name={glyphOf(ic)} size={18} stroke={2} /></button>
              {/each}
            </div>
            {#if error}<p class="ap-err">{error}</p>{/if}
            <div class="ap-btns">
              <button class="ap-btn" onclick={() => (naming = false)}>{t('common.cancel')}</button>
              <button class="ap-btn main" onclick={commitSave} disabled={busy || !draftName.trim()}>{t('maps.save')}</button>
            </div>
          </div>
        {:else}
          <div class="head">
            <div class="txt">
              <div class="ttl">{selected.name}</div>
              <div class="sub">
                {#if me}{distanceText(distance(me, selected))} · {compassPoint(bearingTo(me, selected))}{/if}
                {#if selected.category !== 'pin'} · {t(`maps.cat.${selected.category}`)}{/if}
              </div>
              {#if me}
                <div class="sub">{t('maps.drive', { n: minutes(distance(me, selected), 'drive') })} · {t('maps.walk', { n: minutes(distance(me, selected), 'walk') })}</div>
              {/if}
            </div>
            <button class="ap-round" onclick={() => (selected = null)} aria-label={t('common.close')}><Glyph name="close" size={18} stroke={2.2} /></button>
          </div>
          {#if error}<p class="ap-err">{error}</p>{/if}
          <div class="ap-btns left">
            {#if goal && Math.hypot(goal.x - selected.x, goal.y - selected.y) < 30}
              <button class="ap-btn red" onclick={stop}>{t('maps.stopGps')}</button>
            {:else}
              <button class="ap-btn main" onclick={go} disabled={busy}>{t('maps.startGps')}</button>
            {/if}
            {#if selected.savedId}
              <button class="ap-btn red" onclick={removeSaved}>{t('maps.remove')}</button>
            {:else}
              <button class="ap-btn" onclick={startSave}>{t('maps.save')}</button>
            {/if}
          </div>
        {/if}
      </div>
    {:else if goal}
      <div class="sheet slim">
        <div class="txt">
          <div class="ttl">{t('maps.gpsOn')}</div>
          <div class="sub">{distanceText(goalFar)} · {t('maps.drive', { n: minutes(goalFar, 'drive') })}</div>
        </div>
        <button class="ap-btn red" onclick={stop}>{t('maps.stopGps')}</button>
      </div>
    {/if}
  </div>
{/snippet}

<TwoPane list={where} detail={board} cover="switch" showDetail={view === 'map'} bleed />

<style>
  .board {
    position: absolute;
    inset: 0;
    overflow: hidden;
    background: var(--surface-2);
  }
  .map {
    position: absolute;
    inset: 0;
    touch-action: none;
    cursor: grab;
    user-select: none;
  }
  .map:active {
    cursor: grabbing;
  }
  svg {
    display: block;
  }
  .grid line {
    stroke: var(--line);
    stroke-width: 1;
  }
  .grid line.major {
    stroke: var(--ink-3);
    stroke-opacity: 0.35;
  }
  .ring {
    fill: none;
    stroke: var(--accent);
    stroke-opacity: 0.35;
    stroke-dasharray: 3 5;
  }
  .route {
    stroke: #e5484d;
    stroke-width: 3;
    stroke-dasharray: 8 6;
    stroke-linecap: round;
  }
  .mark circle {
    stroke: #fff;
    stroke-width: 2;
  }
  .mark.sel circle {
    stroke: var(--ink);
    stroke-width: 3;
  }
  .you .halo {
    fill: var(--accent);
    fill-opacity: 0.22;
  }
  .you path {
    fill: var(--accent);
    stroke: #fff;
    stroke-width: 2;
    stroke-linejoin: round;
  }
  .locating {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    font-size: 14px;
    font-weight: 600;
    color: var(--ink-3);
    pointer-events: none;
  }
  .info {
    position: absolute;
    left: 10px;
    top: 52px;
    max-width: calc(100% - 80px);
    padding: 8px 12px;
    border-radius: 14px;
    background: var(--surface);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.12);
    pointer-events: none;
  }
  .street {
    font-size: 15px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .zone {
    font-size: 12px;
    color: var(--ink-3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .tools {
    position: absolute;
    right: 10px;
    top: 52px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .tool {
    width: 42px;
    height: 42px;
    display: grid;
    place-items: center;
    border-radius: 14px;
    background: var(--surface);
    color: var(--ink);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.12);
  }
  .tool.on {
    background: var(--accent);
    color: var(--on-accent);
  }
  .tool:disabled {
    opacity: 0.4;
  }
  .sheet {
    position: absolute;
    left: 8px;
    right: 8px;
    bottom: 40px;
    padding: 14px;
    border-radius: 20px;
    background: var(--surface);
    box-shadow: 0 4px 18px rgba(0, 0, 0, 0.18);
  }
  .sheet.slim {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  .head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 10px;
    margin-bottom: 10px;
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ttl {
    font-size: 16px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .ap-btns.left {
    justify-content: flex-start;
  }
  .icons {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .ic {
    width: 36px;
    height: 36px;
    display: grid;
    place-items: center;
    border-radius: 12px;
    background: var(--surface-2);
    color: var(--ink);
  }
  .ic.on {
    background: var(--accent);
    color: var(--on-accent);
  }
  .ico {
    flex: none;
    width: 34px;
    height: 34px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: #fff;
    background: var(--ink-3);
  }
  .ico.on {
    background: #e5484d;
  }
  .ap-row .txt {
    gap: 1px;
  }
  .cats {
    margin: 4px 0 6px;
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 2px;
  }
  .cats .ap-chip {
    flex: none;
    padding: 6px 12px;
  }
  .gps {
    background: var(--accent-soft);
    margin-bottom: 4px;
  }
</style>
