<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { months_ } from '../../lib/format.js';
  import { clockText } from './shared.js';

  let { open = $bindable(false), mode = 'adjust', inmate = null, remaining = 0, maxMonths = 300, perMonth = 60, ondone } = $props();

  let months = $state(1);
  let reason = $state('');
  let busy = $state(false);

  $effect(() => {
    if (open && inmate) {
      months = Math.max(1, Math.ceil(remaining / perMonth));
      reason = '';
    }
  });

  const monthsOk = $derived(Number.isInteger(Number(months)) && Number(months) >= 1 && Number(months) <= maxMonths);

  async function submit(e) {
    e?.preventDefault();
    if (busy || !inmate) return;
    if (mode === 'adjust' && !monthsOk) return;
    busy = true;
    const res = mode === 'adjust'
      ? await request('prison.adjust', { cid: inmate.cid, months: Number(months) }, { success: `${inmate.name} now has ${months_(Number(months))} left` })
      : await request('prison.release', { cid: inmate.cid, reason: reason.trim() }, { success: `${inmate.name} was released` });
    busy = false;
    if (res.ok) {
      open = false;
      ondone?.(res.data);
    }
  }
</script>

<Modal bind:open title={mode === 'adjust' ? 'Change sentence' : 'Release early'} width={460}>
  {#if inmate}
    <form class="form" onsubmit={submit}>
      <div class="who">
        <Mugshot id={inmate.mugshot} name={inmate.name} size={48} />
        <div class="names">
          <span class="nm">{inmate.name}</span>
          <span class="muted">{months_(inmate.months)} sentence{' · '}<span class="mono">{clockText(remaining)}</span> left</span>
        </div>
      </div>
      {#if mode === 'adjust'}
        <Field label="Time left in months" id="im-months" hint="One month is {perMonth} seconds of time served in the city." error={monthsOk ? '' : `Between 1 and ${maxMonths} months.`}>
          <div class="months"><Input id="im-months" type="number" min="1" max={maxMonths} bind:value={months} mono autofocus /></div>
        </Field>
      {:else}
        <p class="muted">Their belongings are returned and they're moved to the prison gate. This is logged.</p>
        <Field label="Reason" id="im-reason" hint="Optional.">
          <Input id="im-reason" bind:value={reason} maxlength={80} placeholder="Plea deal" autofocus />
        </Field>
      {/if}
    </form>
  {/if}
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    {#if mode === 'adjust'}
      <Button variant="primary" icon="check" {busy} disabled={!monthsOk} onclick={submit}>Save</Button>
    {:else}
      <Button variant="danger" icon="unlock" {busy} onclick={submit}>Release now</Button>
    {/if}
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .who { display: flex; align-items: center; gap: 12px; padding: 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .names { display: flex; flex-direction: column; gap: 2px; }
  .nm { font-weight: 700; font-size: 16px; }
  .months { width: 140px; }
  .months :global(input::-webkit-inner-spin-button), .months :global(input::-webkit-outer-spin-button) { -webkit-appearance: none; margin: 0; }
</style>
