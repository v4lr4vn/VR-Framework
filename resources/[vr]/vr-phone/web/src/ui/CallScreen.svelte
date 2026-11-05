<script>
  import { fade } from 'svelte/transition';
  import Avatar from './Avatar.svelte';
  import Glyph from './Glyph.svelte';
  import { phone, openApp } from '../lib/store.svelte.js';
  import {
    comms,
    callName,
    callSeconds,
    contactFor,
    answerCall,
    hangUp,
    minimizeCall,
    sendVoicemail,
    errorText,
  } from '../lib/comms.svelte.js';
  import { addContact } from '../lib/actions.js';
  import { durationText } from '../lib/time.js';
  import { t } from '../lib/i18n.js';
  import { dur } from '../lib/motion.js';

  // The call on the screen. It sits on top of everything (even the lock screen), so a call can be answered without a PIN.
  //   cover (closed): one column. The person, then the buttons
  //   flex (half open): the person on top, the buttons on the bottom half
  //   open: the person on the left half, the buttons on the right half
  // A call that is going on can be put in the corner (the green time in the status bar) and brought back by tapping it.
  const call = $derived(comms.call);
  const shown = $derived(call !== null && !call.minimized);
  const name = $derived(callName(call));
  const known = $derived(call ? contactFor(call.number) !== null : true);
  const keys = $derived(call?.keys ?? { answer: 'Y', hangup: 'U' });

  const status = $derived.by(() => {
    if (!call) return '';
    switch (call.state) {
      case 'calling':
        return t('call.calling');
      case 'incoming':
        return t('call.incoming');
      case 'active':
        return durationText(callSeconds(call));
      case 'voicemail':
        return t('call.noAnswer');
      default: {
        const why = t(`call.end.${call.reason}`);
        return call.duration > 0 ? `${why} · ${durationText(call.duration)}` : why;
      }
    }
  });

  let text = $state('');
  let sending = $state(false);
  let error = $state('');

  // A new call starts with an empty message box.
  $effect(() => {
    call?.id;
    text = '';
    error = '';
    sending = false;
  });

  async function leave() {
    if (sending || !text.trim()) return;
    sending = true;
    error = '';
    const r = await sendVoicemail(text.trim());
    sending = false;
    if (!r?.ok) error = errorText(r?.reason);
  }

  function onbox(e) {
    // Enter sends. Shift+Enter makes a new line.
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      leave();
    }
  }

  function add() {
    if (!call) return;
    const number = call.number;
    minimizeCall(true);
    addContact(number);
  }
</script>

{#if shown}
  <div class="call" data-fold={phone.fold} data-state={call.state} transition:fade={{ duration: dur(160) }}>
    <section class="who">
      <Avatar name={contactFor(call.number)?.name ?? call.name} number={call.number} size={phone.fold === 'cover' ? 104 : 92} />
      <h1>{name}</h1>
      {#if name !== call.number}<div class="num">{call.number}</div>{/if}
      <div class="status" class:ring={call.state === 'incoming'} class:live={call.state === 'active'}>{status}</div>
    </section>

    <section class="ctrl">
      {#if call.state === 'incoming'}
        <div class="two">
          <div class="slot">
            <button class="big red" onclick={hangUp} aria-label={t('call.decline')}><Glyph name="hangup" size={30} stroke={2} /></button>
            <span class="cap">{t('call.decline')}</span>
            {#if keys.hangup}<kbd>{keys.hangup}</kbd>{/if}
          </div>
          <div class="slot">
            <button class="big green shake" onclick={answerCall} aria-label={t('call.answer')}><Glyph name="phone" size={30} stroke={2} /></button>
            <span class="cap">{t('call.answer')}</span>
            {#if keys.answer}<kbd>{keys.answer}</kbd>{/if}
          </div>
        </div>
      {:else if call.state === 'voicemail'}
        <div class="vm">
          <label for="vm-box">{t('call.leaveMessage')}</label>
          <textarea
            id="vm-box"
            rows="4"
            maxlength="300"
            bind:value={text}
            onkeydown={onbox}
            placeholder={t('call.messagePlaceholder')}
          ></textarea>
          {#if error}<div class="err">{error}</div>{/if}
          <div class="row">
            <button class="pillbtn" onclick={hangUp}>{t('call.hangUp')}</button>
            <button class="pillbtn main" onclick={leave} disabled={sending || !text.trim()}>
              <Glyph name="send" size={18} stroke={2} />{t('call.sendMessage')}
            </button>
          </div>
        </div>
      {:else if call.state === 'ended'}
        <div class="done">
          {#if call.reason === 'unavailable' || call.reason === 'dropped'}<span class="small">{t(`call.endHint.${call.reason}`)}</span>{/if}
        </div>
      {:else}
        <div class="two">
          <div class="slot">
            <button class="big dark" onclick={() => minimizeCall(true)} aria-label={t('call.minimize')}><Glyph name="chev-down" size={28} stroke={2.2} /></button>
            <span class="cap">{t('call.minimize')}</span>
          </div>
          <div class="slot">
            <button class="big red" onclick={hangUp} aria-label={t(call.state === 'calling' ? 'call.cancel' : 'call.hangUp')}>
              <Glyph name="hangup" size={30} stroke={2} />
            </button>
            <span class="cap">{t(call.state === 'calling' ? 'call.cancel' : 'call.hangUp')}</span>
            {#if keys.hangup}<kbd>{keys.hangup}</kbd>{/if}
          </div>
        </div>
        {#if !known && !phone.locked && call.state === 'active'}
          <button class="pillbtn add" onclick={add}><Glyph name="user-plus" size={18} stroke={2} />{t('call.addContact')}</button>
        {/if}
      {/if}
    </section>
  </div>
{/if}

<style>
  .call {
    position: absolute;
    inset: 0;
    z-index: 28;
    display: flex;
    flex-direction: column;
    color: #fff;
    background: linear-gradient(165deg, var(--accent-dark) 0%, #1b1730 62%, #100e1b 100%);
    pointer-events: auto;
  }
  section {
    display: flex;
    flex-direction: column;
    align-items: center;
    min-width: 0;
    min-height: 0;
  }
  .who {
    flex: 1;
    justify-content: center;
    padding: 70px 24px 10px;
    text-align: center;
  }
  .ctrl {
    justify-content: flex-start;
    padding: 6px 24px 70px;
    gap: 18px;
  }
  /* half open: each half has its own job */
  .call[data-fold='flex'] .who {
    flex: none;
    height: 50%;
    padding-top: 56px;
    padding-bottom: 26px;
  }
  .call[data-fold='flex'] .ctrl {
    flex: 1;
    justify-content: center;
    padding: 26px 36px 50px;
  }
  .call[data-fold='open'] {
    flex-direction: row;
  }
  .call[data-fold='open'] .who {
    flex: none;
    width: 50%;
    padding: 56px 36px;
  }
  .call[data-fold='open'] .ctrl {
    flex: 1;
    justify-content: center;
    padding: 56px 40px;
  }

  h1 {
    margin: 16px 0 0;
    max-width: 100%;
    font-size: 28px;
    font-weight: 700;
    letter-spacing: -0.01em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .num {
    margin-top: 2px;
    font-size: 14px;
    opacity: 0.7;
  }
  .status {
    margin-top: 10px;
    font-size: 17px;
    font-weight: 600;
    opacity: 0.85;
    font-variant-numeric: tabular-nums;
  }
  .status.ring {
    animation: pulse 1.4s var(--ease-soft) infinite;
  }
  .status.live {
    color: #7dffa8;
    opacity: 1;
  }
  @keyframes pulse {
    50% {
      opacity: 0.45;
    }
  }

  .two {
    display: flex;
    justify-content: center;
    gap: 44px;
  }
  .slot {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 7px;
  }
  .big {
    width: 68px;
    height: 68px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    color: #fff;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.3);
    transition: transform 0.12s var(--ease);
  }
  .big:active {
    transform: scale(0.93);
  }
  .red {
    background: #e5484d;
  }
  .green {
    background: #2fa84f;
  }
  .dark {
    background: rgba(255, 255, 255, 0.16);
    box-shadow: none;
  }
  .shake {
    animation: ringer 1.2s var(--ease-soft) infinite;
  }
  @keyframes ringer {
    0%,
    60%,
    100% {
      transform: rotate(0);
    }
    10%,
    30%,
    50% {
      transform: rotate(-9deg);
    }
    20%,
    40% {
      transform: rotate(9deg);
    }
  }
  .cap {
    font-size: 13px;
    font-weight: 600;
    opacity: 0.85;
  }
  kbd {
    min-width: 22px;
    padding: 1px 7px;
    border-radius: 6px;
    background: rgba(255, 255, 255, 0.16);
    font-family: var(--mono);
    font-size: 11px;
    font-weight: 700;
    text-align: center;
  }

  .pillbtn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    padding: 11px 18px;
    border-radius: 22px;
    background: rgba(255, 255, 255, 0.16);
    color: #fff;
    font-size: 14px;
    font-weight: 700;
  }
  .pillbtn.main {
    background: #2fa84f;
  }
  .pillbtn:disabled {
    opacity: 0.45;
  }
  .add {
    align-self: center;
  }

  .vm {
    width: 100%;
    max-width: 320px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .vm label {
    font-size: 14px;
    font-weight: 600;
    opacity: 0.85;
  }
  textarea {
    width: 100%;
    resize: none;
    padding: 12px 14px;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.22);
    background: rgba(255, 255, 255, 0.12);
    color: #fff;
    font: inherit;
    font-size: 15px;
    line-height: 1.35;
  }
  textarea::placeholder {
    color: rgba(255, 255, 255, 0.55);
  }
  textarea:focus {
    outline: 2px solid rgba(255, 255, 255, 0.6);
  }
  .vm .row {
    display: flex;
    gap: 10px;
    justify-content: space-between;
  }
  .err {
    font-size: 13px;
    color: #ffb4b8;
  }
  .done {
    min-height: 40px;
    text-align: center;
  }
  .small {
    font-size: 14px;
    opacity: 0.8;
  }
</style>
