<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Icon from '../../components/Icon.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import { api, on } from '../../lib/nui.js';
  import { request, go, can } from '../../lib/state.svelte.js';
  import { date, agoWords } from '../../lib/format.js';
  import { types, outcomes, labelOf, typeTone, outcomeTone, ageOf } from './meta.js';

  let { cid } = $props();

  let data = $state(null);
  let error = $state('');
  let form = $state({ allergies: '', conditions: '', medications: '', emergencyContact: '', notes: '' });
  let saved = $state('');
  let busy = $state(false);

  const editable = $derived(can('patients.edit'));
  const dirty = $derived(JSON.stringify(form) !== saved);

  function fillForm(p) {
    form = {
      allergies: p?.allergies || '',
      conditions: p?.conditions || '',
      medications: p?.medications || '',
      emergencyContact: p?.emergencyContact || '',
      notes: p?.notes || '',
    };
    saved = JSON.stringify(form);
  }

  async function load(want, keepForm = false) {
    const res = await api('patients.get', { cid: want });
    if (want !== cid) return;
    if (res.ok) {
      data = res.data;
      error = '';
      if (!keepForm) fillForm(res.data.profile);
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    const want = cid;
    data = null;
    error = '';
    load(want);
  });

  $effect(() => on('medreports:changed', (p) => { if (!p.cid || p.cid === cid) load(cid, true); }));

  async function save(e) {
    e?.preventDefault();
    if (busy || !dirty) return;
    busy = true;
    const res = await request('patients.save', { cid, ...form }, { success: 'Medical profile saved' });
    busy = false;
    if (res.ok) {
      data.profile = res.data;
      fillForm(res.data);
    }
  }

  const id = $derived(data?.identity);
  const age = $derived(ageOf(id?.dob));
  const allergyList = $derived((data?.profile?.allergies || '').split('\n').map((s) => s.trim()).filter(Boolean));
  const gender = $derived(id?.gender === 1 || id?.gender === '1' ? 'Female' : id?.gender === 0 || id?.gender === '0' ? 'Male' : '—');
</script>

{#if error}
  <Empty icon="person" title="Patient not found" text="Their record may have been removed." />
{:else if !data}
  <Spinner label="Loading patient" />
{:else}
  <div class="pv">
    <header class="top">
      <Mugshot name={id.name} size={64} />
      <div class="who">
        <div class="meta">
          <span class="cid mono">{id.cid}</span>
          {#if id.online}<Badge tone="ok">In town</Badge>{/if}
        </div>
        <h1>{id.name}</h1>
        <dl class="facts">
          <div><dt>Born</dt><dd class="mono">{id.dob || '—'}{#if age != null}<span class="age"> ({age})</span>{/if}</dd></div>
          <div><dt>Sex</dt><dd>{gender}</dd></div>
          <div><dt>Phone</dt><dd class="mono">{id.phone || '—'}</dd></div>
          <div><dt>Occupation</dt><dd>{id.jobLabel || '—'}</dd></div>
          <div><dt>Nationality</dt><dd>{id.nationality || '—'}</dd></div>
        </dl>
      </div>
      <div class="blood" class:unknown={!id.bloodtype} aria-label="Blood type {id.bloodtype || 'unknown'}">
        <span class="bl"><Icon name="droplet" size={13} /> Blood type</span>
        <span class="bv mono">{id.bloodtype || '?'}</span>
      </div>
    </header>

    {#if allergyList.length}
      <div class="allergy" role="note">
        <Icon name="alert" size={16} />
        <b>Allergies</b>
        <span>{allergyList.join(' · ')}</span>
      </div>
    {/if}

    <div class="cols">
      <form class="profile" onsubmit={save}>
        <div class="shead">
          <h2>Medical profile</h2>
          {#if data.profile?.updatedAt}<span class="upd">Updated {agoWords(data.profile.updatedAt)} by {data.profile.updatedBy}</span>{/if}
        </div>
        <div class="grid">
          <Field label="Allergies" id="pt-allergies"><Textarea id="pt-allergies" bind:value={form.allergies} rows={3} maxlength={1000} placeholder={editable ? 'None known' : 'None recorded'} disabled={!editable} /></Field>
          <Field label="Conditions" id="pt-conditions"><Textarea id="pt-conditions" bind:value={form.conditions} rows={3} maxlength={1000} placeholder={editable ? 'Chronic conditions, past injuries' : 'None recorded'} disabled={!editable} /></Field>
          <Field label="Medications" id="pt-meds"><Textarea id="pt-meds" bind:value={form.medications} rows={3} maxlength={1000} placeholder={editable ? 'Name, dose, how often' : 'None recorded'} disabled={!editable} /></Field>
          <Field label="Notes" id="pt-notes"><Textarea id="pt-notes" bind:value={form.notes} rows={3} maxlength={1000} placeholder={editable ? 'Anything the next medic should know' : 'None recorded'} disabled={!editable} /></Field>
          <div class="span2">
            <Field label="Emergency contact" id="pt-contact"><Input id="pt-contact" bind:value={form.emergencyContact} maxlength={96} placeholder={editable ? 'Name, relationship and number' : 'None recorded'} disabled={!editable} /></Field>
          </div>
        </div>
        {#if editable}
          <div class="save">
            {#if dirty}<span class="unsaved">Unsaved changes</span>{/if}
            <Button variant="ghost" disabled={!dirty || busy} onclick={() => fillForm(data.profile)}>Discard</Button>
            <Button variant="primary" icon="check" type="submit" busy={busy} disabled={!dirty}>Save profile</Button>
          </div>
        {/if}
      </form>

      <section class="history" aria-label="Medical history">
        <div class="shead">
          <h2>History</h2>
          <span class="mono muted">{data.reports.length}</span>
          <span class="grow"></span>
          {#if can('medreports.create')}
            <Button size="sm" icon="plus" onclick={() => go('medreports', { edit: 'new', cid: id.cid, name: id.name })}>New report</Button>
          {/if}
        </div>
        <div class="reports scroll">
          {#each data.reports as r (r.id)}
            <button type="button" class="rep" onclick={() => go('medreports', { id: r.id })}>
              <div class="rrow">
                <Badge tone={typeTone(r.type)}>{labelOf(types, r.type)}</Badge>
                <span class="rt">{r.title}</span>
              </div>
              <div class="rrow sub">
                <span class="mono">{date(r.createdAt)}</span>
                <span>{r.author?.name}</span>
                {#if r.injuryCount}<span>{r.injuryCount} {r.injuryCount === 1 ? 'injury' : 'injuries'}</span>{/if}
                {#if r.outcome}<span class="out {outcomeTone(r.outcome)}">{labelOf(outcomes, r.outcome)}</span>{/if}
              </div>
            </button>
          {:else}
            <p class="none">No medical reports for this patient yet.</p>
          {/each}
        </div>
      </section>
    </div>
  </div>
{/if}

<style>
  .pv { flex: 1; display: flex; flex-direction: column; gap: 14px; min-height: 0; padding: 18px 24px 20px; }
  .top { display: flex; align-items: center; gap: 16px; }
  .who { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
  .meta { display: flex; align-items: center; gap: 8px; }
  .cid { color: var(--ems-text); font-weight: 600; font-size: 13px; letter-spacing: 0.04em; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.15; }
  .facts { margin: 4px 0 0; display: flex; gap: 22px; flex-wrap: wrap; }
  .facts div { display: flex; flex-direction: column; gap: 1px; }
  dt { color: var(--faint); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; }
  dd { margin: 0; color: var(--text); }
  .age { color: var(--muted); }
  .blood { width: 128px; flex: none; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 10px 0 8px; border-radius: var(--radius-lg); border: 1px solid #5B2A3A; background: var(--ems-bg); }
  .bl { display: flex; align-items: center; gap: 5px; color: var(--ems-text); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; font-weight: 600; }
  .bv { font-size: 36px; font-weight: 600; line-height: 1.1; color: var(--text); }
  .blood.unknown { border-color: var(--line-2); background: var(--panel); }
  .blood.unknown .bv { color: var(--faint); }
  .allergy { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-radius: var(--radius); background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger-text); }
  .allergy b { color: var(--danger-text); font-weight: 700; }
  .allergy span { color: var(--text); }
  .cols { flex: 1; display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); align-items: start; gap: 16px; min-height: 0; }
  .history { max-height: 100%; }
  .profile, .history { display: flex; flex-direction: column; gap: 12px; min-height: 0; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .shead { display: flex; align-items: center; gap: 8px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.02em; }
  .upd { margin-left: auto; color: var(--faint); font-size: 12px; }
  .grow { flex: 1; }
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .grid :global(.ta) { min-height: 76px; resize: none; }
  .span2 { grid-column: span 2; }
  .save { display: flex; align-items: center; justify-content: flex-end; gap: 8px; }
  .unsaved { color: var(--p2-text); font-size: 13px; margin-right: auto; }
  .reports { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 6px; }
  .rep { display: flex; flex-direction: column; gap: 5px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); text-align: left; flex: none; }
  .rep:hover { border-color: var(--line-3); background: var(--panel-2); }
  .rrow { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .rt { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .rrow.sub { color: var(--muted); font-size: 12px; gap: 12px; }
  .out.ok { color: var(--ok); }
  .out.info { color: var(--info-text); }
  .out.accent { color: var(--accent); }
  .out.danger { color: var(--danger-text); }
  .none { color: var(--faint); font-size: 13px; padding: 6px 2px; }
</style>
