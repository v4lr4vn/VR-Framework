<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import { request } from '../../lib/state.svelte.js';

  let { open = $bindable(false), category = null, onsaved } = $props();

  let name = $state('');
  let busy = $state(false);

  $effect(() => {
    if (open) untrack(() => (name = category?.name || ''));
  });

  const ok = $derived(name.trim().length >= 2);

  async function save(e) {
    e?.preventDefault();
    if (!ok || busy) return;
    busy = true;
    const res = await request('penal.categorySave', { id: category?.id, name: name.trim() }, { success: category ? 'Category renamed' : 'Category added' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={category ? 'Rename category' : 'New category'} width={420}>
  <form onsubmit={save}>
    <Field label="Name" id="pc-name" hint="For example: Traffic, Weapons, Wildlife.">
      <Input id="pc-name" bind:value={name} maxlength={48} placeholder="Category name" autofocus />
    </Field>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="save" busy={busy} disabled={!ok} onclick={save}>{category ? 'Save' : 'Add category'}</Button>
  {/snippet}
</Modal>
