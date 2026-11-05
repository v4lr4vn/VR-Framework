<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import PersonPicker from './PersonPicker.svelte';
  import { request } from '../../lib/state.svelte.js';

  let { open = $bindable(false), oncreated } = $props();

  let serial = $state('');
  let label = $state('');
  let owner = $state(null);
  let busy = $state(false);

  $effect(() => {
    if (open) {
      serial = '';
      label = '';
      owner = null;
    }
  });

  const serialOk = $derived(/^[A-Za-z0-9-]{4,32}$/.test(serial.trim()));
  const valid = $derived(serialOk && label.trim().length > 0);

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const res = await request('weapons.register', { serial: serial.trim(), label: label.trim(), cid: owner?.cid || '' }, { success: 'Weapon registered' });
    busy = false;
    if (res.ok) {
      open = false;
      oncreated?.(res.data);
    }
  }
</script>

<Modal bind:open title="Register a weapon" width={500}>
  <form class="form" onsubmit={submit}>
    <p class="muted">Weapons bought legally are registered automatically. Use this for recovered or unlisted weapons.</p>
    <Field label="Serial number" id="rw-serial" hint="Letters, numbers and dashes." error={serial.trim() && !serialOk ? 'Use 4 to 32 letters, numbers or dashes.' : ''}>
      <Input id="rw-serial" bind:value={serial} maxlength={32} placeholder="FOUND-0092" mono autofocus />
    </Field>
    <Field label="Weapon" id="rw-label">
      <Input id="rw-label" bind:value={label} maxlength={64} placeholder="Sawn-off shotgun" />
    </Field>
    <Field label="Owner" id="rw-owner" hint="Leave empty if the owner is unknown.">
      <PersonPicker id="rw-owner" bind:value={owner} />
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="plus" {busy} disabled={!valid} onclick={submit}>Register</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
</style>
