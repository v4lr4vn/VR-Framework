<script>
  let { label, value = '', mono = false, children } = $props();
</script>

<div class="kv">
  <span class="k">{label}</span>
  <span class="v" class:mono>{#if children}{@render children()}{:else}{value || '—'}{/if}</span>
</div>

<style>
  .kv { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .k { color: var(--faint); font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; }
  .v { color: var(--text); overflow-wrap: anywhere; }
  .mono { font-family: var(--mono); }
</style>
