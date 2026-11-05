<script>
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import Empty from '../components/Empty.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Tabs from '../components/Tabs.svelte';
  import ReportEditor from './ems/ReportEditor.svelte';
  import ReportView from './ems/ReportView.svelte';
  import { api, on } from '../lib/nui.js';
  import { go, can } from '../lib/state.svelte.js';
  import { date, time } from '../lib/format.js';
  import { types, outcomes, labelOf, typeTone, outcomeTone } from './ems/meta.js';

  let { params = {} } = $props();

  let tab = $state('all');
  let q = $state('');
  let page = $state(1);
  let data = $state(null);
  let error = $state('');
  let loading = $state(false);
  let seq = 0;

  const mode = $derived(params.edit ? 'edit' : params.id ? 'view' : 'list');
  const editId = $derived(params.edit && params.edit !== 'new' ? Number(params.edit) : null);

  async function load() {
    const mine = ++seq;
    loading = true;
    const res = await api('medreports.list', { mine: tab === 'mine', q: q.trim(), page });
    if (mine !== seq) return;
    loading = false;
    if (res.ok) {
      data = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    tab;
    page;
    if (mode === 'list') load();
  });

  $effect(() => on('medreports:changed', () => { if (mode === 'list') load(); }));

  function search(term) {
    q = term;
    page = 1;
    load();
  }

  const tabs = [
    { id: 'all', label: 'All reports' },
    { id: 'mine', label: 'Written by me' },
  ];
</script>

{#if mode === 'edit'}
  <ReportEditor id={editId} cid={params.cid || null} name={params.name || null} />
{:else if mode === 'view'}
  <ReportView id={Number(params.id)} />
{:else}
  <div class="page">
    <header class="ph">
      <div>
        <h1>Medical reports</h1>
        <p class="muted">Treatment, transport and check-up records</p>
      </div>
      <div class="tools">
        <div class="search"><SearchBox bind:value={q} placeholder="Search title, patient or medic" onsearch={search} /></div>
        {#if can('medreports.create')}
          <Button variant="primary" icon="plus" onclick={() => go('medreports', { edit: 'new' })}>New report</Button>
        {/if}
      </div>
    </header>

    <Tabs {tabs} bind:value={tab} onchange={() => (page = 1)} />

    <div class="body scroll">
      {#if error}
        <Empty icon="alert" title="Couldn't load reports" text="Something went wrong. Try again in a moment.">
          <Button icon="refresh" onclick={load}>Retry</Button>
        </Empty>
      {:else if !data}
        <Spinner label="Loading reports" />
      {:else if !data.rows.length}
        <Empty icon="report" title={q ? 'No matching reports' : tab === 'mine' ? "You haven't written any reports" : 'No reports yet'} text={q ? `Nothing matches "${q}".` : 'Reports you and other medics write show up here.'} />
      {:else}
        <table class:dim={loading}>
          <thead>
            <tr><th class="c-id">Report</th><th>Title</th><th class="c-pt">Patient</th><th class="c-ty">Type</th><th class="c-inj">Injuries</th><th class="c-out">Outcome</th><th class="c-by">Medic</th><th class="c-at">Written</th></tr>
          </thead>
          <tbody>
            {#each data.rows as r (r.id)}
              <tr>
                <td class="mono num">MR-{r.id}</td>
                <td class="trunc"><button type="button" class="open" onclick={() => go('medreports', { id: r.id })}>{r.title}</button></td>
                <td class="trunc" class:unid={!r.cid} title={r.cid ? r.cid : 'Unidentified patient'}>{r.name}</td>
                <td><Badge tone={typeTone(r.type)}>{labelOf(types, r.type)}</Badge></td>
                <td class="mono">{#if r.injuryCount}{r.injuryCount}{:else}<span class="faint">—</span>{/if}</td>
                <td>{#if r.outcome}<span class="out {outcomeTone(r.outcome)}">{labelOf(outcomes, r.outcome)}</span>{:else}<span class="faint">—</span>{/if}</td>
                <td class="trunc"><span class="mono cs">{r.author?.callsign || ''}</span> {r.author?.name}</td>
                <td class="mono muted at">{date(r.createdAt)} {time(r.createdAt)}</td>
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
{/if}

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 14px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .tools { display: flex; align-items: center; gap: 12px; }
  .search { width: 320px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding-bottom: 20px; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; transition: opacity 0.15s; }
  table.dim { opacity: 0.6; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 12px; border-bottom: 1px solid var(--line-2); }
  .c-id { width: 100px; }
  .c-pt { width: 200px; }
  .c-ty { width: 110px; }
  .c-inj { width: 84px; }
  .c-out { width: 170px; }
  .c-by { width: 190px; }
  .c-at { width: 172px; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  tbody tr { position: relative; }
  tbody tr:hover td { background: var(--panel); }
  .num { color: var(--ems-text); font-weight: 600; }
  .open { border: 0; background: transparent; padding: 0; color: var(--text); font-weight: 600; text-align: left; max-width: 100%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: block; }
  .open::after { content: ''; position: absolute; inset: 0; }
  tbody tr:hover .open { color: var(--accent); }
  .trunc { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .out { font-size: 13px; font-weight: 600; }
  .out.ok { color: var(--ok); }
  .out.info { color: var(--info-text); }
  .out.accent { color: var(--accent); }
  .out.danger { color: var(--danger-text); }
  .out.muted { color: var(--muted); }
  .cs { color: var(--ems-text); font-size: 12px; }
  .at { font-size: 13px; white-space: nowrap; }
  .unid { color: var(--text-2); font-style: italic; }
  .pager { display: flex; align-items: center; justify-content: center; gap: 12px; padding-top: 14px; }
</style>
