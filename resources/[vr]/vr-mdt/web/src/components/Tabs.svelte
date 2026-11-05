<script>
  let { tabs = [], value = $bindable(), onchange } = $props();
</script>

<div class="tabs" role="tablist">
  {#each tabs as t}
    <button type="button" role="tab" class="tab" class:on={value === t.id} aria-selected={value === t.id} onclick={() => { value = t.id; onchange?.(t.id); }}>
      {t.label}
      {#if t.count != null}<span class="count mono">{t.count}</span>{/if}
    </button>
  {/each}
</div>

<style>
  .tabs { display: flex; gap: 2px; border-bottom: 1px solid var(--line); }
  .tab { height: 36px; padding: 0 14px; border: 0; background: transparent; color: var(--muted); font-weight: 600; border-bottom: 2px solid transparent; margin-bottom: -1px; display: inline-flex; align-items: center; gap: 8px; }
  .tab:hover { color: var(--text); }
  .on { color: var(--text); border-bottom-color: var(--accent); }
  .count { font-size: 12px; color: var(--faint); }
  .on .count { color: var(--accent); }
</style>
