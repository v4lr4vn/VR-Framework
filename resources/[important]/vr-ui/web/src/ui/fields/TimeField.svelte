<script>
  import Glyph from '../Glyph.svelte';
  import Icon from '../Icon.svelte';
  let { value = $bindable(null), row, error = '' } = $props();
  const twelve = $derived(String(row.format) === '12');
  const init = value ? new Date(value) : null;
  let hh = $state(init ? init.getHours() : null);
  let mm = $state(init ? init.getMinutes() : null);

  const sync = () => {
    if (hh === null || mm === null) { value = null; return; }
    const d = new Date();
    d.setHours(hh, mm, 0, 0);
    value = d.getTime();
  };
  const shownH = $derived(hh === null ? '--' : String(twelve ? hh % 12 || 12 : hh).padStart(2, '0'));
  const shownM = $derived(mm === null ? '--' : String(mm).padStart(2, '0'));
  const bumpH = (n) => { hh = ((hh ?? (n > 0 ? -1 : 0)) + n + 24) % 24; if (mm === null) mm = 0; sync(); };
  const bumpM = (n) => { mm = ((mm ?? (n > 0 ? -1 : 0)) + n + 60) % 60; if (hh === null) hh = 12; sync(); };
  const keyH = (e) => { if (e.key === 'ArrowUp') { e.preventDefault(); bumpH(1); } else if (e.key === 'ArrowDown') { e.preventDefault(); bumpH(-1); } else if (/^\d$/.test(e.key)) { const n = Number(`${hh !== null && hh < 3 ? hh : ''}${e.key}`); hh = n < 24 ? n : Number(e.key); if (mm === null) mm = 0; sync(); } };
  const keyM = (e) => { if (e.key === 'ArrowUp') { e.preventDefault(); bumpM(1); } else if (e.key === 'ArrowDown') { e.preventDefault(); bumpM(-1); } else if (/^\d$/.test(e.key)) { const n = Number(`${mm !== null && mm < 6 ? mm : ''}${e.key}`); mm = n < 60 ? n : Number(e.key); if (hh === null) hh = 12; sync(); } };
</script>

<div class="ctl tm" class:bad={error} class:off={row.disabled}>
  <span class="lead">{#if row.icon}<Icon icon={row.icon} size={13} />{:else}<Glyph name="clock" size={14} />{/if}</span>
  <span class="seg">
    <button type="button" class="part mono" onkeydown={keyH} onwheel={(e) => bumpH(e.deltaY < 0 ? 1 : -1)} onclick={() => bumpH(1)} disabled={row.disabled}>{shownH}</button>
    <span class="colon">:</span>
    <button type="button" class="part mono" onkeydown={keyM} onwheel={(e) => bumpM(e.deltaY < 0 ? 5 : -5)} onclick={() => bumpM(5)} disabled={row.disabled}>{shownM}</button>
    {#if twelve}
      <button type="button" class="ampm mono" disabled={row.disabled || hh === null} onclick={() => { hh = (hh + 12) % 24; sync(); }}>{hh !== null && hh >= 12 ? 'PM' : 'AM'}</button>
    {/if}
  </span>
  {#if row.clearable && hh !== null}
    <span class="tail"><button class="tbtn" type="button" tabindex="-1" onclick={() => { hh = null; mm = null; sync(); }} aria-label="Clear"><Glyph name="close" size={11} /></button></span>
  {/if}
</div>

<style>
  .tm .lead { margin-right: -2px; }
  .seg { flex: 1; display: inline-flex; align-items: center; gap: 2px; padding: 0 10px; }
  .mono { font-family: var(--mono); }
  .part { min-width: 30px; height: 26px; border-radius: 4px; border: 1px solid transparent; background: transparent; color: var(--text); font-size: 14px; font-weight: 600; }
  .part:hover, .part:focus { background: var(--panel-2); border-color: var(--line-3); outline: none; }
  .colon { color: var(--faint); font-weight: 600; }
  .ampm { margin-left: 6px; height: 24px; padding: 0 8px; border-radius: 4px; border: 1px solid var(--accent-line); background: var(--accent-soft); color: var(--accent-2); font-size: 12px; font-weight: 600; }
</style>
