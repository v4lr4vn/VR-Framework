<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Photo from '../reports/Photo.svelte';
  import { callback } from '../../lib/nui.js';
  import { request } from '../../lib/state.svelte.js';

  let { open = $bindable(false), caseId = null, kind = 'note', imageId = null, item = null, onsaved } = $props();

  let title = $state('');
  let description = $state('');
  let location = $state('');
  let busy = $state(false);

  const labels = { note: 'note', item: 'item', photo: 'photo' };
  const mode = $derived(item ? item.kind : kind);
  const titleOk = $derived(mode === 'photo' ? !title.trim() || title.trim().length >= 2 : title.trim().length >= 2);

  function reset() {
    title = item?.title || '';
    description = item?.description || '';
    location = item?.location || '';
    if (!item) {
      callback('evidenceHere', {}).then((res) => {
        if (res?.ok && res.data?.street && !location) location = res.data.street;
      });
    }
  }

  $effect(() => {
    if (open) untrack(reset);
  });

  async function save(e) {
    e?.preventDefault();
    if (!titleOk || busy) return;
    busy = true;
    const data = { title: title.trim(), description: description.trim(), location: location.trim() };
    const res = item
      ? await request('evidence.update', { id: item.id, ...data }, { success: 'Evidence updated' })
      : await request('evidence.add', { caseId, kind: mode, imageId: mode === 'photo' ? imageId : undefined, ...data }, { success: 'Evidence logged' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={item ? `Edit ${labels[mode]}` : `Log ${mode === 'item' ? 'an item' : mode === 'photo' ? 'a photo' : 'a note'}`} width={560}>
  <form class="form" onsubmit={save}>
    {#if mode === 'photo' && (imageId || item?.imageId)}
      <Photo id={item?.imageId || imageId} alt="Evidence photo" height={240} fit="contain" />
    {/if}
    <Field label="Title" id="ev-title" hint={mode === 'item' ? 'What it is and how many, e.g. 9mm casings x3.' : mode === 'photo' ? 'Optional. Defaults to "Photograph".' : ''}>
      <Input id="ev-title" bind:value={title} maxlength={96} placeholder={mode === 'note' ? 'Statement: witness name' : mode === 'item' ? '9mm casings x3, bagged' : 'What the photo shows'} autofocus />
    </Field>
    <Field label={mode === 'note' ? 'Note' : 'Description'} id="ev-desc">
      <Textarea id="ev-desc" bind:value={description} rows={mode === 'note' ? 6 : 3} maxlength={2000} placeholder={mode === 'item' ? 'Bag number, where it is stored, who it was sent to' : 'Details'} />
    </Field>
    <Field label="Location" id="ev-loc" hint={item ? '' : 'Filled in from where you are standing.'}>
      <Input id="ev-loc" bind:value={location} maxlength={96} placeholder="Where it was found" />
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="save" busy={busy} disabled={!titleOk} onclick={save}>{item ? 'Save' : 'Log evidence'}</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
</style>
