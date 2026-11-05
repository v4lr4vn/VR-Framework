<script>
  import Select from '../../components/Select.svelte';
  import { dispatch, session, request, upsertUnit, radio, moveUnit } from '../../lib/state.svelte.js';
  import { statusTone } from '../../lib/status.js';
  import { ago } from '../../lib/format.js';

  let { onselect } = $props();

  const statusOptions = $derived(session.statuses.map((s) => ({ value: s.id, label: `${s.code} ${s.label}` })));

  const groups = $derived([
    { id: 'police', label: 'Police', list: dispatch.units.filter((u) => u.dept === 'police') },
    { id: 'ems', label: 'EMS', list: dispatch.units.filter((u) => u.dept === 'ems') },
  ]);

  function label(id) {
    return session.statuses.find((s) => s.id === id)?.label || id;
  }

  function radioOptions(u) {
    const list = radio.channels.filter((c) => c.dept === u.dept || c.dept === 'all');
    const opts = [{ value: 0, label: 'Radio off' }, ...list.map((c) => ({ value: c.id, label: `CH ${c.id} ${c.label}` }))];
    if (u.radio && !list.some((c) => c.id === u.radio)) opts.push({ value: u.radio, label: `CH ${u.radio}` });
    return opts;
  }

  function callOf(u) {
    return u.callId ? dispatch.calls.find((c) => c.id === u.callId) : null;
  }

  async function setStatus(u, status) {
    const res = await request('units.setStatus', { cid: u.cid, status }, { success: `${u.callsign || u.name} set to ${label(status)}` });
    if (res.ok) upsertUnit(res.data);
  }
</script>

<aside class="board" aria-label="Units">
  <div class="head">
    <h2>UNITS</h2>
    <span class="mono muted">{dispatch.units.length} on duty</span>
  </div>
  <div class="list scroll">
    {#each groups as g (g.id)}
      <div class="group">
        <span class="eyebrow">{g.label} · {g.list.length}</span>
        {#each g.list as u (u.cid)}
          {@const call = callOf(u)}
          <div class="unit {statusTone(u.status)}">
            <span class="bar"></span>
            <div class="who">
              <span class="cs mono" class:ems={u.dept === 'ems'}>{u.callsign || '—'}</span>
              <span class="nm">{u.name}{u.gradeName ? ` · ${u.gradeName}` : ''}</span>
              {#if call}
                <button type="button" class="call mono" onclick={() => onselect?.(call.id)}>{call.code} {call.title}</button>
              {:else}
                <span class="since">{label(u.status)} · {ago(u.since)}</span>
              {/if}
            </div>
            <div class="sel">
              <Select value={u.status} options={statusOptions} onchange={(e) => setStatus(u, e.currentTarget.value)} aria-label="Status of {u.callsign || u.name}" />
              {#if radio.loaded && radio.voice}
                <Select value={u.radio || 0} options={radioOptions(u)} onchange={(e) => moveUnit(u, Number(e.currentTarget.value))} aria-label="Radio channel of {u.callsign || u.name}" />
              {/if}
            </div>
          </div>
        {:else}
          <p class="none">Nobody on duty.</p>
        {/each}
      </div>
    {/each}
  </div>
  <p class="tip">Select a call to assign units to it. Change a unit's radio to move them.</p>
</aside>

<style>
  .board { width: 380px; flex: none; display: flex; flex-direction: column; border-left: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: baseline; gap: 10px; padding: 14px 16px 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 14px; padding: 4px 12px 12px; }
  .group { display: flex; flex-direction: column; gap: 6px; }
  .unit { position: relative; display: flex; align-items: center; gap: 10px; padding: 8px 10px 8px 14px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); overflow: hidden; }
  .bar { position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--muted); }
  .unit.ok .bar { background: var(--ok); }
  .unit.accent .bar { background: var(--accent); }
  .unit.info .bar { background: var(--info); }
  .who { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .cs { font-weight: 600; color: var(--text); }
  .cs.ems { color: var(--ems-text); }
  .nm { color: var(--text-2); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .since { color: var(--faint); font-size: 12px; }
  .call { border: 0; padding: 0; background: transparent; color: var(--accent-2); font-size: 12px; text-align: left; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer; }
  .call:hover { text-decoration: underline; }
  .sel { width: 160px; flex: none; display: flex; flex-direction: column; gap: 4px; }
  .none { color: var(--faint); font-size: 13px; }
  .tip { color: var(--faint); font-size: 12px; padding: 10px 16px; border-top: 1px solid var(--line); }
</style>
