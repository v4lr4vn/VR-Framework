<script>
  let { hud } = $props();
</script>

<aside class="hud card" aria-label="Shift">
  <header>
    <span class="dot"></span>
    <h3>{hud.title}</h3>
  </header>
  {#if hud.pct != null}
    <div class="bar"><span style="width:{Math.max(0, Math.min(100, hud.pct))}%"></span></div>
  {/if}
  <ul>
    {#each hud.lines as l}
      <li class={l.state || ''}>
        <span class="k">{l.label}</span>
        <span class="v num">{l.value}</span>
      </li>
    {/each}
  </ul>
</aside>

<style>
  .hud { position: fixed; right: 18px; top: 34%; width: 270px; padding: 12px 14px; display: flex; flex-direction: column; gap: 9px; }
  header { display: flex; align-items: center; gap: 8px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 8px var(--accent); }
  h3 { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-2); }
  ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 5px; }
  li { display: flex; justify-content: space-between; align-items: baseline; gap: 14px; font-size: 13px; }
  .k { color: var(--muted); white-space: nowrap; }
  .v { color: var(--text); text-align: right; font-size: 12.5px; }
  li.go .v { color: var(--ok-text); }
  li.wait .v { color: var(--faint); }
</style>
