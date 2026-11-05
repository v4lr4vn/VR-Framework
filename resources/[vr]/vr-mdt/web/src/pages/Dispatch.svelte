<script>
  import CallCard from './dispatch/CallCard.svelte';
  import CallDetail from './dispatch/CallDetail.svelte';
  import MapView from './dispatch/MapView.svelte';
  import NewCallModal from './dispatch/NewCallModal.svelte';
  import UnitStrip from './dispatch/UnitStrip.svelte';
  import UnitBoard from './dispatch/UnitBoard.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Button from '../components/Button.svelte';
  import { dispatch, session, can, loadDispatch } from '../lib/state.svelte.js';

  let { params = {} } = $props();
  let filter = $state('all');
  let creating = $state(false);
  let pickAt = $state(null);
  let focus = $state(null);

  $effect(() => {
    if (!dispatch.loaded) loadDispatch();
  });

  $effect(() => {
    if (params.id) select(Number(params.id));
  });

  const dispatcher = $derived(session.dept?.id === 'dispatch');

  const list = $derived.by(() => {
    if (filter === 'closed') return dispatch.closed;
    if (filter === 'mine') return dispatch.calls.filter((c) => c.units.some((u) => u.cid === session.me?.cid));
    if (filter === 'open') return dispatch.calls.filter((c) => !c.units.length);
    if (filter === 'police') return dispatch.calls.filter((c) => c.jobs.includes('leo'));
    if (filter === 'ems') return dispatch.calls.filter((c) => c.jobs.includes('ems'));
    return dispatch.calls;
  });

  const selected = $derived(dispatch.calls.find((c) => c.id === dispatch.selected) || dispatch.closed.find((c) => c.id === dispatch.selected) || null);

  function select(id) {
    dispatch.selected = id;
    const call = dispatch.calls.find((c) => c.id === id) || dispatch.closed.find((c) => c.id === id);
    if (call) focus = { x: call.coords.x, y: call.coords.y, t: Date.now() };
  }

  const filters = $derived(
    dispatcher
      ? [
          { id: 'all', label: 'All' },
          { id: 'open', label: 'Unassigned' },
          { id: 'police', label: 'Police' },
          { id: 'ems', label: 'EMS' },
          { id: 'closed', label: 'Closed' },
        ]
      : [
          { id: 'all', label: 'All' },
          { id: 'open', label: 'Unassigned' },
          { id: 'mine', label: 'Mine' },
          { id: 'closed', label: 'Closed' },
        ],
  );
</script>

<div class="dispatch">
  <section class="calls" aria-label="Calls">
    <div class="head">
      <h2>{filter === 'closed' ? 'CLOSED CALLS' : 'ACTIVE CALLS'}</h2>
      <span class="mono muted">{list.length}</span>
      <span class="grow"></span>
      {#if can('dispatch.manage')}
        <Button size="sm" icon="plus" onclick={() => (creating = true)}>New</Button>
      {/if}
    </div>
    <div class="filters" role="tablist" aria-label="Filter calls">
      {#each filters as f}
        <button type="button" role="tab" class="f" class:on={filter === f.id} aria-selected={filter === f.id} onclick={() => (filter = f.id)}>{f.label}</button>
      {/each}
    </div>
    <div class="list scroll">
      {#if !dispatch.loaded}
        <Spinner />
      {:else}
        {#each list as call (call.id)}
          <CallCard {call} selected={call.id === dispatch.selected} showDepts={dispatcher} onselect={(c) => select(c.id)} />
        {:else}
          <Empty icon="radio" title={filter === 'closed' ? 'No closed calls' : 'All quiet'} text={filter === 'all' ? 'New calls show up here and on the map.' : ''} />
        {/each}
      {/if}
    </div>
    {#if !dispatcher}<UnitStrip />{/if}
  </section>

  <MapView selectedId={dispatch.selected} onselect={select} {focus} onpick={can('dispatch.manage') ? (c) => { pickAt = c; creating = true; } : null} />

  {#if selected}
    <CallDetail call={selected} onclose={() => (dispatch.selected = null)} />
  {:else if dispatcher}
    <UnitBoard onselect={select} />
  {/if}
</div>

<NewCallModal bind:open={creating} bind:at={pickAt} oncreated={(c) => select(c.id)} />

<style>
  .dispatch { flex: 1; display: flex; min-height: 0; }
  .calls { width: 360px; flex: none; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: center; gap: 8px; padding: 14px 16px 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .grow { flex: 1; }
  .filters { display: flex; gap: 4px; padding: 0 12px 10px; }
  .f { height: 28px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; }
  .f:hover { color: var(--text); }
  .f.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 0 12px 12px; }
</style>
