<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import PersonPicker from './PersonPicker.svelte';
  import { request } from '../../lib/state.svelte.js';

  let { open = $bindable(false), person = null, oncreated } = $props();

  let target = $state(null);
  let reason = $state('');
  let charges = $state([]);
  let reportId = $state('');
  let busy = $state(false);

  $effect(() => {
    if (open) {
      target = person ? { cid: person.cid, name: person.name } : null;
      reason = '';
      charges = [{ title: '', count: 1 }];
      reportId = '';
    }
  });

  const cleanCharges = $derived(charges.filter((c) => c.title.trim()).map((c) => ({ title: c.title.trim(), count: Math.min(20, Math.max(1, Number(c.count) || 1)) })));
  const reportValid = $derived(!reportId.trim() || /^\d+$/.test(reportId.trim()));
  const valid = $derived(target && reason.trim().length >= 3 && reportValid);

  function addCharge() {
    if (charges.length < 25) charges = [...charges, { title: '', count: 1 }];
  }

  function removeCharge(i) {
    charges = charges.filter((_, n) => n !== i);
  }

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const data = { cid: target.cid, reason: reason.trim(), charges: cleanCharges };
    if (reportId.trim()) data.reportId = Number(reportId.trim());
    const res = await request('warrants.create', data, { success: 'Warrant requested. A judge will review it.' });
    busy = false;
    if (res.ok) {
      open = false;
      oncreated?.(res.data);
    }
  }
</script>

<Modal bind:open title="Request a warrant" width={560}>
  <form class="form" onsubmit={submit}>
    <Field label="Person" id="wm-person">
      {#if person}
        <div class="fixed"><span class="nm">{person.name}</span><span class="mono faint">{person.cid}</span></div>
      {:else}
        <PersonPicker id="wm-person" bind:value={target} />
      {/if}
    </Field>
    <Field label="Probable cause" id="wm-reason" hint="What happened and why an arrest is justified.">
      <Textarea id="wm-reason" bind:value={reason} rows={4} maxlength={2000} placeholder="On 12 Oct at 14:20 the suspect was identified on Fleeca CCTV..." />
    </Field>
    <div class="charges">
      <span class="lbl">Charges</span>
      {#each charges as c, i}
        <div class="charge">
          <label class="sr-only" for="wm-charge-{i}">Charge {i + 1}</label>
          <Input id="wm-charge-{i}" bind:value={c.title} maxlength={96} placeholder="Armed robbery" />
          <label class="sr-only" for="wm-count-{i}">Count for charge {i + 1}</label>
          <div class="count"><Input id="wm-count-{i}" type="number" min="1" max="20" bind:value={c.count} mono /></div>
          <IconButton icon="trash" variant="danger" label="Remove charge {i + 1}" size={36} onclick={() => removeCharge(i)} />
        </div>
      {/each}
      <Button size="sm" variant="ghost" icon="plus" onclick={addCharge} disabled={charges.length >= 25}>Add charge</Button>
    </div>
    <Field label="Report number" id="wm-report" hint="Optional." error={reportValid ? '' : 'Use the report number only.'}>
      <div class="report"><Input id="wm-report" bind:value={reportId} maxlength={9} placeholder="1042" mono /></div>
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="send" {busy} disabled={!valid} onclick={submit}>Send for approval</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .fixed { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .nm { font-weight: 600; flex: 1; }
  .charges { display: flex; flex-direction: column; gap: 8px; align-items: flex-start; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .charge { display: flex; gap: 8px; width: 100%; align-items: center; }
  .count { width: 76px; flex: none; }
  .count :global(input::-webkit-inner-spin-button), .count :global(input::-webkit-outer-spin-button) { -webkit-appearance: none; margin: 0; }
  .count :global(input) { text-align: center; }
  .report { width: 160px; }
</style>
