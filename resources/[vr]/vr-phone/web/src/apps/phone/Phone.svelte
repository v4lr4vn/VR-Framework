<script>
  import { untrack } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Dialer from './Dialer.svelte';
  import Recents from './Recents.svelte';
  import Favourites from './Favourites.svelte';
  import Voicemail from './Voicemail.svelte';
  import { phone } from '../../lib/store.svelte.js';
  import { comms, loadRecents, loadVoicemail, markCallsSeen } from '../../lib/comms.svelte.js';
  import { t } from '../../lib/i18n.js';

  // Favourites, recent calls, voicemail and the keypad.
  //   cover (closed): one page at a time, with a tab bar at the bottom
  //   flex (half open): the keypad on the top half, the lists on the bottom half
  //   open: the lists on the left, the keypad on the right
  let tab = $state('recents'); // 'favourites' | 'recents' | 'voicemail' | 'keypad'

  const cover = $derived(phone.fold === 'cover');
  const unheard = $derived(comms.voicemail.filter((v) => !v.heard).length);

  // The keypad is a tab only on the closed phone. The other folds always show it.
  $effect(() => {
    if (!cover && tab === 'keypad') tab = 'recents';
  });

  // Fetch the lists when the app opens, and again when something new arrives.
  $effect(() => {
    comms.rev.recents;
    untrack(() => loadRecents(true).then(() => (tab === 'recents' ? markCallsSeen() : null)));
  });
  $effect(() => {
    comms.rev.voicemail;
    untrack(() => loadVoicemail(true));
  });

  // Looking at the recent calls is what makes missed calls "seen".
  $effect(() => {
    if (tab === 'recents') untrack(() => markCallsSeen());
  });

  const TABS = [
    { id: 'favourites', glyph: 'star', label: 'phone.favourites' },
    { id: 'recents', glyph: 'clock', label: 'phone.recents' },
    { id: 'keypad', glyph: 'keypad', label: 'phone.keypad' },
    { id: 'voicemail', glyph: 'voicemail', label: 'phone.voicemail' },
  ];
  const wide = TABS.filter((x) => x.id !== 'keypad');
</script>

{#snippet content()}
  {#if tab === 'favourites'}
    <Favourites />
  {:else if tab === 'voicemail'}
    <Voicemail />
  {:else}
    <Recents />
  {/if}
{/snippet}

{#snippet lists()}
  <div class="seg" role="tablist">
    {#each wide as x (x.id)}
      <button role="tab" aria-selected={tab === x.id} class:on={tab === x.id} onclick={() => (tab = x.id)}>
        {t(x.label)}
        {#if x.id === 'voicemail' && unheard > 0}<i class="count">{unheard}</i>{/if}
      </button>
    {/each}
  </div>
  {@render content()}
{/snippet}

{#snippet pad()}
  <Dialer compact={phone.fold === 'flex'} />
{/snippet}

{#if cover}
  <div class="cover">
    <div class="page">
      {#if tab === 'keypad'}
        <Dialer />
      {:else}
        {@render content()}
      {/if}
    </div>
    <div class="bar" role="tablist">
      {#each TABS as x (x.id)}
        <button role="tab" aria-selected={tab === x.id} class:on={tab === x.id} onclick={() => (tab = x.id)} aria-label={t(x.label)}>
          <Glyph name={x.glyph} size={22} stroke={tab === x.id ? 2.2 : 1.8} />
          <span>{t(x.label)}</span>
          {#if x.id === 'voicemail' && unheard > 0}<i class="count">{unheard}</i>{/if}
          {#if x.id === 'recents' && comms.badges.phone - unheard > 0}<i class="count">{comms.badges.phone - unheard}</i>{/if}
        </button>
      {/each}
    </div>
  </div>
{:else}
  <TwoPane list={lists} detail={pad} />
{/if}

<style>
  .cover {
    position: absolute;
    inset: 0;
  }
  .page {
    position: absolute;
    inset: 0;
    overflow-y: auto;
    padding: 50px 16px 104px;
  }
  .bar {
    position: absolute;
    left: 10px;
    right: 10px;
    bottom: 36px;
    height: 58px;
    display: flex;
    border-radius: 22px;
    background: var(--surface);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.14);
    z-index: 6;
  }
  .bar button {
    position: relative;
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    border-radius: 22px;
    font-size: 10.5px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .bar button.on {
    color: var(--accent);
  }
  .bar .count {
    position: absolute;
    top: 5px;
    left: 50%;
    margin-left: 7px;
  }
  .count {
    min-width: 17px;
    height: 17px;
    padding: 0 4px;
    border-radius: 9px;
    background: #ff4d5e;
    color: #fff;
    font-size: 10.5px;
    font-style: normal;
    font-weight: 700;
    line-height: 17px;
    text-align: center;
  }
  .seg {
    display: flex;
    gap: 3px;
    padding: 3px;
    margin-bottom: 14px;
    border-radius: 13px;
    background: var(--surface-2);
  }
  .seg button {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 8px 6px;
    border-radius: 10px;
    font-size: 13px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .seg button.on {
    background: var(--surface);
    color: var(--ink);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.18);
  }
</style>
