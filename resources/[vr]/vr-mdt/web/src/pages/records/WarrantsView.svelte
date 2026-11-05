<script>
  import './records.css';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import SearchBox from '../../components/SearchBox.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import WarrantDetail from './WarrantDetail.svelte';
  import WarrantModal from './WarrantModal.svelte';
  import { onMount } from 'svelte';
  import { api, on } from '../../lib/nui.js';
  import { session, can } from '../../lib/state.svelte.js';
  import { setBadge } from '../../lib/badges.svelte.js';
  import { agoWords, date } from '../../lib/format.js';
  import { errorText } from '../../lib/lang.js';
  import { warrantTone, warrantLabel, chargeText } from './shared.js';

  let { focusId = null, oncounts } = $props();

  let filter = $state(session.dept?.id === 'doj' ? 'pending' : 'active');
  let q = $state('');
  let data = $state(null);
  let error = $state('');
  let selected = $state(null);
  let requesting = $state(false);
  let seq = 0;

  async function load() {
    const mine = ++seq;
    const res = await api('warrants.list', { status: filter, q: q.trim() });
    if (mine !== seq) return;
    if (!res.ok) {
      error = errorText(res.error);
      return;
    }
    error = '';
    data = res.data;
    setBadge('warrants', res.data.counts.pending);
    oncounts?.(res.data.counts);
    if (selected) {
      const fresh = res.data.items.find((w) => w.id === selected.id);
      if (fresh) selected = fresh;
    } else if (res.data.items.length) {
      selected = res.data.items[0];
    }
  }

  async function open(id) {
    const res = await api('warrants.get', { id });
    if (!res.ok) return;
    selected = res.data;
    const s = res.data.status;
    filter = s === 'pending' || s === 'active' ? s : 'history';
    load();
  }

  onMount(() => {
    if (focusId) open(Number(focusId));
    else load();
  });

  $effect(() => on('warrants:changed', () => {
    load();
    if (selected) api('warrants.get', { id: selected.id }).then((res) => { if (res.ok && selected && res.data.id === selected.id) selected = res.data; });
  }));

  function setFilter(f) {
    if (filter === f) return;
    filter = f;
    selected = null;
    data = null;
    load();
  }

  function changed(w) {
    selected = w;
    load();
  }

  const filters = $derived([
    { id: 'pending', label: 'Pending', count: data?.counts.pending },
    { id: 'active', label: 'Active', count: data?.counts.active },
    { id: 'history', label: 'History' },
  ]);
</script>

<div class="wrap">
  <section class="listcol">
    <div class="bar">
      <div class="filters" role="tablist" aria-label="Warrant status">
        {#each filters as f}
          <button type="button" role="tab" class="f" class:on={filter === f.id} aria-selected={filter === f.id} onclick={() => setFilter(f.id)}>
            {f.label}{#if f.count}<span class="n mono" class:hot={f.id === 'pending'}>{f.count}</span>{/if}
          </button>
        {/each}
      </div>
      {#if can('warrants.create')}
        <Button size="sm" icon="plus" onclick={() => (requesting = true)}>Request</Button>
      {/if}
    </div>
    <div class="search"><SearchBox bind:value={q} placeholder="Filter by name, citizen ID or reason" onsearch={() => load()} id="warrant-filter" /></div>
    <div class="list scroll">
      {#if error}
        <Empty icon="alert" title="Couldn't load warrants" text={error} />
      {:else if !data}
        <Spinner />
      {:else}
        {#each data.items as w (w.id)}
          <button type="button" class="item" class:sel={selected?.id === w.id} aria-pressed={selected?.id === w.id} onclick={() => (selected = w)}>
            <div class="l1">
              <Badge tone={warrantTone(w.status)} solid={w.status === 'active'}>{warrantLabel(w.status)}</Badge>
              <span class="nm rec-clip">{w.name}</span>
              <span class="mono faint id">#{w.id}</span>
            </div>
            <span class="reason rec-clip">{w.reason}</span>
            {#if w.charges?.length}<span class="rec-sub rec-clip">{w.charges.map(chargeText).join(' · ')}</span>{/if}
            <span class="l3">
              <span>{w.created_by_name}{' · '}{agoWords(w.created_at)}</span>
              {#if w.status === 'active'}<span class="exp">Expires {date(w.expires_at)}</span>{/if}
            </span>
          </button>
        {:else}
          <Empty icon="alert" title={filter === 'pending' ? 'Nothing to review' : filter === 'active' ? 'No active warrants' : 'No history yet'} text={filter === 'pending' ? 'New warrant requests show up here.' : q ? 'Nothing matches that filter.' : ''} />
        {/each}
      {/if}
    </div>
  </section>

  {#if selected}
    <WarrantDetail warrant={selected} canDecide={data?.canDecide} fallback={data?.fallback} onchanged={changed} />
  {:else}
    <div class="placeholder"><Empty icon="alert" title="No warrant selected" text="Pick a warrant on the left to see the details." /></div>
  {/if}
</div>

<WarrantModal bind:open={requesting} oncreated={(w) => { filter = 'pending'; selected = w; load(); }} />

<style>
  .wrap { flex: 1; min-height: 0; display: flex; gap: 14px; }
  .listcol { width: 470px; flex: none; display: flex; flex-direction: column; min-height: 0; background: var(--bg-2); border: 1px solid var(--line-2); border-radius: var(--radius-lg); }
  .bar { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 10px 12px 8px; }
  .filters { display: flex; gap: 4px; }
  .f { height: 30px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
  .f:hover { color: var(--text); }
  .f.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .n { font-size: 11px; padding: 0 5px; border-radius: 4px; background: var(--panel-2); color: var(--text-2); }
  .n.hot { background: var(--accent); color: var(--accent-ink); }
  .search { padding: 0 12px 10px; }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 0 12px 12px; }
  .item { display: flex; flex-direction: column; gap: 5px; padding: 11px 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: var(--text); width: 100%; flex: none; }
  .item:hover { border-color: var(--line-3); background: #141c29; }
  .item.sel { background: var(--panel-2); border-color: var(--accent); }
  .l1 { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .nm { font-weight: 600; font-size: 15px; flex: 1; }
  .id { font-size: 12px; }
  .reason { color: var(--text-2); font-size: 13px; }
  .l3 { display: flex; justify-content: space-between; gap: 8px; font-size: 12px; color: var(--muted); }
  .exp { color: var(--danger-text); }
  .placeholder { flex: 1; display: flex; border: 1px dashed var(--line-2); border-radius: var(--radius-lg); }
</style>
