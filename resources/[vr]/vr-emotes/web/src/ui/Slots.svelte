<script>
  import { em, itemById } from '../lib/state.svelte.js';
  import { post } from '../lib/nui.js';

  let { onhover, onleave } = $props();

  const rows = $derived(Array.from({ length: em.slots }, (_, i) => {
    const id = em.state.slots[i] || null;
    return { n: i + 1, id, item: id ? itemById(id) : null, key: em.state.keys[i] || '' };
  }));

  const setKey = (r) => {
    em.capture = { slot: r.n, label: r.item ? r.item.l : '', current: r.key || null };
  };

  const clear = async (r) => {
    const res = await post('slot', { slot: r.n, id: null });
    if (res && res.state) em.state = res.state;
  };

  const pickSelected = async (r) => {
    if (!em.selected) return;
    const res = await post('slot', { slot: r.n, id: em.selected });
    if (res && res.state) em.state = res.state;
  };
</script>

<div class="wrap scroll" role="list" onmouseleave={() => onleave && onleave()}>
  <p class="intro">Put your favourite emotes on quick slots, then give each slot a key. Pressing the key plays the emote, pressing it again stops it.</p>
  {#each rows as r (r.n)}
    <div class="row" class:empty={!r.item} role="listitem" onmouseenter={() => r.item && onhover && onhover(r.item)}>
      <span class="n mono">{r.n}</span>
      <div class="what">
        {#if r.item}
          <span class="label">{r.item.l}</span>
          <span class="cmd mono">/e {r.item.k}</span>
        {:else}
          <span class="label dim">Empty</span>
          <span class="cmd">Select an emote, then use <b>Quick slot</b> below it</span>
        {/if}
      </div>
      {#if !r.item && em.selected}
        <button class="ghost small" onclick={() => pickSelected(r)}><i class="fa-solid fa-arrow-down"></i>Put selected here</button>
      {/if}
      <button class="key" class:set={!!r.key} onclick={() => setKey(r)} title="Set the key for this slot">
        {#if r.key}<kbd class="mono">{r.key}</kbd>{:else}<span class="mono none">Set key</span>{/if}
      </button>
      <button class="x" onclick={() => clear(r)} disabled={!r.item} aria-label="Remove emote from slot" title="Remove emote"><i class="fa-solid fa-xmark"></i></button>
    </div>
  {/each}
</div>

<style>
  .wrap { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 6px; padding-right: 4px; }
  .intro { color: var(--muted); font-size: 13px; padding: 2px 2px 6px; }
  .row { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: var(--radius-lg); border: 1px solid var(--line); background: var(--panel); }
  .row:hover { border-color: var(--line-3); }
  .row.empty { border-style: dashed; background: transparent; }
  .n { width: 26px; height: 26px; border-radius: 6px; display: flex; align-items: center; justify-content: center; background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-weight: 600; font-size: 13px; flex-shrink: 0; }
  .what { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .label { font-weight: 600; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .label.dim { color: var(--faint); font-weight: 500; }
  .cmd { font-size: 12px; color: var(--faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cmd b { color: var(--text-2); font-weight: 600; }
  button { border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); border-radius: var(--radius); }
  .key { min-width: 96px; height: 36px; padding: 0 10px; display: inline-flex; align-items: center; justify-content: center; border-style: dashed; background: var(--bg-2); }
  .key.set { border-style: solid; }
  .key:hover { border-color: var(--accent); }
  kbd { display: inline-flex; align-items: center; height: 24px; padding: 0 8px; border-radius: 5px; border: 1px solid var(--line-3); border-bottom-width: 2px; background: var(--panel-2); color: var(--accent-2); font-size: 12px; font-weight: 600; }
  .none { color: var(--faint); font-size: 12px; }
  .x { width: 30px; height: 30px; display: inline-flex; align-items: center; justify-content: center; background: transparent; color: var(--muted); }
  .x:hover:not(:disabled) { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .x:disabled { opacity: 0.3; }
  .ghost { background: transparent; }
  .small { height: 30px; padding: 0 10px; font-size: 12px; display: inline-flex; align-items: center; gap: 6px; color: var(--muted); }
  .small:hover { color: var(--text); border-color: var(--accent-line); }
</style>
