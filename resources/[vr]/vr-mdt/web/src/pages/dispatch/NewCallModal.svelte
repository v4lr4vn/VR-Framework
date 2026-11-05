<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Select from '../../components/Select.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import { request, upsertCall, session, dispatch, toast } from '../../lib/state.svelte.js';
  import { callback } from '../../lib/nui.js';

  let { open = $bindable(false), at = $bindable(null), oncreated } = $props();

  let title = $state('');
  let code = $state('');
  let priority = $state(2);
  let description = $state('');
  let police = $state(true);
  let ems = $state(false);
  const dispatcher = $derived(session.dept?.id === 'dispatch');
  let where = $state(session.dept?.id === 'dispatch' ? 'waypoint' : 'me');
  let unitCid = $state('');
  const unitOptions = $derived(dispatch.units.filter((u) => dispatch.positions[u.cid]).map((u) => ({ value: u.cid, label: `${u.callsign || u.name} · ${u.dept === 'ems' ? 'EMS' : 'Police'}` })));
  const whereOptions = $derived([
    ...(at ? [{ value: 'map', label: 'Where I right-clicked the map' }] : []),
    ...(dispatcher ? [] : [{ value: 'me', label: 'My position' }]),
    { value: 'waypoint', label: 'My map waypoint' },
    { value: 'unit', label: "A unit's position" },
  ]);
  let busy = $state(false);

  $effect(() => {
    if (open && at) where = 'map';
    if (!open) {
      at = null;
      if (where === 'map') where = dispatcher ? 'waypoint' : 'me';
    }
  });

  async function coords() {
    if (where === 'map' && at) return { x: at.x, y: at.y, z: 30 };
    if (where === 'waypoint') {
      const res = await callback('getWaypoint', {});
      if (res && res.x != null) return res;
      if (dispatcher) return null;
    }
    if (where === 'unit') {
      const p = unitCid && dispatch.positions[unitCid];
      return p ? { x: p.x, y: p.y, z: 30 } : null;
    }
    const me = session.me && dispatch.positions[session.me.cid];
    return me ? { x: me.x, y: me.y, z: 30 } : null;
  }

  async function submit(e) {
    e?.preventDefault();
    if (!title.trim() || busy) return;
    busy = true;
    const jobs = [police && 'leo', ems && 'ems'].filter(Boolean);
    const at = await coords();
    if (!at && dispatcher) {
      busy = false;
      toast(where === 'unit' ? 'That unit is not on the map right now.' : 'Set a waypoint on your map first.', 'error');
      return;
    }
    const res = await request('dispatch.create', { title, code, priority: Number(priority), description, jobs, coords: at }, { success: 'Call created' });
    busy = false;
    if (res.ok) {
      upsertCall(res.data);
      oncreated?.(res.data);
      open = false;
      title = '';
      code = '';
      description = '';
    }
  }
</script>

<Modal bind:open title="New call" width={520}>
  <form class="form" onsubmit={submit}>
    <div class="two">
      <Field label="Code" id="nc-code"><Input id="nc-code" bind:value={code} placeholder="10-38" maxlength={16} mono /></Field>
      <Field label="Priority" id="nc-prio"><Select id="nc-prio" bind:value={priority} options={[{ value: 1, label: 'Priority 1' }, { value: 2, label: 'Priority 2' }, { value: 3, label: 'Priority 3' }]} /></Field>
    </div>
    <Field label="Title" id="nc-title"><Input id="nc-title" bind:value={title} placeholder="Traffic stop" maxlength={64} autofocus /></Field>
    <Field label="Details" id="nc-desc"><Textarea id="nc-desc" bind:value={description} rows={3} maxlength={600} placeholder="What units need to know" /></Field>
    <div class="two">
      <Field label="Location" id="nc-where"><Select id="nc-where" bind:value={where} options={whereOptions} /></Field>
      {#if where === 'unit'}
        <Field label="Unit" id="nc-unit"><Select id="nc-unit" bind:value={unitCid} options={[{ value: '', label: unitOptions.length ? 'Pick a unit…' : 'No units on the map' }, ...unitOptions]} /></Field>
      {/if}
    </div>
    <div class="row">
      <Checkbox id="nc-police" bind:checked={police} label="Police" />
      <Checkbox id="nc-ems" bind:checked={ems} label="EMS" />
    </div>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="plus" busy={busy} disabled={!title.trim() || (!police && !ems) || (where === 'unit' && !unitCid)} onclick={submit}>Create call</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .row { display: flex; gap: 20px; }
</style>
