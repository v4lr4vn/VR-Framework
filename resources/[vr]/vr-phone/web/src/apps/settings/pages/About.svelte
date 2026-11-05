<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import { phone } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';
</script>

<Group>
  <Row title={t('settings.number')}><span class="val mono">{phone.number || '—'}</span></Row>
  <Row title={t('settings.apps')}><span class="val">{phone.installed.length}</span></Row>
  <Row title={t('settings.version')}><span class="val">vr-phone 0.4</span></Row>
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
