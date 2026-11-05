<script>
  import Badge from '../components/Badge.svelte';
  import Select from '../components/Select.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import { dispatch, session, can, request, upsertUnit, loadDispatch, go } from '../lib/state.svelte.js';
  import { statusTone } from '../lib/status.js';
  import { ago } from '../lib/format.js';

  let q = $state('');

  $effect(() => {
    if (!dispatch.loaded) loadDispatch();
  });

  const manage = $derived(can('dispatch.manage'));
  const statusOptions = $derived(session.statuses.map((s) => ({ value: s.id, label: `${s.code} ${s.label}` })));

  const groups = $derived.by(() => {
    const term = q.toLowerCase();
    const match = (u) => !term || `${u.callsign} ${u.name}`.toLowerCase().includes(term);
    return [
      { id: 'police', label: 'Police', list: dispatch.units.filter((u) => u.dept === 'police' && match(u)) },
      { id: 'ems', label: 'EMS', list: dispatch.units.filter((u) => u.dept === 'ems' && match(u)) },
    ].filter((g) => g.list.length);
  });

  const counts = $derived.by(() => {
    const c = {};
    for (const u of dispatch.units) c[u.status] = (c[u.status] || 0) + 1;
    return c;
  });

  function label(id) {
    return session.statuses.find((s) => s.id === id)?.label || id;
  }

  function callOf(u) {
    return u.callId ? dispatch.calls.find((c) => c.id === u.callId) : null;
  }

  async function setStatus(u, status) {
    const res = await request('units.setStatus', { cid: u.cid, status }, { success: `${u.callsign || u.name} set to ${label(status)}` });
    if (res.ok) upsertUnit(res.data);
  }
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Units</h1>
      <p class="muted">{dispatch.units.length} on duty</p>
    </div>
    <div class="stats">
      {#each session.statuses as s}
        <div class="stat {statusTone(s.id)}"><span class="n mono">{counts[s.id] || 0}</span><span class="l">{s.label}</span></div>
      {/each}
    </div>
  </header>

  <div class="tools"><SearchBox bind:value={q} placeholder="Filter by callsign or name" /></div>

  <div class="body scroll">
    {#if !dispatch.loaded}
      <Spinner />
    {:else if !groups.length}
      <Empty icon="units" title="No units" text={q ? 'Nobody matches that.' : 'Nobody is on duty.'} />
    {:else}
      {#each groups as g}
        <section>
          <h2 class="eyebrow">{g.label} · {g.list.length}</h2>
          <table>
            <thead>
              <tr><th>Callsign</th><th>Name</th><th>Rank</th><th>Status</th><th>Call</th><th>Since</th></tr>
            </thead>
            <tbody>
              {#each g.list as u (u.cid)}
                {@const call = callOf(u)}
                <tr class:me={u.cid === session.me?.cid}>
                  <td class="mono strong">{u.callsign || '—'}</td>
                  <td>{u.name}</td>
                  <td class="muted">{u.gradeName || ''}</td>
                  <td>
                    {#if manage}
                      <div class="sel"><Select value={u.status} options={statusOptions} onchange={(e) => setStatus(u, e.currentTarget.value)} aria-label="Status of {u.callsign || u.name}" /></div>
                    {:else}
                      <Badge tone={statusTone(u.status)}>{label(u.status)}</Badge>
                    {/if}
                  </td>
                  <td>
                    {#if call}
                      <button type="button" class="call" onclick={() => go('dispatch', { id: call.id })}><span class="mono">{call.code}</span> {call.title}</button>
                    {:else}<span class="faint">—</span>{/if}
                  </td>
                  <td class="mono muted">{ago(u.since)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </section>
      {/each}
    {/if}
  </div>
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 16px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .stats { display: flex; gap: 8px; }
  .stat { display: flex; flex-direction: column; align-items: flex-start; padding: 8px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); min-width: 88px; }
  .stat .n { font-size: 20px; font-weight: 600; }
  .stat .l { color: var(--muted); font-size: 12px; }
  .stat.ok .n { color: var(--ok); }
  .stat.accent .n { color: var(--accent); }
  .stat.info .n { color: var(--info); }
  .tools { max-width: 360px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 22px; padding-bottom: 24px; }
  section { display: flex; flex-direction: column; gap: 8px; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 12px; border-bottom: 1px solid var(--line-2); }
  td { padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  tr.me td { background: rgba(245, 165, 36, 0.05); }
  .strong { font-weight: 600; }
  .sel { width: 190px; }
  .call { border: 0; background: transparent; padding: 0; color: var(--text-2); text-align: left; }
  .call:hover { color: var(--accent); }
</style>
