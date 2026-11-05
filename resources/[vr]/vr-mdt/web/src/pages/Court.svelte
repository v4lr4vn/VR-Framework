<script>
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import Checkbox from '../components/Checkbox.svelte';
  import Empty from '../components/Empty.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Tabs from '../components/Tabs.svelte';
  import CaseView from './court/CaseView.svelte';
  import CaseModal from './court/CaseModal.svelte';
  import HearingStrip from './court/HearingStrip.svelte';
  import { api, on } from '../lib/nui.js';
  import { can, go } from '../lib/state.svelte.js';
  import { agoWords } from '../lib/format.js';
  import { statusLabels, statusTone, verdictLabels, hearingParts } from './court/meta.js';

  let { params = {} } = $props();

  let tab = $state('open');
  let q = $state('');
  let mine = $state(false);
  let page = $state(1);
  let data = $state(null);
  let error = $state('');
  let loading = $state(false);
  let calendar = $state({ hearings: [], courtrooms: [], days: 14 });
  let calLoading = $state(true);
  let creating = $state(false);
  let openTotal = $state(null);
  let seq = 0;

  const caseId = $derived(params.id ? Number(params.id) : null);

  async function load() {
    const mineSeq = ++seq;
    loading = true;
    const res = await api('court.list', { status: tab, q: q.trim(), mine, page });
    if (mineSeq !== seq) return;
    loading = false;
    if (res.ok) {
      data = res.data;
      error = '';
      if (!q.trim() && !mine) openTotal = res.data.counts.open;
    } else {
      error = res.error;
    }
  }

  async function loadCalendar() {
    const res = await api('court.calendar', {});
    calLoading = false;
    if (res.ok) calendar = res.data;
  }

  $effect(() => {
    tab;
    mine;
    page;
    if (!caseId) load();
  });

  $effect(() => {
    loadCalendar();
  });

  $effect(() => on('court:changed', () => {
    if (!caseId) load();
    loadCalendar();
  }));

  function search(term) {
    q = term;
    page = 1;
    load();
  }

  const tabs = $derived([
    { id: 'open', label: 'Open', count: data?.counts?.open },
    { id: 'scheduled', label: 'Scheduled', count: data?.counts?.scheduled },
    { id: 'in_session', label: 'In session', count: data?.counts?.in_session },
    { id: 'verdict', label: 'Verdict', count: data?.counts?.verdict },
    { id: 'closed', label: 'Closed', count: data?.counts?.closed },
    { id: 'dismissed', label: 'Dismissed', count: data?.counts?.dismissed },
    { id: 'all', label: 'All', count: data?.counts?.all },
  ]);

  const week = $derived(calendar.hearings.filter((h) => h.hearingAt < Date.now() / 1000 + 7 * 86400).length);
</script>

{#if caseId}
  <CaseView id={caseId} courtrooms={calendar.courtrooms} />
{:else}
  <div class="page">
    <header class="ph">
      <div>
        <h1>Court cases</h1>
        <p class="muted">{openTotal != null ? `${openTotal} open` : '—'}{' · '}{week} {week === 1 ? 'hearing' : 'hearings'} in the next 7 days</p>
      </div>
      <div class="tools">
        <div class="search"><SearchBox bind:value={q} placeholder="Search number, title or defendant" onsearch={search} /></div>
        <Checkbox id="court-mine" bind:checked={mine} label="My cases" onchange={() => (page = 1)} />
        {#if can('court.manage')}
          <Button variant="primary" icon="plus" onclick={() => (creating = true)}>New case</Button>
        {/if}
      </div>
    </header>

    <HearingStrip hearings={calendar.hearings} days={calendar.days} loading={calLoading} />

    <Tabs {tabs} bind:value={tab} onchange={() => (page = 1)} />

    <div class="body scroll">
      {#if error}
        <Empty icon="alert" title="Couldn't load cases" text="Something went wrong. Try again in a moment.">
          <Button icon="refresh" onclick={load}>Retry</Button>
        </Empty>
      {:else if !data}
        <Spinner label="Loading cases" />
      {:else if !data.rows.length}
        <Empty icon="court" title={q ? 'No matching cases' : 'No cases here'} text={q ? `Nothing matches "${q}".` : mine ? "You're not a party to any case in this list." : 'Cases filed by the DA or the court show up here.'} />
      {:else}
        <table class:dim={loading}>
          <thead>
            <tr><th class="c-num">Number</th><th>Case</th><th>Defendant</th><th>Judge</th><th class="c-hear">Hearing</th><th class="c-st">Status</th><th class="c-up">Updated</th></tr>
          </thead>
          <tbody>
            {#each data.rows as r (r.id)}
              {@const h = hearingParts(r.hearingAt)}
              <tr class:mine={r.mine}>
                <td class="mono num">{r.number}</td>
                <td>
                  <button type="button" class="open" onclick={() => go('court', { id: r.id })}>{r.title}</button>
                  <span class="cc">{r.chargeCount} {r.chargeCount === 1 ? 'charge' : 'charges'}</span>
                </td>
                <td class="trunc">{r.defendant}</td>
                <td class="trunc muted">{r.judge || '—'}</td>
                <td class="mono">{#if h && ['scheduled', 'in_session'].includes(r.status)}<span class="hd">{h.rel || h.date}</span> {h.time}{:else}<span class="faint">—</span>{/if}</td>
                <td>
                  <Badge tone={statusTone(r.status)}>{statusLabels[r.status]}</Badge>
                  {#if r.verdict && r.status !== 'dismissed'}<span class="vd">{verdictLabels[r.verdict]}</span>{/if}
                </td>
                <td class="muted up">{agoWords(r.updatedAt)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        {#if data.more || page > 1}
          <div class="pager">
            <Button size="sm" icon="back" disabled={page <= 1} onclick={() => (page -= 1)}>Newer</Button>
            <span class="mono muted">Page {page}</span>
            <Button size="sm" iconRight="chevron" disabled={!data.more} onclick={() => (page += 1)}>Older</Button>
          </div>
        {/if}
      {/if}
    </div>
  </div>

  <CaseModal bind:open={creating} onsaved={(c) => go('court', { id: c.id })} />
{/if}

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 14px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .tools { display: flex; align-items: center; gap: 14px; }
  .search { width: 320px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding-bottom: 20px; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; transition: opacity 0.15s; }
  table.dim { opacity: 0.6; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 12px; border-bottom: 1px solid var(--line-2); }
  .c-num { width: 140px; }
  .c-hear { width: 150px; }
  .c-st { width: 190px; }
  .c-up { width: 110px; }
  td { padding: 9px 12px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  tbody tr { position: relative; }
  tbody tr:hover td { background: var(--panel); }
  tr.mine td:first-child { box-shadow: inset 2px 0 0 var(--doj); }
  .num { color: var(--doj-text); font-weight: 600; }
  .open { border: 0; background: transparent; padding: 0; color: var(--text); font-weight: 600; text-align: left; max-width: 100%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: block; }
  .open::after { content: ''; position: absolute; inset: 0; }
  tbody tr:hover .open { color: var(--accent); }
  .cc { color: var(--faint); font-size: 12px; }
  .trunc { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .hd { color: var(--info-text); font-family: var(--font); margin-right: 4px; }
  .vd { margin-left: 8px; color: var(--muted); font-size: 12px; }
  .up { font-size: 13px; }
  .pager { display: flex; align-items: center; justify-content: center; gap: 12px; padding-top: 14px; }
</style>
