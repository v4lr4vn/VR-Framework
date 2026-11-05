<script>
  import { onMount } from 'svelte';
  import { fly } from 'svelte/transition';
  import Glyph from './Glyph.svelte';
  import { share, respondShare, dropExpired, mediaError } from '../lib/media.svelte.js';
  import { dur } from '../lib/motion.js';
  import { t } from '../lib/i18n.js';

  // Nearby share, the receiving side: someone close wants to send photos or contacts.
  let now = $state(Date.now());
  let error = $state('');

  const req = $derived(share.incoming[0] ?? null);
  const left = $derived(req ? Math.max(0, Math.ceil((req.until - now) / 1000)) : 0);

  onMount(() => {
    const id = setInterval(() => {
      now = Date.now();
      dropExpired(now);
    }, 500);
    return () => clearInterval(id);
  });

  async function answer(accept) {
    if (!req) return;
    error = '';
    const r = await respondShare(req.id, accept);
    if (accept && !r.ok) error = mediaError(r.reason, 'share');
  }
</script>

{#if req}
  <div class="wrap" in:fly={{ y: -40, duration: dur(220) }}>
    <div class="card" role="alertdialog" aria-label={t('share.requestTitle')}>
      <div class="top">
        {#if req.kind === 'photo' && req.preview}
          <img src={req.preview} alt="" />
        {:else}
          <span class="ico"><Glyph name={req.kind === 'photo' ? 'gallery' : 'contacts'} size={24} stroke={1.8} /></span>
        {/if}
        <div class="text">
          <b>{t('share.requestTitle')}</b>
          <span>
            {req.kind === 'photo' ? t('share.wantsPhotos', { name: req.name, n: req.count }) : t('share.wantsContacts', { name: req.name, n: req.count })}
          </span>
          {#if req.kind === 'contact' && req.preview}<span class="sub">{req.preview}{req.count > 1 ? ` +${req.count - 1}` : ''}</span>{/if}
        </div>
        <span class="secs">{left}</span>
      </div>
      {#if error}<p class="err">{error}</p>{/if}
      <div class="btns">
        <button class="no" onclick={() => answer(false)}>{t('share.decline')}</button>
        <button class="yes" onclick={() => answer(true)}>{t('share.accept')}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .wrap {
    position: absolute;
    top: 46px;
    left: 12px;
    right: 12px;
    z-index: 80;
    display: flex;
    justify-content: center;
  }
  .card {
    width: 100%;
    max-width: 420px;
    padding: 14px;
    border-radius: 22px;
    background: var(--surface);
    color: var(--ink);
    box-shadow: 0 10px 34px rgba(0, 0, 0, 0.34);
  }
  .top {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  img,
  .ico {
    width: 52px;
    height: 52px;
    flex: none;
    border-radius: 13px;
    object-fit: cover;
    background: var(--surface-2);
  }
  .ico {
    display: grid;
    place-items: center;
    color: var(--accent);
  }
  .text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 13.5px;
    line-height: 1.35;
    color: var(--ink-2);
  }
  .text b {
    font-size: 15px;
    color: var(--ink);
  }
  .sub {
    color: var(--ink-3);
  }
  .secs {
    flex: none;
    min-width: 30px;
    text-align: right;
    font-family: var(--mono);
    font-size: 13px;
    color: var(--ink-3);
  }
  .btns {
    display: flex;
    gap: 8px;
    margin-top: 12px;
  }
  .btns button {
    flex: 1;
    padding: 11px;
    border-radius: 14px;
    font-size: 14.5px;
    font-weight: 700;
  }
  .no {
    background: var(--surface-2);
    color: var(--ink);
  }
  .yes {
    background: var(--accent);
    color: var(--on-accent);
  }
  .err {
    margin: 8px 0 0;
    font-size: 13px;
    font-weight: 600;
    color: #e5484d;
  }
</style>
