<script>
  import Icon from '../../components/Icon.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import { api } from '../../lib/nui.js';

  let { value = $bindable(null), id, placeholder = 'Search by name or citizen ID', allowFree = false, freeHint = 'Not in records', disabled = false } = $props();

  let q = $state('');
  let results = $state([]);
  let searched = $state(false);
  let loading = $state(false);
  let timer;
  let seq = 0;

  function input() {
    clearTimeout(timer);
    const term = q.trim();
    if (term.length < 2) {
      results = [];
      searched = false;
      return;
    }
    timer = setTimeout(() => run(term), 250);
  }

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('people.search', { q: term });
    if (mine !== seq) return;
    loading = false;
    searched = true;
    results = res.ok ? res.data : [];
  }

  function pick(p) {
    value = { cid: p.cid, name: p.name };
    reset();
  }

  function useFree() {
    const name = q.trim();
    if (name.length < 2) return;
    value = { name };
    reset();
  }

  function reset() {
    q = '';
    results = [];
    searched = false;
  }

  function key(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (results.length) pick(results[0]);
      else if (allowFree) useFree();
    }
  }
</script>

<div class="picker">
  {#if value}
    <div class="chosen">
      <span class="ico"><Icon name="person" size={15} /></span>
      <span class="name">{value.name}</span>
      {#if value.cid}<span class="cid mono">{value.cid}</span>{:else}<span class="free">{freeHint}</span>{/if}
      {#if !disabled}<IconButton icon="x" label="Clear {value.name}" size={26} onclick={() => (value = null)} />{/if}
    </div>
  {:else}
    <label class="box">
      <Icon name="search" size={15} />
      <span class="sr-only">{placeholder}</span>
      <input {id} bind:value={q} {placeholder} oninput={input} onkeydown={key} {disabled} spellcheck="false" autocomplete="off" />
      {#if loading}<span class="spin" aria-hidden="true"></span>{/if}
    </label>
    {#if searched || (allowFree && q.trim().length >= 2)}
      <div class="results scroll" role="listbox" aria-label="Matching people">
        {#each results as p (p.cid)}
          <button type="button" class="row" role="option" aria-selected="false" onclick={() => pick(p)}>
            <span class="name">{p.name}</span>
            <span class="aside mono">{p.dob || ''}</span>
            <span class="aside mono">{p.cid}</span>
          </button>
        {:else}
          {#if searched}<span class="none">No one matches "{q.trim()}"</span>{/if}
        {/each}
        {#if allowFree && q.trim().length >= 2}
          <button type="button" class="row free-row" onclick={useFree}>
            <Icon name="plus" size={14} />
            <span>Use "{q.trim()}" as a name</span>
            <span class="aside">{freeHint}</span>
          </button>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<style>
  .picker { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .box { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .box:focus-within { border-color: var(--accent); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .chosen { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 4px 0 10px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); min-width: 0; }
  .ico { color: var(--accent); display: flex; }
  .chosen .name { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cid { color: var(--muted); font-size: 12px; }
  .free { color: var(--faint); font-size: 12px; }
  .chosen :global(.ib) { margin-left: auto; }
  .results { max-height: 168px; display: flex; flex-direction: column; gap: 2px; padding: 4px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg); }
  .row { display: flex; align-items: center; gap: 10px; min-height: 32px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .row:hover, .row:focus-visible { background: var(--panel-2); color: var(--text); }
  .row .name { color: var(--text); font-weight: 600; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aside { color: var(--muted); font-size: 12px; }
  .free-row { color: var(--accent); }
  .free-row span:first-of-type { flex: 1; }
  .none { padding: 8px 10px; color: var(--faint); font-size: 13px; }
</style>
