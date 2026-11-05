<script>
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import PersonPicker from '../court/PersonPicker.svelte';
  import BodyDiagram from './BodyDiagram.svelte';
  import InjuryList from './InjuryList.svelte';
  import { api } from '../../lib/nui.js';
  import { request, go, back, dispatch } from '../../lib/state.svelte.js';
  import { types, outcomes } from './meta.js';

  let { id = null, cid = null, name = null } = $props();

  let loaded = $state(false);
  let error = $state('');
  let title = $state('');
  let type = $state('treatment');
  let outcome = $state('');
  let patient = $state(null);
  let callId = $state('');
  let body = $state('');
  let treatment = $state('');
  let injuries = $state([]);
  let busy = $state(false);

  $effect(() => {
    if (!id && cid) patient = { cid, name: name || cid };
  });

  $effect(() => {
    if (id) load(id);
    else loaded = true;
  });

  async function load(want) {
    const res = await api('medreports.get', { id: want });
    if (!res.ok) {
      error = res.error;
      loaded = true;
      return;
    }
    const r = res.data;
    if (!r.canEdit) {
      error = 'not_allowed';
      loaded = true;
      return;
    }
    title = r.title;
    type = r.type;
    outcome = r.outcome || '';
    patient = r.cid ? { cid: r.cid, name: r.name } : { name: r.name };
    callId = r.callId ? String(r.callId) : '';
    body = r.body || '';
    treatment = r.treatment || '';
    injuries = r.injuries || [];
    loaded = true;
  }

  const callOptions = $derived.by(() => {
    const list = [...dispatch.calls, ...dispatch.closed].slice(0, 30).map((c) => ({ value: String(c.id), label: `#${c.id} · ${c.code} ${c.title}` }));
    if (callId && !list.some((o) => o.value === callId)) list.unshift({ value: callId, label: `#${callId}` });
    return [{ value: '', label: 'No linked call' }, ...list];
  });

  const valid = $derived(title.trim().length >= 3 && !!patient);

  function addInjury(i) {
    if (injuries.length >= 30) return;
    injuries = [...injuries, i];
  }

  function removeInjury(n) {
    injuries = injuries.filter((_, i) => i !== n);
  }

  async function save(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const res = await request('medreports.save', {
      id: id || undefined,
      title: title.trim(),
      type,
      cid: patient?.cid || undefined,
      name: patient?.cid ? undefined : patient?.name,
      outcome: outcome || undefined,
      callId: Number(callId) || undefined,
      body: body.trim(),
      treatment: treatment.trim(),
      injuries,
    }, { success: id ? 'Report updated' : 'Report saved' });
    busy = false;
    if (res.ok) go('medreports', { id: res.data.id });
  }
</script>

{#if !loaded}
  <div class="state"><Spinner label="Loading report" /></div>
{:else if error}
  <div class="state">
    <Empty icon={error === 'not_allowed' ? 'lock' : 'report'} title={error === 'not_allowed' ? "You can't edit this report" : 'Report not found'} text={error === 'not_allowed' ? 'Only the author or a senior medic can change it.' : 'It may have been deleted.'}>
      <Button icon="back" onclick={() => back('medreports')}>Go back</Button>
    </Empty>
  </div>
{:else}
  <form class="editor" onsubmit={save}>
    <header class="ph">
      <IconButton icon="back" label="Go back" size={34} variant="outline" onclick={() => back('medreports')} />
      <div class="titles">
        <span class="eyebrow">{id ? `Medical report #${id}` : 'Medical report'}</span>
        <h1>{id ? 'Edit report' : 'New report'}</h1>
      </div>
      <Button variant="ghost" onclick={() => back('medreports')}>Cancel</Button>
      <Button variant="primary" icon="check" type="submit" busy={busy} disabled={!valid}>Save report</Button>
    </header>

    <div class="cols">
      <div class="form scroll">
        <Field label="Title" id="mr-title"><Input id="mr-title" bind:value={title} maxlength={96} placeholder="Short summary, e.g. GSW left thigh, Grove St" autofocus={!id} /></Field>
        <div class="two">
          <Field label="Type" id="mr-type"><Select id="mr-type" bind:value={type} options={types} /></Field>
          <Field label="Outcome" id="mr-outcome"><Select id="mr-outcome" bind:value={outcome} options={[{ value: '', label: 'Not decided yet' }, ...outcomes]} /></Field>
        </div>
        <div class="two">
          <Field label="Patient" id="mr-patient" hint={patient ? '' : 'Search records, or enter a description for an unidentified patient.'}>
            <PersonPicker id="mr-patient" bind:value={patient} allowFree freeHint="Unidentified" />
          </Field>
          <Field label="Linked call" id="mr-call"><Select id="mr-call" bind:value={callId} options={callOptions} /></Field>
        </div>
        <Field label="Report" id="mr-body"><Textarea id="mr-body" bind:value={body} rows={9} maxlength={12000} placeholder="What happened, assessment, vitals, what changed during care" /></Field>
        <Field label="Treatment" id="mr-treat"><Textarea id="mr-treat" bind:value={treatment} rows={3} maxlength={2000} placeholder="Interventions and medication given" /></Field>
      </div>

      <aside class="side scroll" aria-label="Injuries">
        <div class="shead">
          <h2>Injuries</h2>
          <span class="mono muted">{injuries.length}</span>
        </div>
        <BodyDiagram {injuries} editable onadd={addInjury} height={330} />
        <InjuryList {injuries} onremove={removeInjury} />
      </aside>
    </div>
  </form>
{/if}

<style>
  .state { flex: 1; display: flex; }
  .editor { flex: 1; display: flex; flex-direction: column; min-height: 0; }
  .ph { display: flex; align-items: center; gap: 12px; padding: 16px 24px; border-bottom: 1px solid var(--line); }
  .titles { flex: 1; display: flex; flex-direction: column; gap: 2px; }
  h1 { font-size: 22px; font-weight: 700; }
  .cols { flex: 1; display: flex; min-height: 0; }
  .form { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; padding: 18px 24px 24px; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
  .side { width: 440px; flex: none; display: flex; flex-direction: column; gap: 12px; padding: 14px 18px 20px; border-left: 1px solid var(--line); background: var(--bg-2); }
  .shead { display: flex; align-items: center; gap: 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; }
</style>
