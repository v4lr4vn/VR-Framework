<script>
  import { untrack } from 'svelte';
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import TraineeView from './department/TraineeView.svelte';
  import { request, go } from '../lib/state.svelte.js';
  import { on } from '../lib/nui.js';
  import { agoWords } from '../lib/format.js';
  import { recommendation, scoreTone } from './department/labels.js';

  let { params = {} } = $props();

  let data = $state(null);
  let loading = $state(true);
  let failed = $state(false);
  let selected = $state(untrack(() => params.cid || null));
  let timer;

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('fto.list', {}, { quiet: true });
    loading = false;
    failed = !res.ok && !data;
    if (res.ok) {
      data = res.data;
      if (!selected && data.trainees.length) selected = data.trainees[0].cid;
    }
  }

  $effect(() => {
    untrack(() => load());
    const off = on('fto:changed', () => {
      clearTimeout(timer);
      timer = setTimeout(() => load(true), 250);
    });
    return () => {
      off();
      clearTimeout(timer);
    };
  });

  const trainees = $derived(data?.trainees || []);
</script>

<div class="fto">
  <aside class="list" aria-label="Trainees">
    <div class="head">
      <h2>TRAINEES</h2>
      <span class="mono muted">{trainees.length}</span>
    </div>
    <div class="cards scroll">
      {#if loading && !data}
        <Spinner label="Loading trainees" />
      {:else if failed}
        <Empty icon="alert" title="Couldn't load trainees">
          <Button icon="refresh" onclick={() => load()}>Try again</Button>
        </Empty>
      {:else}
        {#each trainees as t (t.cid)}
          {@const r = t.last ? recommendation(t.last.recommendation) : null}
          <button type="button" class="card" class:sel={selected === t.cid} aria-pressed={selected === t.cid} onclick={() => (selected = t.cid)}>
            <div class="row">
              <span class="ph mono">P{t.phase}</span>
              <span class="name">{t.name}</span>
              <span class="avg mono {scoreTone(t.average)}">{t.average != null ? t.average.toFixed(2) : '–'}</span>
            </div>
            <span class="sub">{#if t.callsign}<span class="mono">{t.callsign}</span>{' · '}{/if}{t.gradeName}{' · '}{t.evals} evaluation{t.evals === 1 ? '' : 's'}</span>
            {#if t.last}
              <span class="last">{agoWords(t.last.at)}{' · '}<span class="rec {r.tone}">{r.label}</span></span>
            {:else}
              <span class="last none">Not evaluated yet</span>
            {/if}
          </button>
        {:else}
          <Empty icon="grad" title="No trainees" text="Members with the {data?.division || 'Trainee'} division show up here." />
        {/each}
      {/if}
    </div>
    <p class="hint">Add or remove the {data?.division || 'Trainee'} division on the <button type="button" class="link" onclick={() => go('roster')}>roster</button>.</p>
  </aside>

  {#if selected}
    {#key selected}
      <TraineeView cid={selected} onchanged={() => load(true)} />
    {/key}
  {:else}
    <div class="empty"><Empty icon="clipboard" title="Pick a trainee" text="Their phase, scores and evaluation history show here." /></div>
  {/if}
</div>

<style>
  .fto { flex: 1; display: flex; min-height: 0; }
  .list { width: 340px; flex: none; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: center; gap: 8px; padding: 16px 16px 10px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .cards { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 0 12px 12px; }
  .card { display: flex; flex-direction: column; gap: 4px; padding: 11px 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: var(--text); flex: none; }
  .card:hover { border-color: var(--line-3); background: #141c29; }
  .card.sel, .card.sel:hover { background: var(--panel-2); border-color: var(--accent); }
  .row { display: flex; align-items: center; gap: 8px; }
  .ph { font-size: 12px; font-weight: 600; padding: 0 6px; border-radius: 4px; background: var(--accent-soft); color: var(--p2-text); }
  .name { flex: 1; min-width: 0; font-weight: 600; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .avg { font-weight: 600; color: var(--muted); }
  .avg.ok { color: var(--ok); }
  .avg.info { color: var(--info-text); }
  .avg.p2 { color: var(--p2-text); }
  .avg.danger { color: var(--danger-text); }
  .sub { color: var(--muted); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .last { color: var(--faint); font-size: 12px; }
  .last.none { color: var(--p1-text); }
  .rec.ok { color: var(--ok); }
  .rec.p2 { color: var(--p2-text); }
  .rec.danger { color: var(--danger-text); }
  .rec.info { color: var(--info-text); }
  .hint { padding: 10px 16px 14px; border-top: 1px solid var(--line); color: var(--faint); font-size: 12px; }
  .link { border: 0; background: transparent; padding: 0; color: var(--accent); font-weight: 600; font-size: 12px; }
  .empty { flex: 1; display: flex; }
</style>
