<script>
  import IconButton from './IconButton.svelte';
  let { open = $bindable(false), title, width = 520, onclose, children, footer } = $props();

  function close() {
    open = false;
    onclose?.();
  }

  function key(e) {
    if (e.key === 'Escape' && open) {
      e.stopPropagation();
      close();
    }
  }
</script>

<svelte:window onkeydown={key} />

{#if open}
  <div class="backdrop" role="presentation" onmousedown={(e) => { if (e.target === e.currentTarget) close(); }}>
    <div class="modal" role="dialog" aria-modal="true" aria-label={title} style:width="{width}px">
      <header>
        <h2>{title}</h2>
        <IconButton icon="x" label="Close" onclick={close} />
      </header>
      <div class="content scroll">{@render children()}</div>
      {#if footer}<footer>{@render footer()}</footer>{/if}
    </div>
  </div>
{/if}

<style>
  .backdrop { position: absolute; inset: 0; background: rgba(4, 6, 10, 0.66); display: flex; align-items: center; justify-content: center; z-index: 50; }
  .modal { max-height: 86%; display: flex; flex-direction: column; background: var(--bg-2); border: 1px solid var(--line-3); border-radius: var(--radius-lg); box-shadow: var(--shadow); }
  header { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line); }
  h2 { font-size: 17px; font-weight: 700; }
  .content { padding: 16px; display: flex; flex-direction: column; gap: 14px; min-height: 0; }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line); }
</style>
