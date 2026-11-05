<script>
  import { untrack } from 'svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import SearchBox from '../../components/SearchBox.svelte';
  import Select from '../../components/Select.svelte';
  import Icon from '../../components/Icon.svelte';
  import MemberPanel from './MemberPanel.svelte';
  import HireModal from './HireModal.svelte';
  import { request, session, can } from '../../lib/state.svelte.js';
  import { on } from '../../lib/nui.js';
  import { agoWords } from '../../lib/format.js';
  import { statusLabel, statusTone, hours } from './labels.js';

  let { initial = null } = $props();

  let list = $state([]);
  let meta = $state(null);
  let loading = $state(true);
  let failed = $state(false);
  let q = $state('');
  let filter = $state('all');
  let division = $state('');
  let selected = $state(untrack(() => initial));
  let hiring = $state(false);
  let timer;
  let seq = 0;

  async function load(quiet = false) {
    const mine = ++seq;
    if (!quiet) loading = true;
    const res = await request('roster.list', { q: q.trim() }, { quiet });
    if (mine !== seq) return;
    loading = false;
    failed = !res.ok && !list.length;
    if (res.ok) list = res.data;
  }

  async function loadMeta() {
    const res = await request('roster.meta', {}, { quiet: true });
    if (res.ok) meta = res.data;
  }

  $effect(() => {
    untrack(() => {
      load();
      loadMeta();
    });
    const offChanged = on('roster:changed', () => {
      clearTimeout(timer);
      timer = setTimeout(() => load(true), 250);
    });
    const offDuty = on('roster:duty', (p) => {
      list = list.map((m) => (m.cid === p.cid ? { ...m, onduty: p.onduty, online: p.onduty || m.online } : m));
    });
    return () => {
      offChanged();
      offDuty();
      clearTimeout(timer);
    };
  });

  const counts = $derived.by(() => {
    const c = { all: list.length, onduty: 0, active: 0, loa: 0, suspended: 0, hours: 0 };
    for (const m of list) {
      if (m.onduty) c.onduty += 1;
      c[m.status] = (c[m.status] || 0) + 1;
      c.hours += Number(m.hours7) || 0;
    }
    return c;
  });

  const shown = $derived(
    list.filter((m) => {
      if (filter === 'onduty' && !m.onduty) return false;
      if (['active', 'loa', 'suspended'].includes(filter) && m.status !== filter) return false;
      if (division && !m.divisions.includes(division)) return false;
      return true;
    }),
  );

  const filters = $derived([
    { id: 'all', label: 'All', n: counts.all },
    { id: 'onduty', label: 'On duty', n: counts.onduty },
    { id: 'active', label: 'Active', n: counts.active || 0 },
    { id: 'loa', label: 'Leave', n: counts.loa || 0 },
    { id: 'suspended', label: 'Suspended', n: counts.suspended || 0 },
  ]);

  const divisionOptions = $derived([{ value: '', label: 'All divisions' }, ...(meta?.divisions || []).map((d) => ({ value: d, label: d }))]);

  function seen(m) {
    if (m.onduty) return 'On duty now';
    if (m.online) return 'Online, off duty';
    return m.lastSeen ? agoWords(m.lastSeen) : 'Never';
  }

  function changed(m) {
    list = list.map((x) => (x.cid === m.cid ? { ...x, ...m, hours7: m.hours7 ?? x.hours7 } : x));
  }

  function removed(cid) {
    list = list.filter((x) => x.cid !== cid);
    selected = null;
  }

  function hired(m) {
    load(true);
    if (m?.cid) selected = m.cid;
  }

  function key(e, cid) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      selected = cid;
    }
  }
</script>

<div class="members">
  <div class="main">
    <div class="toolbar" class:narrow={!!selected}>
      <div class="search"><SearchBox bind:value={q} placeholder="Name, callsign or badge" onsearch={() => load(true)} /></div>
      <div class="chips" role="tablist" aria-label="Filter members">
        {#each filters as f}
          <button type="button" role="tab" class="chip" class:on={filter === f.id} aria-selected={filter === f.id} onclick={() => (filter = f.id)}>
            {f.label}<span class="n mono">{f.n}</span>
          </button>
        {/each}
      </div>
      <div class="div"><Select bind:value={division} options={divisionOptions} aria-label="Division" /></div>
      <span class="grow"></span>
      <div class="week" title="Duty hours of everyone listed, last 7 days">
        <span class="mono">{hours(counts.hours)}</span><span class="l">on duty this week</span>
      </div>
      {#if can('roster.manage')}
        <Button variant="primary" icon="userplus" onclick={() => (hiring = true)} disabled={!meta}>Hire</Button>
      {/if}
    </div>

    <div class="tablewrap scroll">
      {#if loading && !list.length}
        <Spinner label="Loading the roster" />
      {:else if failed}
        <Empty icon="alert" title="Couldn't load the roster" text="Check your connection to the MDT and try again.">
          <Button icon="refresh" onclick={() => load()}>Try again</Button>
        </Empty>
      {:else if !shown.length}
        <Empty icon="users" title={list.length ? 'Nobody matches' : 'No members yet'} text={list.length ? 'Try another filter or search.' : 'Hire someone to start the roster.'} />
      {:else}
        <table class:narrow={!!selected}>
          <thead>
            <tr>
              <th class="dotcol"><span class="sr-only">On duty</span></th>
              <th>Callsign</th>
              <th>Name</th>
              <th>Rank</th>
              <th class="wide">Badge</th>
              <th>Divisions</th>
              <th>Status</th>
              <th class="num">This week</th>
              <th class="wide">Last on duty</th>
            </tr>
          </thead>
          <tbody>
            {#each shown as m (m.cid)}
              <tr class:sel={selected === m.cid} class:me={m.cid === session.me?.cid} tabindex="0" aria-selected={selected === m.cid} onclick={() => (selected = m.cid)} onkeydown={(e) => key(e, m.cid)}>
                <td class="dotcol"><span class="dot" class:on={m.onduty} class:online={m.online && !m.onduty} title={m.onduty ? 'On duty' : m.online ? 'Online, off duty' : 'Offline'}></span></td>
                <td class="mono strong">{m.callsign || '—'}</td>
                <td class="name">{m.name}</td>
                <td class="rank">{#if m.isboss}<span class="boss" title="Command"><Icon name="star" size={12} /></span>{/if}{m.gradeName || '—'}</td>
                <td class="mono wide muted">{m.badge || '—'}</td>
                <td>
                  <div class="divs">
                    {#each m.divisions.slice(0, selected ? 2 : 3) as d}
                      <span class="dchip" class:trainee={d === meta?.traineeDivision}>{d}</span>
                    {/each}
                    {#if m.divisions.length > (selected ? 2 : 3)}<span class="dchip more">+{m.divisions.length - (selected ? 2 : 3)}</span>{/if}
                  </div>
                </td>
                <td>{#if m.status === 'active'}<span class="active">Active</span>{:else}<Badge tone={statusTone(m.status)}>{statusLabel(m.status, true)}</Badge>{/if}</td>
                <td class="num mono" class:zero={!m.hours7}>{hours(m.hours7)}</td>
                <td class="wide seen" class:live={m.onduty}>{seen(m)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  </div>

  {#if selected}
    {#key selected}
      <MemberPanel cid={selected} {meta} onclose={() => (selected = null)} onchange={changed} onremove={removed} />
    {/key}
  {/if}
</div>

{#if meta}
  <HireModal bind:open={hiring} {meta} onhired={hired} />
{/if}

<style>
  .members { flex: 1; display: flex; min-height: 0; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; }
  .toolbar { display: flex; align-items: center; gap: 10px; padding: 14px 24px 12px; flex-wrap: nowrap; }
  .search { width: 280px; flex: none; }
  .chips { display: flex; gap: 4px; flex: none; }
  .chip { height: 32px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
  .chip:hover { color: var(--text); }
  .chip.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .chip .n { font-size: 12px; color: var(--faint); }
  .chip.on .n { color: var(--accent); }
  .div { width: 170px; flex: none; }
  .grow { flex: 1; }
  .week { display: flex; flex-direction: column; align-items: flex-end; line-height: 1.15; padding-right: 4px; }
  .week .mono { font-size: 15px; font-weight: 600; }
  .week .l { color: var(--faint); font-size: 11px; }
  .tablewrap { flex: 1; min-height: 0; display: flex; flex-direction: column; padding: 0 24px 20px; }
  table { width: 100%; border-collapse: collapse; }
  thead th { position: sticky; top: 0; z-index: 1; background: var(--bg); text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 10px; border-bottom: 1px solid var(--line-2); white-space: nowrap; }
  td { padding: 0 10px; height: 40px; border-bottom: 1px solid var(--line); vertical-align: middle; white-space: nowrap; }
  tbody tr { cursor: pointer; }
  tbody tr:hover td { background: var(--bg-2); }
  tbody tr:focus-visible { outline: 2px solid var(--accent); outline-offset: -2px; }
  tr.me td { background: rgba(245, 165, 36, 0.04); }
  tr.sel td, tr.sel:hover td { background: var(--panel-2); }
  tr.sel td:first-child { box-shadow: inset 3px 0 0 var(--accent); }
  .dotcol { width: 30px; padding-right: 0; }
  .dot { display: block; width: 8px; height: 8px; border-radius: 50%; background: var(--line-3); }
  .dot.on { background: var(--ok); box-shadow: 0 0 0 3px rgba(61, 214, 140, 0.16); }
  .dot.online { background: var(--muted); }
  .strong { font-weight: 600; }
  .name { color: var(--text); max-width: 220px; overflow: hidden; text-overflow: ellipsis; }
  .rank { color: var(--text-2); }
  .boss { display: inline-flex; color: var(--accent); margin-right: 6px; vertical-align: -1px; }
  .divs { display: flex; gap: 4px; }
  .dchip { font-size: 12px; padding: 1px 6px; border-radius: 4px; background: var(--panel-2); color: var(--text-2); }
  .dchip.trainee { background: var(--accent-soft); color: var(--p2-text); }
  .dchip.more { color: var(--muted); background: transparent; border: 1px solid var(--line-2); }
  .num { text-align: right; }
  .zero { color: var(--faint); }
  .seen { color: var(--muted); }
  .seen.live { color: var(--ok); }
  .narrow .wide { display: none; }
  .toolbar.narrow .week { display: none; }
  .toolbar.narrow .search { width: 220px; }
  .toolbar.narrow .div { width: 150px; }
  .active { color: var(--muted); }
  .narrow .name { max-width: 160px; }
</style>
