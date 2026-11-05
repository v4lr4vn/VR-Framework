<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Segmented from './Segmented.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { recommendations, ratingWords, scoreTone } from './labels.js';

  let { open = $bindable(false), trainee, categories = [], phases = 4, phase: startPhase = 1, onsaved } = $props();

  let phase = $state(1);
  let ratings = $state({});
  let notes = $state('');
  let recommendation = $state('continue');
  let busy = $state(false);

  $effect(() => {
    if (!open) return;
    untrack(() => {
      phase = startPhase;
      ratings = {};
      notes = '';
      recommendation = 'continue';
      busy = false;
    });
  });

  const phaseOptions = $derived(Array.from({ length: phases }, (_, i) => ({ value: i + 1, label: `Phase ${i + 1}` })));
  const scale = [1, 2, 3, 4, 5].map((v) => ({ value: v, label: String(v), title: ratingWords[v] }));
  const recOptions = recommendations.map((r) => ({ value: r.id, label: r.label, tone: r.tone, title: r.long }));
  const rated = $derived(categories.filter((c) => ratings[c] != null).length);
  const complete = $derived(rated === categories.length && categories.length > 0);
  const average = $derived(rated ? categories.reduce((n, c) => n + (ratings[c] || 0), 0) / rated : null);

  async function submit() {
    if (!complete || busy) return;
    busy = true;
    const res = await request('fto.evaluate', { cid: trainee.cid, phase, ratings: { ...ratings }, notes, recommendation }, { success: `Evaluation saved for ${trainee.name}` });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title="Evaluate {trainee?.name || 'trainee'}" width={700}>
  <div class="top">
    <Field label="Phase"><Segmented options={phaseOptions} bind:value={phase} label="Phase" /></Field>
    <div class="avg {scoreTone(average)}">
      <span class="n mono">{average == null ? '–' : average.toFixed(2)}</span>
      <span class="l">{rated} of {categories.length} rated</span>
    </div>
  </div>

  <div class="ratings">
    <div class="legend"><span>1 Unacceptable</span><span>3 Acceptable</span><span>5 Superior</span></div>
    {#each categories as cat}
      <div class="rate">
        <span class="cat">{cat}</span>
        <Segmented size="sm" mono options={scale} value={ratings[cat]} label="{cat} rating" onchange={(v) => (ratings = { ...ratings, [cat]: v })} />
        <span class="word {scoreTone(ratings[cat])}">{ratings[cat] ? ratingWords[ratings[cat]] : 'Not rated'}</span>
      </div>
    {/each}
  </div>

  <Field label="Notes" id="ev-notes">
    <Textarea id="ev-notes" bind:value={notes} rows={3} maxlength={2000} placeholder="What went well, what needs work, calls handled" />
  </Field>

  <Field label="Recommendation">
    <Segmented full options={recOptions} bind:value={recommendation} label="Recommendation" />
  </Field>

  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="check" busy={busy} disabled={!complete} onclick={submit}>Save evaluation</Button>
  {/snippet}
</Modal>

<style>
  .top { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .avg { display: flex; flex-direction: column; align-items: flex-end; line-height: 1.1; }
  .avg .n { font-size: 26px; font-weight: 600; color: var(--text); }
  .avg .l { color: var(--faint); font-size: 12px; }
  .avg.ok .n { color: var(--ok); }
  .avg.info .n { color: var(--info-text); }
  .avg.p2 .n { color: var(--p2-text); }
  .avg.danger .n { color: var(--danger-text); }
  .ratings { display: flex; flex-direction: column; border: 1px solid var(--line-2); border-radius: var(--radius); background: var(--panel); }
  .legend { display: flex; justify-content: space-between; padding: 8px 12px; color: var(--faint); font-size: 11px; letter-spacing: 0.06em; text-transform: uppercase; border-bottom: 1px solid var(--line); }
  .rate { display: grid; grid-template-columns: 170px auto 1fr; align-items: center; gap: 14px; padding: 7px 12px; border-bottom: 1px solid var(--line); }
  .rate:last-child { border-bottom: 0; }
  .cat { font-weight: 600; color: var(--text); }
  .word { color: var(--faint); font-size: 13px; }
  .word.ok { color: var(--ok); }
  .word.info { color: var(--info-text); }
  .word.p2 { color: var(--p2-text); }
  .word.danger { color: var(--danger-text); }
</style>
