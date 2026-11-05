<script>
  import { fly, fade } from 'svelte/transition';
  import AppTile from './AppTile.svelte';
  import { phone, dismissToast, openApp, noteTitle, noteText } from '../lib/store.svelte.js';
  import { comms } from '../lib/comms.svelte.js';
  import { appLabel } from '../lib/apps.js';
  import { t } from '../lib/i18n.js';
  import { dur } from '../lib/motion.js';

  // Banners for new notifications. Inside the phone they sit in the top of the screen.
  // When the phone is put away they float in the corner of the game screen instead.
  let { floating = false } = $props();

  // Banners keep the text out of sight on a locked phone when the player turned previews off.
  const hide = $derived(phone.locked && !phone.settings.lock.showPreviews);

  function pick(toast) {
    dismissToast(toast.tid);
    if (!floating && !phone.locked) openApp(toast.app);
  }
</script>

<div class="toasts" class:floating class:withcall={floating && comms.call !== null} data-fold={phone.fold}>
  {#each phone.toasts as toast (toast.tid)}
    <button class="toast" onclick={() => pick(toast)} in:fly={{ y: -28, duration: dur(260) }} out:fade={{ duration: dur(160) }}>
      <AppTile id={toast.app} size={36} />
      <span class="text">
        <span class="app">{appLabel(toast.app)}</span>
        {#if hide}
          <span class="title">{t('notify.hidden')}</span>
        {:else}
          {#if noteTitle(toast)}<span class="title">{noteTitle(toast)}</span>{/if}
          {#if noteText(toast)}<span class="msg">{noteText(toast)}</span>{/if}
        {/if}
      </span>
    </button>
  {/each}
</div>

<style>
  .toasts {
    position: absolute;
    top: 42px;
    left: 14px;
    right: 14px;
    z-index: 40;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
  }
  /* In the open phone, keep banners on the right half so they stay off the crease. */
  .toasts[data-fold='open'] {
    left: calc(50% + 14px);
  }
  /* Half open: keep the banners to a readable width in the middle. */
  .toasts[data-fold='flex'] {
    left: 50%;
    right: auto;
    width: 440px;
    margin-left: -220px;
  }
  .toasts.floating {
    margin-left: 0;
    position: fixed;
    top: 28px;
    right: 36px;
    left: auto;
    width: 340px;
  }
  .toasts.floating.withcall {
    top: 100px;
  }
  .toast {
    pointer-events: auto;
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 11px 14px;
    border-radius: 20px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.28);
    color: var(--ink);
    text-align: left;
  }
  .text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .app {
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .title {
    font-size: 14px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .msg {
    font-size: 12.5px;
    color: var(--ink-2);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
