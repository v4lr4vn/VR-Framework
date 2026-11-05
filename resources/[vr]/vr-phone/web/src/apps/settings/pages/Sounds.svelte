<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import Slider from '../../../ui/kit/Slider.svelte';
  import Glyph from '../../../ui/Glyph.svelte';
  import { phone, saveSettings, setQuick } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';

  const s = $derived(phone.settings);
  const narrow = $derived(phone.fold === 'cover');
</script>

<Group>
  <Row title={t('settings.silent')} hint={t('settings.silentHint')}>
    <Switch checked={s.quick.silent} onchange={(v) => setQuick({ silent: v })} label={t('settings.silent')} />
  </Row>
  <Row title={t('settings.volume')} stack={narrow}>
    <div class="slide" class:narrow>
      <Slider min={0} max={1} step={0.05} value={s.sound.volume} onchange={(v) => saveSettings({ sound: { volume: v } })} label={t('settings.volume')} />
    </div>
  </Row>
  <Row title={t('settings.soundNotify')}>
    <Switch checked={s.sound.notifications} onchange={(v) => saveSettings({ sound: { notifications: v } })} label={t('settings.soundNotify')} />
  </Row>
  <Row title={t('settings.soundTouch')}>
    <Switch checked={s.sound.touch} onchange={(v) => saveSettings({ sound: { touch: v } })} label={t('settings.soundTouch')} />
  </Row>
</Group>

<Label>{t('settings.ringtone')}</Label>
{#if phone.ringtones.length === 0}
  <p class="hint">{t('settings.noRingtones')}</p>
{:else}
  <div class="tones">
    {#each phone.ringtones as tone (tone.id)}
      <button class="tone" class:on={s.sound.ringtone === tone.id} onclick={() => saveSettings({ sound: { ringtone: tone.id } })}>
        <span class="label">{tone.label || tone.id}</span>
        {#if s.sound.ringtone === tone.id}<Glyph name="check" size={18} stroke={2.6} />{/if}
      </button>
    {/each}
  </div>
{/if}

<style>
  .slide {
    width: 150px;
  }
  .slide.narrow {
    width: 100%;
  }
  .hint {
    margin: 0 4px;
    font-size: 13.5px;
    color: var(--ink-3);
  }
  .tones {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .tone {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 13px 16px;
    border-radius: var(--r-m);
    background: var(--surface);
    font-size: 15px;
    font-weight: 600;
  }
  .tone.on {
    background: var(--accent-soft);
    color: var(--accent);
  }
</style>
