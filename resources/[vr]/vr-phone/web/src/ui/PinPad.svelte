<script>
  import Glyph from './Glyph.svelte';
  import { setTyping } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // A number pad that collects `length` digits and calls onsubmit(pin).
  // onsubmit may return a promise. Return true when the PIN was accepted; false shakes the dots and clears them.
  let { length = 4, disabled = false, compact = false, onsubmit, oncancel, cancelLabel = '' } = $props();

  let digits = $state('');
  let busy = $state(false);
  let shaking = $state(false);

  // While the pad is on screen, the game must not read the number keys.
  $effect(() => {
    setTyping(true);
    return () => setTyping(false);
  });

  // A new length starts a fresh entry.
  $effect(() => {
    length;
    digits = '';
  });

  async function add(d) {
    if (disabled || busy || digits.length >= length) return;
    digits += d;
    if (digits.length === length) {
      busy = true;
      const ok = await onsubmit?.(digits);
      digits = '';
      busy = false;
      if (ok === false) {
        shaking = true;
        setTimeout(() => (shaking = false), 420);
      }
    }
  }

  function erase() {
    if (disabled || busy) return;
    digits = digits.slice(0, -1);
  }

  function onkey(e) {
    if (/^[0-9]$/.test(e.key)) {
      add(e.key);
      e.preventDefault();
    } else if (e.key === 'Backspace') {
      erase();
      e.preventDefault();
    }
  }
</script>

<svelte:window onkeydown={onkey} />

<div class="pad" class:disabled class:compact>
  <div class="dots" class:shake={shaking} aria-label={t('lock.pin')}>
    {#each Array(length) as _, i}
      <span class="dot" class:on={i < digits.length}></span>
    {/each}
  </div>

  <div class="keys">
    {#each ['1', '2', '3', '4', '5', '6', '7', '8', '9'] as d}
      <button class="key" onclick={() => add(d)} {disabled}>{d}</button>
    {/each}
    {#if oncancel}
      <button class="key ghost" onclick={oncancel}>{cancelLabel || t('common.cancel')}</button>
    {:else}
      <span></span>
    {/if}
    <button class="key" onclick={() => add('0')} {disabled}>0</button>
    <button class="key ghost" onclick={erase} {disabled} aria-label={t('lock.erase')}>
      <Glyph name="backspace" size={24} />
    </button>
  </div>
</div>

<style>
  .pad {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 26px;
  }
  .pad.disabled {
    opacity: 0.55;
  }
  .dots {
    display: flex;
    gap: 16px;
    height: 16px;
  }
  .dot {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    border: 2px solid var(--pad-ink, #fff);
    opacity: 0.75;
    transition: background 0.12s, transform 0.12s var(--ease);
  }
  .dot.on {
    background: var(--pad-ink, #fff);
    opacity: 1;
    transform: scale(1.08);
  }
  .shake {
    animation: shake 0.4s var(--ease-soft);
  }
  @keyframes shake {
    20% { transform: translateX(-10px); }
    40% { transform: translateX(9px); }
    60% { transform: translateX(-6px); }
    80% { transform: translateX(4px); }
  }
  .keys {
    display: grid;
    grid-template-columns: repeat(3, 72px);
    grid-auto-rows: 72px;
    gap: 14px 22px;
  }
  .key {
    border-radius: 50%;
    font-size: 27px;
    font-weight: 400;
    display: grid;
    place-items: center;
    color: var(--pad-ink, #fff);
    background: var(--pad-key, rgba(255, 255, 255, 0.16));
    transition: background 0.12s, transform 0.12s var(--ease);
  }
  .key:hover:not(:disabled) {
    background: var(--pad-key-hover, rgba(255, 255, 255, 0.26));
  }
  .key:active:not(:disabled) {
    transform: scale(0.93);
  }
  .key.ghost {
    background: transparent;
    font-size: 15px;
    font-weight: 600;
  }
  .key.ghost:hover:not(:disabled) {
    background: var(--pad-ghost-hover, rgba(255, 255, 255, 0.12));
  }

  /* Smaller keys for the half-open phone, where the pad has half the screen. */
  .compact {
    gap: 12px;
  }
  .compact .keys {
    grid-template-columns: repeat(3, 56px);
    grid-auto-rows: 46px;
    gap: 7px 18px;
  }
  .compact .key {
    border-radius: 23px;
    font-size: 21px;
  }
  .compact .key.ghost {
    font-size: 13px;
    white-space: nowrap;
  }
</style>
