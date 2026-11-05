<script>
  let { licences = [], editable = false, busy = '', ontoggle } = $props();
</script>

<ul class="lics">
  {#each licences as l (l.key)}
    <li class="lic">
      <span class="name" class:off={!l.value}>{l.label.replace(/ licence$/i, '')}</span>
      {#if editable}
        <button type="button" class="switch" class:on={l.value} role="switch" aria-checked={l.value} aria-label={l.label} disabled={busy === l.key} onclick={() => ontoggle?.(l)}>
          <span class="knob"></span>
        </button>
      {:else}
        <span class="state" class:on={l.value}>{l.value ? 'Valid' : 'None'}</span>
      {/if}
    </li>
  {/each}
</ul>

<style>
  .lics { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 20px; }
  .lic { display: flex; align-items: center; justify-content: space-between; gap: 12px; min-height: 34px; border-bottom: 1px solid var(--line); }
  .lic:nth-last-child(-n + 2):nth-child(odd), .lic:last-child { border-bottom: 0; }
  .name { color: var(--text); }
  .name.off { color: var(--muted); }
  .switch { position: relative; width: 38px; height: 22px; border-radius: 11px; border: 1px solid var(--line-3); background: var(--bg-2); padding: 0; flex: none; transition: background 0.15s, border-color 0.15s; }
  .knob { position: absolute; top: 3px; left: 3px; width: 14px; height: 14px; border-radius: 50%; background: var(--faint); transition: transform 0.15s, background 0.15s; }
  .switch.on { background: var(--ok-bg); border-color: var(--ok-line); }
  .switch.on .knob { transform: translateX(16px); background: var(--ok); }
  .state { font-size: 13px; color: var(--faint); }
  .state.on { color: var(--ok); font-weight: 600; }
</style>
