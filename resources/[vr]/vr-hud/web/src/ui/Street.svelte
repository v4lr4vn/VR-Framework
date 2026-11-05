<script>
  import { hud, ui, showCompass } from '../lib/store.svelte.js';

  const NAMES = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  let shown = $state(hud.heading);
  $effect(() => {
    if (!showCompass()) return;
    let raf, last = performance.now();
    const tick = (now) => {
      const dt = Math.min(0.1, (now - last) / 1000);
      last = now;
      const diff = ((hud.heading - shown + 540) % 360) - 180;
      shown = Math.abs(diff) < 0.02 ? hud.heading : (shown + diff * (1 - Math.exp(-dt * 16)) + 360) % 360;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  const marks = $derived.by(() => {
    const h = shown;
    const base = Math.round(h / 15) * 15;
    const out = [];
    for (let a = -90; a <= 90; a += 15) {
      const deg = base + a;
      const n = ((deg % 360) + 360) % 360;
      out.push({ deg, x: 50 + ((deg - h) / 90) * 50, label: n % 45 === 0 ? NAMES[n / 45] : '·', major: n % 45 === 0, north: n === 0 });
    }
    return out;
  });
</script>

<div class="card street">
  {#if showCompass()}
    <div class="comp">
      {#each marks as m (m.deg)}
        <span class:m={m.major} class:n={m.north} style:left="{m.x}%">{m.label}</span>
      {/each}
      <i class="caret"></i>
    </div>
  {/if}
  <div class="st">
    <span class="sn">{hud.street || '—'}</span>
    {#if ui.settings.postal && hud.postal}<span class="pc mono" title="{hud.postalDist} m to postal">P {hud.postal}</span>{/if}
    <span class="sd mono">{hud.time}</span>
  </div>
</div>
