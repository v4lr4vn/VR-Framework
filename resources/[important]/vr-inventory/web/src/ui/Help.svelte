<script>
  import { ui, t } from '../lib/state.svelte.js';

  const rows = [
    ['RMB', 'ui_rmb'],
    ['CTRL + LMB', 'ui_ctrl_lmb'],
    ['SHIFT + DRAG', 'ui_shift_drag'],
    ['CTRL + SHIFT + LMB', 'ui_ctrl_shift_lmb'],
    ['ALT + LMB', 'ui_alt_lmb'],
    ['DBL CLICK', 'ui_dblclick'],
    ['CTRL + C', 'ui_ctrl_c'],
  ];
</script>

{#if ui.help}
  <div class="help" role="dialog">
    <button class="x" onclick={() => (ui.help = false)} aria-label="close"><i class="fa-solid fa-xmark"></i></button>
    <div class="title mono">{t('ui_usefulcontrols')}</div>
    {#each rows as [key, label] (key)}
      <div class="row"><kbd class="key">{key}</kbd><span>{t(label)}</span></div>
    {/each}
  </div>
{/if}

<style>
  .help {
    position: fixed; left: 50%; top: 50%; transform: translate(-50%, -50%); z-index: 50; width: 420px; padding: 12px 14px;
    background: var(--card-solid); border: 1px solid var(--line-3); border-radius: var(--radius-lg); box-shadow: 0 14px 34px rgba(0, 0, 0, 0.6);
    display: flex; flex-direction: column; gap: 6px; animation: up 0.15s ease-out;
  }
  @keyframes up { from { opacity: 0; transform: translate(-50%, calc(-50% + 8px)); } to { opacity: 1; transform: translate(-50%, -50%); } }
  .x { position: absolute; right: 8px; top: 8px; width: 26px; height: 26px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--muted); font-size: 12px; }
  .x:hover { color: var(--text); }
  .title { font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; margin-bottom: 2px; }
  .row { display: flex; align-items: center; gap: 10px; font-size: 13px; color: var(--text-2); }
  .row :global(kbd) { flex: none; min-width: 128px; justify-content: center; }
</style>
