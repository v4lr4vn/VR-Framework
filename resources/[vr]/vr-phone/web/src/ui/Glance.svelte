<script>
  import Glyph from './Glyph.svelte';
  import ClockText from './ClockText.svelte';
  import NotificationList from './NotificationList.svelte';
  import { phone, clearNotifications, openApp, shownClock } from '../lib/store.svelte.js';
  import { dateText } from '../lib/time.js';
  import { t } from '../lib/i18n.js';

  // The home screen's "at a glance" column: clock, date, weather and the latest notifications.
  let { compact = false } = $props();

  const weatherGlyph = { clear: 'sun', cloud: 'cloud', rain: 'rain', storm: 'storm', fog: 'fog', snow: 'snow' };
  const kind = $derived(phone.clock.weather);

  function open(n) {
    openApp(n.app);
  }
</script>

<div class="glance" class:compact>
  <ClockText variant="row" size={compact ? 92 : 116} />
  <div class="date">{dateText(shownClock())}</div>
  <div class="wx">
    <Glyph name={weatherGlyph[kind] ?? 'sun'} size={20} />
    <span>{t(`weather.${kind}`)}</span>
  </div>

  <div class="notes">
    <div class="head">
      <span>{t('notify.title')}</span>
      {#if phone.notifications.length > 0}
        <button class="clear" onclick={clearNotifications}>{t('notify.clear')}</button>
      {/if}
    </div>
    {#if phone.notifications.length === 0}
      <p class="empty">{t('notify.empty')}</p>
    {:else}
      <NotificationList limit={compact ? 1 : 3} onopen={open} />
    {/if}
  </div>
</div>

<style>
  .glance {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    color: var(--wp-ink);
    text-shadow: var(--wp-text-shadow, none);
  }
  .date {
    font-size: 18px;
    font-weight: 600;
    opacity: 0.94;
  }
  .wx {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
    opacity: 0.85;
    margin-top: 2px;
  }
  .notes {
    width: 100%;
    max-width: 330px;
    margin-top: 22px;
    text-shadow: none;
  }
  .compact .notes {
    margin-top: 12px;
    max-width: 380px;
  }
  .head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--wp-ink);
    opacity: 0.85;
    margin-bottom: 9px;
    text-shadow: var(--wp-text-shadow, none);
  }
  .clear {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0;
    text-transform: none;
    padding: 3px 10px;
    border-radius: 10px;
    background: rgba(255, 255, 255, 0.18);
  }
  .clear:hover {
    background: rgba(255, 255, 255, 0.28);
  }
  .empty {
    margin: 0;
    font-size: 13.5px;
    opacity: 0.7;
    color: var(--wp-ink);
  }
</style>
