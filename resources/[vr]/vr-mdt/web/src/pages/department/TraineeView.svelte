<script>
  import { untrack } from 'svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import EvaluationForm from './EvaluationForm.svelte';
  import { request, can } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { on } from '../../lib/nui.js';
  import { agoWords, date, dateTime } from '../../lib/format.js';
  import { recommendation, scoreTone } from './labels.js';

  let { cid, onchanged } = $props();

  let data = $state(null);
  let loading = $state(true);
  let failed = $state(false);
  let evaluating = $state(false);
  let busy = $state(false);

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('fto.get', { cid }, { quiet: true });
    loading = false;
    failed = !res.ok;
    if (res.ok) data = res.data;
  }

  $effect(() => {
    untrack(() => load());
    return on('fto:changed', (p) => {
      if (p?.cid === cid) load(true);
    });
  });

  const t = $derived(data?.trainee);
  const manage = $derived(can('fto.manage') && t?.isTrainee && !t?.isSelf);
  const latest = $derived(data?.evals?.[0] || null);

  function pct(v) {
    return `${Math.max(0, Math.min(100, ((Number(v) || 0) / 5) * 100))}%`;
  }

  async function signoff() {
    const ok = await confirm({ title: `Sign off ${t.name}?`, text: `${t.name} finishes field training and leaves the trainee list. Their evaluations stay on record.`, yes: 'Sign off' });
    if (!ok) return;
    busy = true;
    const res = await request('fto.signoff', { cid }, { success: `${t.name} signed off` });
    busy = false;
    if (res.ok) {
      await load(true);
      onchanged?.();
    }
  }

  function saved() {
    load(true);
    onchanged?.();
  }
</script>

<section class="view">
  {#if loading && !data}
    <Spinner label="Loading trainee" />
  {:else if failed || !data}
    <Empty icon="alert" title="Couldn't load this trainee" text="They may have left the department." />
  {:else}
    <header class="head">
      <Mugshot name={t.name} size={56} />
      <div class="who">
        <span class="cs mono" class:none={!t.callsign}>{t.callsign || 'No callsign'}</span>
        <h2>{t.name}</h2>
        <span class="sub">{t.gradeName}{t.hiredAt ? ` · hired ${date(t.hiredAt)}` : ''}</span>
      </div>
      <div class="acts">
        {#if !t.isTrainee}<Badge tone="ok">Training complete</Badge>{/if}
        {#if t.isSelf}<Badge>This is you</Badge>{/if}
        {#if manage}
          <Button icon="award" busy={busy} onclick={signoff}>Sign off</Button>
          <Button variant="primary" icon="clipboard" onclick={() => (evaluating = true)}>New evaluation</Button>
        {/if}
      </div>
    </header>

    <div class="scrollarea scroll">
      <div class="phases" style:--n={data.phases} aria-label="Training phase {data.phase} of {data.phases}">
        {#each Array.from({ length: data.phases }, (_, i) => i + 1) as p}
          <div class="ph" class:done={p < data.phase || !t.isTrainee} class:now={p === data.phase && t.isTrainee}>
            <span class="bar"></span>
            <span class="pl">Phase {p}</span>
          </div>
        {/each}
      </div>

      <div class="tiles">
        <div class="tile"><span class="n mono">{data.evals.length}</span><span class="l">Evaluations</span></div>
        <div class="tile {scoreTone(data.average)}"><span class="n mono">{data.average != null ? data.average.toFixed(2) : '–'}</span><span class="l">Average of 5</span></div>
        <div class="tile"><span class="n">{#if latest}<Badge tone={recommendation(latest.recommendation).tone}>{recommendation(latest.recommendation).label}</Badge>{:else}–{/if}</span><span class="l">Latest recommendation</span></div>
        <div class="tile"><span class="n">{latest ? agoWords(latest.at) : 'Never'}</span><span class="l">Last evaluated{latest ? ` by ${latest.ftoName}` : ''}</span></div>
      </div>

      <div class="cols">
        <div class="card cats">
          <h3 class="eyebrow">Average by category</h3>
          {#each data.averages as a}
            <div class="cat">
              <span class="cn">{a.category}</span>
              <span class="track"><span class="fill {scoreTone(a.value)}" style:width={pct(a.value)}></span></span>
              <span class="cv mono">{a.value != null ? a.value.toFixed(1) : '–'}</span>
            </div>
          {/each}
        </div>

        <div class="history">
          <h3 class="eyebrow">Evaluation history</h3>
          {#each data.evals as e (e.id)}
            {@const r = recommendation(e.recommendation)}
            <article class="ev">
              <header>
                <span class="score mono {scoreTone(e.score)}">{e.score.toFixed(2)}</span>
                <div class="evm">
                  <span class="evt">Phase {e.phase}{' · '}{e.ftoName}</span>
                  <span class="evd" title={dateTime(e.at)}>{dateTime(e.at)}</span>
                </div>
                <Badge tone={r.tone}>{r.label}</Badge>
              </header>
              <div class="minis">
                {#each e.ratings as rt}
                  <div class="mini" title="{rt.category}: {rt.value ?? 'not rated'}">
                    <span class="ml">{rt.category}</span>
                    <span class="segs">
                      {#each [1, 2, 3, 4, 5] as v}<span class="seg {v <= (rt.value || 0) ? scoreTone(rt.value) : ''}"></span>{/each}
                    </span>
                  </div>
                {/each}
              </div>
              {#if e.notes}<p class="notes">{e.notes}</p>{/if}
            </article>
          {:else}
            <Empty icon="clipboard" title="No evaluations yet" text={manage ? 'Write the first evaluation after a ride-along.' : 'Field training officers write evaluations after each shift.'} />
          {/each}
        </div>
      </div>
    </div>

    {#if manage}
      <EvaluationForm bind:open={evaluating} trainee={t} categories={data.categories} phases={data.phases} phase={data.phase} onsaved={saved} />
    {/if}
  {/if}
</section>

<style>
  .view { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; }
  .head { display: flex; align-items: center; gap: 14px; padding: 18px 24px 16px; border-bottom: 1px solid var(--line); }
  .who { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.2; }
  .cs { color: var(--accent); font-weight: 600; font-size: 13px; }
  .cs.none { color: var(--faint); }
  h2 { font-size: 22px; font-weight: 700; }
  .sub { color: var(--muted); }
  .acts { display: flex; align-items: center; gap: 8px; }
  .scrollarea { flex: 1; min-height: 0; padding: 16px 24px 24px; display: flex; flex-direction: column; gap: 16px; }
  .phases { display: grid; grid-template-columns: repeat(var(--n, 4), minmax(0, 1fr)); gap: 6px; }
  .ph { display: flex; flex-direction: column; gap: 6px; }
  .bar { height: 6px; border-radius: 3px; background: var(--panel-2); }
  .ph.done .bar { background: var(--ok); }
  .ph.now .bar { background: var(--accent); }
  .pl { font-size: 12px; color: var(--faint); font-weight: 600; }
  .ph.now .pl { color: var(--accent); }
  .ph.done .pl { color: var(--text-2); }
  .tiles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
  .tile { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); min-width: 0; }
  .tile .n { font-size: 20px; font-weight: 600; min-height: 26px; display: flex; align-items: center; }
  .tile .l { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tile.ok .n { color: var(--ok); }
  .tile.info .n { color: var(--info-text); }
  .tile.p2 .n { color: var(--p2-text); }
  .tile.danger .n { color: var(--danger-text); }
  .cols { display: grid; grid-template-columns: 330px minmax(0, 1fr); gap: 16px; align-items: start; }
  .card { padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 10px; }
  .cat { display: grid; grid-template-columns: 120px 1fr 30px; align-items: center; gap: 10px; }
  .cn { color: var(--text-2); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .track { height: 8px; border-radius: 4px; background: var(--bg-2); overflow: hidden; }
  .fill { display: block; height: 100%; border-radius: 4px; background: var(--muted); }
  .fill.ok, .seg.ok { background: var(--ok); }
  .fill.info, .seg.info { background: var(--info); }
  .fill.p2, .seg.p2 { background: var(--p2); }
  .fill.danger, .seg.danger { background: var(--danger); }
  .cv { text-align: right; font-size: 13px; color: var(--text); }
  .history { display: flex; flex-direction: column; gap: 10px; min-width: 0; }
  .ev { padding: 12px 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 10px; }
  .ev header { display: flex; align-items: center; gap: 12px; }
  .score { font-size: 20px; font-weight: 600; width: 56px; color: var(--text); }
  .score.ok { color: var(--ok); }
  .score.info { color: var(--info-text); }
  .score.p2 { color: var(--p2-text); }
  .score.danger { color: var(--danger-text); }
  .evm { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.25; }
  .evt { font-weight: 600; color: var(--text); }
  .evd { color: var(--faint); font-size: 12px; }
  .minis { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px 18px; }
  .mini { display: flex; align-items: center; justify-content: space-between; gap: 8px; min-width: 0; }
  .ml { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .segs { display: flex; gap: 2px; flex: none; }
  .seg { width: 12px; height: 6px; border-radius: 2px; background: var(--panel-3); }
  .notes { color: var(--text-2); line-height: 1.5; white-space: pre-wrap; border-top: 1px solid var(--line); padding-top: 8px; }
</style>
