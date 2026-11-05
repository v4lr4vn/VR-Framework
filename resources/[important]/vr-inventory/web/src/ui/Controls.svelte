<script>
  import { ui, t, closeInventory } from '../lib/state.svelte.js';

  const over = $derived(ui.drag && ui.drag.active && ui.drag.overZone);
  const canGive = $derived(ui.drag && ui.drag.active && ui.drag.inv === ui.player);

  const setAmount = (value) => {
    const n = Math.floor(Number(String(value).replace(/[^0-9]/g, '')) || 0);
    ui.amount = Math.max(0, Math.min(n, 999999));
  };

  const bump = (d) => setAmount((Number(ui.amount) || 0) + d);
</script>

<div class="rail">
  <div class="amount">
    <span class="lbl">{t('ui_amount')}</span>
    <div class="field">
      <button class="step" onclick={() => bump(-1)} aria-label="-"><i class="fa-solid fa-minus"></i></button>
      <input
        class="mono"
        inputmode="numeric"
        value={ui.amount > 0 ? ui.amount : ''}
        placeholder={t('ui_amount_all')}
        oninput={(e) => setAmount(e.currentTarget.value)}
        onkeydown={(e) => { if (e.key === 'Escape') e.currentTarget.blur(); }}
      />
      <button class="step" onclick={() => bump(1)} aria-label="+"><i class="fa-solid fa-plus"></i></button>
    </div>
  </div>

  <div class="zone use" class:hot={over === 'use'} class:armed={canGive} data-drop="use">
    <i class="fa-solid fa-hand-pointer"></i>
    <span>{t('ui_use')}</span>
  </div>
  <div class="zone give" class:hot={over === 'give'} class:armed={canGive} data-drop="give">
    <i class="fa-solid fa-hand-holding"></i>
    <span>{t('ui_give')}</span>
  </div>

  <button class="close" onclick={closeInventory}>
    <i class="fa-solid fa-xmark"></i>
    <span>{t('ui_close')}</span>
  </button>

  <button class="help" class:on={ui.help} onclick={() => (ui.help = !ui.help)} aria-label="help">
    <i class="fa-solid fa-keyboard"></i>
  </button>
</div>

<style>
  .rail { flex: none; width: 132px; display: flex; flex-direction: column; gap: 10px; align-self: center; animation: fade 0.2s ease; }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  .amount { display: flex; flex-direction: column; gap: 6px; padding: 10px; border-radius: var(--radius-lg); background: var(--card); border: 1px solid var(--line-2); }
  .lbl { font-family: var(--mono); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; }
  .field { display: flex; align-items: center; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg); overflow: hidden; }
  .field:focus-within { border-color: var(--accent); }
  .field input { flex: 1; min-width: 0; height: 100%; border: 0; outline: none; background: transparent; color: var(--text); text-align: center; font-size: 15px; font-weight: 600; }
  .field input::placeholder { color: var(--faint); font-family: var(--font); font-weight: 500; }
  .step { width: 28px; height: 100%; border: 0; background: var(--panel); color: var(--muted); font-size: 10px; }
  .step:hover { color: var(--text); background: var(--panel-2); }

  .zone { height: 64px; border-radius: var(--radius-lg); border: 1px dashed var(--line-3); background: var(--card); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 5px; color: var(--muted); font-weight: 700; font-size: 14px; transition: all 0.12s; }
  .zone i { font-size: 16px; }
  .zone.armed { border-color: var(--accent-line); color: var(--text-2); }
  .zone.use.hot { border-style: solid; border-color: var(--accent); background: var(--accent-soft); color: var(--accent-2); }
  .zone.give.hot { border-style: solid; border-color: var(--info); background: var(--info-bg); color: var(--info-text); }

  .close { height: 40px; display: inline-flex; align-items: center; justify-content: center; gap: 8px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--card); color: var(--text-2); font-weight: 600; font-size: 14px; }
  .close:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .help { align-self: center; width: 34px; height: 30px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--card); color: var(--muted); font-size: 13px; }
  .help:hover, .help.on { color: var(--accent-2); border-color: var(--accent-line); }
</style>
