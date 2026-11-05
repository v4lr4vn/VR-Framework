<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import Segmented from '../../../ui/kit/Segmented.svelte';
  import AppTile from '../../../ui/AppTile.svelte';
  import Glyph from '../../../ui/Glyph.svelte';
  import { phone, saveSettings } from '../../../lib/store.svelte.js';
  import { appLabel } from '../../../lib/apps.js';
  import { t } from '../../../lib/i18n.js';

  // The notification style, lock screen previews, and a list of apps. Tap an app to set its own rules.
  let { onpick } = $props();

  const s = $derived(phone.settings);
  const styles = ['list', 'stack', 'count'];
  const apps = $derived(
    phone.installed
      .filter((id) => id !== 'settings')
      .map((id) => ({ id, label: appLabel(id) }))
      .sort((a, b) => a.label.localeCompare(b.label)),
  );

  function state(id) {
    const rule = s.notify.apps[id];
    if (rule && rule.enabled === false) return t('common.off');
    if (rule && (rule.banner === false || rule.lock === false || rule.sound === false)) return t('settings.custom');
    return t('common.on');
  }
</script>

<Label>{t('settings.notifyStyle')}</Label>
<Segmented
  label={t('settings.notifyStyle')}
  value={s.notify.style}
  onchange={(v) => saveSettings({ notify: { style: v } })}
  options={styles.map((id) => ({ value: id, label: t(`settings.style.${id}`) }))}
/>
<p class="hint">{t(`settings.style.${s.notify.style}Hint`)}</p>

<Group>
  <Row title={t('settings.previews')} hint={t('settings.previewsHint')}>
    <Switch checked={s.lock.showPreviews} onchange={(v) => saveSettings({ lock: { showPreviews: v } })} label={t('settings.previews')} />
  </Row>
</Group>

<Label>{t('settings.byApp')}</Label>
<div class="apps">
  {#each apps as app (app.id)}
    <button class="app" onclick={() => onpick(app.id)}>
      <AppTile id={app.id} size={34} />
      <span class="name">{app.label}</span>
      <span class="state">{state(app.id)}</span>
      <Glyph name="chev-right" size={18} />
    </button>
  {/each}
</div>

<style>
  .hint {
    margin: 8px 4px 16px;
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .apps {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .app {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 9px 14px;
    border-radius: var(--r-m);
    background: var(--surface);
    color: var(--ink-3);
  }
  .app:hover {
    background: var(--surface-2);
  }
  .name {
    flex: 1;
    min-width: 0;
    font-size: 15px;
    font-weight: 600;
    color: var(--ink);
  }
  .state {
    font-size: 13px;
    font-weight: 600;
  }
</style>
