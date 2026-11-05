<script>
  import Avatar from './Avatar.svelte';
  import { comms, callName, callSeconds, contactFor } from '../lib/comms.svelte.js';
  import { durationText } from '../lib/time.js';
  import { t } from '../lib/i18n.js';

  // The call, shown in the corner of the game screen while the phone is put away.
  // Nothing here can be clicked (the mouse belongs to the game), so it says which keys do what.
  const call = $derived(comms.call);
  const keys = $derived(call?.keys ?? { answer: 'Y', hangup: 'U' });
  const name = $derived(callName(call));

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
        return t('call.noAnswerAway');
      default:
        return t(`call.end.${call.reason}`);
    }
  });
</script>

{#if call}
  <div class="pill" class:live={call.state === 'active'} class:ring={call.state === 'incoming'} class:over={call.state === 'ended'}>
    <Avatar name={contactFor(call.number)?.name ?? call.name} number={call.number} size={42} />
    <div class="text">
      <div class="who">{name}</div>
      <div class="status">{status}</div>
    </div>
    {#if call.state === 'incoming'}
      <div class="keys">
        <span><kbd>{keys.answer}</kbd>{t('call.answer')}</span>
        <span><kbd>{keys.hangup}</kbd>{t('call.decline')}</span>
      </div>
    {:else if call.state !== 'ended'}
      <div class="keys">
        <span><kbd>{keys.hangup}</kbd>{t(call.state === 'calling' ? 'call.cancel' : 'call.hangUp')}</span>
      </div>
    {/if}
  </div>
{/if}

<style>
  .pill {
    position: fixed;
    top: 28px;
    right: 36px;
    width: 340px;
    z-index: 60;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 11px 14px;
    border-radius: 22px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.3);
    color: var(--ink);
    pointer-events: none;
  }
  .pill.live {
    box-shadow: 0 0 0 2px #2fa84f, 0 10px 28px rgba(0, 0, 0, 0.3);
  }
  .pill.ring {
    box-shadow: 0 0 0 2px var(--accent), 0 10px 28px rgba(0, 0, 0, 0.3);
    animation: glow 1.4s var(--ease-soft) infinite;
  }
  .pill.over {
    opacity: 0.85;
  }
  @keyframes glow {
    50% {
      box-shadow: 0 0 0 5px rgba(var(--accent-rgb), 0.35), 0 10px 28px rgba(0, 0, 0, 0.3);
    }
  }
  .text {
    flex: 1;
    min-width: 0;
  }
  .who {
    font-size: 15px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .status {
    font-size: 13px;
    color: var(--ink-2);
    font-variant-numeric: tabular-nums;
  }
  .live .status {
    color: #1f8a3c;
    font-weight: 700;
  }
  .keys {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 11.5px;
    font-weight: 600;
    color: var(--ink-2);
  }
  .keys span {
    display: flex;
    align-items: center;
    gap: 6px;
    white-space: nowrap;
  }
  kbd {
    min-width: 20px;
    padding: 1px 6px;
    border-radius: 6px;
    background: var(--surface-3);
    color: var(--ink);
    font-family: var(--mono);
    font-size: 11px;
    font-weight: 700;
    text-align: center;
  }
</style>
