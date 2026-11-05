<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Photo from './Photo.svelte';
  import { dateTime } from '../../lib/format.js';

  let { open = $bindable(false), items = [], index = $bindable(0), ondelete = null } = $props();

  const item = $derived(items[index] || null);

  function step(d) {
    if (!items.length) return;
    index = (index + d + items.length) % items.length;
  }

  function key(e) {
    if (!open) return;
    if (e.key === 'ArrowRight') step(1);
    if (e.key === 'ArrowLeft') step(-1);
  }
</script>

<svelte:window onkeydown={key} />

<Modal bind:open title={item ? item.title || 'Photo' : 'Photo'} width={980}>
  {#if item}
    <div class="stage"><Photo id={item.imageId || item.id} alt={item.title || item.caption || 'Photo'} height={520} fit="contain" /></div>
    <div class="meta">
      <div class="text">
        {#if item.description || item.caption}<p>{item.description || item.caption}</p>{/if}
        <span class="sub">
          {[item.location, item.collectedBy?.name, dateTime(item.createdAt)].filter(Boolean).join(' · ')}
        </span>
      </div>
      <span class="count mono">{index + 1} / {items.length}</span>
    </div>
  {/if}
  {#snippet footer()}
    {#if ondelete && item}
      <Button variant="danger" icon="trash" onclick={() => ondelete(item)}>Remove</Button>
    {/if}
    <span class="grow"></span>
    <Button icon="arrowleft" disabled={items.length < 2} onclick={() => step(-1)}>Previous</Button>
    <Button iconRight="arrowright" disabled={items.length < 2} onclick={() => step(1)}>Next</Button>
  {/snippet}
</Modal>

<style>
  .stage { background: #05070a; border-radius: var(--radius); }
  .stage :global(.photo) { border: 0; background: #05070a; }
  .meta { display: flex; align-items: flex-start; gap: 16px; }
  .text { flex: 1; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  p { color: var(--text-2); line-height: 1.45; white-space: pre-wrap; }
  .sub { color: var(--muted); font-size: 13px; }
  .count { color: var(--faint); font-size: 12px; }
  .grow { flex: 1; }
</style>
