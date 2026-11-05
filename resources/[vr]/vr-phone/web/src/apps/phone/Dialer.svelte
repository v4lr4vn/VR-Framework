<script>
  import Keypad from '../../ui/Keypad.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { setTyping } from '../../lib/store.svelte.js';
  import { comms, contactFor, dial, errorText } from '../../lib/comms.svelte.js';
  import { addContact } from '../../lib/actions.js';
  import { t } from '../../lib/i18n.js';

  // The number, the keypad and the call button. Number keys on the keyboard work too.
  let { compact = false } = $props();

  let number = $state('');
  let error = $state('');
  let busy = $state(false);

  const digits = $derived(number.replace(/\D/g, ''));
  const match = $derived(digits.length >= 3 ? contactFor(number) : null);
  const inCall = $derived(comms.call !== null);

  // While the keypad is on screen, the game must not read the number keys.
  $effect(() => {
    setTyping(true);
    return () => setTyping(false);
  });

  function press(d) {
    if (number.length >= 20) return;
    number += d;
    error = '';
  }

  function erase() {
    number = number.slice(0, -1);
    error = '';
  }

  async function call() {
    if (!number || busy || inCall) return;
    busy = true;
    error = '';
    const r = await dial(number);
    busy = false;
    if (r.ok) number = '';
    else error = errorText(r.reason);
  }

  function onkey(e) {
    const el = e.target;
    if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA')) return;
    if (comms.call) return;
    if (/^[0-9*#+]$/.test(e.key)) {
      press(e.key);
      e.preventDefault();
    } else if (e.key === 'Backspace') {
      erase();
      e.preventDefault();
    } else if (e.key === 'Enter') {
      call();
      e.preventDefault();
    }
  }
</script>

<svelte:window onkeydown={onkey} />

<div class="dialer" class:compact>
  <div class="screen">
    <div class="number" class:empty={!number}>{number || t('phone.enterNumber')}</div>
    <div class="sub">
      {#if error}
        <span class="err">{error}</span>
      {:else if match}
        <span class="who">{match.name}</span>
      {:else if digits.length >= 3}
        <button class="add" onclick={() => addContact(number)}><Glyph name="user-plus" size={15} stroke={2} />{t('phone.addContact')}</button>
      {/if}
    </div>
  </div>

  <Keypad onkey={press} {compact} />

  <div class="actions">
    <span class="gap"></span>
    <button class="call" onclick={call} disabled={!number || busy || inCall} aria-label={t('phone.call')}>
      <Glyph name="phone" size={28} stroke={2} />
    </button>
    {#if number}
      <button class="erase" onclick={erase} aria-label={t('lock.erase')}><Glyph name="backspace" size={26} /></button>
    {:else}
      <span class="gap"></span>
    {/if}
  </div>
</div>

<style>
  .dialer {
    display: flex;
    flex-direction: column;
    gap: 12px;
    max-width: 320px;
    margin: 0 auto;
  }
  .screen {
    min-height: 62px;
    text-align: center;
  }
  .number {
    min-height: 38px;
    font-size: 30px;
    font-weight: 600;
    letter-spacing: 0.02em;
    font-variant-numeric: tabular-nums;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .number.empty {
    font-size: 16px;
    font-weight: 500;
    line-height: 38px;
    color: var(--ink-3);
  }
  .sub {
    min-height: 24px;
    font-size: 14px;
  }
  .who {
    font-weight: 700;
    color: var(--ink-2);
  }
  .err {
    font-weight: 600;
    color: #e5484d;
  }
  .add {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 700;
    color: var(--accent);
  }
  .actions {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    align-items: center;
    justify-items: center;
  }
  .call {
    width: 66px;
    height: 66px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: #2fa84f;
    color: #fff;
    box-shadow: 0 4px 12px rgba(47, 168, 79, 0.35);
  }
  .call:disabled {
    opacity: 0.4;
    box-shadow: none;
  }
  .erase {
    width: 48px;
    height: 48px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: var(--ink-2);
  }
  .erase:hover {
    background: var(--surface-2);
  }
  .compact {
    gap: 8px;
  }
  .compact .screen {
    min-height: 44px;
  }
  .compact .number {
    min-height: 28px;
    font-size: 22px;
  }
  .compact .number.empty {
    font-size: 14px;
    line-height: 28px;
  }
  .compact .sub {
    min-height: 18px;
    font-size: 13px;
  }
  .compact .call {
    width: 46px;
    height: 46px;
  }
</style>
