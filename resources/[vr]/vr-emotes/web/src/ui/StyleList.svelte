<script>
  let { list = [], current = false, kind = 'walk', resetLabel = 'Default', onhover, onleave, onpick } = $props();
</script>

<div class="list scroll" role="list" onmouseleave={() => onleave && onleave()}>
  <button class="row reset" class:on={!current} onmouseenter={() => onhover && onhover(null)} onclick={() => onpick(null)}>
    <i class="fa-solid fa-rotate-left"></i>
    <span class="label">{resetLabel}</span>
    {#if !current}<span class="now mono">CURRENT</span>{/if}
  </button>
  {#each list as s (s.k)}
    <button class="row" class:on={current === s.k} onmouseenter={() => onhover && onhover(s)} onclick={() => onpick(s)}>
      <i class="fa-solid fa-{kind === 'walk' ? 'person-walking' : 'face-smile'}"></i>
      <span class="label">{s.l}</span>
      <span class="cmd mono">/{kind === 'walk' ? 'walk' : 'mood'} {s.k.toLowerCase()}</span>
      {#if current === s.k}<span class="now mono">CURRENT</span>{/if}
    </button>
  {/each}
</div>

<style>
  .list { flex: 1; min-height: 0; display: grid; grid-template-columns: 1fr 1fr; align-content: start; gap: 6px; padding-right: 4px; }
  .row { display: flex; align-items: center; gap: 10px; height: 48px; padding: 0 12px; border-radius: var(--radius-lg); border: 1px solid var(--line); background: var(--panel); color: var(--text); text-align: left; min-width: 0; }
  .row:hover { border-color: var(--line-3); background: var(--panel-2); }
  .row.on { border-color: var(--ok-line); background: linear-gradient(90deg, rgba(61, 214, 140, 0.1), transparent 70%), var(--panel-2); }
  .row i { color: var(--muted); font-size: 13px; width: 16px; text-align: center; }
  .reset { grid-column: 1 / -1; border-style: dashed; }
  .label { font-weight: 600; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cmd { margin-left: auto; font-size: 11px; color: var(--faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 45%; }
  .now { margin-left: auto; font-size: 9px; letter-spacing: 0.12em; color: var(--ok-text); font-weight: 600; }
  .cmd + .now { margin-left: 6px; }
</style>
