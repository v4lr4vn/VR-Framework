<script>
  import { fly } from 'svelte/transition';
  import Glyph from './Glyph.svelte';
  import QuickTile from './QuickTile.svelte';
  import NotificationList from './NotificationList.svelte';
  import Slider from './kit/Slider.svelte';
  import { phone, setQuick, setLowPower, saveSettings, clearNotifications, closePanel, openApp, lockVisible } from '../lib/store.svelte.js';
  import { dur } from '../lib/motion.js';
  import { t } from '../lib/i18n.js';

  // The quick panel. Pull it down from the status bar (tap the bar).
  //   open: notifications on the left half, switches on the right half. Nothing sits on the crease.
  //   flex: notifications on the top half, switches on the bottom half.
  //   closed: one column. Switches, brightness, then notifications.
  const q = $derived(phone.settings.quick);
  const st = $derived(phone.status);
  const cover = $derived(phone.fold === 'cover');

  // Audio can only go to Bluetooth while Bluetooth is on.
  const outputs = $derived(q.bluetooth ? ['phone', 'speaker', 'bluetooth'] : ['phone', 'speaker']);
  const audio = $derived(outputs.includes(q.audio) ? q.audio : 'phone');
  const audioGlyph = { phone: 'phone', speaker: 'speaker', bluetooth: 'bluetooth' };

  function cycleAudio() {
    const next = outputs[(outputs.indexOf(audio) + 1) % outputs.length];
    setQuick({ audio: next });
  }

  const list = $derived(phone.locked ? lockVisible(phone.notifications) : phone.notifications);
  const summary = $derived(
    [
      st.signal.airplane ? t('panel.airplaneOn') : st.signal.service ? st.signal.carrier : t('status.noService'),
      `${Math.round(st.battery)}%${st.charging ? ' · ' + t('panel.charging') : ''}`,
    ]
      .filter(Boolean)
      .join(' · '),
  );

  function open(n) {
    if (phone.locked) return;
    openApp(n.app);
  }
</script>

{#if phone.panel}
  <div class="panel" data-fold={phone.fold} role="dialog" aria-label={t('panel.title')} transition:fly={{ y: -34, duration: dur(220) }}>
    <div class="body">
    <section class="tiles">
      <div class="summary">{summary}</div>
      <div class="grid">
        <QuickTile glyph="plane" label={t('panel.airplane')} sub={q.airplane ? t('common.on') : t('common.off')} on={q.airplane} onclick={() => setQuick({ airplane: !q.airplane })} />
        <QuickTile glyph="bluetooth" label={t('panel.bluetooth')} sub={q.bluetooth ? t('common.on') : t('common.off')} on={q.bluetooth} onclick={() => setQuick({ bluetooth: !q.bluetooth })} />
        <QuickTile glyph={q.silent ? 'bell-off' : 'bell'} label={t('panel.silent')} sub={q.silent ? t('common.on') : t('common.off')} on={q.silent} onclick={() => setQuick({ silent: !q.silent })} />
        <QuickTile glyph="leaf" label={t('panel.lowPower')} sub={st.lowPower ? t('common.on') : t('common.off')} on={st.lowPower} onclick={() => setLowPower(!st.lowPower)} />
        <QuickTile glyph={audioGlyph[audio]} label={t('panel.audio')} sub={t(`panel.audio.${audio}`)} onclick={cycleAudio} />
        <QuickTile glyph="cast" label={t('panel.cast')} sub={t('panel.castNone')} disabled onclick={() => {}} />
      </div>
      <div class="bright">
        <Glyph name="sun" size={20} />
        <Slider min={0.25} max={1} step={0.05} value={q.brightness} onchange={(v) => saveSettings({ quick: { brightness: v } })} label={t('panel.brightness')} />
      </div>
    </section>

    <section class="notes">
      <div class="head">
        <span>{t('notify.title')}</span>
        {#if list.length > 0}<button class="clear" onclick={clearNotifications}>{t('notify.clear')}</button>{/if}
      </div>
      {#if list.length === 0}
        <p class="empty">{t('notify.empty')}</p>
      {:else}
        <NotificationList limit={30} locked={phone.locked} onopen={phone.locked ? undefined : open} dismissable />
      {/if}
    </section>
    </div>

    <button class="close" onclick={closePanel} aria-label={t('common.close')}><Glyph name="chev-up" size={22} stroke={2.4} /></button>
  </div>
{/if}

<style>
  .panel {
    position: absolute;
    inset: 0;
    z-index: 28;
    background: var(--bg);
    color: var(--ink);
  }
  .body {
    position: absolute;
    inset: 0;
    display: flex;
  }
  section {
    flex: 1;
    min-width: 0;
    min-height: 0;
    overflow-y: auto;
  }
  .summary {
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.02em;
    color: var(--ink-3);
    margin-bottom: 12px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
  }
  .bright {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 16px;
    padding: 6px 14px;
    border-radius: 20px;
    background: var(--surface);
    box-shadow: inset 0 0 0 1px var(--line);
    color: var(--ink-2);
  }
  .head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-bottom: 12px;
  }
  .clear {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0;
    text-transform: none;
    padding: 4px 11px;
    border-radius: 10px;
    background: var(--surface-2);
    color: var(--ink);
  }
  .empty {
    margin: 4px 0;
    font-size: 14px;
    color: var(--ink-3);
  }
  .close {
    position: absolute;
    bottom: 8px;
    left: 50%;
    margin-left: -26px;
    width: 52px;
    height: 30px;
    display: grid;
    place-items: center;
    border-radius: 15px;
    color: var(--ink-2);
    background: var(--surface-2);
    z-index: 2;
  }
  .close:hover {
    background: var(--surface-3);
  }

  /* Open: switches on the right half, notifications on the left half. */
  .panel[data-fold='open'] .body {
    flex-direction: row-reverse;
  }
  .panel[data-fold='open'] .tiles {
    padding: 58px 32px 52px 22px;
  }
  .panel[data-fold='open'] .notes {
    padding: 58px 22px 52px 32px;
  }
  .panel[data-fold='open'] .close {
    left: 75%;
  }

  /* Flex: notifications on the top half, switches on the bottom half. */
  .panel[data-fold='flex'] .body {
    flex-direction: column-reverse;
  }
  .panel[data-fold='flex'] .tiles {
    padding: 22px 36px 46px;
  }
  .panel[data-fold='flex'] .notes {
    padding: 50px 36px 8px;
  }
  .panel[data-fold='flex'] .grid,
  .panel[data-fold='flex'] .bright,
  .panel[data-fold='flex'] .summary {
    max-width: 520px;
    margin-left: auto;
    margin-right: auto;
  }
  .panel[data-fold='flex'] .summary {
    margin-bottom: 12px;
  }
  .panel[data-fold='flex'] .bright {
    margin-top: 16px;
  }

  /* Closed: a single column that scrolls. */
  .panel[data-fold='cover'] .body {
    display: block;
    overflow-y: auto;
    padding: 50px 16px 52px;
  }
  .panel[data-fold='cover'] section {
    overflow: visible;
  }
  .panel[data-fold='cover'] .notes {
    margin-top: 22px;
  }
  .panel[data-fold='cover'] .grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
  }
  .panel[data-fold='cover'] :global(.tile) {
    padding: 10px 9px 9px;
    border-radius: 18px;
  }
</style>
