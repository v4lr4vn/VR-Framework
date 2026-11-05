<script>
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import PinPad from '../../ui/PinPad.svelte';
  import Profile from './pages/Profile.svelte';
  import Display from './pages/Display.svelte';
  import Wallpapers from './pages/Wallpapers.svelte';
  import Notifications from './pages/Notifications.svelte';
  import AppNotify from './pages/AppNotify.svelte';
  import Sounds from './pages/Sounds.svelte';
  import Battery from './pages/Battery.svelte';
  import Network from './pages/Network.svelte';
  import Storage from './pages/Storage.svelte';
  import Security from './pages/Security.svelte';
  import About from './pages/About.svelte';
  import { createPinFlow } from './pinflow.svelte.js';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { appLabel } from '../../lib/apps.js';
  import { t } from '../../lib/i18n.js';

  const sections = [
    { id: 'profile', glyph: 'user', color: '#8b7f72' },
    { id: 'display', glyph: 'palette', color: '#7a5cff' },
    { id: 'wallpapers', glyph: 'gallery', color: '#f0a22e' },
    { id: 'notifications', glyph: 'bell', color: '#e5484d' },
    { id: 'sounds', glyph: 'volume', color: '#d6409f' },
    { id: 'battery', glyph: 'battery', color: '#27a869' },
    { id: 'network', glyph: 'sim', color: '#3b82f6' },
    { id: 'storage', glyph: 'gallery', color: '#f0a22e' },
    { id: 'security', glyph: 'shield', color: '#4668f0' },
    { id: 'about', glyph: 'info', color: '#6b7280' },
  ];
  const pages = { profile: Profile, display: Display, wallpapers: Wallpapers, sounds: Sounds, battery: Battery, network: Network, storage: Storage, about: About };

  let section = $state('display');
  let showDetail = $state(false); // closed phone only: false = the list of pages, true = one page
  let sub = $state(null); // Notifications: the app whose rules are open
  const pin = createPinFlow();

  // The back button leaves the PIN flow first, then an app's notification rules, then the page, and only then the app.
  $effect(() =>
    onBack(() => {
      if (pin.flow) {
        pin.end();
        return true;
      }
      if (sub) {
        sub = null;
        return true;
      }
      if (phone.fold === 'cover' && showDetail) {
        showDetail = false;
        return true;
      }
      return false;
    }),
  );

  // Choosing another page ends any PIN flow.
  function pick(id) {
    pin.end();
    sub = null;
    section = id;
    showDetail = true;
  }

  const Page = $derived(pages[section]);
</script>

{#snippet pad(compact)}
  <div class="padwrap" style:--pad-ink="var(--ink)" style:--pad-key="var(--surface-2)" style:--pad-key-hover="var(--surface-3)" style:--pad-ghost-hover="var(--line)">
    <PinPad {compact} length={pin.padLength} disabled={pin.waitLeft > 0} onsubmit={pin.submit} oncancel={pin.end} />
  </div>
{/snippet}

{#snippet list()}
  {#if pin.flow && phone.fold === 'flex'}
    <!-- Half open: the prompt is on the top half and the keys are on the bottom half. -->
    {@render pad(true)}
  {:else}
    <h1>{t('app.settings')}</h1>
    <div class="cats">
      {#each sections as c (c.id)}
        <button class="cat" class:on={section === c.id} onclick={() => pick(c.id)}>
          <span class="chip" style:background={c.color}><Glyph name={c.glyph} size={20} /></span>
          <span class="name">{t(`settings.${c.id}`)}</span>
          <Glyph name="chev-right" size={18} />
        </button>
      {/each}
    </div>
  {/if}
{/snippet}

{#snippet detail()}
  {#if section === 'notifications' && sub}
    <button class="crumb" onclick={() => (sub = null)}>
      <Glyph name="chev-left" size={18} stroke={2.2} /> {t('settings.notifications')}
    </button>
    <AppNotify id={sub} />
  {:else}
    <h2>{t(`settings.${section}`)}</h2>
    {#if section === 'notifications'}
      <Notifications onpick={(id) => (sub = id)} />
    {:else if section === 'security'}
      <Security {pin} {pad} />
    {:else if Page}
      <Page />
    {/if}
  {/if}
{/snippet}

<TwoPane {list} {detail} {showDetail} />

<style>
  h1 {
    margin: 0 0 18px;
    font-size: 28px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  h2 {
    margin: 0 0 16px;
    font-size: 22px;
    font-weight: 700;
  }
  .cats {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .cat {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 10px 14px;
    border-radius: var(--r-m);
    background: var(--surface);
    color: var(--ink-3);
    transition: background 0.16s var(--ease-soft);
  }
  .cat .name {
    flex: 1;
    font-size: 16px;
    font-weight: 600;
    color: var(--ink);
  }
  .cat.on {
    background: var(--accent-soft);
  }
  .chip {
    width: 34px;
    height: 34px;
    border-radius: 11px;
    display: grid;
    place-items: center;
    color: #fff;
  }
  .crumb {
    display: flex;
    align-items: center;
    gap: 4px;
    margin: 0 0 14px -4px;
    padding: 4px 8px 4px 4px;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    color: var(--accent);
  }
  .crumb:hover {
    background: var(--accent-soft);
  }
  .padwrap {
    display: flex;
    justify-content: center;
  }
</style>
