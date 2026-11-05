<script>
  import { untrack } from 'svelte';
  import { isGame, post } from './lib/nui.js';
  import { builderCall } from './lib/mock.js';
  import Modal from './ui/Modal.svelte';

  let { data, hidden = false, placed = null, onclose } = $props();

  const TYPES = [['public', 'Public', 'fa-square-parking'], ['job', 'Job', 'fa-briefcase'], ['gang', 'Gang', 'fa-people-group'], ['impound', 'Impound', 'fa-truck-ramp-box']];
  const CATS = [['car', 'Cars'], ['air', 'Aircraft'], ['boat', 'Boats'], ['all', 'Everything']];
  const SOURCE = { config: ['Config', ''], edited: ['Edited', 'accent'], built: ['Built in game', 'ok'], removed: ['Removed', 'danger'] };
  const ERRORS = {
    bad_id: 'The ID can only use letters, numbers and _',
    id_taken: 'Another garage already uses that ID',
    need_group: 'Pick which job or gang owns this garage',
    unknown_group: 'That job or gang does not exist',
    need_center: 'Place the garage centre first',
    bad_type: 'Pick a garage type',
    no_garage: 'That garage no longer exists',
    no_access: 'You need admin rights for the garage builder',
    slow_down: 'Slow down a little',
  };

  const initial = () => data.garages || [];
  let garages = $state(initial());
  let groups = $derived(data.groups || { job: [], gang: [] });
  let search = $state('');
  let filter = $state('all');
  let draft = $state(null);
  let original = $state('');
  let isNew = $state(false);
  let idTouched = $state(false);
  let busy = $state(false);
  let toast = $state(null);
  let confirm = $state(null);
  let checks = $state({});
  let pedModel = $state('mp_m_weapexp_01');
  let mockPlaced = $state(null);
  let lastPlaced = null;

  const call = async (action, payload = {}) => {
    if (!isGame) return builderCall(action, payload);
    const r = await post('builder:api', { action, data: payload });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  let toastTimer;
  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3400);
  }

  const counts = $derived.by(() => {
    const c = { all: garages.length };
    for (const g of garages) c[g.type] = (c[g.type] || 0) + 1;
    return c;
  });

  const shown = $derived.by(() => {
    const s = search.trim().toLowerCase();
    return garages.filter((g) => (filter === 'all' || g.type === filter) && (!s || `${g.label} ${g.id} ${g.group || ''}`.toLowerCase().includes(s)));
  });

  const groupList = $derived(draft && (draft.type === 'job' || draft.type === 'gang') ? groups[draft.type] || [] : []);
  const grades = $derived(groupList.find((g) => g.name === draft?.group)?.grades || []);
  const groupLabel = (g) => {
    if (!g.group) return null;
    const list = groups[g.type] || [];
    return list.find((x) => x.name === g.group)?.label || g.group;
  };
  const dirty = $derived(draft ? JSON.stringify(strip(draft)) !== original : false);

  function ids(list, on) {
    return (list || []).filter((e) => !!e.on === on).map((e) => e.id).join(', ');
  }

  function parseIds(s) {
    return String(s || '').split(/[\s,]+/).filter((t) => t !== '').map(Number).filter((n) => Number.isInteger(n) && n >= 0 && n <= 20);
  }

  function toDraft(g) {
    return {
      ...JSON.parse(JSON.stringify(g)),
      ped: g.ped ? { ...g.ped } : null,
      vehicles: (g.vehicles || []).map((v) => ({
        model: v.model || '', label: v.label || '', grade: v.grade || 0, plate: v.plate || '', livery: v.livery ?? '', maxMods: !!v.maxMods,
        extrasOn: ids(v.extras, true), extrasOff: ids(v.extras, false), c1: v.colours ? v.colours[0] : '', c2: v.colours ? v.colours[1] : '',
        mods: v.mods || null, fuel: v.fuel ?? null,
      })),
    };
  }

  function strip(d) {
    return {
      label: d.label, type: d.type, category: d.category, group: d.group || null, requireDuty: !!d.requireDuty, blip: d.blip !== false, setupMenu: !!d.setupMenu,
      center: d.center, radius: Number(d.radius), spawns: d.spawns, ped: d.ped,
      vehicles: (d.type === 'job' || d.type === 'gang') ? d.vehicles.map((v) => {
        const extras = [...parseIds(v.extrasOn).map((id) => ({ id, on: true })), ...parseIds(v.extrasOff).map((id) => ({ id, on: false }))];
        return {
          model: v.model.trim().toLowerCase(), label: v.label.trim() || null, grade: Number(v.grade) || 0, plate: v.plate.trim().toUpperCase() || null,
          livery: v.livery === '' || v.livery === null ? null : Number(v.livery), maxMods: !!v.maxMods, extras: extras.length ? extras : null,
          colours: v.c1 === '' || v.c1 === null ? null : [Number(v.c1), v.c2 === '' || v.c2 === null ? Number(v.c1) : Number(v.c2)],
          mods: v.mods, fuel: v.fuel,
        };
      }) : [],
    };
  }

  function edit(g) {
    draft = toDraft(g);
    original = JSON.stringify(strip(draft));
    isNew = false;
    idTouched = true;
    checks = {};
  }

  function slug(s) {
    return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 40);
  }

  function create() {
    const me = data.me || { x: 0, y: 0, z: 0, w: 0 };
    draft = {
      id: '', label: 'New garage', type: 'public', category: 'car', group: null, requireDuty: false, blip: true, setupMenu: false,
      center: { x: me.x, y: me.y, z: me.z }, radius: data.radius || 18, spawns: [], ped: null, vehicles: [], source: 'built',
    };
    original = '';
    isNew = true;
    idTouched = false;
    checks = {};
  }

  $effect(() => {
    if (draft && isNew && !idTouched) draft.id = slug(draft.label);
  });

  $effect(() => {
    if (!isGame) return;
    const d = draft;
    post('builder:preview', d ? { center: d.center, radius: Number(d.radius) || 0, spawns: d.spawns, ped: d.ped } : null);
  });

  function applyPlaced(p) {
    if (!draft || p.cancelled || !p.coords) return;
    const c = p.coords;
    if (p.kind === 'center') draft.center = { x: c.x, y: c.y, z: c.z };
    else if (p.kind === 'spawn') {
      if (Number.isInteger(p.index) && draft.spawns[p.index]) draft.spawns[p.index] = { x: c.x, y: c.y, z: c.z, w: c.w };
      else draft.spawns = [...draft.spawns, { x: c.x, y: c.y, z: c.z, w: c.w }];
    } else if (p.kind === 'ped') draft.ped = { model: draft.ped?.model || pedModel, x: c.x, y: c.y, z: c.z, w: c.w };
  }

  $effect(() => {
    const p = mockPlaced || placed;
    if (!p || p === lastPlaced) return;
    lastPlaced = p;
    untrack(() => applyPlaced(p));
  });

  function back() {
    if (dirty) return (confirm = { kind: 'discard' });
    draft = null;
  }

  function place(kind, index) {
    if (kind === 'ped' && draft.ped?.model) pedModel = draft.ped.model;
    if (!isGame) {
      const c = { x: 100 + Math.random() * 20, y: -900 + Math.random() * 20, z: 29.4, w: Math.round(Math.random() * 360) };
      setTimeout(() => (mockPlaced = { kind, index, coords: c }), 50);
      return;
    }
    post('builder:place', { kind, index, radius: Number(draft.radius) || 0 });
  }

  function go(c) {
    if (isGame) post('builder:tp', c);
    else say('Teleported', 'ok');
  }

  function removeSpot(i) {
    draft.spawns = draft.spawns.filter((_, j) => j !== i);
  }

  function addVehicle() {
    draft.vehicles = [...draft.vehicles, { model: '', label: '', grade: 0, plate: draft.vehicles[0]?.plate || '', livery: '', maxMods: false, extrasOn: '', extrasOff: '', c1: '', c2: '', mods: null, fuel: null }];
  }

  function removeVehicle(i) {
    draft.vehicles = draft.vehicles.filter((_, j) => j !== i);
  }

  async function checkModel(i) {
    const m = draft.vehicles[i]?.model.trim().toLowerCase();
    if (!m) return;
    const r = isGame ? await post('builder:model', { model: m }) : { ok: !m.includes('x'), name: m.toUpperCase() };
    checks = { ...checks, [m]: r || { ok: false } };
  }

  async function save() {
    if (busy) return;
    if ((draft.type === 'job' || draft.type === 'gang') && !draft.group) return say(ERRORS.need_group, 'err');
    if (draft.vehicles.some((v) => !v.model.trim())) return say('Every job vehicle needs a model', 'err');
    busy = true;
    const r = await call('builder.save', { id: draft.id, isNew, garage: strip(draft) });
    busy = false;
    if (!r.ok) return say(ERRORS[r.error] || 'Could not save the garage', 'err');
    garages = r.data.garages;
    const fresh = garages.find((g) => g.id === r.data.id);
    if (fresh) edit(fresh);
    say(isNew ? 'Garage created. It is live for everyone now.' : 'Saved. Changes are live for everyone now.', 'ok');
  }

  async function act(action) {
    confirm = null;
    busy = true;
    const r = await call(action, { id: draft.id });
    busy = false;
    if (!r.ok) return say(ERRORS[r.error] || 'That did not work', 'err');
    garages = r.data.garages;
    const fresh = garages.find((g) => g.id === draft.id);
    if (action === 'builder.reset' && fresh) {
      edit(fresh);
      say('Back to the config version', 'ok');
    } else {
      draft = null;
      say(action === 'builder.delete' ? 'Garage removed' : 'Done', 'ok');
    }
  }

  function close() {
    if (draft && dirty) return (confirm = { kind: 'close' });
    onclose?.();
  }

  const fmt = (n) => (Number(n) || 0).toFixed(1);
  const typeIcon = (t) => (TYPES.find((x) => x[0] === t) || TYPES[0])[2];

  $effect(() => {
    const onKey = (e) => {
      if (e.key !== 'Escape' || hidden) return;
      if (document.querySelector('[role="dialog"]')) return;
      if (draft) back();
      else close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });
</script>

<div class="dock" class:gone={hidden}>
  <section class="panel card" aria-label="Garage builder">
    <header class="top">
      <span class="logo"><i class="fa-solid fa-screwdriver-wrench"></i></span>
      <div class="title">
        <h1>Garage builder</h1>
        <p class="sub">{garages.length} garages · changes go live for everyone when you save</p>
      </div>
      <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>

    {#if !draft}
      <div class="listHead">
        <div class="search">
          <i class="fa-solid fa-magnifying-glass"></i>
          <input class="input" placeholder="Search name, ID or job" bind:value={search} />
        </div>
        <button class="btn primary" onclick={create}><i class="fa-solid fa-plus"></i>New garage</button>
      </div>
      <div class="filters">
        {#each [['all', 'All'], ...TYPES.map((t) => [t[0], t[1]])] as [k, t]}
          <button class="pill" class:on={filter === k} onclick={() => (filter = k)}>{t} <span class="num">{counts[k] || 0}</span></button>
        {/each}
      </div>
      <div class="glist scroll">
        {#if !shown.length}
          <div class="empty"><i class="fa-solid fa-warehouse"></i>No garages match</div>
        {/if}
        {#each shown as g (g.id)}
          <button class="grow" class:removed={g.source === 'removed'} onclick={() => edit(g)}>
            <span class="gic t-{g.type}"><i class="fa-solid {typeIcon(g.type)}"></i></span>
            <span class="ginfo">
              <span class="gname">{g.label}</span>
              <span class="gmeta"><span class="num">{g.id}</span>{#if g.group}<span>· {groupLabel(g)}</span>{/if}<span>· {g.spawns.length} {g.spawns.length === 1 ? 'spot' : 'spots'}</span>{#if g.vehicles.length}<span>· {g.vehicles.length} vehicles</span>{/if}</span>
            </span>
            <span class="chip {SOURCE[g.source][1]}">{SOURCE[g.source][0]}</span>
            <i class="fa-solid fa-chevron-right chev"></i>
          </button>
        {/each}
      </div>
    {:else}
      <div class="ehead">
        <button class="btn ghost small" onclick={back}><i class="fa-solid fa-arrow-left"></i>All garages</button>
        <span class="chip {SOURCE[draft.source]?.[1] || 'ok'}">{isNew ? 'New' : SOURCE[draft.source]?.[0]}</span>
        {#if dirty}<span class="chip warn"><i class="fa-solid fa-circle"></i>Unsaved</span>{/if}
      </div>

      <div class="editor scroll">
        <div class="box">
          <div class="box-head"><h3><i class="fa-solid fa-warehouse"></i>Garage</h3></div>
          <div class="box-body grid">
            <label class="field wide"><span>Name</span><input class="input" maxlength="40" bind:value={draft.label} /></label>
            <label class="field wide"><span>ID</span><input class="input num" maxlength="40" disabled={!isNew} bind:value={draft.id} oninput={() => (idTouched = true)} /></label>
            <div class="field wide">
              <span>Type</span>
              <div class="seg">
                {#each TYPES as [k, t, ic]}
                  <button class:on={draft.type === k} onclick={() => { draft.type = k; if (k === 'impound') draft.category = 'all'; if (k !== 'job' && k !== 'gang') draft.group = null; }}><i class="fa-solid {ic}"></i>{t}</button>
                {/each}
              </div>
            </div>
            <div class="field wide">
              <span>Holds</span>
              <div class="seg">
                {#each CATS as [k, t]}
                  <button class:on={draft.category === k} onclick={() => (draft.category = k)}>{t}</button>
                {/each}
              </div>
            </div>
            {#if draft.type === 'job' || draft.type === 'gang'}
              <label class="field wide">
                <span>{draft.type === 'job' ? 'Job' : 'Gang'}</span>
                <select class="input" bind:value={draft.group}>
                  <option value={null}>Pick a {draft.type}</option>
                  {#each groupList as gr}<option value={gr.name}>{gr.label} ({gr.name})</option>{/each}
                </select>
              </label>
            {/if}
            <div class="toggles wide">
              <label class="tog"><input type="checkbox" bind:checked={draft.blip} /><span class="sw"></span>Show on the map</label>
              {#if draft.type === 'job'}<label class="tog"><input type="checkbox" bind:checked={draft.requireDuty} /><span class="sw"></span>On duty only</label>{/if}
              {#if draft.type === 'job' || draft.type === 'gang'}<label class="tog"><input type="checkbox" bind:checked={draft.setupMenu} /><span class="sw"></span>Livery menu after spawning</label>{/if}
            </div>
            {#if draft.type === 'job'}
              <div class="notice wide"><i class="fa-solid fa-circle-info"></i><span>Job garages only hand out the job vehicles below. Personal cars are kept at public garages.</span></div>
            {/if}
          </div>
        </div>

        <div class="box">
          <div class="box-head">
            <h3><i class="fa-solid fa-bullseye"></i>Area</h3>
            <div class="row">
              <button class="btn small ghost" onclick={() => go(draft.center)}><i class="fa-solid fa-location-arrow"></i>Go there</button>
              <button class="btn small" onclick={() => place('center')}><i class="fa-solid fa-crosshairs"></i>Place centre</button>
            </div>
          </div>
          <div class="box-body">
            <div class="coords num">{fmt(draft.center.x)}, {fmt(draft.center.y)}, {fmt(draft.center.z)}</div>
            <div class="range">
              <span class="k">Radius</span>
              <input type="range" min="3" max="80" step="1" bind:value={draft.radius} />
              <span class="num rv">{Math.round(draft.radius)} m</span>
            </div>
            <p class="hint">Players see the E prompt anywhere inside the amber circle.</p>
          </div>
        </div>

        <div class="box">
          <div class="box-head">
            <h3><i class="fa-solid fa-car-side"></i>Spawn spots <span class="num cnt">{draft.spawns.length}</span></h3>
            <button class="btn small" onclick={() => place('spawn')}><i class="fa-solid fa-plus"></i>Add spot</button>
          </div>
          <div class="box-body">
            {#if !draft.spawns.length}
              <div class="notice warn"><i class="fa-solid fa-triangle-exclamation"></i><span>No spots yet. Vehicles will come out on the nearest road until you add one.</span></div>
            {/if}
            {#each draft.spawns as sp, i}
              <div class="spot">
                <span class="badge num">{i + 1}</span>
                <span class="num sc">{fmt(sp.x)}, {fmt(sp.y)}, {fmt(sp.z)}</span>
                <span class="num head"><i class="fa-solid fa-compass"></i>{Math.round(sp.w || 0)}°</span>
                <button class="btn small icon ghost" title="Go there" onclick={() => go(sp)}><i class="fa-solid fa-location-arrow"></i></button>
                <button class="btn small icon ghost" title="Move it" onclick={() => place('spawn', i)}><i class="fa-solid fa-crosshairs"></i></button>
                <button class="btn small icon ghost del" title="Remove" onclick={() => removeSpot(i)}><i class="fa-solid fa-trash"></i></button>
              </div>
            {/each}
            <p class="hint">Drive or walk to the bay, face the way the vehicle should point, then press E.</p>
          </div>
        </div>

        <div class="box">
          <div class="box-head">
            <h3><i class="fa-solid fa-user-tie"></i>Worker</h3>
            {#if draft.ped}
              <div class="row">
                <button class="btn small ghost" onclick={() => place('ped')}><i class="fa-solid fa-crosshairs"></i>Move</button>
                <button class="btn small ghost del" onclick={() => (draft.ped = null)}><i class="fa-solid fa-trash"></i>Remove</button>
              </div>
            {:else}
              <button class="btn small" onclick={() => place('ped')}><i class="fa-solid fa-plus"></i>Place a worker</button>
            {/if}
          </div>
          <div class="box-body">
            {#if draft.ped}
              <div class="grid">
                <label class="field"><span>Ped model</span><input class="input num" maxlength="40" bind:value={draft.ped.model} /></label>
                <div class="field"><span>Stands at</span><div class="coords num">{fmt(draft.ped.x)}, {fmt(draft.ped.y)} · {Math.round(draft.ped.w || 0)}°</div></div>
              </div>
            {:else}
              <label class="field"><span>Ped model for the worker</span><input class="input num" maxlength="40" bind:value={pedModel} /></label>
              <p class="hint">Optional. Stand where the worker should be, facing the way they should face.</p>
            {/if}
          </div>
        </div>

        {#if draft.type === 'job' || draft.type === 'gang'}
          <div class="box">
            <div class="box-head">
              <h3><i class="fa-solid fa-car-on"></i>{draft.type === 'job' ? 'Job' : 'Gang'} vehicles <span class="num cnt">{draft.vehicles.length}</span></h3>
              <button class="btn small" onclick={addVehicle}><i class="fa-solid fa-plus"></i>Add vehicle</button>
            </div>
            <div class="box-body vlist">
              {#if !draft.vehicles.length}
                <div class="notice"><i class="fa-solid fa-circle-info"></i><span>No vehicles yet. Members will see an empty list here.</span></div>
              {/if}
              {#each draft.vehicles as v, i}
                {@const ck = checks[v.model.trim().toLowerCase()]}
                <div class="veh">
                  <div class="vtop">
                    <span class="badge num">{i + 1}</span>
                    <label class="field"><span>Model</span>
                      <span class="mwrap">
                        <input class="input num" maxlength="40" placeholder="police" bind:value={v.model} onblur={() => checkModel(i)} />
                        {#if ck}<i class="fa-solid {ck.ok ? 'fa-circle-check ok' : 'fa-circle-xmark bad'}" title={ck.ok ? ck.name : 'Not a vehicle model on this server'}></i>{/if}
                      </span>
                    </label>
                    <label class="field"><span>Name in the garage</span><input class="input" maxlength="40" placeholder={ck?.ok ? ck.name : 'Patrol Cruiser'} bind:value={v.label} /></label>
                    <button class="btn small icon ghost del" title="Remove" onclick={() => removeVehicle(i)}><i class="fa-solid fa-trash"></i></button>
                  </div>
                  <div class="vgrid">
                    <label class="field"><span>Lowest rank</span>
                      <select class="input" bind:value={v.grade}>
                        {#if !grades.length}<option value={0}>Any</option>{/if}
                        {#each grades as gr}<option value={gr.level}>{gr.level} · {gr.name}</option>{/each}
                        {#if grades.length && !grades.some((gr) => gr.level === Number(v.grade))}<option value={v.grade}>{v.grade}</option>{/if}
                      </select>
                    </label>
                    <label class="field"><span>Plate start</span><input class="input num" maxlength="8" placeholder="LSPD" bind:value={v.plate} /></label>
                    <label class="field"><span>Livery</span><input class="input num" type="number" min="0" max="100" placeholder="Any" bind:value={v.livery} /></label>
                    <label class="tog sm"><input type="checkbox" bind:checked={v.maxMods} /><span class="sw"></span>Max mods</label>
                  </div>
                  <div class="vgrid">
                    <label class="field"><span>Extras on</span><input class="input num" placeholder="1, 2" bind:value={v.extrasOn} /></label>
                    <label class="field"><span>Extras off</span><input class="input num" placeholder="3" bind:value={v.extrasOff} /></label>
                    <label class="field"><span>Paint</span><input class="input num" type="number" min="0" max="255" placeholder="Main" bind:value={v.c1} /></label>
                    <label class="field"><span>&nbsp;</span><input class="input num" type="number" min="0" max="255" placeholder="Second" bind:value={v.c2} /></label>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <footer class="foot">
        {#if !isNew && draft.source !== 'removed'}
          <button class="btn danger" disabled={busy} onclick={() => (confirm = { kind: 'delete' })}><i class="fa-solid fa-trash"></i>Remove</button>
        {/if}
        {#if draft.source === 'edited' || draft.source === 'removed'}
          <button class="btn ghost" disabled={busy} onclick={() => (confirm = { kind: 'reset' })}><i class="fa-solid fa-rotate-left"></i>{draft.source === 'removed' ? 'Bring back' : 'Reset to config'}</button>
        {/if}
        <span class="grow1"></span>
        <button class="btn primary big" disabled={busy || (!dirty && !isNew)} onclick={save}><i class="fa-solid fa-floppy-disk"></i>{isNew ? 'Create garage' : 'Save'}</button>
      </footer>
    {/if}

    {#if confirm}
      <Modal title={confirm.kind === 'delete' ? 'Remove garage' : confirm.kind === 'reset' ? (draft?.source === 'removed' ? 'Bring it back' : 'Reset to config') : 'Unsaved changes'} icon={confirm.kind === 'delete' ? 'fa-trash' : 'fa-rotate-left'} onclose={() => (confirm = null)} width={400}>
        {#if confirm.kind === 'delete'}
          <p class="msg">Remove <strong>{draft.label}</strong> for everyone? Cars parked there show under Elsewhere and can be moved to another garage.</p>
          <div class="row end"><button class="btn ghost" onclick={() => (confirm = null)}>Keep it</button><button class="btn danger" onclick={() => act('builder.delete')}>Remove</button></div>
        {:else if confirm.kind === 'reset'}
          <p class="msg">{draft.source === 'removed' ? 'Bring this garage back exactly as it is in config.lua?' : 'Throw away the in-game changes and go back to what config.lua says?'}</p>
          <div class="row end"><button class="btn ghost" onclick={() => (confirm = null)}>Cancel</button><button class="btn primary" onclick={() => act('builder.reset')}>{draft.source === 'removed' ? 'Bring back' : 'Reset'}</button></div>
        {:else}
          <p class="msg">You have changes that are not saved yet.</p>
          <div class="row end">
            <button class="btn ghost" onclick={() => (confirm = null)}>Keep editing</button>
            <button class="btn danger" onclick={() => { const k = confirm.kind; confirm = null; if (k === 'close') onclose?.(); else draft = null; }}>Throw them away</button>
          </div>
        {/if}
      </Modal>
    {/if}

    {#if toast}
      <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
    {/if}
  </section>
</div>

<style>
  .dock { position: fixed; top: 16px; right: 16px; bottom: 16px; width: 580px; max-width: calc(100vw - 32px); display: flex; }
  .dock.gone { display: none; }
  .panel { position: relative; flex: 1; display: flex; flex-direction: column; overflow: hidden; min-height: 0; }
  .top { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 36px; height: 36px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 16px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 32px; height: 32px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .listHead { display: flex; gap: 8px; padding: 12px 14px 8px; }
  .search { position: relative; flex: 1; }
  .search i { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--faint); font-size: 12px; }
  .search .input { padding-left: 32px; height: 34px; font-size: 13px; }
  .filters { display: flex; gap: 6px; padding: 0 14px 10px; border-bottom: 1px solid var(--line-2); flex-wrap: wrap; }
  .pill { height: 28px; padding: 0 10px; border-radius: 999px; border: 1px solid var(--line-3); background: transparent; color: var(--muted); font-size: 12px; font-weight: 600; display: inline-flex; gap: 6px; align-items: center; }
  .pill .num { color: var(--faint); font-size: 11px; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent-line); color: var(--accent-2); }
  .pill.on .num { color: var(--accent-2); }
  .glist { flex: 1; min-height: 0; padding: 8px; display: flex; flex-direction: column; gap: 3px; }
  .grow { display: grid; grid-template-columns: 34px 1fr auto 12px; gap: 10px; align-items: center; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; text-align: left; }
  .grow:hover { background: var(--panel); border-color: var(--line-2); }
  .grow.removed { opacity: 0.6; }
  .grow.removed .gname { text-decoration: line-through; }
  .gic { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-3); color: var(--text-2); font-size: 13px; }
  .gic.t-job { background: var(--info-bg); color: var(--info-text); }
  .gic.t-gang { background: var(--danger-bg); color: var(--danger-text); }
  .gic.t-impound { background: rgba(255, 138, 61, 0.12); color: var(--warn-text); }
  .gic.t-public { background: var(--accent-soft); color: var(--accent); }
  .ginfo { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .gname { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .gmeta { display: flex; gap: 5px; font-size: 11px; color: var(--muted); white-space: nowrap; overflow: hidden; }
  .gmeta .num { color: var(--accent-2); }
  .chev { color: var(--faint); font-size: 11px; }
  .ehead { display: flex; align-items: center; gap: 8px; padding: 10px 14px; border-bottom: 1px solid var(--line-2); }
  .ehead .chip.warn i { font-size: 7px; }
  .editor { flex: 1; min-height: 0; padding: 12px 14px; display: flex; flex-direction: column; gap: 12px; }
  .box-head h3 { display: flex; align-items: center; gap: 8px; }
  .box-head h3 i { color: var(--accent); font-size: 12px; }
  .cnt { color: var(--faint); font-size: 11px; font-weight: 500; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .wide { grid-column: 1 / -1; }
  .seg { display: grid; grid-auto-flow: column; grid-auto-columns: 1fr; border: 1px solid var(--line-3); border-radius: var(--radius); overflow: hidden; }
  .seg button { height: 34px; border: 0; border-right: 1px solid var(--line-3); background: var(--bg-2); color: var(--muted); font-size: 12px; font-weight: 600; display: inline-flex; gap: 6px; align-items: center; justify-content: center; }
  .seg button:last-child { border-right: 0; }
  .seg button:hover { color: var(--text); background: var(--panel-2); }
  .seg button.on { background: var(--accent-soft); color: var(--accent-2); box-shadow: inset 0 -2px 0 var(--accent); }
  .seg button i { font-size: 11px; }
  .toggles { display: flex; flex-wrap: wrap; gap: 8px 18px; }
  .tog { display: inline-flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-2); cursor: pointer; }
  .tog input { position: absolute; opacity: 0; pointer-events: none; }
  .sw { width: 32px; height: 18px; border-radius: 999px; background: var(--panel-3); border: 1px solid var(--line-3); position: relative; transition: background 0.15s var(--ease); flex: none; }
  .sw::after { content: ''; position: absolute; top: 2px; left: 2px; width: 12px; height: 12px; border-radius: 50%; background: var(--muted); transition: transform 0.15s var(--ease), background 0.15s var(--ease); }
  .tog input:checked + .sw { background: var(--accent-soft); border-color: var(--accent-line); }
  .tog input:checked + .sw::after { transform: translateX(14px); background: var(--accent); }
  .tog input:focus-visible + .sw { outline: 2px solid var(--accent); outline-offset: 2px; }
  .tog.sm { font-size: 12px; align-self: end; height: 36px; }
  .input:disabled { opacity: 0.55; cursor: not-allowed; }
  .coords { font-size: 13px; color: var(--text-2); padding: 8px 10px; background: var(--bg-2); border: 1px solid var(--line-2); border-radius: var(--radius); }
  .range { display: grid; grid-template-columns: auto 1fr 52px; gap: 12px; align-items: center; margin-top: 12px; }
  .range input { accent-color: var(--accent); }
  .rv { text-align: right; font-size: 13px; }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .hint { color: var(--faint); font-size: 12px; margin-top: 8px; }
  .spot { display: grid; grid-template-columns: 24px 1fr auto auto auto auto; gap: 8px; align-items: center; padding: 6px 8px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); margin-bottom: 6px; }
  .badge { width: 24px; height: 24px; border-radius: 5px; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent-2); font-size: 11px; font-weight: 600; }
  .sc { font-size: 12px; color: var(--text-2); }
  .head { font-size: 12px; color: var(--muted); display: inline-flex; gap: 5px; align-items: center; }
  .head i { font-size: 10px; }
  .del:hover:not(:disabled) { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .row { display: flex; gap: 6px; align-items: center; }
  .row.end { justify-content: flex-end; }
  .vlist { display: flex; flex-direction: column; gap: 10px; }
  .veh { padding: 10px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 10px; }
  .vtop { display: grid; grid-template-columns: 24px 1fr 1.3fr 28px; gap: 10px; align-items: end; }
  .vtop .badge { margin-bottom: 6px; }
  .vtop .del { margin-bottom: 4px; }
  .vgrid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; align-items: end; }
  .field > span { font-size: 11px; }
  .vgrid .input, .vtop .input { height: 32px; font-size: 13px; }
  .mwrap { position: relative; display: block; }
  .mwrap i { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); font-size: 13px; }
  .mwrap .ok { color: var(--ok); }
  .mwrap .bad { color: var(--danger); }
  .foot { display: flex; gap: 8px; align-items: center; padding: 12px 14px; border-top: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.6); }
  .grow1 { flex: 1; }
  .btn.big { height: 40px; padding: 0 20px; font-size: 14px; }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .toast { position: absolute; left: 50%; bottom: 76px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); white-space: nowrap; }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
  input[type='number'] { appearance: textfield; -moz-appearance: textfield; }
  input[type='number']::-webkit-inner-spin-button, input[type='number']::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }
</style>
