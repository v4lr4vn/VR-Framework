<script>
  import Glyph from './Glyph.svelte';
  import { pad } from '../lib/gamedate.js';
  import { phone } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // Picks a time of day as a minute (0 to 1439), or none when allowNone is set (an all-day event, a reminder with no time).
  // Hours and minutes have their own buttons: no popup that the game's browser might not draw.
  let { value = null, allowNone = false, onchange, noneLabel = '' } = $props();

  const time24 = $derived(phone.settings.general.time24);
  const h = $derived(value === null ? 9 : Math.floor(value / 60));
  const m = $derived(value === null ? 0 : value % 60);

  const set = (hh, mm) => onchange?.(((hh + 24) % 24) * 60 + ((mm + 60) % 60));
  const hourText = $derived(time24 ? pad(h) : String(h % 12 || 12));
</script>

<div class="tp">
  {#if allowNone}
    <button type="button" class="switch" class:on={value === null} onclick={() => onchange?.(value === null ? 9 * 60 : null)}>
      {noneLabel || t('time.none')}
    </button>
  {/if}
  {#if value !== null}
    <div class="dial">
      <div class="unit">
        <button type="button" onclick={() => set(h + 1, m)} aria-label={t('time.hourUp')}><Glyph name="chev-up" size={16} stroke={2.6} /></button>
        <b>{hourText}</b>
        <button type="button" onclick={() => set(h - 1, m)} aria-label={t('time.hourDown')}><Glyph name="chev-down" size={16} stroke={2.6} /></button>
      </div>
      <span class="colon">:</span>
      <div class="unit">
        <button type="button" onclick={() => set(h, m + 5)} aria-label={t('time.minuteUp')}><Glyph name="chev-up" size={16} stroke={2.6} /></button>
        <b>{pad(m)}</b>
        <button type="button" onclick={() => set(h, m - 5)} aria-label={t('time.minuteDown')}><Glyph name="chev-down" size={16} stroke={2.6} /></button>
      </div>
      {#if !time24}
        <button type="button" class="ampm" onclick={() => set(h + 12, m)}>{h >= 12 ? 'PM' : 'AM'}</button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .tp {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }
  .switch {
    padding: 11px 16px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 14px;
    font-weight: 700;
    color: var(--ink);
  }
  .switch.on {
    background: var(--accent);
    color: var(--on-accent);
  }
  .dial {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .unit {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }
  .unit b {
    min-width: 54px;
    padding: 6px 0;
    text-align: center;
    border-radius: 12px;
    background: var(--surface);
    border: 1px solid var(--line);
    font-size: 22px;
    font-variant-numeric: tabular-nums;
    color: var(--ink);
  }
  .unit button {
    width: 54px;
    height: 24px;
    display: grid;
    place-items: center;
    border-radius: 8px;
    background: var(--surface-2);
    color: var(--ink-2);
  }
  .colon {
    font-size: 22px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .ampm {
    margin-left: 6px;
    padding: 10px 12px;
    border-radius: 12px;
    background: var(--accent-soft);
    font-size: 14px;
    font-weight: 700;
    color: var(--ink);
  }
</style>
