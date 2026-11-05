<script>
  import { onMount } from 'svelte';
  import { hud, ui, STATS, statVisible, pinned, showMap, persist } from './lib/store.svelte.js';
  import { post, on } from './lib/nui.js';
  import Group from './ui/Group.svelte';
  import Status from './ui/Status.svelte';
  import Chip from './ui/Chip.svelte';
  import Vehicle from './ui/Vehicle.svelte';
  import Voice from './ui/Voice.svelte';
  import Street from './ui/Street.svelte';
  import Settings from './ui/Settings.svelte';

  const on_ = $derived(hud.visible || ui.edit);
  const showVeh = $derived(on_ && (hud.inVehicle || ui.edit));

  const placeMap = (vw, vh) => [16, vh - vh * 0.2 - 16];
  const placeStatus = (vw, vh) => [16, vh - vh * 0.2 - 16 - 66];
  const placeVeh = (vw, vh, w, h) => [vw - w - 16, vh - h - 16];
  const placeChip = (i) => (vw, vh) => [16 + i * 52, vh - vh * 0.2 - 16 - 66];
  const placeVoice = () => [16, 16];
  const placeStreet = (vw, vh, w) => [(vw - w) / 2, 12];

  const closePanel = () => { persist(); post('hud:close'); };

  onMount(() => {
    const off = on((msg) => {
      if (!msg || !msg.action) return;
      const d = msg.data || {};
      if (msg.action === 'init') {
        if (d.settings) ui.settings = d.settings;
        ui.layout = d.layout && !Array.isArray(d.layout) ? d.layout : {};
        ui.voiceModes = d.voiceModes || 3;
        ui.ready = true;
      } else if (msg.action === 'patch') {
        Object.assign(hud, d);
      } else if (msg.action === 'panel') {
        ui.panel = !!d.open;
        if (!ui.panel) ui.edit = false;
      }
    });
    const key = (e) => {
      if (e.key !== 'Escape') return;
      if (ui.edit) { ui.edit = false; persist(); }
      else if (ui.panel) closePanel();
    };
    window.addEventListener('keydown', key);
    post('hud:ready');
    return () => { off(); window.removeEventListener('keydown', key); };
  });
</script>

{#if ui.ready}
  <Group id="voice" name="Voice / ID" show={on_} place={placeVoice}><Voice /></Group>
  <Group id="street" name="Street / compass / time" show={on_} place={placeStreet}><Street /></Group>
  <Group id="status" name="Status" show={on_ && !ui.edit} place={placeStatus}><Status /></Group>
  {#each STATS as s, i (s.key)}
    <Group id="stat_{s.key}" name={s.label} show={on_ && (ui.edit || (pinned(s) && statVisible(s)))} place={placeChip(i)}><Chip {s} /></Group>
  {/each}
  <Group id="map" name="Minimap" show={on_ && showMap()} place={placeMap}><div class="mapframe"></div></Group>
  <Group id="vehicle" name="Vehicle" show={showVeh} place={placeVeh}><Vehicle /></Group>

  {#if ui.panel && !ui.edit}<div class="panelwrap"><Settings /></div>{/if}
  {#if ui.edit}
    <div class="card etool">
      <span>Drag to move. Right-click a status icon to put it back in the row.</span>
      <button class="btn" onclick={() => { ui.edit = false; persist(); }}>Done</button>
    </div>
  {/if}
{/if}
