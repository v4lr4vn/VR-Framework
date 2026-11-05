<script>
  import { untrack } from 'svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import Modal from '../../components/Modal.svelte';
  import Field from '../../components/Field.svelte';
  import Segmented from './Segmented.svelte';
  import { request, session, can } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { on } from '../../lib/nui.js';
  import { agoWords, date, time } from '../../lib/format.js';
  import { statusLabel, statusTone, hours, duration, memberStatus } from './labels.js';

  let { cid, meta = null, onclose, onchange, onremove } = $props();

  let m = $state(null);
  let loading = $state(true);
  let failed = $state(false);
  let busy = $state('');
  let callsign = $state('');
  let badge = $state('');
  let grade = $state(0);
  let divisions = $state([]);
  let notes = $state('');
  let firing = $state(false);
  let statusKey = $state(0);
  let reason = $state('');

  function sync(data) {
    m = data;
    callsign = data.callsign || '';
    badge = data.badge || '';
    grade = data.grade;
    divisions = [...(data.divisions || [])];
    notes = data.notes || '';
  }

  function merge(data) {
    const old = m;
    if (!old) return sync(data);
    if (callsign === (old.callsign || '')) callsign = data.callsign || '';
    if (badge === (old.badge || '')) badge = data.badge || '';
    if (Number(grade) === old.grade) grade = data.grade;
    if (JSON.stringify(divisions) === JSON.stringify(old.divisions || [])) divisions = [...(data.divisions || [])];
    if (notes === (old.notes || '')) notes = data.notes || '';
    m = data;
  }

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('roster.get', { cid }, { quiet: true });
    loading = false;
    if (quiet) {
      if (res.ok) merge(res.data);
      return;
    }
    failed = !res.ok;
    if (res.ok) sync(res.data);
  }

  $effect(() => {
    untrack(() => load());
    return on('roster:changed', (p) => {
      if (p?.cid === cid && !busy) load(true);
    });
  });

  async function save(name, action, data, success) {
    busy = name;
    const res = await request(action, { cid, ...data }, { success });
    busy = '';
    if (res.ok && res.data) {
      sync(res.data);
      onchange?.(res.data);
    }
    return res;
  }

  const grades = $derived.by(() => {
    const job = meta?.jobs?.find((j) => j.name === m?.job);
    const me = session.me || {};
    return (job?.grades || []).filter((g) => me.isboss || g.level < me.grade || g.level === m?.grade);
  });
  const gradeOptions = $derived(grades.map((g) => ({ value: g.level, label: `${g.level} · ${g.name}${g.isboss ? ' (command)' : ''}` })));
  const statusOptions = Object.entries(memberStatus).map(([value, s]) => ({ value, label: s.short || s.label, tone: s.tone }));
  const dirtyDivisions = $derived(m && JSON.stringify([...divisions].sort()) !== JSON.stringify([...(m.divisions || [])].sort()));
  const dirtyNotes = $derived(m && notes.trim() !== (m.notes || ''));
  const cleanCallsign = $derived(callsign.trim().toUpperCase());
  const callsignValid = $derived(cleanCallsign === '' || /^[A-Z0-9 -]{2,16}$/.test(cleanCallsign));
  const badgeValid = $derived(badge.trim() === '' || /^[A-Za-z0-9-]{1,12}$/.test(badge.trim()));

  async function setStatus(v) {
    const res = await save('status', 'roster.status', { status: v }, `Status set to ${statusLabel(v)}`);
    if (!res.ok) statusKey += 1;
  }

  function toggle(d) {
    divisions = divisions.includes(d) ? divisions.filter((x) => x !== d) : [...divisions, d];
  }

  async function applyGrade() {
    const g = grades.find((x) => x.level === Number(grade));
    if (!g || g.level === m.grade) return;
    const up = g.level > m.grade;
    const ok = await confirm({ title: up ? 'Promote?' : 'Demote?', text: `${m.name} will become ${g.name}.`, yes: up ? 'Promote' : 'Demote', danger: !up });
    if (!ok) {
      grade = m.grade;
      return;
    }
    save('grade', 'roster.setGrade', { grade: g.level }, `${m.name} is now ${g.name}`);
  }

  async function fire() {
    if (reason.trim().length < 3) return;
    busy = 'fire';
    const res = await request('roster.fire', { cid, reason: reason.trim() }, { success: `${m.name} was let go` });
    busy = '';
    if (res.ok) {
      firing = false;
      onremove?.(cid);
    }
  }

  function sessionTime(s) {
    const start = `${date(s.startedAt)}, ${time(s.startedAt)}`;
    return s.running ? `${start} – now` : `${start} – ${time(s.endedAt)}`;
  }
</script>

<aside class="panel" aria-label="Member details">
  {#if loading && !m}
    <Spinner label="Loading member" />
  {:else if failed || !m}
    <Empty icon="alert" title="Couldn't load this member" text="They may have left the department.">
      <Button onclick={onclose}>Close</Button>
    </Empty>
  {:else}
    <header class="head">
      <Mugshot name={m.name} size={52} />
      <div class="who">
        <span class="cs mono" class:none={!m.callsign}>{m.callsign || 'No callsign'}</span>
        <h2>{m.name}</h2>
        <span class="sub">{m.gradeName}{' · '}{m.jobLabel}</span>
      </div>
      <IconButton icon="x" label="Close member details" onclick={onclose} />
    </header>
    <div class="tags">
      <Badge tone={statusTone(m.status)}>{statusLabel(m.status)}</Badge>
      {#if m.onduty}<Badge tone="ok"><span class="live"></span>On duty</Badge>{:else if m.online}<Badge>Online</Badge>{:else}<Badge>Offline</Badge>{/if}
      {#if m.isboss}<Badge tone="accent"><Icon name="star" size={11} />Command</Badge>{/if}
      <span class="grow"></span>
      <span class="cid mono">{m.cid}</span>
    </div>

    <div class="body scroll">
      <div class="stats">
        <div class="stat"><span class="n mono">{hours(m.hours7)}</span><span class="l">Last 7 days</span></div>
        <div class="stat"><span class="n mono">{hours(m.hours30)}</span><span class="l">Last 30 days</span></div>
        <div class="stat"><span class="n">{m.onduty ? 'Now' : m.lastSeen ? agoWords(m.lastSeen) : '—'}</span><span class="l">Last on duty</span></div>
        <div class="stat"><span class="n">{m.hiredAt ? date(m.hiredAt) : '—'}</span><span class="l">Hired</span></div>
      </div>

      <section>
        <h3 class="eyebrow">Identity</h3>
        <div class="two">
          <Field label="Callsign" id="mp-cs" error={callsignValid ? '' : 'Letters, numbers, spaces and dashes'}>
            <div class="inline">
              <input id="mp-cs" class="in mono" bind:value={callsign} maxlength="16" placeholder="Not set" disabled={!m.can?.identity} autocomplete="off" spellcheck="false" />
              {#if m.can?.identity && cleanCallsign !== (m.callsign || '')}
                <IconButton icon="check" label="Save callsign" variant="outline" size={34} disabled={!callsignValid || busy === 'cs'} onclick={() => save('cs', 'roster.setCallsign', { callsign: cleanCallsign }, cleanCallsign ? `Callsign set to ${cleanCallsign}` : 'Callsign cleared')} />
              {/if}
            </div>
          </Field>
          <Field label="Badge" id="mp-badge" error={badgeValid ? '' : 'Letters, numbers and dashes'}>
            <div class="inline">
              <input id="mp-badge" class="in mono" bind:value={badge} maxlength="12" placeholder="Not set" disabled={!m.can?.identity} autocomplete="off" spellcheck="false" />
              {#if m.can?.identity && badge.trim().toUpperCase() !== (m.badge || '')}
                <IconButton icon="check" label="Save badge number" variant="outline" size={34} disabled={!badgeValid || busy === 'badge'} onclick={() => save('badge', 'roster.badge', { badge: badge.trim() }, badge.trim() ? 'Badge number saved' : 'Badge number cleared')} />
              {/if}
            </div>
          </Field>
        </div>
      </section>

      <section>
        <h3 class="eyebrow">Rank</h3>
        {#if m.can?.rank}
          <div class="inline">
            <Select bind:value={grade} options={gradeOptions} aria-label="Rank" />
            <Button icon="check" disabled={Number(grade) === m.grade} busy={busy === 'grade'} onclick={applyGrade}>Apply</Button>
          </div>
        {:else}
          <p class="ro">{m.gradeName}{m.cid === session.me?.cid ? " · you can't change your own rank" : ''}</p>
        {/if}
      </section>

      <section>
        <h3 class="eyebrow">Status</h3>
        {#if m.can?.edit}
          {#key statusKey}
            <Segmented full options={statusOptions} value={m.status} label="Status" disabled={busy === 'status'} onchange={setStatus} />
          {/key}
        {:else}
          <p class="ro">{statusLabel(m.status)}</p>
        {/if}
      </section>

      <section>
        <div class="sh">
          <h3 class="eyebrow">Divisions</h3>
          {#if m.can?.edit && dirtyDivisions}
            <Button size="sm" variant="ghost" onclick={() => (divisions = [...m.divisions])}>Undo</Button>
            <Button size="sm" variant="primary" busy={busy === 'div'} onclick={() => save('div', 'roster.divisions', { divisions }, 'Divisions saved')}>Save</Button>
          {/if}
        </div>
        {#if m.can?.edit}
          <div class="dgrid">
            {#each meta?.divisions || [] as d}
              <button type="button" class="dbtn" class:on={divisions.includes(d)} class:trainee={d === meta?.traineeDivision} aria-pressed={divisions.includes(d)} disabled={!divisions.includes(d) && divisions.length >= (meta?.maxDivisions || 8)} onclick={() => toggle(d)}>
                {#if divisions.includes(d)}<Icon name="check" size={12} stroke={3} />{/if}{d}
              </button>
            {/each}
          </div>
        {:else if m.divisions.length}
          <div class="dgrid">{#each m.divisions as d}<span class="dbtn on static">{d}</span>{/each}</div>
        {:else}
          <p class="ro faint">No divisions.</p>
        {/if}
      </section>

      {#if can('roster.manage')}
        <section>
          <div class="sh">
            <h3 class="eyebrow">Command notes</h3>
            {#if m.can?.edit && dirtyNotes}
              <Button size="sm" variant="primary" busy={busy === 'notes'} onclick={() => save('notes', 'roster.notes', { notes }, 'Notes saved')}>Save</Button>
            {/if}
          </div>
          <Textarea bind:value={notes} rows={3} maxlength={2000} placeholder={m.can?.edit ? 'Commendations, warnings, training needs. Only command staff can see these.' : 'No notes.'} disabled={!m.can?.edit} aria-label="Command notes" />
        </section>
      {/if}

      <section>
        <h3 class="eyebrow">Duty sessions</h3>
        {#if m.sessions?.length}
          <ul class="sessions">
            {#each m.sessions as s (s.id)}
              <li class:running={s.running}>
                <span class="when">{sessionTime(s)}</span>
                <span class="len mono">{s.running ? 'On duty' : duration(s.seconds)}</span>
              </li>
            {/each}
          </ul>
        {:else}
          <p class="ro faint">No duty time recorded yet.</p>
        {/if}
      </section>
    </div>

    {#if m.can?.fire}
      <footer class="foot">
        <Button variant="danger" icon="userminus" onclick={() => { reason = ''; firing = true; }}>Let go</Button>
      </footer>
    {/if}
  {/if}
</aside>

<Modal bind:open={firing} title="Let {m?.name || 'member'} go?" width={460}>
  <p class="warn">They lose their job and MDT access right away. Their duty history and files stay on record.</p>
  <Field label="Reason" id="fire-reason" hint="Saved in the audit log.">
    <Textarea id="fire-reason" bind:value={reason} rows={3} maxlength={200} placeholder="Failed probation, repeated no-shows…" />
  </Field>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (firing = false)}>Cancel</Button>
    <Button variant="danger" icon="userminus" busy={busy === 'fire'} disabled={reason.trim().length < 3} onclick={fire}>Let go</Button>
  {/snippet}
</Modal>

<style>
  .panel { width: 400px; flex: none; display: flex; flex-direction: column; border-left: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; align-items: center; gap: 12px; padding: 16px 14px 10px 16px; }
  .who { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.2; }
  .cs { color: var(--accent); font-weight: 600; font-size: 13px; }
  .cs.none { color: var(--faint); }
  h2 { font-size: 20px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 13px; }
  .tags { display: flex; align-items: center; gap: 6px; padding: 0 16px 12px; border-bottom: 1px solid var(--line); }
  .grow { flex: 1; }
  .cid { color: var(--faint); font-size: 12px; }
  .live { width: 6px; height: 6px; border-radius: 50%; background: var(--ok); }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; }
  .stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border-bottom: 1px solid var(--line); }
  .stat { display: flex; flex-direction: column; gap: 2px; padding: 12px 10px 12px 16px; min-width: 0; }
  .stat + .stat { border-left: 1px solid var(--line); padding-left: 12px; }
  .stat .n { font-size: 14px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .stat .l { color: var(--faint); font-size: 11px; }
  section { padding: 12px 16px 14px; display: flex; flex-direction: column; gap: 8px; border-bottom: 1px solid var(--line); }
  section:last-child { border-bottom: 0; }
  .sh { display: flex; align-items: center; gap: 6px; min-height: 28px; }
  .sh h3 { flex: 1; }
  .two { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 10px; }
  .inline { display: flex; gap: 6px; align-items: center; }
  .in { height: 34px; width: 100%; min-width: 0; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg); color: var(--text); outline: none; text-transform: uppercase; }
  .in:focus { border-color: var(--accent); }
  .in:disabled { color: var(--text-2); background: transparent; border-color: var(--line); }
  .ro { color: var(--text-2); }
  .dgrid { display: flex; flex-wrap: wrap; gap: 6px; }
  .dbtn { height: 28px; display: inline-flex; align-items: center; gap: 5px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; }
  .dbtn:hover:not(:disabled):not(.static) { color: var(--text); border-color: var(--line-3); }
  .dbtn.on { background: var(--panel-2); border-color: var(--line-3); color: var(--text); }
  .dbtn.on.trainee { background: var(--accent-soft); border-color: var(--accent-line); color: var(--p2-text); }
  .sessions { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
  .sessions li { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 6px 0; border-bottom: 1px dashed var(--line); font-size: 13px; }
  .sessions li:last-child { border-bottom: 0; }
  .when { color: var(--text-2); }
  .len { color: var(--muted); font-size: 12px; }
  .running .len { color: var(--ok); }
  .foot { padding: 12px 16px; border-top: 1px solid var(--line); display: flex; justify-content: flex-end; }
  .warn { color: var(--text-2); line-height: 1.5; }
</style>
