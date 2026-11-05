<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import Icon from '../../components/Icon.svelte';
  import { request, toast } from '../../lib/state.svelte.js';
  import { money } from '../../lib/format.js';
  import { verdictLabels } from './meta.js';

  let { open = $bindable(false), kase, onsaved } = $props();

  let verdict = $state('guilty');
  let fine = $state(0);
  let months = $state(0);
  let notes = $state('');
  let apply = $state(true);
  let busy = $state(false);
  let wasOpen = false;

  $effect(() => {
    if (open && !wasOpen) {
      verdict = 'guilty';
      fine = 0;
      months = 0;
      notes = '';
      apply = !!kase?.defendant?.cid;
    }
    wasOpen = open;
  });

  const choices = [
    { id: 'guilty', hint: 'Convicted on the charges' },
    { id: 'plea', hint: 'Agreed plea or reduced charge' },
    { id: 'not_guilty', hint: 'Acquitted' },
    { id: 'dismissed', hint: 'Case thrown out' },
  ];

  const convicted = $derived(verdict === 'guilty' || verdict === 'plea');
  const canApply = $derived(convicted && !!kase?.defendant?.cid);
  const fineOk = $derived(Number.isInteger(Number(fine)) && Number(fine) >= 0 && Number(fine) <= 250000);
  const monthsOk = $derived(Number.isInteger(Number(months)) && Number(months) >= 0 && Number(months) <= 300);
  const valid = $derived(!convicted || (fineOk && monthsOk));

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const res = await request('court.verdict', {
      id: kase.id,
      verdict,
      fine: convicted ? Number(fine) || 0 : 0,
      months: convicted ? Number(months) || 0 : 0,
      notes: notes.trim(),
      apply: canApply && apply,
    });
    busy = false;
    if (!res.ok) return;
    if (canApply && apply && !res.data.executed) toast('Verdict recorded. The sentence was saved but could not be applied automatically.', 'error', 6000);
    else toast(`Verdict recorded: ${verdictLabels[verdict]}`, 'ok');
    open = false;
    onsaved?.(res.data);
  }
</script>

<Modal bind:open title="Record verdict · {kase?.number}" width={600}>
  <form class="form" onsubmit={submit}>
    <div class="choices" role="radiogroup" aria-label="Verdict">
      {#each choices as c}
        <button type="button" role="radio" aria-checked={verdict === c.id} class="choice {c.id}" class:on={verdict === c.id} onclick={() => (verdict = c.id)}>
          <span class="t">{verdictLabels[c.id]}</span>
          <span class="h">{c.hint}</span>
        </button>
      {/each}
    </div>

    <fieldset class="sentence" disabled={!convicted}>
      <legend class="lbl">Sentence</legend>
      <div class="two">
        <Field label="Fine" id="vd-fine" error={convicted && !fineOk ? 'Whole dollars, up to $250,000.' : ''} hint={convicted && fineOk && Number(fine) > 0 ? money(fine) : ''}>
          <div class="unit"><span class="mono">$</span><input id="vd-fine" class="mono" type="number" min="0" max="250000" step="100" bind:value={fine} /></div>
        </Field>
        <Field label="Prison time" id="vd-months" error={convicted && !monthsOk ? 'Whole months, up to 300.' : ''}>
          <div class="unit"><input id="vd-months" class="mono" type="number" min="0" max="300" bind:value={months} /><span>months</span></div>
        </Field>
      </div>
    </fieldset>

    <Field label="Notes" id="vd-notes"><Textarea id="vd-notes" bind:value={notes} rows={3} maxlength={1000} placeholder="Reasons, plea terms, conditions" /></Field>

    <div class="apply" class:off={!canApply}>
      <Checkbox id="vd-apply" bind:checked={apply} disabled={!canApply} label="Apply the sentence now" />
      <p>
        {#if !convicted}
          Nothing to apply for this verdict.
        {:else if !kase?.defendant?.cid}
          The defendant isn't linked to a citizen record, so the sentence will only be stored.
        {:else}
          Records the conviction on {kase.defendant.name}'s file and starts the prison term. If that isn't possible, the sentence is still stored.
        {/if}
      </p>
    </div>

    <p class="warn"><Icon name="alert" size={14} /> A verdict can't be changed once it's recorded.</p>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="gavel" busy={busy} disabled={!valid} onclick={submit}>Record verdict</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .choices { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
  .choice { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); text-align: left; }
  .choice:hover { border-color: var(--line-3); background: var(--panel-2); }
  .t { font-weight: 700; }
  .h { font-size: 12px; color: var(--muted); line-height: 1.3; }
  .choice.on { background: var(--panel-2); }
  .choice.on.guilty { border-color: var(--danger); box-shadow: inset 0 0 0 1px var(--danger); }
  .choice.on.plea { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
  .choice.on.not_guilty { border-color: var(--ok); box-shadow: inset 0 0 0 1px var(--ok); }
  .choice.on.dismissed { border-color: var(--text-2); box-shadow: inset 0 0 0 1px var(--text-2); }
  .sentence { border: 0; margin: 0; padding: 0; min-width: 0; }
  .sentence:disabled { opacity: 0.45; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; padding: 0; margin-bottom: 8px; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .unit { display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .unit:focus-within { border-color: var(--accent); }
  .unit input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); height: 100%; }
  .apply { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .apply p { color: var(--muted); font-size: 13px; line-height: 1.45; padding-left: 26px; }
  .warn { display: flex; align-items: center; gap: 6px; color: var(--p2-text); font-size: 13px; }
</style>
