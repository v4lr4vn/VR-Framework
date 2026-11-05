<script>
  import Icon from '../components/Icon.svelte';
  import { api } from '../lib/nui.js';
  import { go, can, session } from '../lib/state.svelte.js';

  let q = $state('');
  let open = $state(false);
  let results = $state(null);
  let loading = $state(false);
  let timer;
  let seq = 0;

  const enabled = $derived(can('records.view') || can('patients.view'));
  const placeholder = $derived(session.dept?.id === 'ems' ? 'Search patients by name' : 'Search name, plate, serial or report number');

  function input() {
    clearTimeout(timer);
    const term = q.trim();
    if (term.length < 2) {
      results = null;
      return;
    }
    timer = setTimeout(() => run(term), 250);
  }

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('search.global', { q: term });
    if (mine !== seq) return;
    loading = false;
    results = res.ok ? res.data : { citizens: [], vehicles: [], weapons: [], reports: [] };
    open = true;
  }

  function pick(page, params) {
    open = false;
    q = '';
    results = null;
    go(page, params);
  }

  function key(e) {
    if (e.key === 'Escape' && open) {
      e.stopPropagation();
      open = false;
    }
  }

  function outside(e) {
    if (open && !e.target.closest('.gsearch')) open = false;
  }

  const empty = $derived(results && !['citizens', 'vehicles', 'weapons', 'reports'].some((k) => results[k]?.length));
</script>

<svelte:window onmousedown={outside} />

{#if enabled}
  <div class="gsearch">
    <label class="box">
      <Icon name="search" size={16} />
      <span class="sr-only">{placeholder}</span>
      <input bind:value={q} {placeholder} oninput={input} onfocus={() => results && (open = true)} onkeydown={key} spellcheck="false" autocomplete="off" />
      {#if loading}<span class="spin" aria-hidden="true"></span>{/if}
    </label>
    {#if open && results}
      <div class="drop scroll" role="listbox">
        {#if empty}
          <p class="none">No matches for "{q}"</p>
        {/if}
        {#if results.citizens?.length}
          <span class="eyebrow h">{session.dept?.id === 'ems' ? 'Patients' : 'Citizens'}</span>
          {#each results.citizens as c}
            <button type="button" class="row" onclick={() => pick(session.dept?.id === 'ems' ? 'patients' : 'citizens', { cid: c.cid })}>
              <Icon name="person" size={15} /><span class="main">{c.name}</span><span class="aside mono">{c.dob || c.cid}</span>
            </button>
          {/each}
        {/if}
        {#if results.vehicles?.length}
          <span class="eyebrow h">Vehicles</span>
          {#each results.vehicles as v}
            <button type="button" class="row" onclick={() => pick('vehicles', { plate: v.plate })}>
              <Icon name="car" size={15} /><span class="main mono">{v.plate}</span><span class="aside">{v.label || v.model} · {v.owner || 'Unregistered'}</span>
            </button>
          {/each}
        {/if}
        {#if results.weapons?.length}
          <span class="eyebrow h">Weapons</span>
          {#each results.weapons as w}
            <button type="button" class="row" onclick={() => pick('weapons', { serial: w.serial })}>
              <Icon name="crosshair" size={15} /><span class="main mono">{w.serial}</span><span class="aside">{w.label} · {w.owner || 'Unknown'}</span>
            </button>
          {/each}
        {/if}
        {#if results.reports?.length}
          <span class="eyebrow h">Reports</span>
          {#each results.reports as r}
            <button type="button" class="row" onclick={() => pick('reports', { id: r.id })}>
              <Icon name="report" size={15} /><span class="main">{r.title}</span><span class="aside mono">#{r.id}</span>
            </button>
          {/each}
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .gsearch { position: relative; flex: 1; max-width: 520px; }
  .box { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius); color: var(--muted); }
  .box:focus-within { border-color: var(--accent); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .drop { position: absolute; left: 0; right: 0; top: 42px; max-height: 460px; padding: 6px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--bg-2); box-shadow: var(--shadow); z-index: 45; display: flex; flex-direction: column; gap: 2px; }
  .h { padding: 8px 10px 4px; }
  .row { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .row:hover { background: var(--panel-2); color: var(--text); }
  .main { color: var(--text); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aside { margin-left: auto; color: var(--muted); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 55%; }
  .none { padding: 14px 10px; color: var(--muted); }
</style>
