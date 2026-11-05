<script>
  import Button from '../../components/Button.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import { agoWords } from '../../lib/format.js';

  let { notes = '', editable = false, onsave, updatedBy = null, updatedAt = null, id = 'notes', placeholder = 'Anything officers should know' } = $props();

  let text = $state('');
  let base = $state('');
  let busy = $state(false);

  $effect(() => {
    const incoming = notes || '';
    if (incoming !== base) {
      base = incoming;
      text = incoming;
    }
  });

  const dirty = $derived(text.trim() !== base.trim());

  async function save() {
    busy = true;
    const ok = await onsave?.(text);
    busy = false;
    if (ok !== false) base = text.trim();
  }
</script>

<div class="notes">
  {#if editable}
    <label class="sr-only" for={id}>Notes</label>
    <Textarea {id} bind:value={text} rows={6} maxlength={4000} {placeholder} />
    <div class="foot">
      <span class="meta faint">
        {#if updatedBy}Updated by {updatedBy}{#if updatedAt}{' · '}{agoWords(updatedAt)}{/if}{:else}{text.length}/4000{/if}
      </span>
      {#if dirty}<Button size="sm" variant="ghost" onclick={() => (text = base)} disabled={busy}>Discard</Button>{/if}
      <Button size="sm" variant="primary" icon="check" {busy} disabled={!dirty} onclick={save}>Save notes</Button>
    </div>
  {:else if base}
    <p class="read">{base}</p>
    {#if updatedBy}<span class="meta faint">Updated by {updatedBy}{#if updatedAt}{' · '}{agoWords(updatedAt)}{/if}</span>{/if}
  {:else}
    <span class="faint">No notes.</span>
  {/if}
</div>

<style>
  .notes { display: flex; flex-direction: column; gap: 8px; }
  .foot { display: flex; align-items: center; gap: 8px; }
  .meta { font-size: 12px; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .read { color: var(--text-2); white-space: pre-wrap; line-height: 1.5; overflow-wrap: anywhere; }
</style>
