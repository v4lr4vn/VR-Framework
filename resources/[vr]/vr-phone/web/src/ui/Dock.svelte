<script>
  import AppIcon from './AppIcon.svelte';
  import { phone } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // The taskbar: pinned apps and recent apps.
  // In the open phone the two groups sit either side of the crease, so no icon is ever on the fold.
  let { pinned, onopen } = $props();

  const recents = $derived(phone.recents.filter((id) => !pinned.includes(id)).slice(0, 4));
</script>

<div class="dock" data-fold={phone.fold}>
  <div class="group pinned">
    {#each pinned as id (id)}
      <AppIcon {id} size={52} label={false} {onopen} />
    {/each}
  </div>
  {#if phone.fold !== 'cover'}
    <div class="gap"></div>
    <div class="group recents" aria-label={t('home.recent')}>
      {#if recents.length === 0}
        <span class="hint">{t('home.recentEmpty')}</span>
      {:else}
        {#each recents as id (id)}
          <AppIcon {id} size={52} label={false} {onopen} />
        {/each}
      {/if}
    </div>
  {/if}
</div>

<style>
  .dock {
    position: absolute;
    left: 22px;
    right: 22px;
    bottom: 30px;
    height: 80px;
    display: flex;
    align-items: center;
    z-index: 10;
  }
  .group {
    flex: 1;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 14px;
    border-radius: 28px;
    background: var(--wp-glass, var(--glass));
    border: 1px solid var(--wp-glass-line, var(--glass-line));
  }
  .gap {
    flex: none;
    width: 34px;
  }
  .hint {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--wp-ink, var(--ink-3));
    opacity: 0.7;
  }
  /* Closed phone: one group across the narrow screen. */
  .dock[data-fold='cover'] {
    left: 14px;
    right: 14px;
    bottom: 36px;
    height: 72px;
  }
  .dock[data-fold='cover'] .group {
    border-radius: 24px;
    gap: 10px;
  }
  /* In flex mode the dock lies across the bottom half and has no crease to avoid. */
  .dock[data-fold='flex'] .gap {
    width: 14px;
  }
</style>
