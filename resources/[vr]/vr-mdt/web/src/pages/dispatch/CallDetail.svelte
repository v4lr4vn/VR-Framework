<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Select from '../../components/Select.svelte';
  import { session, dispatch, request, upsertCall, upsertUnit, can, streetOf, isUnit } from '../../lib/state.svelte.js';
  import { callback } from '../../lib/nui.js';
  import { time, ago, distance, metres } from '../../lib/format.js';
  import { priorityTone, statusTone } from '../../lib/status.js';
  import { confirm } from '../../lib/confirm.svelte.js';

  let { call, onclose } = $props();

  let note = $state('');
  let busy = $state('');
  let assignCid = $state('');
  let timeline;

  const tone = $derived(priorityTone(call.priority));
  const attached = $derived(call.units.some((u) => u.cid === session.me?.cid));
  const manage = $derived(can('dispatch.manage'));
  const amUnit = $derived(isUnit());
  const dispatcher = $derived(session.dept?.id === 'dispatch');
  const statusOptions = $derived(session.statuses.map((s) => ({ value: s.id, label: s.label })));
  const closed = $derived(call.status === 'closed');
  const myPos = $derived(session.me ? dispatch.positions[session.me.cid] : null);
  const dist = $derived(myPos ? distance(myPos, call.coords) : null);
  const freeUnits = $derived(
    dispatch.units
      .filter((u) => !call.units.some((c) => c.cid === u.cid))
      .filter((u) => dispatcher || call.jobs.includes(u.dept === 'ems' ? 'ems' : 'leo') || call.jobs.includes(u.job))
      .map((u) => {
        const extra = dispatcher && !call.jobs.includes(u.dept === 'ems' ? 'ems' : 'leo') ? ` · adds ${u.dept === 'ems' ? 'EMS' : 'police'}` : '';
        return { value: u.cid, label: `${u.callsign || u.name} · ${statusLabel(u.status)}${extra}` };
      }),
  );

  async function unitStatus(cid, status) {
    const u = dispatch.units.find((x) => x.cid === cid);
    const res = await request('units.setStatus', { cid, status }, { success: `${u?.callsign || u?.name || 'Unit'} set to ${statusLabel(status)}` });
    if (res.ok) upsertUnit(res.data);
  }

  function statusLabel(id) {
    return session.statuses.find((s) => s.id === id)?.label || id;
  }

  async function act(name, action, data, success) {
    busy = name;
    const res = await request(action, { id: call.id, ...data }, { success });
    busy = '';
    if (res.ok) upsertCall(res.data);
    return res;
  }

  async function respond() {
    const res = await act('attach', 'dispatch.attach', {});
    if (res.ok) waypoint();
  }

  function waypoint() {
    callback('waypoint', { x: call.coords.x, y: call.coords.y });
  }

  async function sendNote(e) {
    e?.preventDefault();
    const text = note.trim();
    if (!text) return;
    const res = await act('note', 'dispatch.note', { text });
    if (res.ok) note = '';
  }

  async function closeCall() {
    const ok = await confirm({ title: 'Close this call?', text: `${call.code} ${call.title} will move to closed calls and its units will be set available.`, yes: 'Close call' });
    if (ok) act('close', 'dispatch.close', {}, 'Call closed');
  }

  async function assign() {
    if (!assignCid) return;
    const res = await act('assign', 'dispatch.assign', { cid: assignCid }, 'Unit assigned');
    if (res.ok) assignCid = '';
  }

  $effect(() => {
    call.notes.length;
    if (timeline) queueMicrotask(() => (timeline.scrollTop = timeline.scrollHeight));
  });

  const priorities = [
    { value: 1, label: 'Priority 1' },
    { value: 2, label: 'Priority 2' },
    { value: 3, label: 'Priority 3' },
  ];
</script>

<aside class="detail" aria-label="Selected call">
  <div class="top">
    <div class="meta mono">
      <span>CALL #{call.id}</span><span>·</span><span>{time(call.createdAt)}</span><span>·</span><span>{ago(call.createdAt)} ago</span>
      <span class="grow"></span>
      <Badge tone={tone} solid={!closed} mono>{closed ? 'CLOSED' : `PRIORITY ${call.priority}`}</Badge>
      <IconButton icon="x" label="Close details" size={26} onclick={onclose} />
    </div>
    <h1><span class="code mono {tone}">{call.code}</span> {call.title}</h1>
    <span class="where"><Icon name="pin" size={14} /> {streetOf(call)}{#if dist != null}{' · '}{metres(dist)}{/if}</span>
    {#if call.caller && (call.caller.name || call.caller.anonymous || call.caller.callsign)}
      <span class="where"><Icon name="phone" size={14} /> {call.caller.anonymous ? 'Anonymous caller' : [call.caller.callsign, call.caller.name, call.caller.phone].filter(Boolean).join(' · ')}</span>
    {/if}
    {#if call.description}<p class="desc">{call.description}</p>{/if}
    {#if call.info?.length}
      <dl class="info">
        {#each call.info as i}
          <div><dt>{i.label}</dt><dd>{i.value}</dd></div>
        {/each}
      </dl>
    {/if}
    <div class="actions">
      {#if !closed && amUnit}
        {#if attached}
          <Button variant="secondary" icon="unlink" busy={busy === 'detach'} onclick={() => act('detach', 'dispatch.detach', {}, 'Detached')}>Detach</Button>
        {:else}
          <Button variant="primary" size="lg" icon="navigate" busy={busy === 'attach'} onclick={respond}>Respond</Button>
        {/if}
      {/if}
      <Button icon="pin" onclick={waypoint}>Waypoint</Button>
      {#if !closed && (attached || manage)}
        <Button variant="ghost" icon="check" busy={busy === 'close'} onclick={closeCall}>Close</Button>
      {:else if closed && manage}
        <Button variant="ghost" icon="refresh" busy={busy === 'reopen'} onclick={() => act('reopen', 'dispatch.reopen', {}, 'Call reopened')}>Reopen</Button>
      {/if}
    </div>
  </div>

  {#if manage && !closed}
    <div class="block manage">
      <span class="eyebrow">Dispatcher</span>
      <div class="mrow">
        <Select value={call.priority} options={priorities} onchange={(e) => act('prio', 'dispatch.priority', { priority: Number(e.currentTarget.value) })} aria-label="Priority" />
      </div>
      <div class="mrow">
        <Select bind:value={assignCid} options={[{ value: '', label: freeUnits.length ? 'Assign a unit…' : 'No free units' }, ...freeUnits]} aria-label="Unit to assign" />
        <Button icon="plus" disabled={!assignCid} busy={busy === 'assign'} onclick={assign}>Assign</Button>
      </div>
    </div>
  {/if}

  <div class="block">
    <span class="eyebrow">Attached units · {call.units.length}</span>
    {#each call.units as u (u.cid)}
      {@const unit = dispatch.units.find((x) => x.cid === u.cid)}
      <div class="unit">
        <span class="cs mono" class:ems={u.dept === 'ems'}>{u.callsign || '—'}</span>
        <span class="nm">{u.name}</span>
        {#if manage && !closed && unit}
          <div class="ust"><Select value={unit.status} options={statusOptions} onchange={(e) => unitStatus(u.cid, e.currentTarget.value)} aria-label="Status of {u.callsign || u.name}" /></div>
        {:else}
          <span class="st {statusTone(unit?.status)}">{unit ? statusLabel(unit.status) : 'Offline'}</span>
        {/if}
        {#if manage && !closed}
          <IconButton icon="x" label="Remove {u.callsign || u.name}" size={24} onclick={() => act('un', 'dispatch.unassign', { cid: u.cid })} />
        {/if}
      </div>
    {:else}
      <p class="none">No units attached.</p>
    {/each}
  </div>

  <div class="block grow">
    <span class="eyebrow">Timeline</span>
    <div class="timeline scroll" bind:this={timeline}>
      {#each call.notes as n}
        <div class="note" class:sys={n.system}>
          <span class="t mono">{time(n.at)}</span>
          <span class="x">{#if !n.system && (n.callsign || n.name)}<b>{n.callsign || n.name}:</b>{' '}{/if}{n.text}</span>
        </div>
      {:else}
        <p class="none">Nothing logged yet.</p>
      {/each}
    </div>
    {#if !closed}
      <form class="add" onsubmit={sendNote}>
        <label class="sr-only" for="call-note">Add a note</label>
        <input id="call-note" bind:value={note} maxlength="250" placeholder="Add a note to the call" autocomplete="off" />
        <IconButton icon="note" label="Add note" size={34} variant="outline" disabled={!note.trim() || busy === 'note'} onclick={sendNote} />
      </form>
    {/if}
  </div>
</aside>

<style>
  .detail { width: 380px; flex: none; display: flex; flex-direction: column; border-left: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .top { padding: 14px 16px 16px; display: flex; flex-direction: column; gap: 10px; border-bottom: 1px solid var(--line); }
  .meta { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }
  .grow { flex: 1; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.1; }
  .code.p1 { color: var(--p1-text); }
  .code.p2 { color: var(--p2-text); }
  .code.p3 { color: var(--p3-text); }
  .where { display: flex; align-items: center; gap: 6px; color: var(--text-2); }
  .desc { color: var(--text-2); line-height: 1.45; white-space: pre-wrap; }
  .info { margin: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px 12px; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); }
  .info div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  dt { color: var(--faint); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; }
  dd { margin: 0; color: var(--text); overflow-wrap: anywhere; }
  .actions { display: flex; gap: 8px; flex-wrap: wrap; }
  .actions :global(.btn.lg) { flex: 1; }
  .block { padding: 12px 16px; display: flex; flex-direction: column; gap: 8px; border-bottom: 1px solid var(--line); }
  .block.grow { flex: 1; min-height: 0; border-bottom: 0; }
  .mrow { display: flex; gap: 8px; }
  .unit { display: flex; align-items: center; gap: 10px; min-height: 26px; }
  .cs { font-weight: 600; width: 104px; flex: none; color: var(--text); }
  .cs.ems { color: var(--ems-text); }
  .nm { color: var(--text-2); flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .st { font-size: 13px; }
  .ust { width: 128px; flex: none; }
  .st.ok { color: var(--ok); }
  .st.accent { color: var(--accent); }
  .st.info { color: var(--info); }
  .st.muted { color: var(--muted); }
  .none { color: var(--faint); font-size: 13px; }
  .timeline { flex: 1; min-height: 60px; display: flex; flex-direction: column; gap: 8px; }
  .note { display: flex; gap: 10px; }
  .note .t { color: var(--muted); font-size: 12px; width: 40px; flex: none; padding-top: 1px; }
  .note .x { color: var(--text-2); overflow-wrap: anywhere; }
  .note.sys .x { color: var(--muted); }
  .note b { color: var(--text); font-weight: 600; }
  .add { display: flex; gap: 8px; }
  .add input { flex: 1; height: 34px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); outline: none; }
  .add input:focus { border-color: var(--accent); }
</style>
