<script>
  import Glyph from './Glyph.svelte';
  import { phone } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // A phone with an empty battery shows nothing but a hint. Once it has a little charge it starts up again.
  const starting = $derived(phone.status.powered && phone.booting);
  const charging = $derived(phone.status.charging);
</script>

<div class="off" class:starting>
  {#if starting}
    <span class="logo"><Glyph name="power" size={44} stroke={1.8} /></span>
    <span class="spinner"></span>
    <p class="title">{t('power.starting')}</p>
  {:else}
    <span class="batt" class:charging>
      <Glyph name={charging ? 'bolt' : 'battery'} size={44} stroke={1.8} />
    </span>
    <p class="title">{t('power.empty')}</p>
    <p class="hint">{charging ? t('power.charging') : t('power.plugIn')}</p>
  {/if}
</div>

<style>
  .off {
    position: absolute;
    inset: 0;
    z-index: 50;
    background: #000;
    color: #fff;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
    padding: 0 28px;
    text-align: center;
  }
  .batt {
    color: #ff5d66;
  }
  .batt.charging {
    color: #3ddc84;
  }
  .logo {
    color: #fff;
    opacity: 0.9;
  }
  .title {
    margin: 4px 0 0;
    font-size: 18px;
    font-weight: 700;
  }
  .hint {
    margin: 0;
    max-width: 280px;
    font-size: 14px;
    line-height: 1.4;
    color: rgba(255, 255, 255, 0.62);
  }
  .spinner {
    width: 26px;
    height: 26px;
    border-radius: 50%;
    border: 3px solid rgba(255, 255, 255, 0.2);
    border-top-color: #fff;
    animation: spin 0.9s linear infinite;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
