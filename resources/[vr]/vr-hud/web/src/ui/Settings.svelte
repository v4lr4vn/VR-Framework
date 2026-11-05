<script>
  import { ui, STATS, persist } from '../lib/store.svelte.js';
  import { post } from '../lib/nui.js';

  const fix = (k) => {
    const m = ui.settings.stats[k];
    m.at = Math.max(1, Math.min(100, Math.round(Number(m.at) || 1)));
    persist();
  };
  const reset = () => { ui.layout = {}; persist(); };
  const close = () => { persist(); post('hud:close'); };
</script>

<div class="card panel scroll">
  <div class="phead">
    <h3>HUD settings</h3>
    <button class="hbtn" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </div>

  <div class="sub">Status icons</div>
  {#each STATS as s (s.key)}
    {@const m = ui.settings.stats[s.key]}
    <div class="row">
      <label for="m-{s.key}"><i class="fa-solid {s.icon}" style:color={s.color}></i> {s.label}</label>
      <select id="m-{s.key}" bind:value={m.mode} onchange={persist}>
        <option value="always">Always</option>
        <option value="auto">Auto</option>
        <option value="off">Hidden</option>
      </select>
      {#if m.mode === 'auto'}
        <span class="dim">{s.dir === 'low' ? 'below' : 'above'}</span>
        <input type="number" min="1" max="100" bind:value={m.at} onchange={() => fix(s.key)} />%
      {/if}
    </div>
  {/each}

  <div class="sub">On foot</div>
  <div class="row"><label for="s-map">Show minimap</label><input id="s-map" type="checkbox" bind:checked={ui.settings.mapOnFoot} onchange={persist} /></div>
  <div class="row"><label for="s-comp">Show compass</label><input id="s-comp" type="checkbox" bind:checked={ui.settings.compassOnFoot} onchange={persist} /></div>

  <div class="sub">General</div>
  <div class="row"><label for="s-post">Show postal code</label><input id="s-post" type="checkbox" bind:checked={ui.settings.postal} onchange={persist} /></div>
  <div class="row">
    <label for="s-unit">Speed unit</label>
    <select id="s-unit" bind:value={ui.settings.unit} onchange={persist}><option value="mph">MPH</option><option value="kph">KPH</option></select>
  </div>
  <div class="row"><label for="s-gear">Show gear (if unlocked)</label><input id="s-gear" type="checkbox" bind:checked={ui.settings.gears} onchange={persist} /></div>

  <div class="sub">Layout</div>
  <div class="row two">
    <button class="btn" onclick={() => (ui.edit = true)}>Edit layout</button>
    <button class="btn" onclick={reset}>Reset layout</button>
  </div>
</div>
