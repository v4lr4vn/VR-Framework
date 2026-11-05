<script>
  import { hud, ui } from '../lib/store.svelte.js';
  const pips = $derived(Array.from({ length: ui.voiceModes }, (_, i) => i + 1));
</script>

<div class="card voice" class:talk={hud.talking}>
  <span class="mic"><i class="fa-solid fa-microphone"></i></span>
  <span class="pips" title={hud.voiceMode}>
    {#each pips as p (p)}<i class:on={p <= hud.voiceIndex} style:height="{6 + p * 4}px"></i>{/each}
  </span>
  {#if hud.radio > 0}<span class="radio mono" class:live={hud.radioTalking} title="Radio channel">R {hud.radio}</span>{/if}
  <span class="pid mono">ID {hud.id}</span>
</div>
