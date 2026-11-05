<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Icon from '../../components/Icon.svelte';
  import { request } from '../../lib/state.svelte.js';

  let { open = $bindable(false), locations = [], limits = null, onsaved } = $props();

  let label = $state('');
  let location = $state('');
  let pitch = $state(-15);
  let fov = $state(60);
  let busy = $state(false);
  let wasOpen = false;

  const lim = $derived(limits || { pitchMin: -70, pitchMax: 25, fovMin: 15, fovMax: 90 });

  $effect(() => {
    if (open && !wasOpen) {
      label = '';
      location = '';
      pitch = -15;
      fov = 60;
    }
    wasOpen = open;
  });

  const valid = $derived(label.trim().length >= 2 && location.trim().length >= 2);

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const res = await request('cameras.add', { label: label.trim(), location: location.trim(), pitch: Number(pitch), fov: Number(fov) }, { success: 'Camera added' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title="Add a security camera" width={520}>
  <form class="form" onsubmit={submit}>
    <div class="where">
      <Icon name="pin" size={16} />
      <p>After you press the button the tablet hides. Aim at the wall or pole where the camera mounts and click, then aim at what it should watch and click again. No need to climb up there.</p>
    </div>
    <Field label="Name" id="cam-label"><Input id="cam-label" bind:value={label} maxlength={64} placeholder="Alley behind the bank" autofocus /></Field>
    <Field label="Area" id="cam-loc" hint="Cameras are grouped by area.">
      <Input id="cam-loc" bind:value={location} maxlength={48} placeholder="Downtown" list="cam-locations" />
      <datalist id="cam-locations">{#each locations as l}<option value={l}></option>{/each}</datalist>
    </Field>
    <Field label="Field of view" id="cam-fov" hint="Lower is more zoomed in.">
      <div class="range">
        <input id="cam-fov" type="range" min={lim.fovMin} max={lim.fovMax} step="1" bind:value={fov} />
        <span class="mono val">{fov}°</span>
      </div>
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="plus" busy={busy} disabled={!valid} onclick={submit}>Aim and place camera</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .where { display: flex; gap: 10px; align-items: flex-start; padding: 10px 12px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); }
  .where p { color: var(--text-2); line-height: 1.45; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
  .range { display: flex; align-items: center; gap: 10px; height: 36px; }
  .range input { flex: 1; accent-color: var(--accent); }
  .val { width: 44px; text-align: right; color: var(--text); }
</style>
