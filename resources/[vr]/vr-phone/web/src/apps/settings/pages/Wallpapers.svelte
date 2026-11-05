<script>
  import Label from '../../../ui/kit/Label.svelte';
  import { phone, saveSettings } from '../../../lib/store.svelte.js';
  import { wallpapers, wallpaper } from '../../../lib/wallpapers.js';
  import { t } from '../../../lib/i18n.js';

  const s = $derived(phone.settings);
  const ids = Object.keys(wallpapers);
</script>

<Label>{t('settings.wallHome')}</Label>
<div class="walls">
  {#each ids as id}
    <button class="wall" class:on={s.wallpaper.home === id} style:background={wallpaper(id)} aria-label={id} onclick={() => saveSettings({ wallpaper: { home: id } })}></button>
  {/each}
</div>

<Label>{t('settings.wallLock')}</Label>
<div class="walls">
  {#each ids as id}
    <button class="wall" class:on={s.wallpaper.lock === id} style:background={wallpaper(id)} aria-label={id} onclick={() => saveSettings({ wallpaper: { lock: id } })}></button>
  {/each}
</div>

<style>
  .walls {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
  }
  .wall {
    aspect-ratio: 9 / 14;
    border-radius: 14px;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.18);
  }
  .wall.on {
    box-shadow: 0 0 0 3px var(--bg), 0 0 0 5px var(--accent);
  }
</style>
