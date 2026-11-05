<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import AppTile from '../../../ui/AppTile.svelte';
  import { phone, saveSettings } from '../../../lib/store.svelte.js';
  import { appLabel } from '../../../lib/apps.js';
  import { t } from '../../../lib/i18n.js';

  // The rules for one app. An app with no saved rule has everything on.
  let { id } = $props();

  const rule = $derived(phone.settings.notify.apps[id] ?? {});
  const allowed = $derived(rule.enabled !== false);

  function set(key, value) {
    saveSettings({ notify: { apps: { [id]: { [key]: value } } } });
  }
</script>

<div class="head">
  <AppTile {id} size={46} />
  <span class="name">{appLabel(id)}</span>
</div>

<Group>
  <Row title={t('settings.notifyAllow')}>
    <Switch checked={allowed} onchange={(v) => set('enabled', v)} label={t('settings.notifyAllow')} />
  </Row>
  <Row title={t('settings.notifyBanner')} hint={t('settings.notifyBannerHint')}>
    <Switch checked={rule.banner !== false} disabled={!allowed} onchange={(v) => set('banner', v)} label={t('settings.notifyBanner')} />
  </Row>
  <Row title={t('settings.notifyLock')} hint={t('settings.notifyLockHint')}>
    <Switch checked={rule.lock !== false} disabled={!allowed} onchange={(v) => set('lock', v)} label={t('settings.notifyLock')} />
  </Row>
  <Row title={t('settings.notifySound')}>
    <Switch checked={rule.sound !== false} disabled={!allowed} onchange={(v) => set('sound', v)} label={t('settings.notifySound')} />
  </Row>
</Group>
{#if !allowed}<p class="hint">{t('settings.notifyOffHint')}</p>{/if}

<style>
  .head {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-bottom: 18px;
  }
  .name {
    font-size: 20px;
    font-weight: 700;
  }
  .hint {
    margin: 10px 4px 0;
    font-size: 12.5px;
    color: var(--ink-3);
  }
</style>
