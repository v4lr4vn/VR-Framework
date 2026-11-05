<script>
  import AppTile from '../../ui/AppTile.svelte';
  import { appLabel } from '../../lib/apps.js';
  import { t } from '../../lib/i18n.js';

  // Shown for an app that has no screen yet (or whose code could not be loaded).
  let { id, failed = false } = $props();
</script>

<div class="soon">
  <AppTile {id} size={88} />
  <h2>{appLabel(id)}</h2>
  <p>{failed ? t('app.failed') : t('app.soon')}</p>
</div>

<style>
  .soon {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 6px;
    text-align: center;
    padding: 40px;
  }
  h2 {
    margin: 14px 0 0;
    font-size: 22px;
    font-weight: 700;
  }
  p {
    margin: 0;
    max-width: 260px;
    font-size: 14px;
    line-height: 1.45;
    color: var(--ink-3);
  }
</style>
