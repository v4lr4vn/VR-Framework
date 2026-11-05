<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Icon from '../../components/Icon.svelte';
  import PersonPicker from './PersonPicker.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { boloKinds } from './shared.js';

  let { open = $bindable(false), oncreated } = $props();

  let kind = $state('person');
  let title = $state('');
  let subject = $state('');
  let plate = $state('');
  let target = $state(null);
  let details = $state('');
  let busy = $state(false);

  $effect(() => {
    if (open) {
      kind = 'person';
      title = '';
      subject = '';
      plate = '';
      target = null;
      details = '';
    }
  });

  const plateOk = $derived(!plate.trim() || /^[A-Za-z0-9 ]{1,8}$/.test(plate.trim()));
  const valid = $derived(title.trim().length >= 3 && plateOk);

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const data = { kind, title: title.trim(), details: details.trim(), subject: subject.trim() };
    if (kind === 'vehicle' && plate.trim()) data.plate = plate.trim().toUpperCase();
    if (kind === 'person' && target) data.cid = target.cid;
    const res = await request('bolos.create', data, { success: 'BOLO sent to all units' });
    busy = false;
    if (res.ok) {
      open = false;
      oncreated?.(res.data);
    }
  }
</script>

<Modal bind:open title="New BOLO" width={540}>
  <form class="form" onsubmit={submit}>
    <div class="kinds" role="radiogroup" aria-label="What to look out for">
      {#each boloKinds as k}
        <button type="button" role="radio" aria-checked={kind === k.id} class="kind" class:on={kind === k.id} onclick={() => (kind = k.id)}>
          <Icon name={k.icon} size={16} />{k.label}
        </button>
      {/each}
    </div>
    <Field label="Title" id="bm-title">
      <Input id="bm-title" bind:value={title} maxlength={96} placeholder={kind === 'vehicle' ? 'Getaway vehicle from the Fleeca robbery' : kind === 'person' ? 'Armed robbery suspect' : 'Stolen jewellery from Vangelico'} autofocus />
    </Field>
    {#if kind === 'person'}
      <Field label="Person" id="bm-person" hint="Optional. Leave empty if they aren't identified yet.">
        <PersonPicker id="bm-person" bind:value={target} />
      </Field>
    {:else if kind === 'vehicle'}
      <Field label="Plate" id="bm-plate" hint="Optional." error={plateOk ? '' : 'Plates are up to 8 letters and numbers.'}>
        <div class="plate"><Input id="bm-plate" bind:value={plate} maxlength={8} placeholder="46EEK572" mono /></div>
      </Field>
    {/if}
    {#if !(kind === 'person' && target)}
      <Field label="Description" id="bm-subject" hint="Who or what officers should look for.">
        <Input id="bm-subject" bind:value={subject} maxlength={96} placeholder={kind === 'vehicle' ? 'Dark green Karin Sultan RS, tinted windows' : 'Male, 30s, grey hoodie'} />
      </Field>
    {/if}
    <Field label="Details" id="bm-details">
      <Textarea id="bm-details" bind:value={details} rows={3} maxlength={2000} placeholder="Last seen, direction of travel, whether they're armed" />
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="send" {busy} disabled={!valid} onclick={submit}>Send BOLO</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .kinds { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .kind { height: 40px; display: flex; align-items: center; justify-content: center; gap: 8px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); font-weight: 600; }
  .kind:hover { color: var(--text); }
  .kind.on { border-color: var(--accent); background: var(--accent-soft); color: var(--accent); }
  .plate { width: 180px; }
</style>
