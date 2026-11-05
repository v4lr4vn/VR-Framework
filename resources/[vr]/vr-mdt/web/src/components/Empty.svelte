<script>
  import Icon from './Icon.svelte';
  let { icon = 'search', title, text = '', children } = $props();
</script>

<div class="empty">
  <span class="ico"><Icon name={icon} size={22} /></span>
  <strong>{title}</strong>
  {#if text}<p>{text}</p>{/if}
  {#if children}{@render children()}{/if}
</div>

<style>
  .empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; padding: 32px 16px; text-align: center; color: var(--muted); }
  .ico { width: 44px; height: 44px; border-radius: 10px; background: var(--panel-2); display: flex; align-items: center; justify-content: center; color: var(--faint); margin-bottom: 4px; }
  strong { color: var(--text-2); font-size: 15px; }
  p { max-width: 320px; line-height: 1.5; }
</style>
