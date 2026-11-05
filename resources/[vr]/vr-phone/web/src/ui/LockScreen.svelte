<script>
  import { fly } from 'svelte/transition';
  import Glyph from './Glyph.svelte';
  import ClockText from './ClockText.svelte';
  import PinPad from './PinPad.svelte';
  import NotificationList from './NotificationList.svelte';
  import { phone, unlock, unlockWithoutPin, shownClock } from '../lib/store.svelte.js';
  import { dateText, pad } from '../lib/time.js';
  import { wallpaper, lightWallpapers } from '../lib/wallpapers.js';
  import { t } from '../lib/i18n.js';
  import { dur } from '../lib/motion.js';

  const wp = $derived(phone.settings.wallpaper.lock);
  const light = $derived(lightWallpapers[wp] === true);

  let now = $state(Date.now());
  let error = $state('');

  // Count down a lockout.
  $effect(() => {
    const start = Date.now();
    now = start;
    if (phone.lockUntil <= start) return;
    const id = setInterval(() => {
      now = Date.now();
      if (now >= phone.lockUntil) clearInterval(id);
    }, 400);
    return () => clearInterval(id);
  });

  const remaining = $derived(Math.max(0, Math.ceil((phone.lockUntil - now) / 1000)));
  const wait = $derived(`${Math.floor(remaining / 60)}:${pad(remaining % 60)}`);

  async function submit(pin) {
    const result = await unlock(pin);
    now = Date.now();
    if (result.ok) return true;
    error = result.reason === 'locked' ? '' : result.reason === 'busy' ? '' : t('lock.wrong');
    return false;
  }

  function onkey(e) {
    if (!phone.lock.enabled && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault();
      unlockWithoutPin();
    }
  }
</script>

<svelte:window onkeydown={onkey} />

<div
  class="lock"
  class:light
  data-fold={phone.fold}
  style:background={wallpaper(wp)}
  style:--wp-ink={light ? '#17142a' : '#ffffff'}
  style:--bar-ink={light ? '#17142a' : '#ffffff'}
  style:--pad-ink={light ? '#17142a' : '#ffffff'}
  style:--pad-key={light ? 'rgba(23,20,42,0.1)' : 'rgba(255,255,255,0.16)'}
  style:--pad-key-hover={light ? 'rgba(23,20,42,0.18)' : 'rgba(255,255,255,0.26)'}
  out:fly={{ y: -70, duration: dur(320) }}
>
  <div class="scrim"></div>

  <section class="info">
    <div class="who"><Glyph name="lock" size={16} stroke={2.2} /> {t('lock.locked')}</div>
    <ClockText variant={phone.settings.lock.clock} size={phone.fold === 'open' ? 112 : phone.fold === 'flex' ? 92 : 64} />
    <div class="date">{dateText(shownClock())}</div>
    <div class="notes">
      <NotificationList limit={phone.fold === 'open' ? 4 : phone.fold === 'flex' ? 2 : 1} locked />
    </div>
  </section>

  <section class="entry">
    {#if phone.lock.enabled}
      <div class="status" class:bad={remaining > 0 || error}>
        {#if remaining > 0}
          {t('lock.wait', { time: wait })}
        {:else if error}
          {error}
        {:else}
          {t('lock.enter')}
        {/if}
      </div>
      <PinPad length={phone.lock.length} disabled={remaining > 0} compact={phone.fold !== 'open'} onsubmit={submit} />
    {:else}
      <button class="open" onclick={unlockWithoutPin}>
        <Glyph name="unlock" size={26} />
        <span>{t('lock.tap')}</span>
      </button>
    {/if}
  </section>
</div>

<style>
  .lock {
    position: absolute;
    inset: 0;
    z-index: 20;
    color: var(--wp-ink);
  }
  .scrim {
    position: absolute;
    inset: 0;
    background: linear-gradient(180deg, rgba(0, 0, 0, 0.2), rgba(0, 0, 0, 0.04) 42%, rgba(0, 0, 0, 0.3));
  }
  .light .scrim {
    background: none;
  }
  section {
    position: absolute;
    display: flex;
    flex-direction: column;
  }
  .info {
    gap: 6px;
  }
  .who {
    display: flex;
    align-items: center;
    gap: 7px;
    font-size: 12.5px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    opacity: 0.85;
    margin-bottom: 10px;
  }
  .date {
    font-size: 17px;
    font-weight: 600;
    opacity: 0.92;
    margin-bottom: 18px;
  }
  .notes {
    width: 100%;
    max-width: 340px;
  }
  .entry {
    align-items: center;
    justify-content: center;
    gap: 22px;
  }
  .status {
    font-size: 14px;
    font-weight: 600;
    min-height: 20px;
    opacity: 0.9;
  }
  .status.bad {
    color: #ffb4bc;
    opacity: 1;
  }
  .open {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    padding: 22px 34px;
    border-radius: 26px;
    font-weight: 700;
    background: rgba(255, 255, 255, 0.16);
    border: 1px solid rgba(255, 255, 255, 0.22);
  }
  .open:hover {
    background: rgba(255, 255, 255, 0.26);
  }

  /* Open: info on the left half, entry on the right half. The crease runs between them. */
  .lock[data-fold='open'] .info {
    left: 0;
    top: 0;
    bottom: 0;
    width: 50%;
    padding: 64px 34px 40px 44px;
  }
  .lock[data-fold='open'] .entry {
    right: 0;
    top: 0;
    bottom: 0;
    width: 50%;
    padding: 40px 34px 40px 34px;
  }

  /* Flex: info on the top half, entry on the bottom half. */
  .lock[data-fold='flex'] .info {
    left: 0;
    right: 0;
    top: 0;
    height: 50%;
    padding: 50px 50px 8px;
    align-items: center;
    text-align: center;
  }
  .lock[data-fold='flex'] .info .date {
    margin-bottom: 10px;
  }
  .lock[data-fold='flex'] .notes {
    max-width: 420px;
  }
  .lock[data-fold='flex'] .entry {
    left: 0;
    right: 0;
    top: 50%;
    bottom: 0;
    padding: 14px 30px 20px;
    gap: 12px;
  }
  /* Closed phone: a tall narrow screen, so everything stacks. Clock on top, the keys at the bottom. */
  .lock[data-fold='cover'] .info {
    left: 0;
    right: 0;
    top: 0;
    padding: 50px 24px 0;
  }
  .lock[data-fold='cover'] .info .who {
    margin-bottom: 4px;
  }
  .lock[data-fold='cover'] .info .date {
    font-size: 15px;
    margin-bottom: 10px;
  }
  .lock[data-fold='cover'] .entry {
    left: 0;
    right: 0;
    bottom: 0;
    padding: 0 20px 24px;
    gap: 10px;
  }
</style>
