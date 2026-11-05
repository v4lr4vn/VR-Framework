<script>
  import { tick, untrack } from 'svelte';
  import { toDate, dayStart, sameDay, fmtDate, grid, MONTHS } from '../../lib/date.js';
  import { place, outside } from './popover.js';
  import Glyph from '../Glyph.svelte';
  import Icon from '../Icon.svelte';

  let { value = $bindable(null), row, error = '', range = false } = $props();

  const f = $derived(row.format || 'DD/MM/YYYY');
  const min = $derived(toDate(row.min) ? dayStart(toDate(row.min)) : null);
  const max = $derived(toDate(row.max) ? dayStart(toDate(row.max)) : null);

  const asDates = $derived(range ? (Array.isArray(value) ? value.map((x) => (x ? new Date(x) : null)) : [null, null]) : value ? new Date(value) : null);

  let open = $state(false);
  let anchor = $state();
  let style = $state('');
  const seed = untrack(() => (range ? Array.isArray(value) && value[0] : value) || Date.now());
  let view = $state({ y: new Date(seed).getFullYear(), m: new Date(seed).getMonth() });
  let hover = $state(null);

  const days = $derived(grid(view.y, view.m));
  const today = new Date();

  const blocked = (d) => (min && d < min) || (max && d > max);
  const shift = (n) => {
    const d = new Date(view.y, view.m + n, 1);
    view = { y: d.getFullYear(), m: d.getMonth() };
  };

  const pick = (d) => {
    if (blocked(d)) return;
    if (!range) {
      value = d.getTime();
      open = false;
      return;
    }
    const [a, b] = asDates;
    if (!a || (a && b)) value = [d.getTime(), null];
    else if (d < a) value = [d.getTime(), a.getTime()];
    else {
      value = [a.getTime(), d.getTime()];
      open = false;
    }
  };

  const inRange = (d) => {
    if (!range) return false;
    const [a, b] = asDates;
    const end = b || (a && hover);
    if (!a || !end) return false;
    const lo = a < end ? a : end;
    const hi = a < end ? end : a;
    return d > lo && d < hi;
  };
  const isPicked = (d) => (range ? asDates.some((x) => sameDay(x, d)) : sameDay(asDates, d));

  const label = $derived(range ? (asDates[0] ? `${fmtDate(asDates[0], f)} – ${asDates[1] ? fmtDate(asDates[1], f) : '…'}` : '') : asDates ? fmtDate(asDates, f) : '');

  const toggle = async () => {
    if (row.disabled) return;
    open = !open;
    if (open) {
      style = place(anchor, 320, 268);
      await tick();
    }
  };
</script>

<div class="wrap" use:outside={() => (open = false)}>
  <div class="ctl dt" class:open class:bad={error} class:off={row.disabled} bind:this={anchor} role="button" tabindex={row.disabled ? -1 : 0} onclick={toggle} onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && toggle()}>
    <span class="lead">{#if row.icon}<Icon icon={row.icon} size={13} />{:else}<Glyph name="calendar" size={14} />{/if}</span>
    <span class="txt mono" class:ph={!label}>{label || row.placeholder || f}</span>
    {#if row.clearable && label}
      <span class="tail"><button class="tbtn" type="button" tabindex="-1" onclick={(e) => { e.stopPropagation(); value = range ? [null, null] : null; }} aria-label="Clear"><Glyph name="close" size={11} /></button></span>
    {/if}
  </div>
  {#if open}
    <div class="pop cal" {style} role="dialog" tabindex="-1" onkeydown={(e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); open = false; } }}>
      <div class="head">
        <button type="button" class="nav" onclick={() => shift(-1)} aria-label="Previous"><Glyph name="left" size={14} /></button>
        <span class="ttl">{MONTHS[view.m]} <span class="mono">{view.y}</span></span>
        <button type="button" class="nav" onclick={() => shift(1)} aria-label="Next"><Glyph name="right" size={14} /></button>
      </div>
      <div class="wk">{#each ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'] as w}<span>{w}</span>{/each}</div>
      <div class="days">
        {#each days as d}
          <button
            type="button"
            class="day mono"
            class:out={d.getMonth() !== view.m}
            class:today={sameDay(d, today)}
            class:on={isPicked(d)}
            class:mid={inRange(d)}
            disabled={blocked(d)}
            onmouseenter={() => (hover = d)}
            onclick={() => pick(d)}
          >{d.getDate()}</button>
        {/each}
      </div>
    </div>
  {/if}
</div>

<style>
  .wrap { position: relative; }
  .dt { cursor: pointer; outline: none; }
  .dt .lead { margin-right: -4px; }
  .txt { flex: 1; min-width: 0; padding: 0 12px; font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .txt.ph { color: var(--faint); }
  .mono { font-family: var(--mono); }
  .cal { padding: 10px; display: flex; flex-direction: column; gap: 6px; }
  .head { display: flex; align-items: center; justify-content: space-between; }
  .ttl { font-weight: 700; font-size: 14px; }
  .ttl .mono { color: var(--p2-text); font-weight: 600; font-size: 13px; }
  .nav { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; border-radius: 5px; border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text-2); }
  .nav:hover { border-color: var(--line-3); color: var(--text); }
  .wk, .days { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px; }
  .wk span { text-align: center; font-size: 11px; font-weight: 600; letter-spacing: 0.06em; color: var(--faint); padding: 4px 0; text-transform: uppercase; }
  .day { height: 32px; border-radius: 5px; border: 1px solid transparent; background: transparent; color: var(--text-2); font-size: 13px; padding: 0; }
  .day:hover:not(:disabled) { background: var(--panel-2); color: var(--text); }
  .day.out { color: var(--faint); opacity: 0.6; }
  .day.today { border-color: var(--line-3); }
  .day.mid { background: var(--accent-soft); color: var(--text); border-radius: 0; }
  .day.on { background: var(--accent); color: var(--accent-ink); font-weight: 600; }
  .day:disabled { opacity: 0.25; cursor: not-allowed; }
</style>
