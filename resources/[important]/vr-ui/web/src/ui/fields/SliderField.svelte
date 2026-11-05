<script>
  let { value = $bindable(0), row, error = '' } = $props();
  const min = $derived(typeof row.min === 'number' ? row.min : 0);
  const max = $derived(typeof row.max === 'number' ? row.max : 100);
  const step = $derived(Number(row.step) || 1);
  const pct = $derived(max > min ? ((Number(value) - min) / (max - min)) * 100 : 0);
</script>

<div class="sl" class:off={row.disabled}>
  <input type="range" {min} {max} {step} bind:value disabled={row.disabled} style:--p="{pct}%" />
  <span class="val">{value}</span>
</div>

<style>
  .sl { display: flex; align-items: center; gap: 12px; height: 36px; }
  .off { opacity: 0.55; }
  input { flex: 1; -webkit-appearance: none; appearance: none; height: 6px; border-radius: 6px; outline: none;
    background: linear-gradient(90deg, var(--accent) var(--p), var(--panel-2) var(--p)); }
  input::-webkit-slider-thumb { -webkit-appearance: none; width: 16px; height: 16px; border-radius: 50%; background: var(--text); border: 3px solid var(--accent); cursor: pointer; }
  .val { flex: none; min-width: 44px; text-align: center; padding: 3px 6px; border-radius: 4px; background: var(--panel-2); font-family: var(--mono); font-size: 13px; font-weight: 600; color: var(--p2-text); }
</style>
