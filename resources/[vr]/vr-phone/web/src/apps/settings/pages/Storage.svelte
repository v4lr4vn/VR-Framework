<script>
  import { onMount } from 'svelte';
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import { media, loadStats } from '../../../lib/media.svelte.js';
  import { t } from '../../../lib/i18n.js';

  onMount(loadStats);

  const used = $derived(media.stats.max > 0 ? Math.min(100, Math.round((media.stats.photos / media.stats.max) * 100)) : 0);
  function size(bytes) {
    const n = Number(bytes) || 0;
    return n > 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.round(n / 1024)} KB`;
  }
</script>

<div class="bar" role="img" aria-label={`${used}%`}><span style:width="{used}%"></span></div>

<Group>
  <Row title={t('storage.photos')} hint={t('storage.photosHint', { n: media.stats.photos, max: media.stats.max })}>
    <span class="val">{used}%</span>
  </Row>
  <Row title={t('storage.size')}><span class="val">{size(media.stats.bytes)}</span></Row>
  <Row title={t('storage.deleted')} hint={t('storage.deletedHint', { days: media.limits.keepDeletedDays })}>
    <span class="val">{media.stats.deleted}</span>
  </Row>
</Group>

<style>
  .bar {
    height: 10px;
    margin: 0 4px 16px;
    border-radius: 5px;
    background: var(--surface-2);
    overflow: hidden;
  }
  .bar span {
    display: block;
    height: 100%;
    border-radius: 5px;
    background: var(--accent);
    transition: width 0.4s var(--ease);
  }
  .val {
    font-size: 15px;
    color: var(--ink-2);
  }
</style>
