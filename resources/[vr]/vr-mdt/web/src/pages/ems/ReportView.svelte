<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Panel from '../../components/Panel.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import BodyDiagram from './BodyDiagram.svelte';
  import InjuryList from './InjuryList.svelte';
  import { api } from '../../lib/nui.js';
  import { request, go, back, can } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { dateTime, agoWords } from '../../lib/format.js';
  import { types, outcomes, labelOf, typeTone, outcomeTone } from './meta.js';

  let { id } = $props();

  let r = $state(null);
  let error = $state('');
  let deleting = $state(false);

  $effect(() => {
    const want = id;
    r = null;
    error = '';
    api('medreports.get', { id: want }).then((res) => {
      if (want !== id) return;
      if (res.ok) r = res.data;
      else error = res.error;
    });
  });

  async function remove() {
    const ok = await confirm({ title: 'Delete this report?', text: `"${r.title}" will be removed from ${r.name}'s medical history. This can't be undone.`, yes: 'Delete report', danger: true });
    if (!ok) return;
    deleting = true;
    const res = await request('medreports.delete', { id: r.id }, { success: 'Report deleted' });
    deleting = false;
    if (res.ok) go('medreports');
  }
</script>

{#if error}
  <div class="state">
    <Empty icon="report" title="Report not found" text="It may have been deleted.">
      <Button icon="back" onclick={() => back('medreports')}>Go back</Button>
    </Empty>
  </div>
{:else if !r}
  <div class="state"><Spinner label="Loading report" /></div>
{:else}
  <div class="view">
    <header class="ph">
      <IconButton icon="back" label="Go back" size={34} variant="outline" onclick={() => back('medreports')} />
      <div class="titles">
        <div class="meta">
          <span class="num mono">MR-{r.id}</span>
          <Badge tone={typeTone(r.type)}>{labelOf(types, r.type)}</Badge>
          {#if r.outcome}<Badge tone={outcomeTone(r.outcome)}>{labelOf(outcomes, r.outcome)}</Badge>{/if}
        </div>
        <h1>{r.title}</h1>
        <p class="sub">
          <span class="mono">{r.author.callsign || ''}</span>{#if r.author.callsign}{' '}{/if}{r.author.name}{' · '}{dateTime(r.createdAt)}
          {#if r.updatedAt && r.updatedAt - r.createdAt > 60}{' · '}edited {agoWords(r.updatedAt)}{/if}
        </p>
      </div>
      <div class="actions">
        {#if r.canDelete}<Button variant="danger" icon="trash" busy={deleting} onclick={remove}>Delete</Button>{/if}
        {#if r.canEdit}<Button icon="edit" onclick={() => go('medreports', { edit: r.id })}>Edit</Button>{/if}
      </div>
    </header>

    <div class="cols">
      <div class="main scroll">
        <div class="facts">
          <div class="patient">
            <span class="eyebrow">Patient</span>
            {#if r.cid && can('patients.view')}
              <button type="button" class="pname link" onclick={() => go('patients', { cid: r.cid })}>{r.name} <Icon name="chevron" size={14} /></button>
            {:else}
              <span class="pname">{r.name}</span>
            {/if}
            <span class="pcid mono">{r.cid || 'Unidentified'}</span>
          </div>
          <div class="fact">
            <span class="eyebrow">Linked call</span>
            {#if r.callId}<span class="fv mono">#{r.callId}</span>{:else}<span class="fv none">None</span>{/if}
          </div>
          <div class="fact">
            <span class="eyebrow">Injuries</span>
            <span class="fv mono">{r.injuries.length}</span>
          </div>
        </div>

        <Panel title="Report" eyebrow="Narrative">
          {#if r.body}<p class="text">{r.body}</p>{:else}<p class="none">No narrative written.</p>{/if}
        </Panel>
        <Panel title="Treatment" eyebrow="Care given">
          {#if r.treatment}<p class="text">{r.treatment}</p>{:else}<p class="none">No treatment recorded.</p>{/if}
        </Panel>
      </div>

      <aside class="side scroll" aria-label="Injuries">
        <div class="shead">
          <h2>Injuries</h2>
          <span class="mono muted">{r.injuries.length}</span>
        </div>
        <BodyDiagram injuries={r.injuries} height={360} />
        <InjuryList injuries={r.injuries} />
      </aside>
    </div>
  </div>
{/if}

<style>
  .state { flex: 1; display: flex; }
  .view { flex: 1; display: flex; flex-direction: column; min-height: 0; }
  .ph { display: flex; align-items: flex-start; gap: 14px; padding: 18px 24px 16px; border-bottom: 1px solid var(--line); }
  .titles { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
  .meta { display: flex; align-items: center; gap: 8px; }
  .num { color: var(--ems-text); font-weight: 600; letter-spacing: 0.04em; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.15; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 13px; }
  .actions { display: flex; gap: 8px; flex: none; padding-top: 2px; }
  .cols { flex: 1; display: flex; min-height: 0; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; padding: 16px 20px 20px 24px; }
  .facts { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 1fr) minmax(0, 1fr); gap: 10px; }
  .patient, .fact { display: flex; flex-direction: column; gap: 3px; padding: 12px 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); min-width: 0; }
  .patient { border-color: var(--ems-bg); background: linear-gradient(180deg, rgba(255, 111, 145, 0.07), rgba(255, 111, 145, 0) 70%), var(--panel); }
  .pname { font-size: 16px; font-weight: 700; color: var(--text); text-align: left; display: inline-flex; align-items: center; gap: 4px; }
  .link { border: 0; background: transparent; padding: 0; }
  .link:hover { color: var(--accent); }
  .pcid { color: var(--muted); font-size: 12px; }
  .fv { font-size: 16px; font-weight: 600; }
  .fv.none { color: var(--faint); font-weight: 500; font-family: var(--font); }
  .text { color: var(--text-2); line-height: 1.55; white-space: pre-wrap; user-select: text; }
  .none { color: var(--faint); font-size: 13px; }
  .side { width: 440px; flex: none; display: flex; flex-direction: column; gap: 12px; padding: 14px 18px 20px; border-left: 1px solid var(--line); background: var(--bg-2); }
  .shead { display: flex; align-items: center; gap: 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; }
</style>
