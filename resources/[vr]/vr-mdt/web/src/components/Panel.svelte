<script>
  let { title = '', eyebrow = '', actions, children, pad = true, fill = false, class: cls = '' } = $props();
</script>

<section class="panel {cls}" class:fill>
  {#if title || eyebrow || actions}
    <header class="head">
      <div class="titles">
        {#if eyebrow}<span class="eyebrow">{eyebrow}</span>{/if}
        {#if title}<h2>{title}</h2>{/if}
      </div>
      {#if actions}<div class="actions">{@render actions()}</div>{/if}
    </header>
  {/if}
  <div class="body" class:pad>{@render children()}</div>
</section>

<style>
  .panel { background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius-lg); display: flex; flex-direction: column; min-width: 0; }
  .fill { flex: 1; min-height: 0; }
  .head { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-bottom: 1px solid var(--line); }
  .titles { display: flex; flex-direction: column; gap: 2px; min-width: 0; flex: 1; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.02em; }
  .actions { display: flex; align-items: center; gap: 6px; }
  .body { min-height: 0; flex: 1; display: flex; flex-direction: column; }
  .pad { padding: 14px; }
</style>
