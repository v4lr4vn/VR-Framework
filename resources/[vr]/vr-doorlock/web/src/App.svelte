<script>
  import { onMount } from 'svelte';
  import { post } from './lib/nui.js';
  import { play } from './lib/sound.js';
  import Toggle from './ui/Toggle.svelte';

  let open = $state(false);
  let doors = $state([]);
  let sounds = $state([]);
  let defaults = $state({});
  let query = $state('');
  let selected = $state(null);
  let form = $state(null);
  let confirmDelete = $state(false);
  let saved = $state(false);

  const filtered = $derived.by(() => {
    const q = query.trim().toLowerCase();
    const list = [...doors].sort((a, b) => (a.distance ?? 1e9) - (b.distance ?? 1e9) || a.id - b.id);
    if (!q) return list;
    return list.filter((d) => String(d.id) === q || (d.name || '').toLowerCase().includes(q) || (d.zone || '').toLowerCase().includes(q));
  });

  const blank = () => ({
    id: null,
    name: '',
    maxDistance: 2,
    autolock: '',
    doorRate: '',
    passcode: '',
    hasPasscode: false,
    clearPasscode: false,
    locked: true,
    double: false,
    auto: false,
    lockpick: false,
    hideUi: false,
    holdOpen: false,
    lockSound: defaults.lockSound || sounds[0] || '',
    unlockSound: defaults.unlockSound || sounds[1] || '',
    groups: [],
    characters: [],
    items: [],
    lockpickDifficulty: [],
    source: null,
  });

  const fromDoor = (d) => ({
    id: d.id,
    name: d.name || '',
    maxDistance: d.maxDistance ?? 2,
    autolock: d.autolock ?? '',
    doorRate: d.doorRate ?? '',
    passcode: '',
    hasPasscode: d.passcode === true,
    clearPasscode: false,
    locked: d.state !== 0,
    double: !!d.double,
    auto: !!d.auto,
    lockpick: !!d.lockpick,
    hideUi: !!d.hideUi,
    holdOpen: !!d.holdOpen,
    lockSound: d.lockSound || defaults.lockSound || '',
    unlockSound: d.unlockSound || defaults.unlockSound || '',
    groups: Object.entries(d.groups || {}).map(([name, grade]) => ({ name, grade })),
    characters: [...(d.characters || [])],
    items: (d.items || []).map((it) => (typeof it === 'string' ? { name: it, remove: false } : { name: it.name, remove: !!it.remove, metadata: it.metadata })),
    lockpickDifficulty: [...(d.lockpickDifficulty || [])],
    source: d,
  });

  const select = (d) => {
    selected = d ? d.id : null;
    form = d ? fromDoor(d) : blank();
    confirmDelete = false;
    saved = false;
  };

  const num = (v) => (v === '' || v === null || v === undefined || isNaN(Number(v)) ? null : Number(v));

  const payload = () => {
    const f = form;
    const out = {
      id: f.id || undefined,
      name: f.name.trim() || undefined,
      maxDistance: num(f.maxDistance) ?? 2,
      autolock: num(f.autolock) || undefined,
      doorRate: num(f.doorRate) ?? undefined,
      state: f.locked ? 1 : 0,
      auto: f.auto || undefined,
      lockpick: f.lockpick || undefined,
      hideUi: f.hideUi || undefined,
      holdOpen: f.holdOpen || undefined,
      lockSound: f.lockSound || undefined,
      unlockSound: f.unlockSound || undefined,
      groups: Object.fromEntries(f.groups.filter((g) => g.name.trim()).map((g) => [g.name.trim(), Math.max(0, Math.floor(Number(g.grade) || 0))])),
      characters: f.characters.map((c) => c.trim()).filter(Boolean),
      items: f.items.filter((i) => i.name.trim()).map((i) => ({ name: i.name.trim(), remove: !!i.remove, metadata: i.metadata })),
      lockpickDifficulty: f.lockpick ? f.lockpickDifficulty : [],
    };
    if (f.passcode) out.passcode = f.passcode;
    else if (f.hasPasscode && !f.clearPasscode) out.passcode = true;
    if (f.source) {
      if (f.source.doors) out.doors = f.source.doors;
      else {
        out.coords = f.source.coords;
        out.model = f.source.model;
        out.heading = f.source.heading;
      }
    } else {
      out.double = f.double;
    }
    return out;
  };

  const save = () => {
    if (!form) return;
    post('save', payload());
    if (form.id) {
      saved = true;
      setTimeout(() => (saved = false), 1400);
    }
  };

  const remove = () => {
    if (!form?.id) return;
    if (!confirmDelete) {
      confirmDelete = true;
      return;
    }
    post('delete', { id: form.id });
    confirmDelete = false;
  };

  const close = () => post('close');

  const onMessage = (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object') return;
    const { action, data } = msg;
    if (action === 'playSound') play(data?.sound, data?.volume);
    else if (action === 'editor:open') {
      doors = Array.isArray(data?.doors) ? data.doors : [];
      sounds = data?.sounds || [];
      defaults = data?.defaults || {};
      query = '';
      open = true;
      const pick = data?.selected ? doors.find((d) => d.id === data.selected) : null;
      select(pick || doors[0] || null);
    } else if (action === 'editor:close') {
      open = false;
    } else if (action === 'door:update' && data) {
      const i = doors.findIndex((d) => d.id === data.id);
      if (i >= 0) doors[i] = { ...doors[i], ...data };
      else doors = [...doors, data];
      if (selected === data.id && !saved) form = fromDoor(doors.find((d) => d.id === data.id));
    } else if (action === 'door:remove') {
      doors = doors.filter((d) => d.id !== data);
      if (selected === data) select(doors[0] || null);
    }
  };

  const onKey = (e) => {
    if (!open) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      close();
    }
  };

  onMount(() => {
    window.addEventListener('message', onMessage);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('keydown', onKey);
    };
  });
</script>

{#if open}
  <div class="backdrop">
    <section class="panel">
      <header>
        <div class="title">
          <span class="pill"><i class="fa-solid fa-door-closed"></i></span>
          <h1>Door locks</h1>
          <span class="count">{doors.length} {doors.length === 1 ? 'door' : 'doors'}</span>
        </div>
        <div class="actions">
          <button class="btn primary" onclick={() => select(null)}><i class="fa-solid fa-plus"></i> New door</button>
          <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
        </div>
      </header>

      <div class="body">
        <aside class="list">
          <div class="search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input bind:value={query} placeholder="Search name, zone or #id" spellcheck="false" />
          </div>
          <div class="rows scroll">
            {#each filtered as d (d.id)}
              <button class="row" class:sel={selected === d.id} onclick={() => select(d)}>
                <span class="lock" class:open={d.state === 0}><i class="fa-solid {d.state === 0 ? 'fa-lock-open' : 'fa-lock'}"></i></span>
                <span class="meta">
                  <span class="name">{d.name || `Door ${d.id}`}</span>
                  <span class="sub mono">#{d.id}{d.zone ? ` · ${d.zone}` : ''}{d.double ? ' · double' : ''}</span>
                </span>
                {#if d.distance !== undefined && d.distance !== null}<span class="dist mono">{d.distance < 1000 ? `${d.distance}m` : '—'}</span>{/if}
              </button>
            {:else}
              <div class="empty">{query ? 'No doors match.' : 'No doors yet. Create one with New door.'}</div>
            {/each}
          </div>
        </aside>

        {#if form}
          <main class="form scroll">
            <div class="fhead">
              <div>
                <span class="eyebrow">{form.id ? `Door #${form.id}` : 'New door'}</span>
                <h2>{form.name || (form.id ? `Door ${form.id}` : 'Untitled door')}</h2>
              </div>
              <div class="factions">
                {#if form.id}
                  <button class="btn ghost" onclick={() => post('teleport', { id: form.id })}><i class="fa-solid fa-location-arrow"></i> Teleport</button>
                  <button class="btn danger" onclick={remove}><i class="fa-solid fa-trash"></i> {confirmDelete ? 'Confirm delete' : 'Delete'}</button>
                {/if}
                <button class="btn primary" onclick={save}>
                  {#if saved}<i class="fa-solid fa-check"></i> Saved{:else if form.id}Save changes{:else}<i class="fa-solid fa-crosshairs"></i> Save & pick door{/if}
                </button>
              </div>
            </div>

            {#if !form.id}
              <div class="note"><i class="fa-solid fa-circle-info"></i> After saving, aim at the door{form.double ? 's' : ''} in the world and press <kbd>LMB</kbd>. <kbd>RMB</kbd> cancels.</div>
            {/if}

            <section>
              <h3>General</h3>
              <div class="grid">
                <label class="field wide"><span>Name</span><input bind:value={form.name} placeholder="mrpd_front_door" maxlength="50" spellcheck="false" /></label>
                <label class="field"><span>Interact distance</span><input class="mono" type="number" min="0.5" max="20" step="0.5" bind:value={form.maxDistance} /></label>
                <label class="field"><span>Auto-lock after (s)</span><input class="mono" type="number" min="0" step="1" bind:value={form.autolock} placeholder="Off" /></label>
                <label class="field"><span>Door rate</span><input class="mono" type="number" min="0" max="10" step="0.1" bind:value={form.doorRate} placeholder="Default" /></label>
                <label class="field">
                  <span>Passcode</span>
                  <div class="inline">
                    <input type="password" bind:value={form.passcode} placeholder={form.hasPasscode && !form.clearPasscode ? '•••• unchanged' : 'None'} autocomplete="off" />
                    {#if form.hasPasscode}<button class="mini" class:on={form.clearPasscode} onclick={() => (form.clearPasscode = !form.clearPasscode)}>{form.clearPasscode ? 'Removed' : 'Remove'}</button>{/if}
                  </div>
                </label>
              </div>
            </section>

            <section>
              <h3>Behaviour</h3>
              <div class="toggles">
                <Toggle bind:checked={form.locked} label="Locked" hint="State when the server starts" />
                <Toggle bind:checked={form.double} label="Double door" hint="Pick two door halves" disabled={!!form.id} />
                <Toggle bind:checked={form.auto} label="Automatic" hint="Opens by itself when unlocked" />
                <Toggle bind:checked={form.lockpick} label="Lockpickable" hint="Can be picked with a lockpick" />
                <Toggle bind:checked={form.holdOpen} label="Hold open" hint="Stays open while unlocked" />
                <Toggle bind:checked={form.hideUi} label="Hide icon" hint="No lock icon on this door" />
              </div>
            </section>

            <section>
              <h3>Sounds</h3>
              <div class="grid">
                <label class="field">
                  <span>Lock sound</span>
                  <div class="inline">
                    <select bind:value={form.lockSound}>{#each sounds as s}<option value={s}>{s}</option>{/each}</select>
                    <button class="mini" onclick={() => play(form.lockSound, 0.8)} aria-label="Play"><i class="fa-solid fa-play"></i></button>
                  </div>
                </label>
                <label class="field">
                  <span>Unlock sound</span>
                  <div class="inline">
                    <select bind:value={form.unlockSound}>{#each sounds as s}<option value={s}>{s}</option>{/each}</select>
                    <button class="mini" onclick={() => play(form.unlockSound, 0.8)} aria-label="Play"><i class="fa-solid fa-play"></i></button>
                  </div>
                </label>
              </div>
            </section>

            <section>
              <h3>Access <small>Anyone matching one of these can use the door</small></h3>
              <div class="block">
                <div class="bhead"><span>Jobs & gangs</span><button class="mini" onclick={() => (form.groups = [...form.groups, { name: '', grade: 0 }])}><i class="fa-solid fa-plus"></i> Add</button></div>
                {#each form.groups as g, i}
                  <div class="pair">
                    <input bind:value={g.name} placeholder="police" spellcheck="false" />
                    <label class="grade"><span>Min grade</span><input class="mono" type="number" min="0" bind:value={g.grade} /></label>
                    <button class="mini del" onclick={() => (form.groups = form.groups.filter((_, j) => j !== i))} aria-label="Remove"><i class="fa-solid fa-xmark"></i></button>
                  </div>
                {:else}<div class="none">No jobs or gangs.</div>{/each}
              </div>
              <div class="block">
                <div class="bhead"><span>Characters</span><button class="mini" onclick={() => (form.characters = [...form.characters, ''])}><i class="fa-solid fa-plus"></i> Add</button></div>
                {#each form.characters as c, i}
                  <div class="pair">
                    <input class="mono" bind:value={form.characters[i]} placeholder="Citizen ID" spellcheck="false" />
                    <button class="mini del" onclick={() => (form.characters = form.characters.filter((_, j) => j !== i))} aria-label="Remove"><i class="fa-solid fa-xmark"></i></button>
                  </div>
                {:else}<div class="none">No characters.</div>{/each}
              </div>
              <div class="block">
                <div class="bhead"><span>Items</span><button class="mini" onclick={() => (form.items = [...form.items, { name: '', remove: false }])}><i class="fa-solid fa-plus"></i> Add</button></div>
                {#each form.items as it, i}
                  <div class="pair">
                    <input bind:value={it.name} placeholder="keycard_red" spellcheck="false" />
                    <button class="chip" class:on={it.remove} onclick={() => (it.remove = !it.remove)}>{it.remove ? 'Used up' : 'Kept'}</button>
                    <button class="mini del" onclick={() => (form.items = form.items.filter((_, j) => j !== i))} aria-label="Remove"><i class="fa-solid fa-xmark"></i></button>
                  </div>
                {:else}<div class="none">No items.</div>{/each}
              </div>
            </section>

            {#if form.lockpick}
              <section>
                <h3>Lockpick difficulty <small>One skill check per step</small></h3>
                <div class="steps">
                  {#each form.lockpickDifficulty as step, i}
                    <span class="step {step}">{i + 1}. {step}<button onclick={() => (form.lockpickDifficulty = form.lockpickDifficulty.filter((_, j) => j !== i))} aria-label="Remove"><i class="fa-solid fa-xmark"></i></button></span>
                  {/each}
                  {#each ['easy', 'medium', 'hard'] as lvl}
                    <button class="mini" onclick={() => (form.lockpickDifficulty = [...form.lockpickDifficulty, lvl])}><i class="fa-solid fa-plus"></i> {lvl}</button>
                  {/each}
                  {#if !form.lockpickDifficulty.length}<span class="none">Using the server default.</span>{/if}
                </div>
              </section>
            {/if}
          </main>
        {/if}
      </div>
    </section>
  </div>
{/if}

<style>
  .backdrop { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; background: rgba(4, 6, 10, 0.55); animation: fade 0.15s; }
  .panel { width: min(1080px, calc(100vw - 48px)); height: min(700px, calc(100vh - 48px)); display: flex; flex-direction: column; background: var(--bg); border: 1px solid var(--line-3); border-radius: 10px; box-shadow: var(--shadow); overflow: hidden; animation: up 0.18s var(--ease); }
  header { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 12px 14px 12px 16px; border-bottom: 1px solid var(--line); background: var(--bg-2); position: relative; }
  header::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--accent); }
  .title { display: flex; align-items: center; gap: 10px; }
  .pill { width: 28px; height: 24px; border-radius: 5px; background: var(--accent); color: var(--accent-ink); display: inline-flex; align-items: center; justify-content: center; font-size: 12px; }
  h1 { font-size: 18px; font-weight: 700; margin: 0; }
  .count { font-family: var(--mono); font-size: 12px; color: var(--p2-text); font-weight: 600; }
  .actions { display: flex; gap: 8px; align-items: center; }
  .x { width: 32px; height: 32px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); }
  .x:hover { color: var(--text); border-color: var(--line-3); }

  .btn { display: inline-flex; align-items: center; gap: 8px; height: 34px; padding: 0 14px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); font-weight: 600; font-size: 14px; }
  .btn:hover { background: var(--panel-2); border-color: var(--line-3); }
  .btn.primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 700; }
  .btn.primary:hover { background: var(--accent-2); }
  .btn.ghost { background: transparent; border-color: transparent; color: var(--text-2); }
  .btn.ghost:hover { background: var(--panel-2); color: var(--text); }
  .btn.danger { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }

  .body { flex: 1; min-height: 0; display: grid; grid-template-columns: 330px 1fr; }
  .list { display: flex; flex-direction: column; min-height: 0; border-right: 1px solid var(--line); background: var(--bg-2); }
  .search { display: flex; align-items: center; gap: 8px; margin: 12px; height: 36px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg); color: var(--faint); }
  .search:focus-within { border-color: var(--accent); }
  .search input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); font: inherit; }
  .rows { flex: 1; min-height: 0; padding: 0 8px 10px; display: flex; flex-direction: column; gap: 3px; }
  .row { display: flex; align-items: center; gap: 10px; padding: 8px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text); text-align: left; position: relative; }
  .row:hover { background: var(--panel); }
  .row.sel { background: var(--accent-soft); border-color: var(--accent-line); }
  .row.sel::before { content: ''; position: absolute; left: -1px; top: 8px; bottom: 8px; width: 3px; border-radius: 2px; background: var(--accent); }
  .lock { flex: none; width: 28px; height: 28px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center; background: var(--accent-soft); color: var(--accent-2); border: 1px solid var(--accent-line); font-size: 12px; }
  .lock.open { background: var(--ok-bg); color: var(--ok); border-color: var(--ok-line); }
  .meta { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .name { font-weight: 600; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { font-size: 11px; color: var(--faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .dist { flex: none; font-size: 11px; color: var(--muted); }
  .empty { padding: 20px 12px; color: var(--faint); font-size: 13px; text-align: center; }

  .form { min-height: 0; padding: 16px 20px 24px; display: flex; flex-direction: column; gap: 18px; }
  .fhead { display: flex; align-items: flex-end; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
  .eyebrow { font-family: var(--mono); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; }
  h2 { margin: 2px 0 0; font-size: 20px; font-weight: 700; }
  .factions { display: flex; gap: 8px; }
  .note { padding: 10px 12px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-size: 13px; display: flex; align-items: center; gap: 8px; }
  kbd { display: inline-flex; align-items: center; height: 20px; padding: 0 6px; border-radius: 4px; border: 1px solid var(--line-3); border-bottom-width: 2px; background: var(--panel-2); color: var(--accent-2); font-family: var(--mono); font-size: 11px; }

  section { display: flex; flex-direction: column; gap: 10px; }
  h3 { margin: 0; font-size: 12px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); display: flex; align-items: baseline; gap: 10px; }
  h3 small { text-transform: none; letter-spacing: 0; font-weight: 500; color: var(--faint); font-size: 12px; }
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .field { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .field.wide { grid-column: 1 / -1; }
  .field > span, .grade > span { font-size: 12px; font-weight: 600; color: var(--muted); }
  input, select { height: 36px; width: 100%; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; font: inherit; }
  input:focus, select:focus { border-color: var(--accent); }
  input::placeholder { color: var(--faint); }
  select option { background: var(--panel); }
  .mono { font-family: var(--mono); font-size: 13px; }
  .inline { display: flex; gap: 6px; }
  .mini { flex: none; display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; text-transform: capitalize; }
  .inline .mini { height: 36px; }
  .mini:hover { color: var(--text); border-color: var(--line-3); }
  .mini.on { border-color: var(--danger-line); color: var(--danger-text); background: var(--danger-bg); }
  .mini.del { width: 30px; justify-content: center; padding: 0; }
  .toggles { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
  .block { border: 1px solid var(--line-2); border-radius: var(--radius-lg); padding: 10px; display: flex; flex-direction: column; gap: 8px; background: var(--bg-2); }
  .bhead { display: flex; align-items: center; justify-content: space-between; font-weight: 600; font-size: 14px; }
  .pair { display: flex; gap: 8px; align-items: center; }
  .pair input { height: 32px; }
  .grade { display: flex; align-items: center; gap: 6px; flex: none; }
  .grade input { width: 70px; }
  .chip { flex: none; height: 32px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .chip.on { background: var(--accent-soft); border-color: var(--accent-line); color: var(--accent-2); }
  .none { color: var(--faint); font-size: 13px; }
  .steps { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
  .step { display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 4px 0 10px; border-radius: 14px; font-size: 12px; font-weight: 600; text-transform: capitalize; border: 1px solid var(--line-2); }
  .step button { width: 20px; height: 20px; border-radius: 50%; border: 0; background: transparent; color: inherit; display: inline-flex; align-items: center; justify-content: center; }
  .step.easy { color: var(--ok); border-color: var(--ok-line); background: var(--ok-bg); }
  .step.medium { color: var(--p2-text); border-color: var(--accent-line); background: var(--accent-soft); }
  .step.hard { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }

  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  @keyframes up { from { opacity: 0; translate: 0 10px; } to { opacity: 1; translate: 0 0; } }
</style>
