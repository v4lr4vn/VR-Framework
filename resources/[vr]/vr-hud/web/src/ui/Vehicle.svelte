<script>
  import { ui, view } from '../lib/store.svelte.js';

  const d = $derived(view());
  const speed = $derived(Math.round(ui.settings.unit === 'mph' ? d.speed * 0.621371 : d.speed));
  const belted = $derived(d.seatbelt || d.harness);
  const engineBad = $derived(d.engineOn && d.engineHealth < 30);
  const hazard = $derived(d.left && d.right);
  const lowFuel = $derived(d.fuel <= 20 && d.lowFuelAlert);
</script>

<div class="card veh">
  <div class="sp">
    <span class="spd">{String(speed).padStart(3, '0')}</span>
    <span class="unit">{ui.settings.unit === 'mph' ? 'MPH' : 'KPH'}</span>
    {#if ui.settings.gears && d.gearsUnlocked}<span class="gear">{d.gear}</span>{/if}
  </div>
  <div class="fuel">
    <i class="fa-solid fa-gas-pump"></i>
    <span class="bar" class:lo={lowFuel}><i style:width="{d.fuel}%"></i></span>
    <span class="mono">{d.fuel}%</span>
  </div>
  <div class="ind">
    <span class:on={d.left} class:blink={d.left} title={hazard ? 'Hazards' : 'Left indicator'}><i class="fa-solid fa-chevron-left"></i></span>
    {#if !d.noBelt}
      <span class:on={belted} class:bad={!belted && d.speed > 15} class:blink={!belted && d.speed > 15} title={d.harness ? 'Harness' : 'Seatbelt'}><i class="fa-solid fa-user-shield"></i></span>
    {/if}
    <span class:on={d.engineOn && !engineBad} class:bad={engineBad} class:blink={engineBad} title="Engine"><i class="fa-solid fa-gear"></i></span>
    <span class:on={d.lights === 1} class:hi={d.lights === 2} title="Lights"><i class="fa-solid fa-lightbulb"></i></span>
    <span class:on={d.right} class:blink={d.right} title="Right indicator"><i class="fa-solid fa-chevron-right"></i></span>
  </div>
</div>
