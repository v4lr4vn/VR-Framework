<script>
  let { label, hint = '', error = '', id, children, inline = false } = $props();
</script>

<div class="field" class:inline>
  {#if label}<label class="lbl" for={id}>{label}</label>{/if}
  {@render children()}
  {#if error}<span class="err">{error}</span>{:else if hint}<span class="hint">{hint}</span>{/if}
</div>

<style>
  .field { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .inline { flex-direction: row; align-items: center; gap: 10px; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .hint { color: var(--faint); font-size: 12px; }
  .err { color: var(--danger-text); font-size: 12px; }
</style>
