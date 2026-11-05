<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import { phone, setQuick } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';

  const q = $derived(phone.settings.quick);
  const sig = $derived(phone.status.signal);
  const level = $derived(sig.airplane ? 'airplane' : sig.level);
</script>

<Group>
  <Row title={t('settings.carrier')}><span class="val">{sig.carrier || '—'}</span></Row>
  <Row title={t('settings.number')}><span class="val mono">{phone.number || '—'}</span></Row>
  <Row title={t('settings.signal')} hint={sig.service ? '' : t('settings.noServiceHint')}>
    <span class="val">{t(`settings.signal.${level}`)}</span>
  </Row>
</Group>

<Label>{t('settings.connections')}</Label>
<Group>
  <Row title={t('settings.airplane')} hint={t('settings.airplaneHint')}>
    <Switch checked={q.airplane} onchange={(v) => setQuick({ airplane: v })} label={t('settings.airplane')} />
  </Row>
  <Row title={t('panel.bluetooth')}>
    <Switch checked={q.bluetooth} onchange={(v) => setQuick({ bluetooth: v })} label={t('panel.bluetooth')} />
  </Row>
</Group>

<style>
  .val {
    font-size: 15px;
    color: var(--ink-2);
  }
  .mono {
    font-family: var(--mono);
  }
</style>
