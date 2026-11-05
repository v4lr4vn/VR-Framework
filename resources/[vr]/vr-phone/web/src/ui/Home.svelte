<script>
  import { fade, scale } from 'svelte/transition';
  import Glance from './Glance.svelte';
  import AppGrid from './AppGrid.svelte';
  import AppIcon from './AppIcon.svelte';
  import Dock from './Dock.svelte';
  import Glyph from './Glyph.svelte';
  import ClockText from './ClockText.svelte';
  import { phone, openApp, togglePanel, shownClock } from '../lib/store.svelte.js';
  import { dateText } from '../lib/time.js';
  import { wallpaper, lightWallpapers } from '../lib/wallpapers.js';
  import { t } from '../lib/i18n.js';
  import { dur } from '../lib/motion.js';

  // The home screen. Open: glance on the left half, icons on the right half, dock along the bottom.
  // Flex: glance on the top half, icons and dock on the bottom half.
  // Closed (cover): one narrow column. A clock header, the icons, the dock. Tap the clock for notifications.
  const wp = $derived(phone.settings.wallpaper.home);
  const light = $derived(lightWallpapers[wp] === true);
  const open = $derived(phone.fold === 'open');
  const cover = $derived(phone.fold === 'cover');

  const weatherGlyph = { clear: 'sun', cloud: 'cloud', rain: 'rain', storm: 'storm', fog: 'fog', snow: 'snow' };
  const unread = $derived(phone.notifications.filter((n) => !n.read).length);

  let folder = $state(null);

  function launch(id) {
    folder = null;
    openApp(id);
  }
</script>

<div
  class="home"
  class:light
  data-fold={phone.fold}
  style:background={wallpaper(wp)}
  style:--wp-ink={light ? '#17142a' : '#ffffff'}
  style:--bar-ink={light ? '#17142a' : '#ffffff'}
  style:--wp-text-shadow={light ? 'none' : '0 1px 8px rgba(0,0,0,0.28)'}
  style:--wp-glass={light ? 'rgba(255,255,255,0.55)' : 'rgba(255,255,255,0.16)'}
  style:--wp-glass-line={light ? 'rgba(255,255,255,0.7)' : 'rgba(255,255,255,0.22)'}
  in:fade={{ duration: dur(200) }}
>
  <div class="scrim"></div>

  {#if cover}
    <button class="head" onclick={togglePanel} aria-label={t('panel.title')}>
      <ClockText variant="row" size={72} />
      <span class="line">
        <span>{dateText(shownClock(), true)}</span>
        <Glyph name={weatherGlyph[phone.clock.weather] ?? 'sun'} size={16} />
        {#if unread > 0}<span class="badge">{unread}</span>{/if}
      </span>
    </button>
  {:else}
    <section class="glance">
      <Glance compact={!open} />
    </section>
  {/if}

  <section class="apps">
    <AppGrid
      items={phone.layout.items}
      cols={cover ? 4 : open ? 4 : 6}
      rows={cover ? 4 : open ? 4 : 2}
      cellHeight={cover ? 88 : open ? 104 : 100}
      iconSize={cover ? 54 : open ? 62 : 58}
      onopen={launch}
      onfolder={(item) => (folder = item)}
    />
  </section>

  <Dock pinned={phone.layout.dock} onopen={launch} />

  {#if folder}
    <div class="overlay" transition:fade={{ duration: dur(160) }}>
      <button class="backdrop" aria-label={t('common.close')} onclick={() => (folder = null)}></button>
      <div class="folder" role="dialog" aria-label={folder.folder} transition:scale={{ start: 0.9, duration: dur(200) }}>
        <h3>{folder.folder}</h3>
        <div class="fgrid">
          {#each folder.apps as id (id)}
            <AppIcon {id} size={58} onopen={launch} />
          {/each}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .home {
    position: absolute;
    inset: 0;
    color: var(--wp-ink);
  }
  .scrim {
    position: absolute;
    inset: 0;
    background: linear-gradient(180deg, rgba(0, 0, 0, 0.16), rgba(0, 0, 0, 0.03) 40%, rgba(0, 0, 0, 0.3));
  }
  .light .scrim {
    background: none;
  }
  section {
    position: absolute;
  }

  .home[data-fold='open'] .glance {
    left: 0;
    top: 0;
    bottom: 124px;
    width: 50%;
    padding: 58px 30px 0 44px;
  }
  .home[data-fold='open'] .apps {
    right: 0;
    top: 0;
    bottom: 124px;
    width: 50%;
    padding: 60px 26px 0 24px;
  }

  .home[data-fold='flex'] .glance {
    left: 0;
    right: 0;
    top: 0;
    height: 50%;
    padding: 50px 46px 0;
  }
  .home[data-fold='flex'] .apps {
    left: 0;
    right: 0;
    top: 50%;
    bottom: 124px;
    padding: 20px 26px 0;
  }

  .home[data-fold='cover'] .head {
    position: absolute;
    left: 0;
    right: 0;
    top: 0;
    padding: 46px 22px 0;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
    color: var(--wp-ink);
    text-shadow: var(--wp-text-shadow, none);
  }
  .head .line {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 15px;
    font-weight: 600;
    opacity: 0.94;
  }
  .badge {
    min-width: 20px;
    height: 20px;
    padding: 0 6px;
    border-radius: 10px;
    display: grid;
    place-items: center;
    font-size: 12px;
    font-weight: 700;
    background: var(--accent);
    color: var(--on-accent);
    text-shadow: none;
  }
  .home[data-fold='cover'] .apps {
    left: 0;
    right: 0;
    top: 138px;
    padding: 0 14px;
  }

  .overlay {
    position: absolute;
    inset: 0;
    z-index: 25;
    display: grid;
    place-items: center;
  }
  .backdrop {
    position: absolute;
    inset: 0;
    background: rgba(8, 6, 20, 0.42);
  }
  .folder {
    position: relative;
    min-width: 320px;
    padding: 20px 26px 24px;
    border-radius: 30px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    color: var(--ink);
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.4);
  }
  .folder :global(.name) {
    color: var(--ink);
    text-shadow: none;
  }
  h3 {
    margin: 0 0 16px;
    text-align: center;
    font-size: 16px;
    font-weight: 700;
  }
  .fgrid {
    display: grid;
    grid-template-columns: repeat(3, 90px);
    gap: 18px 14px;
    justify-content: center;
  }
  .home[data-fold='cover'] .folder {
    min-width: 0;
    width: calc(100% - 28px);
    padding: 18px 8px 20px;
  }
  .home[data-fold='cover'] .fgrid {
    grid-template-columns: repeat(3, 1fr);
    gap: 16px 4px;
  }
</style>
