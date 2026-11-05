<script>
  let { checked = false, onchange, label = '', disabled = false } = $props();
</script>

<button
  class="switch"
  class:on={checked}
  role="switch"
  aria-checked={checked}
  aria-label={label}
  {disabled}
  onclick={() => onchange?.(!checked)}
>
  <span class="knob"></span>
</button>

<style>
  .switch {
    position: relative;
    width: 46px;
    height: 28px;
    border-radius: 14px;
    background: var(--surface-3);
    transition: background 0.2s var(--ease-soft);
    flex: none;
  }
  .switch.on {
    background: var(--accent);
  }
  .switch:disabled {
    opacity: 0.4;
  }
  .knob {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #fff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
    transition: transform 0.22s var(--ease);
  }
  .on .knob {
    transform: translateX(18px);
  }
</style>
