<script>
  import Glyph from './Glyph.svelte';
  import { phone, setFold, closePhone } from '../lib/store.svelte.js';
  import { t } from '../lib/i18n.js';

  // Hardware-style controls beside the phone: fold it shut, half open or fully open, or put it away.
  const states = [
    { id: 'cover', glyph: 'fold-cover', label: 'fold.cover' },
    { id: 'flex', glyph: 'fold-flex', label: 'fold.flex' },
    { id: 'open', glyph: 'fold-open', label: 'fold.open' },
  ];
</script>

<div class="switch" role="toolbar" aria-label={t('fold.title')}>
  {#each states as s (s.id)}
    {#if phone.features.fold[s.id] !== false}
      <button class:on={phone.fold === s.id} onclick={() => setFold(s.id)} aria-label={t(s.label)} title={t(s.label)}>
        <Glyph name={s.glyph} size={22} />
      </button>
    {/if}
  {/each}
  <span class="sep"></span>
  <button class="away" onclick={closePhone} aria-label={t('phone.putAway')} title={t('phone.putAway')}>
    <Glyph name="power" size={20} />
  </button>
</div>

<style>
  .switch {
    position: absolute;
    right: calc(100% + 16px);
    bottom: 26px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 8px;
    border-radius: 24px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.28);
    color: var(--ink);
  }
  button {
    width: 44px;
    height: 44px;
    border-radius: 16px;
    display: grid;
    place-items: center;
    color: var(--ink-2);
    transition: background 0.18s var(--ease-soft), color 0.18s var(--ease-soft);
  }
  button:hover {
    background: var(--line);
    color: var(--ink);
  }
  button.on {
    background: var(--accent);
    color: var(--on-accent);
  }
  .sep {
    width: 24px;
    height: 1px;
    background: var(--line);
    margin: 2px 0;
  }
  .away:hover {
    background: rgba(255, 77, 94, 0.18);
    color: #ff4d5e;
  }
</style>
