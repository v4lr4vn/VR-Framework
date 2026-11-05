<script>
  let { checked = $bindable(false), label = '', hint = '', disabled = false } = $props();
</script>

<button type="button" class="tg" class:on={checked} {disabled} onclick={() => (checked = !checked)}>
  <span class="track"><span class="knob"></span></span>
  <span class="txt">
    <span class="lbl">{label}</span>
    {#if hint}<span class="hint">{hint}</span>{/if}
  </span>
</button>

<style>
  .tg { display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text-2); text-align: left; width: 100%; }
  .tg:hover:not(:disabled) { border-color: var(--line-3); }
  .tg:disabled { opacity: 0.5; cursor: not-allowed; }
  .track { flex: none; position: relative; width: 32px; height: 18px; border-radius: 9px; background: var(--panel-3); transition: background 0.12s; }
  .knob { position: absolute; left: 2px; top: 2px; width: 14px; height: 14px; border-radius: 50%; background: var(--text-2); transition: transform 0.12s, background 0.12s; }
  .on .track { background: var(--accent); }
  .on .knob { transform: translateX(14px); background: var(--accent-ink); }
  .txt { display: flex; flex-direction: column; min-width: 0; }
  .lbl { font-weight: 600; font-size: 14px; color: var(--text); }
  .hint { font-size: 12px; color: var(--faint); }
</style>
