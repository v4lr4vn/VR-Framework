<script>
  import Icon from './Icon.svelte';
  let { variant = 'secondary', size = 'md', icon = null, iconRight = null, type = 'button', disabled = false, busy = false, full = false, onclick, children, title, ...rest } = $props();
</script>

<button {type} class="btn {variant} {size}" class:full disabled={disabled || busy} {onclick} {title} aria-busy={busy} {...rest}>
  {#if busy}
    <span class="spin" aria-hidden="true"></span>
  {:else if icon}
    <Icon name={icon} size={size === 'sm' ? 14 : 16} />
  {/if}
  {#if children}<span class="label">{@render children()}</span>{/if}
  {#if iconRight}<Icon name={iconRight} size={14} />{/if}
</button>

<style>
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 8px;
    height: 36px; padding: 0 14px; border-radius: var(--radius); border: 1px solid var(--line-2);
    background: var(--panel); color: var(--text); font-weight: 600; white-space: nowrap;
    transition: background 0.12s, border-color 0.12s, color 0.12s;
  }
  .btn:hover:not(:disabled) { background: var(--panel-2); border-color: var(--line-3); }
  .sm { height: 28px; padding: 0 10px; font-size: 13px; gap: 6px; }
  .lg { height: 42px; padding: 0 18px; font-size: 15px; }
  .full { width: 100%; }
  .primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 700; }
  .primary:hover:not(:disabled) { background: var(--accent-2); border-color: var(--accent-2); }
  .ghost { background: transparent; border-color: transparent; color: var(--text-2); }
  .ghost:hover:not(:disabled) { background: var(--panel-2); border-color: transparent; color: var(--text); }
  .danger { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  .danger:hover:not(:disabled) { background: #3a171a; border-color: var(--danger); }
  .ok { background: var(--ok-bg); border-color: var(--ok-line); color: var(--ok); }
  .label { overflow: hidden; text-overflow: ellipsis; }
  .spin { width: 14px; height: 14px; border-radius: 50%; border: 2px solid currentColor; border-right-color: transparent; animation: r 0.7s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
</style>
