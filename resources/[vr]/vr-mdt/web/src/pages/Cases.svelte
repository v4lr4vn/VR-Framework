<script>
  import { untrack } from 'svelte';
  import CaseCard from './cases/CaseCard.svelte';
  import CaseView from './cases/CaseView.svelte';
  import CaseEditor from './cases/CaseEditor.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Button from '../components/Button.svelte';
  import IconButton from '../components/IconButton.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import { api, on } from '../lib/nui.js';
  import { can, go } from '../lib/state.svelte.js';
  import { errorText } from '../lib/lang.js';

  let { params = {} } = $props();

  let q = $state('');
  let term = $state('');
  let status = $state('open');
  let page = $state(1);
  let list = $state({ items: [], total: 0, pages: 1 });
  let listState = $state('loading');
  let listError = $state('');
  let current = $state(null);
  let detailState = $state('idle');
  let detailError = $state('');
  let creating = $state(false);
  let seq = 0;
  let timer;

  const manage = $derived(can('cases.manage'));
  const filters = [
    { id: 'open', label: 'Open' },
    { id: 'cold', label: 'Cold' },
    { id: 'closed', label: 'Closed' },
    { id: '', label: 'All' },
  ];

  async function loadList() {
    const mine = ++seq;
    if (!list.items.length) listState = 'loading';
    const res = await api('cases.list', { q: term, status, page });
    if (mine !== seq) return;
    if (!res.ok) {
      listState = 'error';
      listError = errorText(res.error);
      return;
    }
    list = res.data;
    listState = 'ready';
  }

  async function loadCase(id) {
    detailState = 'loading';
    const res = await api('cases.get', { id });
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

  function openCase(id) {
    if (!id) {
      current = null;
      detailState = 'idle';
      return;
    }
    if (current?.id === id && detailState === 'ready') return;
    loadCase(id);
  }

  $effect(() => {
    term; status; page;
    untrack(loadList);
  });

  $effect(() => {
    const id = Number(params.id);
    untrack(() => openCase(id));
  });

  $effect(() => {
    const offs = [
      on('cases:changed', (p) => {
        clearTimeout(timer);
        timer = setTimeout(loadList, 300);
        if (current && p?.id === current.id) loadCase(current.id);
      }),
      on('evidence:changed', (p) => {
        if (current && p?.caseId === current.id) loadCase(current.id);
      }),
    ];
    return () => {
      offs.forEach((off) => off());
      clearTimeout(timer);
    };
  });

  function changed(c) {
    current = c;
    detailState = 'ready';
    loadList();
  }

  function created(c) {
    current = c;
    detailState = 'ready';
    status = c.status;
    go('cases', { id: c.id });
    loadList();
  }
</script>

<div class="cases">
  <section class="listpane" aria-label="Cases">
    <div class="head">
      <h2>CASES</h2>
      <span class="mono muted">{list.total}</span>
      <span class="grow"></span>
      {#if manage}<Button size="sm" icon="plus" onclick={() => (creating = true)}>New</Button>{/if}
    </div>
    <div class="tools">
      <SearchBox bind:value={q} placeholder="Title, person or #number" onsearch={(v) => { term = v; page = 1; }} />
      <div class="seg" role="tablist" aria-label="Case status">
        {#each filters as f}
          <button type="button" role="tab" class="f" class:on={status === f.id} aria-selected={status === f.id} onclick={() => { status = f.id; page = 1; }}>{f.label}</button>
        {/each}
      </div>
    </div>
    <div class="list scroll">
      {#if listState === 'loading'}
        <Spinner label="Loading cases" />
      {:else if listState === 'error'}
        <Empty icon="alert" title="Couldn't load cases" text={listError}>
          <Button size="sm" icon="refresh" onclick={loadList}>Try again</Button>
        </Empty>
      {:else}
        {#each list.items as c (c.id)}
          <CaseCard item={c} selected={current?.id === c.id} onselect={() => go('cases', { id: c.id })} />
        {:else}
          <Empty icon="folder" title={term ? 'No matching cases' : status ? `No ${status} cases` : 'No cases yet'} text={manage && !term ? 'Open a case to group reports and evidence.' : ''} />
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

  <section class="detail" aria-label="Case">
    {#if params.id}
      {#if detailState === 'loading' && !current}
        <Spinner label="Loading the case" />
      {:else if detailState === 'error'}
        <Empty icon="folder" title="Case not available" text={detailError}>
          <Button size="sm" onclick={() => go('cases', {})}>Back to the list</Button>
        </Empty>
      {:else if current}
        <div class="scrollwrap scroll">
          <CaseView item={current} onchanged={changed} />
        </div>
      {/if}
    {:else}
      <Empty icon="folder" title="Select a case" text="Cases group reports, people and evidence for one investigation.">
        {#if manage}<Button variant="primary" icon="plus" onclick={() => (creating = true)}>Open a case</Button>{/if}
      </Empty>
    {/if}
  </section>
</div>

<CaseEditor bind:open={creating} onsaved={created} />

<style>
  .cases { flex: 1; display: flex; min-height: 0; }
  .listpane { width: 360px; flex: none; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: center; gap: 8px; padding: 14px 16px 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .grow { flex: 1; }
  .tools { display: flex; flex-direction: column; gap: 8px; padding: 0 12px 10px; }
  .seg { display: flex; gap: 4px; }
  .f { height: 28px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; }
  .f:hover { color: var(--text); }
  .f.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 0 12px 12px; }
  .pager { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 8px 12px; border-top: 1px solid var(--line); color: var(--muted); font-size: 12px; }
  .detail { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; position: relative; }
  .scrollwrap { flex: 1; min-height: 0; }
</style>
