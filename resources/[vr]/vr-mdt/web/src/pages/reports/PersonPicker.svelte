<script>
  import Icon from '../../components/Icon.svelte';
  import { api } from '../../lib/nui.js';

  let { source = 'people', placeholder = 'Search by name or citizen ID', onpick, onfree = null, exclude = [], id, disabled = false, up = false } = $props();

  let q = $state('');
  let open = $state(false);
  let results = $state([]);
  let loading = $state(false);
  let active = $state(0);
  let timer;
  let seq = 0;
  let root;
  const listId = `pp-${Math.random().toString(36).slice(2, 9)}`;

  const staff = $derived(source === 'staff');
  const shown = $derived(results.filter((p) => !exclude.includes(p.cid)).slice(0, 12));
  const free = $derived(onfree && q.trim().length >= 2 ? q.trim() : '');
  const count = $derived(shown.length + (free ? 1 : 0));

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api(staff ? 'people.staff' : 'people.search', staff ? { q: term } : { q: term, limit: 15 });
    if (mine !== seq) return;
    loading = false;
    results = res.ok ? res.data || [] : [];
    active = 0;
  }

  function input() {
    clearTimeout(timer);
    open = true;
    const term = q.trim();
    if (!staff && term.length < 2) {
      results = [];
      loading = false;
      return;
    }
    timer = setTimeout(() => run(term), 220);
  }

  function focus() {
    open = true;
    if (staff && !results.length) run(q.trim());
  }

  function choose(i) {
    if (i < shown.length) onpick?.(shown[i]);
    else if (free) onfree?.(free);
    q = '';
    results = staff ? results : [];
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
  <label class="box" class:disabled>
    <Icon name={staff ? 'shield' : 'userplus'} size={15} />
    <span class="sr-only">{placeholder}</span>
    <input {id} bind:value={q} {placeholder} {disabled} oninput={input} onfocus={focus} onkeydown={key} spellcheck="false" autocomplete="off" role="combobox" aria-expanded={open} aria-controls={listId} />
    {#if loading}<span class="spin" aria-hidden="true"></span>{/if}
  </label>
  {#if open && (count || loading || (!staff && q.trim().length >= 2))}
    <div class="drop scroll" class:up role="listbox" id={listId}>
      {#each shown as p, i (p.cid)}
        <button type="button" role="option" class="opt" class:on={i === active} aria-selected={i === active} onmouseenter={() => (active = i)} onclick={() => choose(i)}>
          {#if staff}
            <span class="cs mono">{p.callsign || '—'}</span>
            <span class="nm">{p.name}</span>
            <span class="aside">{p.gradeName || ''}{p.onduty ? ' · on duty' : ''}</span>
          {:else}
            <span class="nm">{p.name}</span>
            <span class="aside mono">{p.dob || ''}</span>
            <span class="cid mono">{p.cid}</span>
          {/if}
        </button>
      {/each}
      {#if free}
        <button type="button" role="option" class="opt free" class:on={active === shown.length} aria-selected={active === shown.length} onmouseenter={() => (active = shown.length)} onclick={() => choose(shown.length)}>
          <Icon name="plus" size={14} />
          <span class="nm">Add "{free}" without a record</span>
        </button>
      {/if}
      {#if !count && !loading}
        <p class="none">No matches.</p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .picker { position: relative; min-width: 0; }
  .box { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .box:focus-within { border-color: var(--accent); }
  .disabled { opacity: 0.55; }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .drop { position: absolute; left: 0; right: 0; top: 40px; max-height: 280px; padding: 4px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--bg-2); box-shadow: var(--shadow); z-index: 40; display: flex; flex-direction: column; gap: 2px; }
  .drop.up { top: auto; bottom: 40px; }
  .opt { display: flex; align-items: center; gap: 10px; min-height: 34px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .opt.on { background: var(--panel-2); color: var(--text); }
  .nm { flex: 1; min-width: 0; color: var(--text); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cs { width: 96px; flex: none; color: var(--p3-text); font-size: 13px; }
  .aside { color: var(--muted); font-size: 12px; white-space: nowrap; }
  .cid { color: var(--faint); font-size: 12px; }
  .free { color: var(--accent); }
  .free .nm { color: var(--accent); font-weight: 500; }
  .none { padding: 10px; color: var(--muted); font-size: 13px; }
</style>
