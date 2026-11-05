<script>
  import { bindParts } from '../lib/state.svelte.js';

  let { bind = null, empty = 'Not set', size = 'md', live = null } = $props();

  const parts = $derived(live ?? bindParts(bind));
</script>

<span class="chip {size}" class:empty={!parts.length}>
  {#if parts.length}
    {#each parts as p, i (i)}
      {#if i > 0}<span class="plus">+</span>{/if}
      <kbd class="mono">{p}</kbd>
    {/each}
  {:else}
    <span class="none">{empty}</span>
  {/if}
</span>

<style>
  .chip { display: inline-flex; align-items: center; gap: 4px; }
  kbd {
    display: inline-flex; align-items: center; justify-content: center; min-width: 30px; height: 28px; padding: 0 9px;
    border-radius: 6px; border: 1px solid var(--line-3); border-bottom-width: 3px; background: var(--panel-2);
    color: var(--accent-2); font-size: 13px; font-weight: 600; line-height: 1; white-space: nowrap;
  }
  .lg kbd { min-width: 52px; height: 52px; padding: 0 16px; font-size: 22px; border-radius: 8px; border-bottom-width: 4px; }
  .sm kbd { min-width: 22px; height: 22px; padding: 0 6px; font-size: 11px; border-bottom-width: 2px; }
  .plus { color: var(--faint); font-family: var(--mono); font-size: 12px; }
  .lg .plus { font-size: 18px; }
  .none { color: var(--faint); font-family: var(--mono); font-size: 12px; letter-spacing: 0.04em; }
  .lg .none { font-size: 16px; }
</style>
