<script>
  let { title, icon = 'fa-circle-info', onclose, children, width = 440 } = $props();
  const key = (e) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      onclose?.();
    }
  };
</script>

<svelte:window onkeydown={key} />

<div class="scrim" role="presentation" onclick={(e) => e.target === e.currentTarget && onclose?.()}>
  <div class="modal card" style="width:{width}px" role="dialog" aria-modal="true" aria-label={title}>
    <header>
      <span class="ic"><i class="fa-solid {icon}"></i></span>
      <h2>{title}</h2>
      <button class="x" onclick={() => onclose?.()} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>
    <div class="body">{@render children()}</div>
  </div>
</div>

<style>
  .scrim { position: absolute; inset: 0; z-index: 20; display: grid; place-items: center; background: rgba(6, 9, 13, 0.62); border-radius: inherit; }
  .modal { max-width: calc(100% - 40px); animation: pop 0.16s var(--ease); }
  @keyframes pop { from { transform: translateY(6px) scale(0.98); opacity: 0; } }
  header { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); }
  .ic { width: 28px; height: 28px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent-soft); color: var(--accent); border: 1px solid var(--accent-line); font-size: 12px; }
  h2 { flex: 1; font-size: 15px; font-weight: 700; }
  .x { width: 28px; height: 28px; border-radius: var(--radius); border: 1px solid var(--line-3); background: transparent; color: var(--muted); }
  .x:hover { color: var(--text); background: var(--panel-2); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 14px; }
</style>
