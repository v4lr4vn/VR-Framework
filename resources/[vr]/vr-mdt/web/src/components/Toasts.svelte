<script>
  import Icon from './Icon.svelte';
  import { toasts } from '../lib/state.svelte.js';
</script>

<div class="toasts" aria-live="polite">
  {#each toasts.list as t (t.id)}
    <div class="toast {t.kind}">
      <Icon name={t.kind === 'error' ? 'alert' : t.kind === 'ok' ? 'check' : 'dot'} size={15} />
      <span>{t.text}</span>
    </div>
  {/each}
</div>

<style>
  .toasts { position: absolute; left: 50%; bottom: 20px; transform: translateX(-50%); display: flex; flex-direction: column; align-items: center; gap: 8px; z-index: 80; pointer-events: none; }
  .toast { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--line-3); color: var(--text); box-shadow: var(--shadow); font-weight: 500; max-width: 560px; }
  .ok { border-color: var(--ok-line); color: var(--ok); }
  .ok span { color: var(--text); }
  .error { border-color: var(--danger-line); color: var(--danger-text); }
  .error span { color: var(--text); }
</style>
