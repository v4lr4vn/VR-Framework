<script>
  import './records/records.css';
  import { onMount } from 'svelte';
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import Mugshot from '../components/Mugshot.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Empty from '../components/Empty.svelte';
  import InmateModal from './records/InmateModal.svelte';
  import { api, on } from '../lib/nui.js';
  import { can, go, clock } from '../lib/state.svelte.js';
  import { agoWords, months_ } from '../lib/format.js';
  import { errorText } from '../lib/lang.js';
  import { clockText } from './records/shared.js';

  let data = $state(null);
  let error = $state('');
  let fetchedAt = $state(0);
  let modal = $state({ open: false, mode: 'adjust', inmate: null });

  async function load() {
    const res = await api('prison.list', {});
    if (!res.ok) {
      error = errorText(res.error);
      return;
    }
    error = '';
    data = res.data;
    fetchedAt = clock.now;
  }

  onMount(load);
  $effect(() => on('prison:changed', () => load()));

  function remaining(i) {
    return i.online ? Math.max(0, i.remaining - (clock.now - fetchedAt)) : i.remaining;
  }

  function progress(i) {
    const total = Math.max(1, i.months * (data?.secondsPerMonth || 60));
    return Math.min(100, Math.max(0, 100 - (remaining(i) / total) * 100));
  }

  $effect(() => {
    if (!data) return;
    if (data.inmates.some((i) => i.online && remaining(i) <= 0)) {
      const t = setTimeout(load, 11000);
      return () => clearTimeout(t);
    }
  });

  function openModal(mode, inmate) {
    modal = { open: true, mode, inmate };
  }

  const manage = $derived(can('prison.manage'));
  const online = $derived(data ? data.inmates.filter((i) => i.online).length : 0);
  const soon = $derived(data ? data.inmates.filter((i) => i.online && remaining(i) <= 600).length : 0);
  const columns = $derived(manage ? 'minmax(0, 1.7fr) 110px minmax(0, 1.5fr) minmax(0, 1.7fr) 130px 190px' : 'minmax(0, 1.7fr) 110px minmax(0, 1.5fr) minmax(0, 1.7fr) 130px');
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Prison</h1>
      <p class="muted">Bolingbroke Penitentiary{#if data}{' · '}one month is {data.secondsPerMonth} seconds served in the city{/if}</p>
    </div>
    {#if data}
      <div class="stats">
        <div class="stat"><span class="n mono">{data.inmates.length}</span><span class="l">Inmates</span></div>
        <div class="stat ok"><span class="n mono">{online}</span><span class="l">Serving now</span></div>
        <div class="stat muted"><span class="n mono">{data.inmates.length - online}</span><span class="l">Paused</span></div>
        <div class="stat accent"><span class="n mono">{soon}</span><span class="l">Out within 10 min</span></div>
      </div>
    {/if}
  </header>

  <div class="body scroll">
    {#if error}
      <Empty icon="alert" title="Couldn't load the prison roll" text={error} />
    {:else if !data}
      <Spinner />
    {:else}
      <section class="rec-section">
        <h2 class="eyebrow">Current inmates · {data.inmates.length}</h2>
        {#if data.inmates.length}
          <div class="rec-rows">
            <div class="rec-head" style:grid-template-columns={columns} aria-hidden="true">
              <span>Inmate</span><span>Sentence</span><span>Time left</span><span>Charges</span><span>Sentenced by</span>{#if manage}<span></span>{/if}
            </div>
            {#each data.inmates as i (i.cid)}
              {@const left = remaining(i)}
              <div class="rec-row inmate" style:grid-template-columns={columns}>
                <button type="button" class="who" onclick={() => go('citizens', { cid: i.cid })}>
                  <Mugshot id={i.mugshot} name={i.name} size={40} />
                  <span class="names">
                    <span class="rec-strong rec-clip nm">{i.name}</span>
                    <span class="mono faint small">{i.cid}</span>
                  </span>
                </button>
                <span class="stack">
                  <span class="mono rec-strong">{months_(i.months)}</span>
                  <span class="rec-sub">since {agoWords(i.since)}</span>
                </span>
                <span class="timer">
                  <span class="tline">
                    <span class="mono clock" class:paused={!i.online} class:soon={i.online && left <= 600}>{clockText(left)}</span>
                    {#if i.online}<Badge tone="ok">Serving</Badge>{:else}<Badge>Paused · away</Badge>{/if}
                  </span>
                  <span class="bar" aria-hidden="true"><span class="fill" class:paused={!i.online} style:width="{progress(i)}%"></span></span>
                </span>
                <span class="rec-clip reason" title={i.reason}>{i.reason}</span>
                <span class="rec-clip">{i.byName || '—'}</span>
                {#if manage}
                  <span class="acts">
                    <Button size="sm" variant="ghost" icon="edit" onclick={() => openModal('adjust', i)}>Adjust</Button>
                    <Button size="sm" variant="danger" icon="unlock" onclick={() => openModal('release', i)}>Release</Button>
                  </span>
                {/if}
              </div>
            {/each}
          </div>
        {:else}
          <Empty icon="lock" title="No one is in prison" text="Inmates appear here when a sentence with jail time is applied." />
        {/if}
      </section>

      {#if data.released.length}
        <section class="rec-section">
          <h2 class="eyebrow">Recently released</h2>
          <div class="rec-rows">
            {#each data.released as r (r.cid)}
              <button type="button" class="rec-row" style:grid-template-columns="minmax(0, 1.7fr) 110px minmax(0, 2fr) minmax(0, 2fr) 130px" onclick={() => go('citizens', { cid: r.cid })}>
                <span class="who plain">
                  <Mugshot id={r.mugshot} name={r.name} size={32} />
                  <span class="rec-strong rec-clip">{r.name}</span>
                </span>
                <span class="mono">{months_(r.months)}</span>
                <span class="rec-clip muted">{r.reason}</span>
                <span class="rec-clip">{r.release_reason}</span>
                <span class="faint">{agoWords(r.released_at)}</span>
              </button>
            {/each}
          </div>
        </section>
      {/if}
    {/if}
  </div>
</div>

<InmateModal bind:open={modal.open} mode={modal.mode} inmate={modal.inmate} remaining={modal.inmate ? remaining(modal.inmate) : 0} maxMonths={data?.maxMonths || 300} perMonth={data?.secondsPerMonth || 60} ondone={load} />

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 16px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .stats { display: flex; gap: 8px; }
  .stat { display: flex; flex-direction: column; align-items: flex-start; padding: 8px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); min-width: 96px; }
  .stat .n { font-size: 20px; font-weight: 600; }
  .stat .l { color: var(--muted); font-size: 12px; }
  .stat.ok .n { color: var(--ok); }
  .stat.accent .n { color: var(--accent); }
  .stat.muted .n { color: var(--text-2); }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding-bottom: 24px; }
  .inmate { min-height: 64px; }
  .inmate:hover { background: rgba(26, 36, 51, 0.5); }
  .who { display: flex; align-items: center; gap: 12px; min-width: 0; border: 0; background: transparent; padding: 0; text-align: left; color: inherit; }
  .who:hover .nm { color: var(--accent); }
  .who.plain { gap: 10px; }
  .names { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
  .nm { font-size: 15px; }
  .small { font-size: 12px; }
  .stack { display: flex; flex-direction: column; gap: 2px; }
  .timer { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .tline { display: flex; align-items: center; gap: 10px; }
  .clock { font-size: 18px; font-weight: 600; color: var(--text); min-width: 76px; }
  .clock.soon { color: var(--ok); }
  .clock.paused { color: var(--muted); }
  .bar { height: 4px; border-radius: 2px; background: var(--panel-2); overflow: hidden; max-width: 220px; }
  .fill { display: block; height: 100%; background: var(--accent); transition: width 0.9s linear; }
  .fill.paused { background: var(--line-3); }
  .reason { color: var(--text-2); }
  .acts { display: flex; gap: 6px; justify-content: flex-end; }
</style>
