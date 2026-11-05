<script>
  import SearchBox from '../../components/SearchBox.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Icon from '../../components/Icon.svelte';
  import { untrack } from 'svelte';
  import { api } from '../../lib/nui.js';
  import { errorText } from '../../lib/lang.js';

  let { action = 'people.search', extra = {}, selected = $bindable(null), placeholder = 'Search by name or citizen ID', blocked = () => null, autofocus = false, minLength = 2, id } = $props();

  let q = $state('');
  let results = $state(null);
  let loading = $state(false);
  let error = $state('');
  let seq = 0;

  async function run(term) {
    const mine = ++seq;
    if (term.length < minLength) {
      results = null;
      loading = false;
      return;
    }
    loading = true;
    error = '';
    const res = await api(action, { ...extra, q: term });
    if (mine !== seq) return;
    loading = false;
    if (!res.ok) {
      error = errorText(res.error);
      results = [];
      return;
    }
    results = res.data || [];
  }

  $effect(() => {
    if (minLength === 0) untrack(() => run(''));
  });

  function choose(p) {
    if (blocked(p)) return;
    selected = p;
  }
</script>

<div class="ps">
  <SearchBox bind:value={q} {placeholder} onsearch={run} {autofocus} {id} />
  <div class="results scroll" role="listbox" aria-label="Results">
    {#if loading && !results}
      <Spinner />
    {:else if error}
      <p class="hint err">{error}</p>
    {:else if results === null}
      <p class="hint">Type at least {minLength} characters to search.</p>
    {:else if !results.length}
      <p class="hint">Nobody matches "{q}".</p>
    {:else}
      {#each results as p (p.cid)}
        {@const why = blocked(p)}
        <button type="button" role="option" class="row" class:on={selected?.cid === p.cid} aria-selected={selected?.cid === p.cid} disabled={!!why} onclick={() => choose(p)}>
          <span class="check" aria-hidden="true">{#if selected?.cid === p.cid}<Icon name="check" size={13} stroke={3} />{/if}</span>
          <span class="who">
            <span class="name">{p.name}</span>
            <span class="sub">{#if p.callsign}<span class="mono">{p.callsign}</span>{' · '}{/if}{p.gradeName ? `${p.gradeName} · ` : ''}{p.jobLabel || 'Unemployed'}</span>
          </span>
          {#if why}<span class="why">{why}</span>{:else}<span class="cid mono">{p.cid}</span>{/if}
        </button>
      {/each}
    {/if}
  </div>
</div>

<style>
  .ps { display: flex; flex-direction: column; gap: 8px; min-width: 0; }
  .results { height: 216px; display: flex; flex-direction: column; gap: 2px; padding: 4px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg); }
  .hint { color: var(--faint); padding: 12px; font-size: 13px; }
  .err { color: var(--danger-text); }
  .row { display: flex; align-items: center; gap: 10px; min-height: 44px; padding: 4px 10px; border: 1px solid transparent; border-radius: var(--radius); background: transparent; text-align: left; color: var(--text); flex: none; }
  .row:hover:not(:disabled) { background: var(--panel); }
  .row.on { background: var(--panel-2); border-color: var(--accent-line); }
  .check { width: 18px; height: 18px; border-radius: 4px; border: 1px solid var(--line-3); display: flex; align-items: center; justify-content: center; flex: none; }
  .on .check { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .who { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.25; }
  .name { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cid { color: var(--faint); font-size: 12px; }
  .why { color: var(--faint); font-size: 12px; }
  .row:disabled { opacity: 1; cursor: default; }
  .row:disabled .name { color: var(--muted); }
</style>
