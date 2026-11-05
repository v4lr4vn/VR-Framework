<script>
  import Glyph from './Glyph.svelte';
  import { phone, togglePanel, shownClock } from '../lib/store.svelte.js';
  import { clockText, durationText } from '../lib/time.js';
  import { comms, callSeconds, minimizeCall } from '../lib/comms.svelte.js';
  import { t } from '../lib/i18n.js';

  // Time on the left, signal and battery on the right. The middle stays empty because that is where the crease is.
  // Tapping the bar opens the quick panel.
  const time = $derived(clockText(shownClock(), phone.settings.general.time24));
  const st = $derived(phone.status);
  const bars = $derived(st.signal.bars);
  const level = $derived(Math.max(0, Math.min(100, Math.round(st.battery))));
  const airplane = $derived(st.signal.airplane);
  const noService = $derived(!airplane && !st.signal.service);
  const low = $derived(level <= 20 && !st.charging);
  const cover = $derived(phone.fold === 'cover');

  // A call put in the corner: the time turns into a green button that brings it back.
  const call = $derived(comms.call);
  const inCorner = $derived(call !== null && call.minimized && call.state !== 'ended' && call.state !== 'incoming');
</script>

<div class="bar">
  {#if inCorner}
    <span class="time"></span>
  {:else}
    <span class="time">{time}</span>
  {/if}
  <span class="right">
    {#if phone.settings.quick.bluetooth}<Glyph name="bluetooth" size={14} stroke={2.2} />{/if}
    {#if phone.settings.quick.silent}<Glyph name="bell-off" size={14} stroke={2.2} />{/if}
    {#if phone.features.signal.enabled}
      {#if airplane}
        <Glyph name="plane" size={15} stroke={2} />
      {:else}
        {#if noService && !cover}<span class="nosvc">{t('status.noService')}</span>{/if}
        <svg class="signal" width="18" height="14" viewBox="0 0 18 14" aria-hidden="true">
          {#each [0, 1, 2, 3] as i}
            <rect x={i * 4.6} y={10 - i * 3.2} width="3" height={4 + i * 3.2} rx="1" opacity={i < bars ? 1 : 0.3} fill="currentColor" />
          {/each}
        </svg>
      {/if}
    {/if}
    {#if phone.features.battery.enabled}
      <span class="battery">
        <svg width="26" height="14" viewBox="0 0 26 14" aria-hidden="true">
          <rect x="0.8" y="0.8" width="21" height="12.4" rx="3.6" fill="none" stroke="currentColor" stroke-width="1.5" opacity="0.5" />
          <rect
            x="2.8"
            y="2.8"
            width={Math.max(1.5, (17 * level) / 100)}
            height="8.4"
            rx="2"
            fill={low ? '#ff5d66' : st.charging ? '#3ddc84' : st.lowPower ? '#ffc83d' : 'currentColor'}
          />
          <rect x="23.4" y="4.6" width="2" height="4.8" rx="1" fill="currentColor" opacity="0.5" />
        </svg>
        {#if st.charging}<span class="bolt"><Glyph name="bolt" size={12} stroke={2.4} /></span>{/if}
        {#if phone.settings.battery.showPercent}<span class="pct">{level}</span>{/if}
      </span>
    {/if}
  </span>
  <button class="hit" onclick={togglePanel} aria-label={t('panel.title')}></button>
  {#if inCorner}
    <button class="cap" onclick={() => minimizeCall(false)} aria-label={t('call.back')}>
      <Glyph name="phone" size={13} stroke={2.4} />
      <span>{call.state === 'active' ? durationText(callSeconds(call)) : t(call.state === 'voicemail' ? 'call.noAnswer' : 'call.calling')}</span>
    </button>
  {/if}
</div>

<style>
  .bar {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 40px;
    padding: 0 30px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 13.5px;
    font-weight: 700;
    letter-spacing: 0.01em;
    color: var(--bar-ink, #fff);
    z-index: 30;
    pointer-events: none;
  }
  .right {
    display: flex;
    align-items: center;
    gap: 9px;
  }
  .battery {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .bolt {
    margin-left: -2px;
    display: flex;
  }
  .pct {
    font-size: 12px;
    font-weight: 700;
  }
  .nosvc {
    font-size: 11.5px;
    font-weight: 700;
    opacity: 0.75;
  }
  svg {
    display: block;
  }
  .hit {
    position: absolute;
    inset: 0;
    pointer-events: auto;
    background: none;
  }
  .cap {
    position: absolute;
    left: 24px;
    top: 7px;
    z-index: 2;
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: 6px;
    height: 26px;
    padding: 0 11px;
    border-radius: 13px;
    background: #2fa84f;
    color: #fff;
    font-size: 12.5px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
</style>
