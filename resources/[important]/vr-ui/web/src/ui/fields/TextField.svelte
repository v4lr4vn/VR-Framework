<script>
  import Icon from '../Icon.svelte';
  import Glyph from '../Glyph.svelte';
  let { value = $bindable(''), row, error = '', onenter } = $props();
  let show = $state(false);
</script>

<div class="ctl" class:bad={error} class:off={row.disabled}>
  {#if row.icon}<span class="lead"><Icon icon={row.icon} size={13} /></span>{/if}
  <input
    type={row.password && !show ? 'password' : 'text'}
    bind:value
    placeholder={row.placeholder || ''}
    maxlength={row.max || undefined}
    disabled={row.disabled}
    onkeydown={(e) => e.key === 'Enter' && onenter?.()}
    autocomplete="off"
    spellcheck="false"
  />
  {#if row.password}
    <span class="tail"><button class="tbtn" type="button" tabindex="-1" onclick={() => (show = !show)} aria-label="Show"><Icon icon={show ? 'eye-slash' : 'eye'} size={12} /></button></span>
  {/if}
</div>


