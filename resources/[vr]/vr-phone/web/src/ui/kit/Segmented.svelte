<script>
  // options: [{ value, label }]
  let { options, value, onchange, label = '' } = $props();
</script>

<div class="seg" role="radiogroup" aria-label={label}>
  {#each options as option (option.value)}
    <button
      class="opt"
      class:on={option.value === value}
      role="radio"
      aria-checked={option.value === value}
      onclick={() => onchange?.(option.value)}
    >
      {option.label}
    </button>
  {/each}
</div>

<style>
  .seg {
    display: flex;
    gap: 3px;
    padding: 3px;
    border-radius: 12px;
    background: var(--surface-2);
  }
  .opt {
    flex: 1 1 auto;
    min-width: 0;
    white-space: nowrap;
    padding: 8px 8px;
    border-radius: 9px;
    font-size: 13px;
    font-weight: 600;
    color: var(--ink-2);
    text-align: center;
    transition: background 0.18s var(--ease-soft), color 0.18s var(--ease-soft);
  }
  .opt.on {
    background: var(--surface);
    color: var(--ink);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.18);
  }
</style>
