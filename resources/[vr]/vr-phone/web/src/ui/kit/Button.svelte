<script>
  // kind: 'plain' | 'primary' | 'danger'
  let { kind = 'plain', onclick, disabled = false, children } = $props();
</script>

<button class="btn {kind}" {onclick} {disabled}>{@render children?.()}</button>

<style>
  .btn {
    padding: 8px 14px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 14px;
    font-weight: 600;
    color: var(--ink);
  }
  .btn:disabled {
    opacity: 0.45;
  }
  .primary {
    background: var(--accent);
    color: var(--on-accent);
  }
  .danger {
    color: #e5484d;
  }
</style>
