<script>
  import Icon from '../../components/Icon.svelte';
  import { api } from '../../lib/nui.js';
  import { plateOk } from './util.js';

  let { onpick, exclude = [], id } = $props();

  let q = $state('');
  let open = $state(false);
  let results = $state([]);
  let loading = $state(false);
  let active = $state(0);
  let timer;
  let seq = 0;
  let root;
  const listId = `vp-${Math.random().toString(36).slice(2, 9)}`;

  const shown = $derived(results.filter((v) => !exclude.includes(v.plate)).slice(0, 10));
  const free = $derived.by(() => {
    const p = plateOk(q);
    if (!p || exclude.includes(p) || shown.some((v) => v.plate === p)) return '';
    return p;
  });
  const count = $derived(shown.length + (free ? 1 : 0));

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('vehicles.search', { q: term });
    if (mine !== seq) return;
    loading = false;
    results = res.ok && Array.isArray(res.data) ? res.data : [];
    active = 0;
  }

  function input() {
    clearTimeout(timer);
    open = true;
    const term = q.trim();
    if (term.length < 2) {
      results = [];
      loading = false;
      return;
    }
    timer = setTimeout(() => run(term), 220);
  }

  function choose(i) {
    if (i < shown.length) {
      const v = shown[i];
      onpick?.({ plate: v.plate, label: v.label || v.model || '', note: v.owner ? `Registered to ${v.owner}` : '' });
    } else if (free) {
      onpick?.({ plate: free, label: '', note: '' });
    }
    q = '';
    results = [];
    open = false;
  }

  function key(e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      active = Math.min(active + 1, Math.max(count - 1, 0));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      active = Math.max(active - 1, 0);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (count) choose(active);
    } else if (e.key === 'Escape' && open) {
      e.stopPropagation();
      open = false;
    }
  }

  function outside(e) {
    if (open && root && !root.contains(e.target)) open = false;
  }
</script>

<svelte:window onmousedown={outside} />

<div class="picker" bind:this={root}>
  <label class="box">
    <Icon name="car" size={15} />
    <span class="sr-only">Search plate or model</span>
    <input {id} bind:value={q} placeholder="Plate or model" maxlength="24" oninput={input} onfocus={() => (open = true)} onkeydown={key} spellcheck="false" autocomplete="off" role="combobox" aria-expanded={open} aria-controls={listId} />
    {#if loading}<span class="spin" aria-hidden="true"></span>{/if}
  </label>
  {#if open && q.trim().length >= 2}
    <div class="drop scroll" role="listbox" id={listId}>
      {#each shown as v, i (v.plate)}
        <button type="button" role="option" class="opt" class:on={i === active} aria-selected={i === active} onmouseenter={() => (active = i)} onclick={() => choose(i)}>
          <span class="pl mono">{v.plate}</span>
          <span class="nm">{v.label || v.model}</span>
          <span class="aside">{v.owner || 'Unregistered'}</span>
        </button>
      {/each}
      {#if free}
        <button type="button" role="option" class="opt free" class:on={active === shown.length} aria-selected={active === shown.length} onmouseenter={() => (active = shown.length)} onclick={() => choose(shown.length)}>
          <Icon name="plus" size={14} />
          <span class="nm">Add plate <span class="mono">{free}</span></span>
        </button>
      {/if}
      {#if !count && !loading}<p class="none">No vehicles match. Plates are up to 8 letters and numbers.</p>{/if}
    </div>
  {/if}
</div>

<style>
  .picker { position: relative; min-width: 0; }
  .box { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .box:focus-within { border-color: var(--accent); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .drop { position: absolute; left: 0; right: 0; top: 40px; max-height: 260px; padding: 4px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--bg-2); box-shadow: var(--shadow); z-index: 40; display: flex; flex-direction: column; gap: 2px; }
  .opt { display: flex; align-items: center; gap: 10px; min-height: 34px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .opt.on { background: var(--panel-2); color: var(--text); }
  .pl { width: 84px; flex: none; color: var(--accent); font-weight: 600; }
  .nm { flex: 1; min-width: 0; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aside { color: var(--muted); font-size: 12px; white-space: nowrap; }
  .free, .free .nm { color: var(--accent); }
  .none { padding: 10px; color: var(--muted); font-size: 13px; }
</style>
