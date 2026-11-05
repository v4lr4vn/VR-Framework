<script>
  import { untrack } from 'svelte';
  import ReportCard from './reports/ReportCard.svelte';
  import ReportView from './reports/ReportView.svelte';
  import ReportEditor from './reports/ReportEditor.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Button from '../components/Button.svelte';
  import IconButton from '../components/IconButton.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Select from '../components/Select.svelte';
  import { api, on } from '../lib/nui.js';
  import { can, go, back } from '../lib/state.svelte.js';
  import { errorText } from '../lib/lang.js';
  import { loadPenal } from './reports/penal.svelte.js';
  import { reportTypes } from './reports/util.js';

  let { params = {} } = $props();

  let q = $state('');
  let term = $state('');
  let type = $state('');
  let mine = $state(false);
  let page = $state(1);
  let list = $state({ items: [], total: 0, pages: 1 });
  let listState = $state('loading');
  let listError = $state('');
  let current = $state(null);
  let detailState = $state('idle');
  let detailError = $state('');
  let editing = $state(false);
  let seq = 0;
  let refreshTimer;

  const canCreate = $derived(can('reports.create'));
  const mode = $derived(params.new ? 'new' : params.id ? 'report' : 'none');
  const typeOptions = [{ value: '', label: 'All types' }, ...reportTypes];

  async function loadList() {
    const mine_ = ++seq;
    if (!list.items.length) listState = 'loading';
    const res = await api('reports.list', { q: term, type, mine, page });
    if (mine_ !== seq) return;
    if (!res.ok) {
      listState = 'error';
      listError = errorText(res.error);
      return;
    }
    list = res.data;
    listState = 'ready';
    if (page > res.data.pages) page = res.data.pages;
  }

  async function loadReport(id) {
    detailState = 'loading';
    const res = await api('reports.get', { id });
    if (Number(params.id) !== id) return;
    if (!res.ok) {
      detailState = 'error';
      detailError = errorText(res.error);
      current = null;
      return;
    }
    current = res.data;
    detailState = 'ready';
  }

  $effect(() => {
    term; type; mine; page;
    untrack(loadList);
  });

  $effect(() => {
    untrack(() => loadPenal(false));
  });

  function openReport(id) {
    editing = false;
    if (!id) {
      current = null;
      detailState = 'idle';
      return;
    }
    if (current?.id === id && detailState === 'ready') return;
    loadReport(id);
  }

  $effect(() => {
    const id = Number(params.id);
    untrack(() => openReport(id));
  });

  $effect(() => {
    const offChanged = on('reports:changed', (p) => {
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(loadList, 300);
      if (current && p?.id === current.id && !editing) {
        if (p.deleted) go('reports', {});
        else loadReport(current.id);
      }
    });
    return () => {
      offChanged();
      clearTimeout(refreshTimer);
    };
  });

  function setMine(v) {
    mine = v;
    page = 1;
  }

  function saved(r) {
    current = r;
    detailState = 'ready';
    editing = false;
    if (Number(params.id) !== r.id) go('reports', { id: r.id });
    loadList();
  }

  function cancelEdit() {
    if (mode === 'new') back('reports');
    else editing = false;
  }

  function deleted() {
    current = null;
    go('reports', {});
    loadList();
  }
</script>

<div class="reports">
  <section class="listpane" aria-label="Reports">
    <div class="head">
      <h2>REPORTS</h2>
      <span class="mono muted">{list.total}</span>
      <span class="grow"></span>
      {#if canCreate}<Button size="sm" icon="plus" onclick={() => go('reports', { new: 1 })}>New</Button>{/if}
    </div>
    <div class="tools">
      <SearchBox bind:value={q} placeholder="Title, person, officer or #number" onsearch={(v) => { term = v; page = 1; }} />
      <div class="filters">
        <div class="seg" role="tablist" aria-label="Whose reports">
          <button type="button" role="tab" class="f" class:on={!mine} aria-selected={!mine} onclick={() => setMine(false)}>All</button>
          {#if canCreate}<button type="button" role="tab" class="f" class:on={mine} aria-selected={mine} onclick={() => setMine(true)}>Mine</button>{/if}
        </div>
        <div class="tsel"><Select bind:value={type} options={typeOptions} onchange={() => (page = 1)} aria-label="Report type" /></div>
      </div>
    </div>
    <div class="list scroll">
      {#if listState === 'loading'}
        <Spinner label="Loading reports" />
      {:else if listState === 'error'}
        <Empty icon="alert" title="Couldn't load reports" text={listError}>
          <Button size="sm" icon="refresh" onclick={loadList}>Try again</Button>
        </Empty>
      {:else}
        {#each list.items as r (r.id)}
          <ReportCard report={r} selected={current?.id === r.id && mode === 'report'} onselect={() => go('reports', { id: r.id })} />
        {:else}
          <Empty icon="report" title={term || type || mine ? 'No matching reports' : 'No reports yet'} text={term || type || mine ? 'Try a different search or filter.' : 'Filed reports show up here.'} />
        {/each}
      {/if}
    </div>
    {#if list.pages > 1}
      <div class="pager">
        <IconButton icon="back" label="Previous page" disabled={page <= 1} onclick={() => (page = page - 1)} />
        <span class="mono">Page {page} of {list.pages}</span>
        <IconButton icon="chevron" label="Next page" disabled={page >= list.pages} onclick={() => (page = page + 1)} />
      </div>
    {/if}
  </section>

  <section class="detail" aria-label="Report">
    {#if mode === 'new'}
      {#if canCreate}
        {#key params}
          <ReportEditor prefill={params} oncancel={cancelEdit} onsaved={saved} />
        {/key}
      {:else}
        <Empty icon="lock" title="You can't write reports" text="Your rank doesn't have permission to file reports." />
      {/if}
    {:else if mode === 'report'}
      {#if detailState === 'loading' && !current}
        <Spinner label="Loading the report" />
      {:else if detailState === 'error'}
        <Empty icon="report" title="Report not available" text={detailError}>
          <Button size="sm" onclick={() => go('reports', {})}>Back to the list</Button>
        </Empty>
      {:else if current}
        {#if editing}
          {#key current.id}
            <ReportEditor report={current} oncancel={cancelEdit} onsaved={saved} />
          {/key}
        {:else}
          <div class="scrollwrap scroll">
            <ReportView report={current} onedit={() => (editing = true)} onchanged={(r) => (current = r)} ondeleted={deleted} />
          </div>
        {/if}
      {/if}
    {:else}
      <Empty icon="report" title="Select a report" text={canCreate ? 'Pick a report on the left, or file a new one.' : 'Pick a report on the left to read it.'}>
        {#if canCreate}<Button variant="primary" icon="plus" onclick={() => go('reports', { new: 1 })}>New report</Button>{/if}
      </Empty>
    {/if}
  </section>
</div>

<style>
  .reports { flex: 1; display: flex; min-height: 0; }
  .listpane { width: 360px; flex: none; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: center; gap: 8px; padding: 14px 16px 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .grow { flex: 1; }
  .tools { display: flex; flex-direction: column; gap: 8px; padding: 0 12px 10px; }
  .filters { display: flex; gap: 8px; align-items: center; }
  .seg { display: flex; gap: 4px; }
  .f { height: 28px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; }
  .f:hover { color: var(--text); }
  .f.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .tsel { flex: 1; min-width: 0; }
  .tsel :global(.sel) { height: 30px; font-size: 13px; }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 0 12px 12px; }
  .pager { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 8px 12px; border-top: 1px solid var(--line); color: var(--muted); font-size: 12px; }
  .detail { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; position: relative; }
  .scrollwrap { flex: 1; min-height: 0; }
</style>
