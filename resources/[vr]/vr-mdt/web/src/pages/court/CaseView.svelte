<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Panel from '../../components/Panel.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import CaseModal from './CaseModal.svelte';
  import ScheduleModal from './ScheduleModal.svelte';
  import VerdictModal from './VerdictModal.svelte';
  import { api, on } from '../../lib/nui.js';
  import { request, back, go, can, session } from '../../lib/state.svelte.js';
  import { dateTime, agoWords, time, date, money, months_ } from '../../lib/format.js';
  import { statusLabels, statusTone, verdictLabels, verdictTone, hearingParts } from './meta.js';

  let { id, courtrooms = [] } = $props();

  let kase = $state(null);
  let error = $state('');
  let note = $state('');
  let sending = $state(false);
  let editing = $state(false);
  let scheduling = $state(false);
  let ruling = $state(false);
  let timeline = $state(null);

  async function load() {
    const res = await api('court.get', { id });
    if (res.ok) {
      kase = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    id;
    kase = null;
    load();
  });

  $effect(() => on('court:changed', (p) => { if (p.id === id && !sending) load(); }));

  $effect(() => {
    kase?.events?.length;
    if (timeline) queueMicrotask(() => (timeline.scrollTop = timeline.scrollHeight));
  });

  function updated(data) {
    kase = data;
  }

  async function sendNote(e) {
    e?.preventDefault();
    const text = note.trim();
    if (!text || sending) return;
    sending = true;
    const res = await request('court.note', { id, text });
    sending = false;
    if (res.ok) {
      kase = res.data;
      note = '';
    }
  }

  const parties = $derived(kase ? [
    { key: 'defendant', label: 'Defendant', p: kase.defendant, empty: 'Unknown' },
    { key: 'prosecutor', label: 'Prosecution', p: kase.prosecutor, empty: 'Not assigned' },
    { key: 'defense', label: 'Defense', p: kase.defense, empty: 'Self-represented' },
    { key: 'judge', label: 'Presiding judge', p: kase.judge, empty: 'Not assigned' },
  ] : []);

  const hearing = $derived(kase?.hearingAt ? hearingParts(kase.hearingAt) : null);
  const eventIcons = { filed: 'folder', scheduled: 'calendar', note: 'note', verdict: 'gavel', status: 'flag' };
  const totalCounts = $derived(kase ? kase.charges.reduce((n, c) => n + (c.count || 1), 0) : 0);

  function openPerson(p) {
    if (p?.cid && can('records.view')) go('citizens', { cid: p.cid });
  }
</script>

{#if error}
  <div class="state">
    <Empty icon="court" title={error === 'not_found' ? 'Case not found' : "Couldn't load this case"} text={error === 'not_found' ? 'It may have been removed.' : 'Try again in a moment.'}>
      <Button icon="back" onclick={() => back('court')}>Back to cases</Button>
    </Empty>
  </div>
{:else if !kase}
  <div class="state"><Spinner label="Loading case" /></div>
{:else}
  <div class="view">
    <header class="ph">
      <IconButton icon="back" label="Back to cases" size={34} variant="outline" onclick={() => back('court')} />
      <div class="titles">
        <div class="meta">
          <span class="num mono">{kase.number}</span>
          <Badge tone={statusTone(kase.status)}>{statusLabels[kase.status]}</Badge>
          {#if kase.role}<Badge tone="doj">You: {kase.role === 'judge' ? 'judge' : kase.role}</Badge>{/if}
        </div>
        <h1>{kase.title}</h1>
        <p class="sub">Filed {dateTime(kase.createdAt)}{' · '}updated {agoWords(kase.updatedAt)}</p>
      </div>
      <div class="actions">
        {#if kase.can.edit}<Button icon="edit" onclick={() => (editing = true)}>Edit</Button>{/if}
        {#if kase.can.schedule}<Button icon="calendar" onclick={() => (scheduling = true)}>{kase.hearingAt ? 'Reschedule' : 'Schedule'}</Button>{/if}
        {#if kase.can.verdict}<Button variant="primary" icon="gavel" onclick={() => (ruling = true)}>Record verdict</Button>{/if}
      </div>
    </header>

    <div class="cols">
      <div class="main scroll">
        <section class="parties" aria-label="Parties">
          {#each parties as x}
            <div class="party" class:empty={!x.p}>
              <span class="eyebrow">{x.label}</span>
              {#if x.p}
                {#if x.key === 'defendant' && x.p.cid && can('records.view')}
                  <button type="button" class="pname link" onclick={() => openPerson(x.p)}>{x.p.name}</button>
                {:else}
                  <span class="pname">{x.p.name}</span>
                {/if}
                <span class="pcid mono">{x.p.cid || 'Not in records'}{#if x.p.cid === session.me?.cid}{' · you'}{/if}</span>
              {:else}
                <span class="pname none">{x.empty}</span>
              {/if}
            </div>
          {/each}
        </section>

        <div class="row2">
          <Panel title="Charges" eyebrow="{kase.charges.length} {kase.charges.length === 1 ? 'charge' : 'charges'} · {totalCounts} {totalCounts === 1 ? 'count' : 'counts'}">
            {#if kase.charges.length}
              <ol class="charges">
                {#each kase.charges as c}
                  <li>
                    <span class="cnt mono">{c.count}x</span>
                    <span class="ct">{c.title}</span>
                    {#if c.id}<span class="pc mono">PC {c.id}</span>{/if}
                  </li>
                {/each}
              </ol>
            {:else}
              <p class="none">No charges listed.</p>
            {/if}
          </Panel>

          <Panel title="Hearing" eyebrow={kase.courtroom || 'Not scheduled'}>
            {#if hearing}
              <div class="hearing">
                <div class="cal">
                  <span class="d mono">{hearing.day}</span>
                  <span class="n">{hearing.date}</span>
                </div>
                <div class="hinfo">
                  <span class="ht mono">{hearing.time}</span>
                  <span class="hr">{hearing.rel || date(kase.hearingAt)}</span>
                  <span class="room"><Icon name="court" size={13} /> {kase.courtroom}</span>
                </div>
              </div>
            {:else}
              <p class="none">No hearing set.</p>
              {#if kase.can.schedule}<div><Button size="sm" icon="calendar" onclick={() => (scheduling = true)}>Schedule a hearing</Button></div>{/if}
            {/if}
          </Panel>
        </div>

        {#if kase.verdict}
          <Panel title="Verdict" eyebrow="Ruling">
            <div class="verdict">
              <Badge tone={verdictTone(kase.verdict)} solid={kase.verdict === 'guilty'}>{verdictLabels[kase.verdict]}</Badge>
              {#if kase.sentence && (kase.verdict === 'guilty' || kase.verdict === 'plea')}
                <div class="terms">
                  <div><span class="eyebrow">Fine</span><span class="tv mono">{money(kase.sentence.fine)}</span></div>
                  <div><span class="eyebrow">Prison</span><span class="tv mono">{months_(kase.sentence.months)}</span></div>
                  <div>
                    <span class="eyebrow">Applied</span>
                    {#if kase.sentence.executed}
                      <span class="tv ok"><Icon name="check" size={14} /> Applied</span>
                    {:else if kase.sentence.apply}
                      <span class="tv warn"><Icon name="alert" size={14} /> Stored, not applied</span>
                    {:else}
                      <span class="tv muted">Not requested</span>
                    {/if}
                  </div>
                </div>
              {/if}
            </div>
            {#if kase.sentence?.notes}<p class="vnotes">{kase.sentence.notes}</p>{/if}
            {#if kase.sentence?.apply && !kase.sentence.executed}
              <p class="hint">{kase.sentence.reason === 'no_defendant' ? 'The defendant has no citizen record, so the sentence has to be carried out by hand.' : 'The sentencing or prison system was unavailable. Apply the sentence manually.'}</p>
            {/if}
          </Panel>
        {/if}

        <Panel title="Summary" eyebrow="Case file">
          {#if kase.summary}<p class="summary">{kase.summary}</p>{:else}<p class="none">No summary yet.</p>{/if}
          {#if kase.reportId || kase.caseId}
            <div class="links">
              {#if kase.reportId}
                <Button size="sm" icon="report" disabled={!can(['reports.view', 'reports.create'])} onclick={() => go('reports', { id: kase.reportId })}>Report <span class="mono">#{kase.reportId}</span></Button>
              {/if}
              {#if kase.caseId}
                <Button size="sm" icon="folder" disabled={!can('cases.view')} onclick={() => go('cases', { id: kase.caseId })}>Investigation <span class="mono">#{kase.caseId}</span></Button>
              {/if}
            </div>
          {/if}
        </Panel>
      </div>

      <aside class="side" aria-label="Timeline">
        <div class="shead">
          <h2>Timeline</h2>
          <span class="mono muted">{kase.events.length}</span>
        </div>
        <div class="timeline scroll" bind:this={timeline}>
          {#each kase.events as e (e.id)}
            <div class="ev {e.kind}">
              <span class="eico"><Icon name={eventIcons[e.kind] || 'dot'} size={13} /></span>
              <div class="ebody">
                <div class="ehead"><b>{e.author || 'System'}</b><span class="et mono">{date(e.at)} {time(e.at)}</span></div>
                <p>{e.text}</p>
              </div>
            </div>
          {:else}
            <p class="none">Nothing logged yet.</p>
          {/each}
        </div>
        {#if kase.can.note}
          <form class="add" onsubmit={sendNote}>
            <label class="sr-only" for="court-note">Add a note to the case</label>
            <textarea id="court-note" bind:value={note} rows="2" maxlength="1000" placeholder="Add a note for the court record" onkeydown={(e) => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) sendNote(e); }}></textarea>
            <Button variant="primary" size="sm" icon="note" busy={sending} disabled={!note.trim()} onclick={sendNote}>Add note</Button>
          </form>
        {:else}
          <p class="readonly">Only parties to the case can add notes.</p>
        {/if}
      </aside>
    </div>
  </div>

  <CaseModal bind:open={editing} {kase} onsaved={updated} />
  <ScheduleModal bind:open={scheduling} {kase} {courtrooms} onsaved={updated} />
  <VerdictModal bind:open={ruling} {kase} onsaved={updated} />
{/if}

<style>
  .state { flex: 1; display: flex; }
  .view { flex: 1; display: flex; flex-direction: column; min-height: 0; }
  .ph { display: flex; align-items: flex-start; gap: 14px; padding: 18px 24px 16px; border-bottom: 1px solid var(--line); }
  .titles { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
  .meta { display: flex; align-items: center; gap: 8px; }
  .num { color: var(--doj-text); font-weight: 600; letter-spacing: 0.04em; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.15; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 13px; }
  .actions { display: flex; gap: 8px; flex: none; padding-top: 2px; }
  .cols { flex: 1; display: flex; min-height: 0; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; padding: 16px 20px 20px 24px; }
  .parties { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
  .party { display: flex; flex-direction: column; gap: 3px; padding: 12px 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); min-width: 0; }
  .party:first-child { border-color: var(--doj-bg); background: linear-gradient(180deg, rgba(183, 156, 255, 0.07), rgba(183, 156, 255, 0) 70%), var(--panel); }
  .pname { font-size: 16px; font-weight: 700; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-align: left; }
  .pname.none { color: var(--faint); font-weight: 500; font-size: 15px; }
  .link { border: 0; background: transparent; padding: 0; }
  .link:hover { color: var(--accent); }
  .pcid { color: var(--muted); font-size: 12px; }
  .row2 { display: grid; grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr); gap: 14px; }
  .charges { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; }
  .charges li { display: flex; align-items: center; gap: 10px; padding: 7px 0; border-bottom: 1px solid var(--line); }
  .charges li:last-child { border-bottom: 0; }
  .cnt { width: 30px; color: var(--accent); font-weight: 600; flex: none; }
  .ct { flex: 1; min-width: 0; }
  .pc { font-size: 11px; color: var(--doj-text); background: var(--doj-bg); padding: 1px 6px; border-radius: 4px; }
  .none { color: var(--faint); font-size: 13px; }
  .hearing { display: flex; gap: 14px; align-items: center; }
  .cal { width: 72px; flex: none; display: flex; flex-direction: column; align-items: center; border-radius: var(--radius); overflow: hidden; border: 1px solid var(--info-line); }
  .cal .d { width: 100%; text-align: center; background: var(--info); color: var(--accent-ink); font-size: 12px; font-weight: 600; padding: 2px 0; }
  .cal .n { padding: 6px 0 7px; font-weight: 700; font-size: 15px; background: var(--info-bg); width: 100%; text-align: center; }
  .hinfo { display: flex; flex-direction: column; gap: 2px; }
  .ht { font-size: 22px; font-weight: 600; }
  .hr { color: var(--info-text); font-size: 13px; }
  .room { display: flex; align-items: center; gap: 6px; color: var(--text-2); font-size: 13px; }
  .verdict { display: flex; align-items: center; gap: 22px; flex-wrap: wrap; }
  .verdict :global(.badge) { height: 26px; font-size: 14px; padding: 0 10px; }
  .terms { display: flex; gap: 28px; }
  .terms div { display: flex; flex-direction: column; gap: 2px; }
  .tv { font-size: 16px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
  .tv.ok { color: var(--ok); font-size: 14px; }
  .tv.warn { color: var(--p2-text); font-size: 14px; }
  .tv.muted { font-size: 14px; font-weight: 500; }
  .vnotes { margin-top: 10px; color: var(--text-2); line-height: 1.5; white-space: pre-wrap; }
  .hint { margin-top: 8px; padding: 8px 10px; border-radius: var(--radius); background: var(--accent-soft); color: var(--p2-text); font-size: 13px; }
  .summary { color: var(--text-2); line-height: 1.55; white-space: pre-wrap; user-select: text; }
  .links { display: flex; gap: 8px; margin-top: 12px; }
  .side { width: 400px; flex: none; display: flex; flex-direction: column; border-left: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .shead { display: flex; align-items: center; gap: 8px; padding: 14px 16px 10px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; }
  .timeline { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 12px; padding: 4px 16px 12px; }
  .ev { display: flex; gap: 10px; }
  .eico { width: 26px; height: 26px; border-radius: 50%; flex: none; display: flex; align-items: center; justify-content: center; background: var(--panel-2); color: var(--muted); }
  .ev.verdict .eico { background: var(--doj-bg); color: var(--doj-text); }
  .ev.scheduled .eico { background: var(--info-bg); color: var(--info-text); }
  .ev.note .eico { background: var(--accent-soft); color: var(--accent); }
  .ebody { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .ehead { display: flex; align-items: baseline; gap: 8px; }
  .ehead b { font-weight: 600; color: var(--text); font-size: 13px; }
  .et { margin-left: auto; color: var(--faint); font-size: 11px; white-space: nowrap; }
  .ebody p { color: var(--text-2); line-height: 1.45; overflow-wrap: anywhere; white-space: pre-wrap; user-select: text; }
  .ev.status p, .ev.filed p, .ev.scheduled p { color: var(--muted); }
  .add { display: flex; flex-direction: column; gap: 8px; align-items: flex-end; padding: 12px 16px 14px; border-top: 1px solid var(--line); }
  .add textarea { width: 100%; resize: none; padding: 8px 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); outline: none; line-height: 1.45; }
  .add textarea:focus { border-color: var(--accent); }
  .add textarea::placeholder { color: var(--faint); }
  .readonly { padding: 12px 16px 14px; border-top: 1px solid var(--line); color: var(--faint); font-size: 13px; }
</style>
