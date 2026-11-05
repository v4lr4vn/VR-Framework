<script>
  import Glyph from './Glyph.svelte';
  import { parse, monthGrid, addMonths, iso, monthText, dayText } from '../lib/gamedate.js';
  import { t } from '../lib/i18n.js';

  // Picks a date on the game's calendar. `value` is 'YYYY-MM-DD' or '' (no date, when allowNone is set).
  // It is drawn here, not with the browser's own date box, because the game's browser can fail to show that popup.
  let { value = '', today, allowNone = false, onchange, label = '' } = $props();

  let open = $state(false);
  const start = parse(value) ?? parse(today) ?? { y: 2026, m: 1, d: 1 };
  let shown = $state({ y: start.y, m: start.m });
  const rows = $derived(monthGrid(shown.y, shown.m, 1));

  function move(n) {
    const next = addMonths(shown.y, shown.m, n);
    if (next.y >= 2000 && next.y <= 2100) shown = next;
  }

  function pick(date) {
    onchange?.(date);
    open = false;
  }

  function toggle() {
    if (!open) {
      const p = parse(value) ?? parse(today);
      if (p) shown = { y: p.y, m: p.m };
    }
    open = !open;
  }
</script>

<div class="dp">
  <button type="button" class="field" onclick={toggle} aria-expanded={open} aria-label={label}>
    <Glyph name="calendar" size={18} />
    <span>{value ? dayText(value, true) : t('date.none')}</span>
  </button>

  {#if open}
    <div class="pop">
      <div class="bar">
        <button type="button" class="nav" onclick={() => move(-1)} aria-label={t('date.prev')}><Glyph name="chev-left" size={18} stroke={2.4} /></button>
        <b>{monthText(shown.y, shown.m)}</b>
        <button type="button" class="nav" onclick={() => move(1)} aria-label={t('date.next')}><Glyph name="chev-right" size={18} stroke={2.4} /></button>
      </div>
      <div class="week">
        {#each [1, 2, 3, 4, 5, 6, 0] as d (d)}<span>{t(`day.${d}`).slice(0, 2)}</span>{/each}
      </div>
      {#each rows as row, i (i)}
        <div class="rowd">
          {#each row as cell (cell.date)}
            <button type="button" class="day" class:dim={!cell.inMonth} class:sel={cell.date === value} class:now={cell.date === today} onclick={() => pick(cell.date)}>{cell.day}</button>
          {/each}
        </div>
      {/each}
      <div class="foot">
        <button type="button" class="link" onclick={() => pick(today)}>{t('date.today')}</button>
        {#if allowNone}<button type="button" class="link red" onclick={() => pick('')}>{t('date.clear')}</button>{/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .dp {
    position: relative;
  }
  .field {
    width: 100%;
    height: 46px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 14px;
    border-radius: 14px;
    border: 1px solid var(--line);
    background: var(--surface);
    font-size: 16px;
    color: var(--ink);
    text-align: left;
  }
  .pop {
    margin-top: 6px;
    padding: 10px;
    border-radius: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
  }
  .bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 6px;
    font-size: 14.5px;
  }
  .nav {
    width: 32px;
    height: 32px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: var(--surface-2);
    color: var(--ink);
  }
  .week,
  .rowd {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 2px;
  }
  .week span {
    text-align: center;
    font-size: 11px;
    font-weight: 700;
    color: var(--ink-3);
    padding: 4px 0;
  }
  .day {
    height: 34px;
    border-radius: 10px;
    font-size: 14px;
    color: var(--ink);
  }
  .day.dim {
    color: var(--ink-3);
    opacity: 0.55;
  }
  .day.now {
    box-shadow: inset 0 0 0 1.5px var(--accent);
  }
  .day.sel {
    background: var(--accent);
    color: var(--on-accent);
    opacity: 1;
  }
  .foot {
    display: flex;
    justify-content: space-between;
    margin-top: 6px;
  }
  .link {
    padding: 6px 8px;
    font-size: 13.5px;
    font-weight: 700;
    color: var(--accent);
  }
  .link.red {
    color: #e5484d;
  }
</style>
