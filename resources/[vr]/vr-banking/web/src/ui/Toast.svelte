<script>
  import { app } from '../lib/store.svelte.js';
</script>

{#if app.toast}
  {#key app.toast.id}
    <div class="toast {app.toast.kind}" role="status">
      <i class="fa-solid {app.toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>
      <span>{app.toast.text}</span>
    </div>
  {/key}
{/if}

<style>
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; max-width: 70%; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); animation: up 0.18s var(--ease); }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
  @keyframes up { from { transform: translate(-50%, 8px); opacity: 0; } }
</style>
