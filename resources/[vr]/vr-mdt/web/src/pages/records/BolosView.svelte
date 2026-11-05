<script>
  import './records.css';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import BoloModal from './BoloModal.svelte';
  import { onMount } from 'svelte';
  import { api, on } from '../../lib/nui.js';
  import { can, go, request } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { agoWords, dateTime } from '../../lib/format.js';
  import { errorText } from '../../lib/lang.js';
  import { boloIcon } from './shared.js';

  let { focusId = null, oncount } = $props();

  let status = $state('active');
  let items = $state(null);
  let error = $state('');
  let creating = $state(false);
  let busy = $state(0);
  let seq = 0;

  async function load() {
    const mine = ++seq;
    const res = await api('bolos.list', { status });
    if (mine !== seq) return;
    if (!res.ok) {
      error = errorText(res.error);
      return;
    }
    error = '';
    items = res.data.items;
    if (status === 'active') oncount?.(items.length);
  }

  onMount(load);
  $effect(() => on('bolos:changed', () => load()));

  function setStatus(s) {
    if (status === s) return;
    status = s;
    items = null;
    load();
  }

  async function closeBolo(b) {
    const ok = await confirm({ title: 'Close this BOLO?', text: `"${b.title}" will be taken off every officer's board.`, yes: 'Close BOLO' });
    if (!ok) return;
    busy = b.id;
    const res = await request('bolos.close', { id: b.id }, { success: 'BOLO closed' });
    busy = 0;
    if (res.ok) load();
  }

  const manage = $derived(can('bolos.manage'));
</script>

<div class="wrap">
  <div class="bar">
    <div class="filters" role="tablist" aria-label="BOLO status">
      <button type="button" role="tab" class="f" class:on={status === 'active'} aria-selected={status === 'active'} onclick={() => setStatus('active')}>Active</button>
      <button type="button" role="tab" class="f" class:on={status === 'closed'} aria-selected={status === 'closed'} onclick={() => setStatus('closed')}>Closed</button>
    </div>
    <span class="grow"></span>
    {#if manage}<Button icon="plus" variant="primary" onclick={() => (creating = true)}>New BOLO</Button>{/if}
  </div>

  <div class="grid scroll">
    {#if error}
      <Empty icon="alert" title="Couldn't load BOLOs" text={error} />
    {:else if !items}
      <Spinner />
    {:else}
      {#each items as b (b.id)}
        <article class="card {b.kind}" class:focus={Number(focusId) === b.id} class:closed={b.status === 'closed'}>
          <header class="h">
            <span class="kind"><Icon name={boloIcon(b.kind)} size={15} />{b.kind}</span>
            <span class="mono faint">#{b.id}</span>
            <span class="grow"></span>
            <span class="faint when">{agoWords(b.created_at)}</span>
          </header>
          <h3>{b.title}</h3>
          {#if b.plate || b.cid || b.subject}
            <div class="subject">
              {#if b.plate}
                <button type="button" class="link" onclick={() => go('vehicles', { plate: b.plate })}><span class="rec-plate">{b.plate}</span></button>
              {/if}
              {#if b.cid}
                <button type="button" class="link person" onclick={() => go('citizens', { cid: b.cid })}><Icon name="person" size={14} />{b.subject}</button>
              {:else if b.subject && b.subject !== b.plate}
                <span class="muted rec-clip">{b.subject}</span>
              {/if}
            </div>
          {/if}
          {#if b.details}<p class="details">{b.details}</p>{/if}
          <footer class="ft">
            <span class="faint">{b.status === 'closed' ? `Closed by ${b.closed_by_name} · ${dateTime(b.closed_at)}` : `By ${b.created_by_name}`}</span>
            {#if manage && b.status === 'active'}
              <Button size="sm" variant="ghost" icon="check" busy={busy === b.id} onclick={() => closeBolo(b)}>Close</Button>
            {/if}
          </footer>
        </article>
      {:else}
        <div class="empty"><Empty icon="alert" title={status === 'active' ? 'No active BOLOs' : 'No closed BOLOs'} text={status === 'active' ? 'Be-on-the-lookout notices for people and vehicles appear here.' : ''} /></div>
      {/each}
    {/if}
  </div>
</div>

<BoloModal bind:open={creating} oncreated={() => { status = 'active'; load(); }} />

<style>
  .wrap { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 12px; }
  .bar { display: flex; align-items: center; gap: 8px; }
  .grow { flex: 1; }
  .filters { display: flex; gap: 4px; }
  .f { height: 30px; padding: 0 12px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; }
  .f:hover { color: var(--text); }
  .f.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; align-content: start; padding-bottom: 8px; }
  .empty { grid-column: 1 / -1; display: flex; }
  .card { display: flex; flex-direction: column; gap: 8px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); border-top: 3px solid var(--accent); min-width: 0; }
  .card.person { border-top-color: var(--p1); }
  .card.vehicle { border-top-color: var(--accent); }
  .card.other { border-top-color: var(--info); }
  .card.focus { box-shadow: 0 0 0 1px var(--accent); }
  .card.closed { border-top-color: var(--line-3); opacity: 0.8; }
  .h { display: flex; align-items: center; gap: 8px; font-size: 12px; }
  .kind { display: inline-flex; align-items: center; gap: 6px; text-transform: uppercase; letter-spacing: 0.1em; font-weight: 600; color: var(--text-2); }
  .when { font-size: 12px; }
  h3 { font-size: 17px; font-weight: 700; line-height: 1.25; }
  .subject { display: flex; align-items: center; gap: 10px; min-width: 0; }
  .link { border: 0; background: transparent; padding: 0; color: var(--text); display: inline-flex; align-items: center; gap: 6px; font-weight: 600; }
  .link:hover, .link:hover :global(.rec-plate) { color: var(--accent); border-color: var(--accent); }
  .details { color: var(--text-2); line-height: 1.45; font-size: 13px; display: -webkit-box; -webkit-line-clamp: 3; line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
  .ft { margin-top: auto; display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 12px; min-height: 28px; }
</style>
