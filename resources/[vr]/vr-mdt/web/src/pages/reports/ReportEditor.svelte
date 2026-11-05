<script>
  import { untrack } from 'svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Badge from '../../components/Badge.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import PersonPicker from './PersonPicker.svelte';
  import VehiclePicker from './VehiclePicker.svelte';
  import ChargePicker from './ChargePicker.svelte';
  import Photo from './Photo.svelte';
  import { api, callback } from '../../lib/nui.js';
  import { session, can, request, toast } from '../../lib/state.svelte.js';
  import { errorText } from '../../lib/lang.js';
  import { rememberImage } from '../../lib/images.js';
  import { money } from '../../lib/format.js';
  import { reportTypes, roles, classShort, classTone } from './util.js';

  let { report = null, prefill = {}, oncancel, onsaved } = $props();

  let keySeq = 0;
  const nextKey = () => ++keySeq;

  function fromPerson(p) {
    return {
      key: nextKey(),
      id: p.id ?? null,
      cid: p.cid || null,
      name: p.name || '',
      callsign: p.callsign || null,
      role: p.role,
      notes: p.notes || '',
      charges: (p.charges || []).map((c) => ({ id: c.id, count: c.count })),
      known: p.charges || [],
      sentenced: p.sentenced === true,
    };
  }

  const { initial, pre } = untrack(() => ({ initial: report, pre: prefill }));
  let title = $state(initial?.title || '');
  let type = $state(initial?.type || (pre.cid ? 'arrest' : 'incident'));
  let location = $state(initial?.location || '');
  let callId = $state(initial?.callId ? String(initial.callId) : pre.callId ? String(pre.callId) : '');
  let caseId = $state(initial?.caseId ? String(initial.caseId) : pre.caseId ? String(pre.caseId) : '');
  let body = $state(initial?.body || '');
  let tagText = $state((initial?.tags || []).join(', '));
  let people = $state((initial?.people || []).map(fromPerson));
  let vehicles = $state((initial?.vehicles || []).map((v) => ({ plate: v.plate, label: v.label || '', note: v.note || '' })));
  let images = $state((initial?.images || []).map((i) => ({ id: i.id, caption: i.caption || '' })));
  let otherRole = $state('witness');
  let cases = $state([]);
  let saving = $state(false);
  let capturing = $state(false);
  let touched = $state(false);

  const author = $derived(initial ? initial.author : { cid: session.me?.cid, name: session.me?.name, callsign: session.me?.callsign });
  const suspects = $derived(people.filter((p) => p.role === 'suspect'));
  const others = $derived(people.filter((p) => p.role !== 'suspect' && p.role !== 'officer'));
  const officers = $derived(people.filter((p) => p.role === 'officer'));
  const titleOk = $derived(title.trim().length >= 3);
  const callOk = $derived(!callId.trim() || /^\d{1,9}$/.test(callId.trim()));
  const caseOptions = $derived([{ value: '', label: 'No case' }, ...cases.map((c) => ({ value: String(c.id), label: `#${c.id} · ${c.title}` }))]);

  $effect(() => {
    if (!can('cases.view')) return;
    api('cases.list', { status: 'open' }).then((res) => {
      if (!res.ok) return;
      const list = res.data.items || [];
      if (initial?.case && !list.some((c) => c.id === initial.case.id)) list.unshift(initial.case);
      cases = list;
    });
  });

  $effect(() => {
    const cid = prefill.cid;
    if (initial || !cid || people.some((p) => p.cid === cid)) return;
    const entry = fromPerson({ cid, name: prefill.name || cid, role: 'suspect' });
    people = [...people, entry];
    if (!prefill.name) {
      api('people.search', { q: cid, limit: 5 }).then((res) => {
        const hit = res.ok && (res.data || []).find((p) => p.cid === cid);
        if (hit) people = people.map((p) => (p.key === entry.key ? { ...p, name: hit.name } : p));
      });
    }
  });

  function addPerson(role, p) {
    if (p.cid && people.some((x) => x.cid === p.cid && x.role === role)) {
      toast(`${p.name} is already listed as ${role}.`, 'info');
      return;
    }
    people = [...people, fromPerson({ cid: p.cid, name: p.name, callsign: p.callsign, role })];
  }

  function removePerson(key) {
    people = people.filter((p) => p.key !== key);
  }

  function update(key, patch) {
    people = people.map((p) => (p.key === key ? { ...p, ...patch } : p));
  }

  function addVehicle(v) {
    if (vehicles.some((x) => x.plate === v.plate)) return;
    vehicles = [...vehicles, v];
  }

  async function takePhoto() {
    if (images.length >= 12) {
      toast('A report can hold 12 photos.', 'error');
      return;
    }
    capturing = true;
    const res = await callback('capture', { kind: 'report' });
    capturing = false;
    if (!res || !res.ok) {
      toast(errorText(res?.error), res?.error === 'cancelled' ? 'info' : 'error');
      return;
    }
    rememberImage(res.data.id, res.data.url);
    images = [...images, { id: res.data.id, caption: '' }];
  }

  function payload() {
    const tags = tagText.split(',').map((t) => t.trim()).filter(Boolean).slice(0, 8);
    return {
      id: initial?.id,
      type,
      title: title.trim(),
      body,
      location: location.trim(),
      callId: callId.trim() ? Number(callId.trim()) : null,
      caseId: caseId ? Number(caseId) : null,
      tags,
      people: people.map((p) => ({ id: p.id || undefined, cid: p.cid || undefined, name: p.name, role: p.role, notes: p.notes.trim(), charges: p.role === 'suspect' ? p.charges : [] })),
      vehicles: vehicles.map((v) => ({ plate: v.plate, label: v.label.trim(), note: v.note.trim() })),
      images: images.map((i) => ({ id: i.id, caption: i.caption.trim() })),
    };
  }

  async function save(e) {
    e?.preventDefault();
    touched = true;
    if (!titleOk || !callOk || saving) return;
    saving = true;
    const res = await request('reports.save', $state.snapshot(payload()), { success: initial ? 'Report saved' : 'Report filed' });
    saving = false;
    if (res.ok) onsaved?.(res.data);
  }
</script>

<form class="editor" onsubmit={save}>
  <header class="bar">
    <div class="titles">
      <span class="eyebrow">{initial ? `Editing report #${initial.id}` : 'New report'}</span>
      <h1>{title.trim() || 'Untitled report'}</h1>
    </div>
    <Button variant="ghost" onclick={oncancel}>Cancel</Button>
    <Button type="submit" variant="primary" icon="save" busy={saving} disabled={!titleOk || !callOk}>{initial ? 'Save changes' : 'File report'}</Button>
  </header>

  <div class="cols scroll">
    <div class="main">
      <section class="card">
        <h2 class="eyebrow">Details</h2>
        <Field label="Title" id="re-title" error={touched && !titleOk ? 'Give the report a title of at least 3 characters.' : ''}>
          <Input id="re-title" bind:value={title} maxlength={96} placeholder="What happened, in a few words" autofocus={!initial} />
        </Field>
        <div class="grid2">
          <Field label="Type" id="re-type"><Select id="re-type" bind:value={type} options={reportTypes} /></Field>
          <Field label="Location" id="re-loc"><Input id="re-loc" bind:value={location} maxlength={96} placeholder="Street or landmark" /></Field>
          <Field label="Call #" id="re-call" error={callOk ? '' : 'Numbers only.'}><Input id="re-call" bind:value={callId} maxlength={9} placeholder="Optional" mono /></Field>
          <Field label="Linked case" id="re-case">
            {#if can('cases.view')}
              <Select id="re-case" bind:value={caseId} options={caseOptions} />
            {:else}
              <Input id="re-case" value={caseId ? `#${caseId}` : 'No case'} disabled />
            {/if}
          </Field>
        </div>
        <Field label="Narrative" id="re-body" hint="{body.length.toLocaleString('en-US')} / 20,000">
          <Textarea id="re-body" bind:value={body} rows={9} maxlength={20000} placeholder="Describe what happened in order: the call, what you saw, what was said, what you did." />
        </Field>
        <Field label="Tags" id="re-tags" hint="Separate with commas, up to 8.">
          <Input id="re-tags" bind:value={tagText} maxlength={200} placeholder="robbery, gang, pursuit" />
        </Field>
      </section>

      <section class="card">
        <div class="sh">
          <h2 class="eyebrow">Suspects · {suspects.length}</h2>
        </div>
        {#each suspects as s (s.key)}
          <div class="suspect">
            <div class="shead">
              <Mugshot name={s.name} size={36} />
              <div class="who">
                <span class="name">{s.name}</span>
                <span class="sub mono">{s.cid || 'No citizen record'}</span>
              </div>
              {#if s.sentenced}<Badge tone="ok" solid>Sentenced</Badge>{/if}
              <IconButton icon="trash" label="Remove {s.name}" variant="danger" disabled={s.sentenced} onclick={() => removePerson(s.key)} />
            </div>
            {#if s.sentenced}
              <div class="locked">
                {#each s.known as c}
                  <span class="lc"><Badge tone={classTone(c.class)} mono>{classShort(c.class)}</Badge> {c.title}{c.count > 1 ? ` ×${c.count}` : ''} <span class="mono muted">{money(c.fine * c.count)}</span></span>
                {/each}
                <span class="hint">Charges are locked after sentencing.</span>
              </div>
            {:else}
              <ChargePicker bind:value={() => s.charges, (v) => update(s.key, { charges: v })} known={s.known} id="cp-{s.key}" />
            {/if}
            <Input value={s.notes} oninput={(e) => update(s.key, { notes: e.currentTarget.value })} maxlength={1000} placeholder="Notes on this suspect (optional)" aria-label="Notes on {s.name}" />
          </div>
        {:else}
          <p class="none">No suspects yet.</p>
        {/each}
        <PersonPicker id="re-add-suspect" placeholder="Add a suspect by name or citizen ID" onpick={(p) => addPerson('suspect', p)} onfree={(name) => addPerson('suspect', { name })} exclude={suspects.map((s) => s.cid).filter(Boolean)} />
      </section>
    </div>

    <div class="side">
      <section class="card">
        <h2 class="eyebrow">Victims, witnesses and others · {others.length}</h2>
        {#each others as p (p.key)}
          <div class="stack">
            <div class="row">
              <div class="rsel"><Select value={p.role} options={roles.filter((r) => r.value !== 'suspect')} onchange={(e) => update(p.key, { role: e.currentTarget.value })} aria-label="Role of {p.name}" /></div>
              <div class="pw"><span class="pn">{p.name}</span><span class="sub mono">{p.cid || 'No citizen record'}</span></div>
              <IconButton icon="x" label="Remove {p.name}" variant="danger" onclick={() => removePerson(p.key)} />
            </div>
            <Input value={p.notes} oninput={(e) => update(p.key, { notes: e.currentTarget.value })} maxlength={1000} placeholder="Notes (optional)" aria-label="Notes on {p.name}" />
          </div>
        {:else}
          <p class="none">Nobody added.</p>
        {/each}
        <div class="addrow">
          <div class="rsel"><Select bind:value={otherRole} options={roles.filter((r) => r.value !== 'suspect')} aria-label="Role for the next person" /></div>
          <div class="grow"><PersonPicker id="re-add-other" placeholder="Name or citizen ID" onpick={(p) => addPerson(otherRole, p)} onfree={(name) => addPerson(otherRole, { name })} /></div>
        </div>
      </section>

      <section class="card">
        <h2 class="eyebrow">Officers · {officers.length + 1}</h2>
        <div class="chips">
          <span class="chip author"><span class="mono">{author.callsign || ''}</span> {author.name} <Badge tone="accent">Author</Badge></span>
          {#each officers as o (o.key)}
            <span class="chip"><span class="mono">{o.callsign || ''}</span> {o.name}<button type="button" class="cx" aria-label="Remove {o.name}" onclick={() => removePerson(o.key)}><Icon name="x" size={12} /></button></span>
          {/each}
        </div>
        <PersonPicker id="re-add-officer" source="staff" placeholder="Add an officer by name or callsign" onpick={(p) => addPerson('officer', p)} exclude={[author.cid, ...officers.map((o) => o.cid)]} />
      </section>

      <section class="card">
        <h2 class="eyebrow">Vehicles · {vehicles.length}</h2>
        {#each vehicles as v, i (v.plate)}
          <div class="stack">
            <div class="vrow">
              <span class="plate mono">{v.plate}</span>
              <Input bind:value={v.label} maxlength={64} placeholder="Model and colour" aria-label="Model of {v.plate}" />
              <IconButton icon="x" label="Remove {v.plate}" variant="danger" onclick={() => (vehicles = vehicles.filter((_, j) => j !== i))} />
            </div>
            <Input bind:value={v.note} maxlength={255} placeholder="Note, e.g. suspect vehicle, impounded" aria-label="Note on {v.plate}" />
          </div>
        {:else}
          <p class="none">No vehicles.</p>
        {/each}
        {#if vehicles.length < 10}<VehiclePicker id="re-add-vehicle" onpick={addVehicle} exclude={vehicles.map((v) => v.plate)} />{/if}
      </section>

      <section class="card">
        <div class="sh">
          <h2 class="eyebrow">Photos · {images.length}</h2>
          <Button size="sm" icon="photo" busy={capturing} onclick={takePhoto}>Take photo</Button>
        </div>
        {#if images.length}
          <div class="gallery">
            {#each images as img, i (img.id)}
              <div class="ph">
                <Photo id={img.id} alt={img.caption || 'Report photo'} height={78} />
                <IconButton icon="x" label="Remove photo" size={24} variant="outline" onclick={() => (images = images.filter((_, j) => j !== i))} />
                <input class="cap" bind:value={img.caption} maxlength="128" placeholder="Caption" aria-label="Caption for photo {i + 1}" />
              </div>
            {/each}
          </div>
        {:else}
          <p class="none">The tablet hides while you frame the shot. Press Enter to take it, Backspace to cancel.</p>
        {/if}
      </section>
    </div>
  </div>
</form>

<style>
  .editor { flex: 1; display: flex; flex-direction: column; min-height: 0; }
  .bar { display: flex; align-items: center; gap: 10px; padding: 14px 24px; border-bottom: 1px solid var(--line); background: var(--bg-2); }
  .titles { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  h1 { font-size: 20px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cols { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(0, 1fr) 380px; gap: 16px; padding: 16px 24px 24px; align-items: start; }
  .main, .side { display: flex; flex-direction: column; gap: 16px; min-width: 0; }
  .card { display: flex; flex-direction: column; gap: 12px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .sh { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .grid2 { display: grid; grid-template-columns: 200px minmax(0, 1fr); gap: 12px; }
  .suspect { display: flex; flex-direction: column; gap: 10px; padding: 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); }
  .shead { display: flex; align-items: center; gap: 10px; }
  .who { flex: 1; display: flex; flex-direction: column; min-width: 0; }
  .name { font-weight: 700; font-size: 15px; }
  .sub { color: var(--muted); font-size: 12px; }
  .locked { display: flex; flex-direction: column; gap: 6px; }
  .lc { display: flex; align-items: center; gap: 8px; color: var(--text); }
  .hint { color: var(--faint); font-size: 12px; }
  .none { color: var(--faint); font-size: 13px; }
  .stack { display: flex; flex-direction: column; gap: 6px; padding-bottom: 10px; border-bottom: 1px solid var(--line); }
  .row { display: flex; gap: 10px; align-items: center; }
  .rsel { width: 112px; flex: none; }
  .pw { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .pn { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .addrow { display: flex; gap: 8px; }
  .grow { flex: 1; min-width: 0; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 4px 0 10px; border-radius: var(--radius); background: var(--panel-2); color: var(--text); font-size: 13px; }
  .chip .mono { color: var(--p3-text); }
  .chip.author { padding-right: 6px; }
  .cx { width: 22px; height: 22px; border: 0; border-radius: 4px; background: transparent; color: var(--muted); display: flex; align-items: center; justify-content: center; padding: 0; }
  .cx:hover { background: var(--danger-bg); color: var(--danger-text); }
  .vrow { display: grid; grid-template-columns: 92px minmax(0, 1fr) 32px; gap: 8px; align-items: center; }
  .plate { padding: 2px 6px; border-radius: 4px; border: 1px solid var(--accent-line); color: var(--accent); font-weight: 600; font-size: 13px; text-align: center; }
  .gallery { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
  .ph { position: relative; display: flex; flex-direction: column; gap: 4px; }
  .ph :global(.ib) { position: absolute; top: 4px; right: 4px; }
  .cap { height: 26px; padding: 0 8px; border-radius: 4px; border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); font-size: 12px; outline: none; min-width: 0; }
  .cap:focus { border-color: var(--accent); }
</style>
