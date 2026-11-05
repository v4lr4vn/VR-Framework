<script>
  import Icon from './Icon.svelte';
  let { icon, label, size = 32, variant = 'ghost', active = false, disabled = false, onclick, ...rest } = $props();
</script>

<button type="button" class="ib {variant}" class:active style:width="{size}px" style:height="{size}px" aria-label={label} title={label} {disabled} {onclick} {...rest}>
  <Icon name={icon} size={size <= 28 ? 14 : 16} />
</button>

<style>
  .ib { display: inline-flex; align-items: center; justify-content: center; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text-2); padding: 0; flex: none; }
  .ib:hover:not(:disabled) { background: var(--panel-2); color: var(--text); }
  .outline { border-color: var(--line-2); background: var(--panel); }
  .danger:hover:not(:disabled) { background: var(--danger-bg); color: var(--danger-text); }
  .active { background: var(--panel-2); color: var(--accent); }
</style>
