<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';
  import { md } from '../lib/md.js';
  import Modal from './Modal.svelte';
  import Button from './Button.svelte';

  let alert = $state(null);
  let run = $state(0);

  const done = (result) => {
    if (!alert) return;
    post('alert:result', { id: alert.id, result });
  };

  const onKey = (e) => {
    if (e.defaultPrevented) return;
    if (!alert) return;
    if (e.key === 'Escape') done('cancel');
    else if (e.key === 'Enter') done('confirm');
  };

  onMount(() => {
    const a = on('alert:open', (d) => {
      alert = d || {};
      run += 1;
    });
    const b = on('alert:close', () => (alert = null));
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if alert}
  {#key run}
    <Modal title={alert.header || ''} size={alert.size || 'sm'} centered={alert.centered !== false} closable={false}>
      <div class="content md" class:clip={alert.overflow}>{@html md(alert.content || '')}</div>
      {#snippet footer()}
        {#if alert.cancel}<Button kind="ghost" onclick={() => done('cancel')}>{alert.labels?.cancel || 'Cancel'}</Button>{/if}
        <Button kind="primary" onclick={() => done('confirm')}>{alert.labels?.confirm || 'Confirm'}</Button>
      {/snippet}
    </Modal>
  {/key}
{/if}

<style>
  .content { color: var(--text-2); line-height: 1.55; font-size: 14px; overflow-wrap: anywhere; }
  .content.clip { max-height: 50vh; overflow-y: auto; }
</style>
