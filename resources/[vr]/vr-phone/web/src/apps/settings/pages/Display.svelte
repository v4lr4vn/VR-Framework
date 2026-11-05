<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import Slider from '../../../ui/kit/Slider.svelte';
  import Segmented from '../../../ui/kit/Segmented.svelte';
  import Glyph from '../../../ui/Glyph.svelte';
  import { phone, saveSettings } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';

  const accents = ['#7a5cff', '#3b82f6', '#1fa596', '#27a869', '#f0a22e', '#f06a35', '#e5484d', '#d6409f'];
  const frames = ['#2b2a33', '#c9c6d4', '#1f3a5f', '#5c2a3a', '#2f4a3a', '#8a6a3b'];

  const s = $derived(phone.settings);
  const narrow = $derived(phone.fold === 'cover');
</script>

<Group>
  <Row title={t('settings.dark')}>
    <Switch checked={s.theme.dark} onchange={(v) => saveSettings({ theme: { dark: v } })} label={t('settings.dark')} />
  </Row>
  <Row title={t('settings.time24')}>
    <Switch checked={s.general.time24} onchange={(v) => saveSettings({ general: { time24: v } })} label={t('settings.time24')} />
  </Row>
  <Row title={t('settings.timeSource')} hint={t('settings.timeSourceHint')} stack>
    <Segmented
      options={[{ value: 'pc', label: t('settings.timePc') }, { value: 'game', label: t('settings.timeGame') }]}
      value={s.general.timeSource}
      onchange={(v) => saveSettings({ general: { timeSource: v } })}
      label={t('settings.timeSource')}
    />
  </Row>
  <Row title={t('settings.brightness')} stack={narrow}>
    <div class="slide" class:narrow>
      <Slider min={0.25} max={1} step={0.05} value={s.quick.brightness} onchange={(v) => saveSettings({ quick: { brightness: v } })} label={t('settings.brightness')} />
    </div>
  </Row>
  <Row title={t('settings.size')} hint={t('settings.sizeHint')} stack={narrow}>
    <div class="slide" class:narrow>
      <Slider min={0.6} max={1.2} step={0.05} value={s.theme.scale} onchange={(v) => saveSettings({ theme: { scale: v } })} label={t('settings.size')} />
    </div>
  </Row>
  <Row title={t('settings.reduceMotion')} hint={t('settings.reduceMotionHint')}>
    <Switch checked={s.perf.reduceMotion} onchange={(v) => saveSettings({ perf: { reduceMotion: v } })} label={t('settings.reduceMotion')} />
  </Row>
</Group>

<Label>{t('settings.accent')}</Label>
<div class="swatches">
  {#each accents as color}
    <button class="swatch" class:on={s.theme.accent === color} style:background={color} aria-label={color} onclick={() => saveSettings({ theme: { accent: color } })}>
      {#if s.theme.accent === color}<Glyph name="check" size={18} stroke={2.6} />{/if}
    </button>
  {/each}
</div>

<Label>{t('settings.frame')}</Label>
<div class="swatches">
  {#each frames as color}
    <button class="swatch" class:on={s.frame.color === color} style:background={color} aria-label={color} onclick={() => saveSettings({ frame: { color } })}>
      {#if s.frame.color === color}<Glyph name="check" size={18} stroke={2.6} />{/if}
    </button>
  {/each}
</div>

<style>
  .slide {
    width: 150px;
  }
  .slide.narrow {
    width: 100%;
  }
  .swatches {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
  }
  .swatch {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    color: #fff;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.15);
  }
  .swatch.on {
    box-shadow: 0 0 0 3px var(--bg), 0 0 0 5px var(--ink-3);
  }
</style>
