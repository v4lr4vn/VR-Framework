<script>
  import Icon from '../Icon.svelte';
  import Glyph from '../Glyph.svelte';
  let { value = $bindable(null), row, error = '', onenter } = $props();
  let text = $state(value === null || value === undefined ? '' : String(value));
  const step = $derived(Number(row.step) || 1);
  const clamp = (n) => {
    if (typeof row.min === 'number') n = Math.max(row.min, n);
    if (typeof row.max === 'number') n = Math.min(row.max, n);
    if (typeof row.precision === 'number') n = Number(n.toFixed(row.precision));
    return n;
  };
  const sync = () => {
    const t = text.trim().replace(',', '.');
    if (t === '' || t === '-') { value = null; return; }
    const n = Number(t);
    value = Number.isFinite(n) ? n : null;
  };
  const blur = () => {
    if (value === null) { text = ''; return; }
    value = clamp(value);
    text = String(value);
  };
  const bump = (dir) => {
    const base = value ?? (typeof row.min === 'number' ? row.min - (dir > 0 ? step : 0) : 0);
    value = clamp(Number((base + dir * step).toFixed(10)));
    text = String(value);
  };
</script>

<div class="ctl" class:bad={error} class:off={row.disabled}>
  {#if row.icon}<span class="lead"><Icon icon={row.icon} size={13} /></span>{/if}
  <input
    class="mono"
    inputmode="decimal"
    bind:value={text}
    oninput={sync}
    onblur={blur}
    placeholder={row.placeholder || ''}
    disabled={row.disabled}
    onkeydown={(e) => {
      if (e.key === 'ArrowUp') { e.preventDefault(); bump(1); }
      else if (e.key === 'ArrowDown') { e.preventDefault(); bump(-1); }
      else if (e.key === 'Enter') { blur(); onenter?.(); }
    }}
    autocomplete="off"
  />
  <span class="tail steps">
    <button class="tbtn" type="button" tabindex="-1" onclick={() => bump(1)} disabled={row.disabled} aria-label="Up"><Glyph name="up" size={12} /></button>
    <button class="tbtn" type="button" tabindex="-1" onclick={() => bump(-1)} disabled={row.disabled} aria-label="Down"><Glyph name="down" size={12} /></button>
  </span>
</div>

<style>

  .mono { font-family: var(--mono); }
  .steps { gap: 0; }
  .steps .tbtn { width: 22px; height: 22px; }
</style>
