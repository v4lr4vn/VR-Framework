<script>
  import Button from '../../components/Button.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { api } from '../../lib/nui.js';
  import { request, toast } from '../../lib/state.svelte.js';
  import { errorText } from '../../lib/lang.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { money } from '../../lib/format.js';

  let { reportId, person, onapplied } = $props();

  let plea = $state(false);
  let quote = $state(null);
  let error = $state('');
  let fine = $state(0);
  let months = $state(0);
  let busy = $state(false);
  let seq = 0;

  async function load(withPlea) {
    const mine = ++seq;
    const res = await api('sentencing.preview', { reportId, personId: person.id, plea: withPlea });
    if (mine !== seq) return;
    if (!res.ok) {
      error = errorText(res.error);
      quote = null;
      return;
    }
    error = '';
    quote = res.data;
    fine = res.data.max.fine;
    months = res.data.max.months;
  }

  $effect(() => {
    load(plea);
  });

  const fineN = $derived(Math.floor(Number(fine)));
  const monthsN = $derived(Math.floor(Number(months)));
  const fineBad = $derived(quote && (!Number.isFinite(fineN) || fineN > quote.max.fine || fineN < quote.min.fine));
  const monthsBad = $derived(quote && (!Number.isFinite(monthsN) || monthsN > quote.max.months || monthsN < quote.min.months));
  const pct = $derived(Math.round((quote?.rules.maxDiscretion || 0) * 100));

  async function apply() {
    if (!quote || fineBad || monthsBad || busy) return;
    const parts = [];
    if (fineN > 0) parts.push(`a ${money(fineN)} fine`);
    if (monthsN > 0) parts.push(`${monthsN} ${monthsN === 1 ? 'month' : 'months'} in prison`);
    const ok = await confirm({
      title: `Sentence ${person.name}?`,
      text: `${person.name} gets ${parts.join(' and ') || 'no penalty'}${plea ? ' after a guilty plea' : ''}. The fine is taken from their bank right away. This can't be undone.`,
      yes: 'Apply sentence',
      danger: true,
    });
    if (!ok) return;
    busy = true;
    const res = await request('sentencing.apply', { reportId, personId: person.id, plea, fine: fineN, months: monthsN });
    busy = false;
    if (!res.ok) return;
    const r = res.data;
    if (r.unpaid > 0) toast(`Sentence applied. ${money(r.unpaid)} of the fine is unpaid.`, 'ok', 5000);
    else toast('Sentence applied.', 'ok');
    for (const w of r.warnings || []) toast(errorText(w), 'error', 6000);
    onapplied?.(r);
  }
</script>

<div class="sp">
  <div class="head">
    <span class="eyebrow">Sentencing</span>
    <Checkbox id="plea-{person.id}" bind:checked={plea} label="Guilty plea ({Math.round((quote?.rules.pleaReduction || 0.25) * 100)}% off)" />
  </div>
  {#if error}
    <p class="err">{error}</p>
  {:else if !quote}
    <Spinner label="Working out the sentence" />
  {:else}
    <div class="grid">
      <label class="f" for="fine-{person.id}">
        <span class="lbl">Fine</span>
        <span class="inp" class:bad={fineBad}><span class="pre mono">$</span><input id="fine-{person.id}" type="number" inputmode="numeric" min={quote.min.fine} max={quote.max.fine} step="1" bind:value={fine} class="mono" /></span>
        <span class="range mono">{money(quote.min.fine)} – {money(quote.max.fine)}</span>
      </label>
      <label class="f" for="months-{person.id}">
        <span class="lbl">Jail</span>
        <span class="inp" class:bad={monthsBad}><input id="months-{person.id}" type="number" inputmode="numeric" min={quote.min.months} max={quote.max.months} step="1" bind:value={months} class="mono" /><span class="post">months</span></span>
        <span class="range mono">{quote.min.months} – {quote.max.months}</span>
      </label>
      <div class="f">
        <span class="lbl">Points</span>
        <span class="static mono">{quote.points}</span>
        <span class="range">Not reducible</span>
      </div>
      <div class="go">
        <Button variant="primary" icon="gavel" busy={busy} disabled={fineBad || monthsBad} onclick={apply}>Apply sentence</Button>
      </div>
    </div>
    <p class="note">You can lower the fine and jail time by up to {pct}% at your discretion, never raise them.</p>
  {/if}
</div>

<style>
  .sp { display: flex; flex-direction: column; gap: 10px; padding: 12px; border-radius: var(--radius); border: 1px solid var(--accent-line); background: rgba(245, 165, 36, 0.05); }
  .head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr 90px auto; gap: 12px; align-items: end; }
  .f { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .inp { display: flex; align-items: center; gap: 6px; height: 36px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); }
  .inp:focus-within { border-color: var(--accent); }
  .inp.bad { border-color: var(--danger); }
  .inp input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); font-size: 15px; }
  .pre, .post { color: var(--muted); font-size: 13px; }
  .static { height: 36px; display: flex; align-items: center; font-size: 15px; }
  .range { color: var(--faint); font-size: 12px; }
  .go { display: flex; padding-bottom: 20px; }
  .note { color: var(--faint); font-size: 12px; }
  .err { color: var(--danger-text); font-size: 13px; }
  input[type='number']::-webkit-outer-spin-button, input[type='number']::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
  input[type='number'] { -moz-appearance: textfield; appearance: textfield; }
</style>
