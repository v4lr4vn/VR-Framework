<script>
  let { kind = '', onclick, disabled = false, children, type = 'button' } = $props();
</script>

<button class="btn {kind}" {type} {onclick} {disabled}>{@render children()}</button>

<style>
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 8px; height: 36px; padding: 0 16px;
    border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text);
    font-weight: 600; white-space: nowrap; transition: background 0.12s, border-color 0.12s, color 0.12s;
  }
  .btn:hover:not(:disabled) { background: var(--panel-2); border-color: var(--line-3); }
  .btn:disabled { opacity: 0.55; }
  .primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 700; }
  .primary:hover:not(:disabled) { background: var(--accent-2); border-color: var(--accent-2); }
  .ghost { background: transparent; border-color: transparent; color: var(--text-2); }
  .ghost:hover:not(:disabled) { background: var(--panel-2); border-color: transparent; color: var(--text); }
  .danger { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
</style>
