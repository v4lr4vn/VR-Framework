<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Select from '../../components/Select.svelte';
  import PersonPicker from './PersonPicker.svelte';
  import { api } from '../../lib/nui.js';
  import { request } from '../../lib/state.svelte.js';
  import { statusLabels } from './meta.js';

  let { open = $bindable(false), kase = null, onsaved } = $props();

  let title = $state('');
  let defendant = $state(null);
  let prosecutorCid = $state('');
  let defenseCid = $state('');
  let judgeCid = $state('');
  let charges = $state([]);
  let reportId = $state('');
  let caseId = $state('');
  let summary = $state('');
  let status = $state('filed');
  let staff = $state([]);
  let penal = $state([]);
  let busy = $state(false);
  let loadedFor = null;

  const editing = $derived(!!kase);
  const final = $derived(!!kase?.verdict);

  $effect(() => {
    if (open && loadedFor !== (kase?.id || 'new')) {
      loadedFor = kase?.id || 'new';
      fill();
      loadLists();
    }
    if (!open) loadedFor = null;
  });

  function fill() {
    title = kase?.title || '';
    defendant = kase?.defendant ? { ...kase.defendant } : null;
    prosecutorCid = kase?.prosecutor?.cid || '';
    defenseCid = kase?.defense?.cid || '';
    judgeCid = kase?.judge?.cid || '';
    charges = (kase?.charges || []).map((c) => ({ ...c }));
    if (!charges.length) charges = [{ id: null, title: '', count: 1 }];
    reportId = kase?.reportId ? String(kase.reportId) : '';
    caseId = kase?.caseId ? String(kase.caseId) : '';
    summary = kase?.summary || '';
    status = kase?.status || 'filed';
  }

  async function loadLists() {
    if (!staff.length) {
      const res = await api('people.staff', { dept: 'doj' });
      if (res.ok) staff = res.data;
    }
    if (!penal.length) {
      const res = await api('penal.list', {});
      if (res.ok) penal = (res.data?.categories || []).flatMap((c) => c.charges || []).map((x) => ({ id: x.id, title: x.title || x.label || x.name })).filter((x) => x.id && x.title);
    }
  }

  function options(job, current, empty) {
    const list = staff.filter((p) => p.job === job).map((p) => ({ value: p.cid, label: `${p.name} · ${p.gradeName || p.jobLabel}` }));
    if (current && !list.some((o) => o.value === current.cid)) list.unshift({ value: current.cid, label: current.name });
    return [{ value: '', label: empty }, ...list];
  }

  const prosecutors = $derived(options('prosecutor', kase?.prosecutor, 'No prosecutor yet'));
  const lawyers = $derived(options('lawyer', kase?.defense, 'Self-represented'));
  const judges = $derived(options('judge', kase?.judge, 'Not assigned'));

  const statusOptions = $derived.by(() => {
    if (final) return [{ value: kase.status, label: statusLabels[kase.status] }, ...(kase.status !== 'closed' ? [{ value: 'closed', label: 'Closed' }] : [])];
    const list = ['filed', 'in_session', 'closed', 'dismissed'];
    if (kase?.hearingAt || kase?.status === 'scheduled') list.splice(1, 0, 'scheduled');
    return list.map((s) => ({ value: s, label: statusLabels[s] }));
  });

  function matchPenal(c) {
    const hit = penal.find((p) => p.title.toLowerCase() === c.title.trim().toLowerCase());
    c.id = hit ? hit.id : null;
  }

  function addCharge() {
    charges = [...charges, { id: null, title: '', count: 1 }];
  }

  function removeCharge(i) {
    charges = charges.filter((_, j) => j !== i);
  }

  const valid = $derived(title.trim().length >= 3 && !!defendant);

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const data = {
      id: kase?.id,
      title: title.trim(),
      defendantCid: defendant?.cid || undefined,
      defendantName: defendant?.cid ? undefined : defendant?.name,
      prosecutorCid: prosecutorCid || undefined,
      defenseCid: defenseCid || undefined,
      judgeCid: judgeCid || undefined,
      charges: charges.filter((c) => c.title.trim()).map((c) => ({ id: c.id || undefined, title: c.title.trim(), count: Number(c.count) || 1 })),
      reportId: Number(reportId) || undefined,
      caseId: Number(caseId) || undefined,
      summary: summary.trim(),
      status: editing ? status : undefined,
    };
    const res = await request('court.save', data, { success: editing ? 'Case updated' : 'Case filed' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={editing ? `Edit ${kase.number}` : 'File a new case'} width={760}>
  <form class="form" onsubmit={submit}>
    {#if final}
      <p class="note">A verdict has been recorded. Only the summary and closing the case can change now.</p>
    {/if}
    <div class="grid">
      <div class="span2">
        <Field label="Title" id="cm-title"><Input id="cm-title" bind:value={title} maxlength={96} placeholder="State v. Lastname" disabled={final} autofocus={!editing} /></Field>
      </div>
      <div class="span2">
        <Field label="Defendant" id="cm-def" hint={defendant ? '' : 'Search citizen records, or enter a name for someone not on file.'}>
          <PersonPicker id="cm-def" bind:value={defendant} allowFree disabled={final} />
        </Field>
      </div>
      <Field label="Prosecution" id="cm-pros"><Select id="cm-pros" bind:value={prosecutorCid} options={prosecutors} disabled={final} /></Field>
      <Field label="Defense" id="cm-defense"><Select id="cm-defense" bind:value={defenseCid} options={lawyers} disabled={final} /></Field>
      <Field label="Presiding judge" id="cm-judge"><Select id="cm-judge" bind:value={judgeCid} options={judges} disabled={final} /></Field>
      {#if editing}
        <Field label="Status" id="cm-status"><Select id="cm-status" bind:value={status} options={statusOptions} /></Field>
      {:else}
        <div class="links">
          <Field label="Report #" id="cm-report"><Input id="cm-report" bind:value={reportId} inputmode="numeric" mono placeholder="Optional" /></Field>
          <Field label="Case #" id="cm-case"><Input id="cm-case" bind:value={caseId} inputmode="numeric" mono placeholder="Optional" /></Field>
        </div>
      {/if}
      {#if editing}
        <div class="links span2">
          <Field label="Linked report #" id="cm-report"><Input id="cm-report" bind:value={reportId} inputmode="numeric" mono placeholder="Optional" disabled={final} /></Field>
          <Field label="Linked case #" id="cm-case"><Input id="cm-case" bind:value={caseId} inputmode="numeric" mono placeholder="Optional" disabled={final} /></Field>
        </div>
      {/if}
    </div>

    <fieldset class="charges" disabled={final}>
      <legend class="lbl">Charges</legend>
      {#each charges as c, i}
        <div class="charge">
          <label class="sr-only" for="cm-charge-{i}">Charge {i + 1}</label>
          <input id="cm-charge-{i}" class="ci" list="cm-penal" bind:value={c.title} onchange={() => matchPenal(c)} maxlength="96" placeholder={penal.length ? 'Start typing a penal code charge' : 'Charge'} autocomplete="off" />
          {#if c.id}<span class="pid mono">PC {c.id}</span>{/if}
          <label class="sr-only" for="cm-count-{i}">Counts</label>
          <input id="cm-count-{i}" class="cc mono" type="number" min="1" max="99" bind:value={c.count} />
          <IconButton icon="x" label="Remove charge {i + 1}" size={30} variant="danger" onclick={() => removeCharge(i)} disabled={final} />
        </div>
      {/each}
      {#if !final && charges.length < 25}
        <div><Button size="sm" variant="ghost" icon="plus" onclick={addCharge}>Add charge</Button></div>
      {/if}
      <datalist id="cm-penal">
        {#each penal as p}<option value={p.title}></option>{/each}
      </datalist>
    </fieldset>

    <Field label="Summary" id="cm-summary"><Textarea id="cm-summary" bind:value={summary} rows={4} maxlength={6000} placeholder="What the case is about, key facts, agreements between counsel" /></Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon={editing ? 'check' : 'gavel'} busy={busy} disabled={!valid} onclick={submit}>{editing ? 'Save changes' : 'File case'}</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 14px; }
  .span2 { grid-column: span 2; }
  .links { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .note { padding: 10px 12px; border-radius: var(--radius); background: var(--doj-bg); color: var(--doj-text); line-height: 1.45; }
  .charges { border: 0; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; padding: 0; margin-bottom: 6px; }
  .charge { display: flex; align-items: center; gap: 8px; }
  .ci, .cc { height: 34px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; }
  .ci { flex: 1; min-width: 0; }
  .cc { width: 64px; text-align: center; -moz-appearance: textfield; }
  .cc::-webkit-inner-spin-button, .cc::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }
  .ci:focus, .cc:focus { border-color: var(--accent); }
  .ci::placeholder { color: var(--faint); }
  .pid { font-size: 11px; color: var(--doj-text); background: var(--doj-bg); padding: 2px 6px; border-radius: 4px; white-space: nowrap; }
  fieldset:disabled { opacity: 0.6; }
</style>
