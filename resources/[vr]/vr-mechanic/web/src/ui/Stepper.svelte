<script>
  let { label, options = [], value = -1, fitted = -1, stock = 'Stock', onchange } = $props();

  let name = $derived(value < 0 ? stock : options[value] || `Option ${value + 1}`);
  const go = (d) => {
    let n = value + d;
    if (n < -1) n = options.length - 1;
    if (n > options.length - 1) n = -1;
    onchange(n);
  };
</script>

<div class="step" class:changed={value !== fitted}>
  <span class="sl">{label}</span>
  <div class="ctl">
    <button class="arr" onclick={() => go(-1)} aria-label="Previous {label}"><i class="fa-solid fa-chevron-left"></i></button>
    <span class="sn" title={name}>{name}</span>
    <button class="arr" onclick={() => go(1)} aria-label="Next {label}"><i class="fa-solid fa-chevron-right"></i></button>
  </div>
  <span class="sc num">{value + 1}/{options.length}</span>
</div>

<style>
  .step { display: grid; grid-template-columns: 104px 1fr 40px; align-items: center; gap: 10px; padding: 6px 8px 6px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .step.changed { border-color: var(--accent-line); background: linear-gradient(90deg, var(--accent-soft), var(--panel) 60%); }
  .sl { font-size: 12px; font-weight: 600; color: var(--text-2); }
  .ctl { display: grid; grid-template-columns: 26px 1fr 26px; align-items: center; gap: 4px; min-width: 0; }
  .arr { height: 26px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-size: 10px; padding: 0; }
  .arr:hover { color: var(--text); border-color: var(--accent-line); }
  .sn { text-align: center; font-size: 12px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .changed .sn { color: var(--accent-2); }
  .sc { font-size: 10px; color: var(--faint); text-align: right; }
</style>
