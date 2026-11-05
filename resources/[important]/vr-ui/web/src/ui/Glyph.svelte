<script>
  import { GLYPHS } from '../lib/glyphs.js';
  let { name, size = 14, stroke = 2.4 } = $props();
  const shapes = $derived((GLYPHS[name] || GLYPHS.primary).map((d) => (d.startsWith('circle:') ? { c: d.slice(7).split(',') } : { d })));
</script>

<svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" stroke-width={stroke} stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
  {#each shapes as s}
    {#if s.c}<circle cx={s.c[0]} cy={s.c[1]} r={s.c[2]} />{:else}<path d={s.d} />{/if}
  {/each}
</svg>
