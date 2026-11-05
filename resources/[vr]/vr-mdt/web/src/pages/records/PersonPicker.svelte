<script>
  import Icon from '../../components/Icon.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import { api } from '../../lib/nui.js';

  let { value = $bindable(null), id, placeholder = 'Search by name or citizen ID' } = $props();

  let q = $state('');
  let results = $state([]);
  let open = $state(false);
  let loading = $state(false);
  let timer;
  let seq = 0;

  function input() {
    clearTimeout(timer);
    const term = q.trim();
    if (term.length < 2) {
      results = [];
      open = false;
      return;
    }
    timer = setTimeout(() => run(term), 250);
  }

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('people.search', { q: term, limit: 8 });
    if (mine !== seq) return;
    loading = false;
    results = res.ok ? res.data : [];
    open = true;
  }

  function pick(p) {
    value = { cid: p.cid, name: p.name, dob: p.dob };
    q = '';
    results = [];
    open = false;
  }

  function outside(e) {
    if (open && !e.target.closest('.picker')) open = false;
  }
</script>

<svelte:window onmousedown={outside} />

<div class="picker">
  {#if value}
    <div class="chosen">
      <Icon name="person" size={15} />
      <span class="nm">{value.name}</span>
      <span class="mono faint">{value.cid}</span>
      <IconButton icon="x" label="Clear {value.name}" size={26} onclick={() => (value = null)} />
    </div>
  {:else}
    <label class="box">
      <Icon name="search" size={15} />
      <span class="sr-only">{placeholder}</span>
      <input {id} bind:value={q} {placeholder} oninput={input} spellcheck="false" autocomplete="off" />
      {#if loading}<span class="spin" aria-hidden="true"></span>{/if}
    </label>
    {#if open}
      <div class="drop scroll" role="listbox">
        {#each results as p (p.cid)}
          <button type="button" class="opt" role="option" aria-selected="false" onclick={() => pick(p)}>
            <span class="nm">{p.name}</span>
            <span class="mono faint">{p.dob || ''}</span>
            <span class="mono cid">{p.cid}</span>
          </button>
        {:else}
          <p class="none">Nobody matches "{q}"</p>
        {/each}
      </div>
    {/if}
  {/if}
</div>

<style>
  .picker { position: relative; }
  .box, .chosen { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .chosen { padding-right: 4px; color: var(--accent); }
  .box:focus-within { border-color: var(--accent); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .nm { color: var(--text); font-weight: 600; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .drop { position: absolute; left: 0; right: 0; top: 40px; max-height: 240px; padding: 4px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--panel); box-shadow: var(--shadow); z-index: 5; display: flex; flex-direction: column; gap: 2px; }
  .opt { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; text-align: left; flex: none; }
  .opt:hover { background: var(--panel-2); }
  .cid { color: var(--text-2); font-size: 12px; }
  .none { padding: 10px; color: var(--muted); }
</style>
