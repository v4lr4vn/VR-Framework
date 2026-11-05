<script>
  import Glyph from './Glyph.svelte';
  import { phone, goHome, goBack } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // The strip at the bottom: a back button while an app is open, and the home pill.
</script>

{#if phone.app}
  <div class="nav">
    <button class="back" onclick={goBack} aria-label={t('nav.back')}>
      <Glyph name="chev-left" size={22} stroke={2.2} />
    </button>
    <button class="pill" onclick={goHome} aria-label={t('nav.home')}><span></span></button>
  </div>
{/if}

<style>
  .nav {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 30;
    pointer-events: none;
  }
  .pill {
    pointer-events: auto;
    padding: 12px 26px;
  }
  .pill span {
    display: block;
    width: 112px;
    height: 5px;
    border-radius: 3px;
    background: var(--ink);
    opacity: 0.55;
    transition: opacity 0.15s;
  }
  .pill:hover span {
    opacity: 0.9;
  }
  .back {
    pointer-events: auto;
    position: absolute;
    left: 22px;
    bottom: 3px;
    width: 40px;
    height: 28px;
    display: grid;
    place-items: center;
    border-radius: 14px;
    color: var(--ink);
    opacity: 0.7;
  }
  .back:hover {
    opacity: 1;
    background: var(--line);
  }
</style>
