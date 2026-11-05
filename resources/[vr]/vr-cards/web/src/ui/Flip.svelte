<script>
  import Back from './Back.svelte';

  let { w = 220, flipped = false, children } = $props();
</script>

<div class="flip" class:on={flipped} style="--w:{w}px">
  <div class="inner">
    <div class="side front">{@render children()}</div>
    <div class="side back"><Back {w} /></div>
  </div>
</div>

<style>
  .flip { width: var(--w); height: calc(var(--w) * 1.4); perspective: 1200px; }
  .inner { position: relative; width: 100%; height: 100%; transform-style: preserve-3d; transform: rotateY(180deg); transition: transform 0.75s cubic-bezier(0.2, 0.8, 0.25, 1); }
  .on .inner { transform: rotateY(0deg); }
  .side { position: absolute; inset: 0; backface-visibility: hidden; -webkit-backface-visibility: hidden; }
  .back { transform: rotateY(180deg); }
</style>
