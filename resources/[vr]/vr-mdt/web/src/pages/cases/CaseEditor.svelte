<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import PersonPicker from '../reports/PersonPicker.svelte';
  import { request, session } from '../../lib/state.svelte.js';
  import { caseRoles } from './util.js';

  let { open = $bindable(false), item = null, onsaved } = $props();

  let title = $state('');
  let summary = $state('');
  let lead = $state(null);
  let people = $state([]);
  let officers = $state([]);
  let role = $state('suspect');
  let busy = $state(false);
  let touched = $state(false);
  let seq = 0;

  function reset() {
    touched = false;
    title = item?.title || '';
    summary = item?.summary || '';
    lead = item?.lead || (item ? null : { cid: session.me?.cid, name: session.me?.name, callsign: session.me?.callsign });
    people = (item?.people || []).map((p) => ({ ...p, key: ++seq }));
    officers = (item?.officers || []).map((o) => ({ ...o }));
  }

  $effect(() => {
    if (open) untrack(reset);
  });

  const ok = $derived(title.trim().length >= 3);

  function addPerson(p) {
    if (p.cid && people.some((x) => x.cid === p.cid && x.role === role)) return;
    people = [...people, { key: ++seq, cid: p.cid || null, name: p.name, role }];
  }

  function addOfficer(o) {
    if (officers.some((x) => x.cid === o.cid)) return;
    officers = [...officers, { cid: o.cid, name: o.name, callsign: o.callsign }];
  }

  async function save(e) {
    e?.preventDefault();
    touched = true;
    if (!ok || busy) return;
    busy = true;
    const res = await request('cases.save', $state.snapshot({
      id: item?.id,
      title: title.trim(),
      summary,
      leadCid: lead?.cid || undefined,
      people: people.map((p) => ({ cid: p.cid || undefined, name: p.name, role: p.role })),
      officers: officers.map((o) => o.cid),
    }), { success: item ? 'Case saved' : 'Case opened' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={item ? `Edit case #${item.id}` : 'Open a case'} width={720}>
  <form class="form" onsubmit={save}>
    <Field label="Title" id="cs-title" error={touched && !ok ? 'At least 3 characters.' : ''}>
      <Input id="cs-title" bind:value={title} maxlength={96} placeholder="Grove St shootings" autofocus={!item} />
    </Field>
    <Field label="Summary" id="cs-sum" hint="What the case is about, what you know and what needs doing next.">
      <Textarea id="cs-sum" bind:value={summary} rows={5} maxlength={20000} />
    </Field>
    <div class="two">
      <Field label="Lead investigator" id="cs-lead">
        {#if lead}
          <div class="chosen"><Icon name="shield" size={14} /><span class="mono cs">{lead.callsign || ''}</span><span class="nm">{lead.name}</span><IconButton icon="x" label="Clear lead" size={26} onclick={() => (lead = null)} /></div>
        {:else}
          <PersonPicker id="cs-lead" source="staff" placeholder="Pick an officer" onpick={(o) => (lead = o)} />
        {/if}
      </Field>
      <Field label="Officers on the case" id="cs-off">
        <PersonPicker id="cs-off" source="staff" placeholder="Add an officer" onpick={addOfficer} exclude={officers.map((o) => o.cid)} />
      </Field>
    </div>
    {#if officers.length}
      <div class="chips">
        {#each officers as o (o.cid)}
          <span class="chip"><span class="mono">{o.callsign || ''}</span> {o.name}<button type="button" class="cx" aria-label="Remove {o.name}" onclick={() => (officers = officers.filter((x) => x.cid !== o.cid))}><Icon name="x" size={12} /></button></span>
        {/each}
      </div>
    {/if}
    <div class="people">
      <span class="lbl">People</span>
      {#each people as p (p.key)}
        <div class="prow">
          <div class="rsel"><Select value={p.role} options={caseRoles} onchange={(e) => (people = people.map((x) => (x.key === p.key ? { ...x, role: e.currentTarget.value } : x)))} aria-label="Role of {p.name}" /></div>
          <span class="pn">{p.name}</span>
          <span class="mono faint">{p.cid || 'No record'}</span>
          <IconButton icon="x" label="Remove {p.name}" variant="danger" onclick={() => (people = people.filter((x) => x.key !== p.key))} />
        </div>
      {:else}
        <p class="none">Nobody linked yet.</p>
      {/each}
      <div class="prow add">
        <div class="rsel"><Select bind:value={role} options={caseRoles} aria-label="Role for the next person" /></div>
        <div class="grow"><PersonPicker id="cs-person" placeholder="Name or citizen ID" onpick={addPerson} onfree={(name) => addPerson({ name })} up /></div>
      </div>
    </div>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="save" busy={busy} disabled={!ok} onclick={save}>{item ? 'Save case' : 'Open case'}</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .chosen { display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 4px 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .cs { color: var(--p3-text); font-size: 13px; }
  .nm { flex: 1; color: var(--text); min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: -4px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 4px 0 10px; border-radius: var(--radius); background: var(--panel-2); color: var(--text); font-size: 13px; }
  .chip .mono { color: var(--p3-text); }
  .cx { width: 22px; height: 22px; border: 0; border-radius: 4px; background: transparent; color: var(--muted); display: flex; align-items: center; justify-content: center; padding: 0; }
  .cx:hover { background: var(--danger-bg); color: var(--danger-text); }
  .people { display: flex; flex-direction: column; gap: 6px; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .prow { display: flex; align-items: center; gap: 10px; }
  .prow.add { padding-top: 6px; }
  .rsel { width: 170px; flex: none; }
  .pn { flex: 1; min-width: 0; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .grow { flex: 1; min-width: 0; }
  .none { color: var(--faint); font-size: 13px; }
</style>
