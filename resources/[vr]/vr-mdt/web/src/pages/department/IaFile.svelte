<script>
  import { untrack } from 'svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import IaFileModal from './IaFileModal.svelte';
  import { request, can, back } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { on } from '../../lib/nui.js';
  import { date, dateTime, time, agoWords } from '../../lib/format.js';
  import { iaStatus, iaOutcomes, iaActive, fileNo } from './labels.js';

  let { id } = $props();

  let file = $state(null);
  let loading = $state(true);
  let failed = $state(false);
  let busy = $state('');
  let investigators = $state([]);
  let assignee = $state('');
  let outcome = $state('');
  let findings = $state('');
  let note = $state('');
  let editing = $state(false);
  let timeline = $state(null);

  const manage = $derived(can('ia.manage'));
  const active = $derived(file && iaActive(file.status));

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('ia.get', { id }, { quiet: true });
    loading = false;
    failed = !res.ok;
    if (res.ok) set(res.data);
  }

  function set(data) {
    file = data;
    assignee = data.assignedCid || '';
    findings = data.findings || '';
    queueMicrotask(() => {
      if (timeline) timeline.scrollTop = timeline.scrollHeight;
    });
  }

  $effect(() => {
    untrack(() => {
      load();
      if (can('ia.manage')) {
        request('ia.investigators', {}, { quiet: true }).then((res) => {
          if (res.ok) investigators = res.data;
        });
      }
    });
    return on('ia:changed', (p) => {
      if (p?.id === id) load(true);
    });
  });

  const assignOptions = $derived([
    { value: '', label: 'Nobody assigned' },
    ...investigators.filter((i) => i.cid !== file?.subjectCid).map((i) => ({ value: i.cid, label: `${i.callsign ? `${i.callsign} · ` : ''}${i.name} · ${i.gradeName}` })),
  ]);

  async function act(name, action, data, success) {
    busy = name;
    const res = await request(action, { id, ...data }, { success });
    busy = '';
    if (res.ok) set(res.data);
    return res;
  }

  async function assign() {
    const who = investigators.find((i) => i.cid === assignee);
    act('assign', 'ia.assign', { cid: assignee }, who ? `Assigned to ${who.name}` : 'Unassigned');
  }

  async function addNote(e) {
    e?.preventDefault();
    if (!note.trim()) return;
    const res = await act('note', 'ia.note', { text: note.trim() });
    if (res.ok) note = '';
  }

  async function closeFile() {
    const o = iaOutcomes.find((x) => x.id === outcome);
    if (!o || findings.trim().length < 3) return;
    const ok = await confirm({ title: `Close as ${o.label}?`, text: `${fileNo(id)} about ${file.subjectName} will be marked ${o.label.toLowerCase()}. You can reopen it later.`, yes: 'Close file' });
    if (ok) {
      const res = await act('close', 'ia.close', { outcome, findings: findings.trim() }, `${fileNo(id)} closed as ${o.label}`);
      if (res.ok) outcome = '';
    }
  }

  async function reopen() {
    const ok = await confirm({ title: 'Reopen this file?', text: 'The outcome stays on record and the file goes back to investigating.', yes: 'Reopen' });
    if (ok) act('reopen', 'ia.save', { summary: file.summary, complainant: file.complainant || '', status: 'investigating' }, `${fileNo(id)} reopened`);
  }
</script>

{#if loading && !file}
  <Spinner label="Loading file" />
{:else if failed || !file}
  <Empty icon="lock" title="File not available" text="It doesn't exist or you can't see it.">
    <Button icon="back" onclick={() => back('ia')}>All files</Button>
  </Empty>
{:else}
  {@const st = iaStatus[file.status] || { label: file.status, tone: 'muted' }}
  <div class="file">
    <div class="main">
      <div class="bar">
        <Button variant="ghost" size="sm" icon="back" onclick={() => back('ia')}>All files</Button>
        <span class="grow"></span>
        {#if manage && active}<Button size="sm" icon="edit" onclick={() => (editing = true)}>Edit</Button>{/if}
      </div>

      <div class="body scroll">
        <header class="fh">
          <span class="no mono">{fileNo(file.id)}</span>
          <Badge tone={st.tone}>{st.label}</Badge>
          <span class="opened">Opened {date(file.createdAt)} by {file.createdByName || 'Unknown'}{' · '}updated {agoWords(file.updatedAt)}</span>
        </header>

        <section class="subject">
          <Mugshot name={file.subject?.name || file.subjectName} size={52} />
          <div class="sw">
            <span class="eyebrow">Subject</span>
            <span class="sn">{file.subject?.name || file.subjectName}</span>
            <span class="ss">{#if file.subject?.callsign}<span class="mono">{file.subject.callsign}</span>{' · '}{/if}{file.subject?.member ? file.subject.gradeName : 'No longer in the department'}</span>
          </div>
          <div class="sw right">
            <span class="eyebrow">Complainant</span>
            <span class="sc">{file.complainant || 'Internal referral'}</span>
          </div>
        </section>

        <section>
          <h3 class="eyebrow">Allegation</h3>
          <p class="text">{file.summary}</p>
        </section>

        {#if !active}
          <section class="outcome">
            <div class="oh">
              <h3 class="eyebrow">Outcome</h3>
              <Badge tone={st.tone} solid={file.status === 'sustained'}>{st.label}</Badge>
              <span class="faint">{file.closedAt ? `closed ${dateTime(file.closedAt)}` : ''}</span>
              <span class="grow"></span>
              {#if manage}<Button size="sm" icon="rotate" busy={busy === 'reopen'} onclick={reopen}>Reopen</Button>{/if}
            </div>
            <p class="text">{file.findings || 'No findings recorded.'}</p>
          </section>
        {:else if manage}
          <section class="outcome">
            <h3 class="eyebrow">Close with an outcome</h3>
            <div class="outs" role="radiogroup" aria-label="Outcome">
              {#each iaOutcomes as o}
                <button type="button" role="radio" aria-checked={outcome === o.id} class="out {iaStatus[o.id].tone}" class:on={outcome === o.id} onclick={() => (outcome = o.id)}>
                  <span class="ol">{o.label}</span>
                  <span class="oh2">{o.hint}</span>
                </button>
              {/each}
            </div>
            <label class="sr-only" for="ia-findings">Findings</label>
            <Textarea id="ia-findings" bind:value={findings} rows={4} maxlength={8000} placeholder="Findings: what the evidence showed and any discipline given" />
            <div class="cr">
              <span class="faint">{outcome ? '' : 'Pick an outcome and write the findings to close the file.'}</span>
              <span class="grow"></span>
              <Button variant="primary" icon="check" busy={busy === 'close'} disabled={!outcome || findings.trim().length < 3} onclick={closeFile}>Close file</Button>
            </div>
          </section>
        {/if}
      </div>
    </div>

    <aside class="side" aria-label="Investigation">
      <div class="block">
        <span class="eyebrow">Investigator</span>
        {#if manage && active}
          <div class="row">
            <Select bind:value={assignee} options={assignOptions} aria-label="Investigator" />
            <Button icon="check" disabled={assignee === (file.assignedCid || '')} busy={busy === 'assign'} onclick={assign}>Assign</Button>
          </div>
        {:else}
          <p class="who">{file.assignedName || 'Nobody assigned'}</p>
        {/if}
      </div>
      <div class="block grow">
        <span class="eyebrow">Timeline · {file.timeline.filter((n) => !n.system).length} notes</span>
        <div class="timeline scroll" bind:this={timeline}>
          {#each file.timeline as n (n.id)}
            <div class="note" class:sys={n.system}>
              <span class="t mono" title={dateTime(n.at)}>{time(n.at)}<span class="d">{date(n.at)}</span></span>
              <span class="x">{#if !n.system}<b>{n.authorName}</b>{/if}<span class="tx">{n.system && n.authorName && !n.text.includes(n.authorName) ? `${n.text} · ${n.authorName}` : n.text}</span></span>
            </div>
          {:else}
            <p class="none">Nothing logged yet.</p>
          {/each}
        </div>
        {#if manage}
          <form class="add" onsubmit={addNote}>
            <label class="sr-only" for="ia-note">Add a note</label>
            <textarea id="ia-note" class="scroll" bind:value={note} rows="2" maxlength="2000" placeholder="Interviews, evidence, next steps"></textarea>
            <IconButton icon="note" label="Add note" size={36} variant="outline" disabled={!note.trim() || busy === 'note'} onclick={addNote} />
          </form>
        {/if}
      </div>
    </aside>
  </div>

  {#if manage}
    <IaFileModal bind:open={editing} {file} onsaved={(f) => set(f)} />
  {/if}
{/if}

<style>
  .file { flex: 1; display: flex; min-height: 0; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; }
  .bar { display: flex; align-items: center; gap: 8px; padding: 12px 24px 0 16px; }
  .grow { flex: 1; }
  .body { flex: 1; min-height: 0; padding: 8px 24px 24px; display: flex; flex-direction: column; gap: 16px; }
  .fh { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .no { font-size: 26px; font-weight: 600; color: var(--text); }
  .opened { color: var(--muted); }
  section { display: flex; flex-direction: column; gap: 8px; }
  .subject { flex-direction: row; align-items: center; gap: 14px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .sw { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .sw.right { margin-left: auto; text-align: right; max-width: 50%; }
  .sn { font-size: 18px; font-weight: 700; }
  .ss { color: var(--muted); }
  .sc { color: var(--text); overflow-wrap: anywhere; }
  .text { color: var(--text-2); line-height: 1.6; white-space: pre-wrap; overflow-wrap: anywhere; user-select: text; }
  .outcome { padding: 14px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); }
  .oh { display: flex; align-items: center; gap: 10px; }
  .outs { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 6px; }
  .out { display: flex; flex-direction: column; gap: 3px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); text-align: left; color: var(--text); min-width: 0; }
  .out:hover { border-color: var(--line-3); }
  .ol { font-weight: 700; }
  .oh2 { color: var(--muted); font-size: 12px; line-height: 1.3; }
  .out.on { border-color: var(--accent); background: var(--panel-2); }
  .out.on.danger { border-color: var(--danger); background: var(--danger-bg); }
  .out.on.danger .ol { color: var(--danger-text); }
  .out.on.ok { border-color: var(--ok-line); background: var(--ok-bg); }
  .out.on.ok .ol { color: var(--ok); }
  .cr { display: flex; align-items: center; gap: 10px; }
  .cr .faint { font-size: 13px; }
  .side { width: 400px; flex: none; display: flex; flex-direction: column; border-left: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .block { padding: 14px 16px; display: flex; flex-direction: column; gap: 8px; border-bottom: 1px solid var(--line); }
  .block.grow { flex: 1; min-height: 0; border-bottom: 0; }
  .row { display: flex; gap: 8px; }
  .who { color: var(--text); }
  .timeline { flex: 1; min-height: 60px; display: flex; flex-direction: column; gap: 12px; padding-right: 4px; }
  .note { display: flex; gap: 10px; }
  .note .t { display: flex; flex-direction: column; width: 64px; flex: none; color: var(--muted); font-size: 12px; line-height: 1.3; }
  .note .d { font-family: var(--font); color: var(--faint); font-size: 11px; }
  .note .x { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .note b { color: var(--text); font-weight: 600; }
  .tx { color: var(--text-2); white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.45; }
  .note.sys .tx { color: var(--muted); font-style: italic; }
  .none { color: var(--faint); font-size: 13px; }
  .add { display: flex; gap: 8px; align-items: flex-end; }
  .add textarea { flex: 1; resize: none; min-height: 36px; padding: 8px 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); outline: none; line-height: 1.4; }
  .add textarea:focus { border-color: var(--accent); }
</style>
