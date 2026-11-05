<script>
  import Icon from './Icon.svelte';
  let { checked = $bindable(false), label, id, disabled = false, onchange } = $props();
</script>

<label class="cb" class:disabled for={id}>
  <input {id} type="checkbox" bind:checked {disabled} {onchange} />
  <span class="box" aria-hidden="true">{#if checked}<Icon name="check" size={12} stroke={3} />{/if}</span>
  <span>{label}</span>
</label>

<style>
  .cb { display: inline-flex; align-items: center; gap: 8px; color: var(--text-2); cursor: pointer; min-height: 28px; }
  .cb input { position: absolute; opacity: 0; width: 1px; height: 1px; }
  .box { width: 18px; height: 18px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--bg-2); display: flex; align-items: center; justify-content: center; color: var(--accent-ink); flex: none; }
  .cb input:checked + .box { background: var(--accent); border-color: var(--accent); }
  .cb input:focus-visible + .box { outline: 2px solid var(--accent); outline-offset: 2px; }
  .disabled { opacity: 0.55; cursor: default; }
</style>
