<script>
  let { options = [], value = $bindable(), onchange, disabled = false, size = 'md', label = '', full = false, mono = false } = $props();

  function pick(o) {
    if (disabled || o.disabled || o.value === value) return;
    value = o.value;
    onchange?.(o.value);
  }
</script>

<div class="seg {size}" class:full class:mono role="radiogroup" aria-label={label}>
  {#each options as o (o.value)}
    <button
      type="button"
      role="radio"
      aria-checked={o.value === value}
      class="opt {o.tone || ''}"
      class:on={o.value === value}
      disabled={disabled || o.disabled}
      title={o.title}
      onclick={() => pick(o)}
    >{o.label}</button>
  {/each}
</div>

<style>
  .seg { display: inline-flex; gap: 2px; padding: 2px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); min-width: 0; }
  .full { display: flex; width: 100%; }
  .full .opt { flex: 1; }
  .opt { height: 30px; padding: 0 12px; border: 1px solid transparent; border-radius: 4px; background: transparent; color: var(--muted); font-weight: 600; font-size: 13px; white-space: nowrap; }
  .sm .opt { height: 24px; padding: 0 9px; font-size: 12px; }
  .mono .opt { font-family: var(--mono); }
  .opt:hover:not(:disabled) { color: var(--text); background: var(--panel); }
  .on, .on:hover:not(:disabled) { background: var(--panel-2); color: var(--text); border-color: var(--line-3); }
  .on.ok { color: var(--ok); border-color: var(--ok-line); background: var(--ok-bg); }
  .on.p2 { color: var(--p2-text); border-color: var(--accent-line); background: var(--accent-soft); }
  .on.danger { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .on.info { color: var(--info-text); border-color: var(--info-line); background: var(--info-bg); }
  .on.accent { color: var(--accent-ink); border-color: var(--accent); background: var(--accent); }
  .opt:disabled { opacity: 0.45; }
  .on:disabled { opacity: 0.8; }
</style>
