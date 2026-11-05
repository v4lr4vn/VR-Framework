<script>
  import { fly, fade } from 'svelte/transition';
  import Glyph from './Glyph.svelte';
  import Avatar from './Avatar.svelte';
  import { share, cancelPicker, sendShare, cancelSending } from '../lib/media.svelte.js';
  import { dur } from '../lib/motion.js';
  import { t } from '../lib/i18n.js';

  // Nearby share, the sending side: pick a player who is close, then wait for their answer.
</script>

{#if share.picker || share.sending}
  <div class="scrim" transition:fade={{ duration: dur(140) }}>
    <button class="back" aria-label={t('common.cancel')} onclick={() => (share.picker ? cancelPicker() : cancelSending())}></button>
    <div class="sheet" transition:fly={{ y: 80, duration: dur(240) }} role="dialog" aria-label={t('share.title')}>
      {#if share.sending}
        <span class="spin"></span>
        <h3>{t('share.waiting', { name: share.sending.name })}</h3>
        <p>{t('share.waitingHint')}</p>
        <button class="btn" onclick={cancelSending}>{t('common.cancel')}</button>
      {:else if share.picker}
        <header>
          <span class="bt"><Glyph name="bluetooth2" size={20} stroke={2} /></span>
          <div>
            <h3>{t('share.title')}</h3>
            <p>{share.picker.label}</p>
          </div>
        </header>

        {#if !share.bluetooth}
          <p class="warn">{t('share.bluetoothOff')}</p>
        {:else if share.people.length === 0}
          <p class="empty">{share.loading ? t('share.looking') : t('share.nobody')}</p>
        {:else}
          <ul>
            {#each share.people as p (p.id)}
              <li>
                <button class="who" onclick={() => sendShare(p)}>
                  <Avatar name={p.name} number={String(p.id)} size={40} />
                  <span class="text">
                    <span class="name">{p.name}</span>
                    <span class="sub">{t('share.metres', { n: p.distance })}</span>
                  </span>
                  <Glyph name="send" size={19} stroke={2} />
                </button>
              </li>
            {/each}
          </ul>
        {/if}
        {#if share.error}<p class="err">{share.error}</p>{/if}
        <button class="btn" onclick={cancelPicker}>{t('common.cancel')}</button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .scrim {
    position: absolute;
    inset: 0;
    z-index: 70;
    display: flex;
    align-items: flex-end;
    background: rgba(8, 6, 16, 0.5);
  }
  .back {
    position: absolute;
    inset: 0;
  }
  .sheet {
    position: relative;
    width: 100%;
    max-height: 78%;
    overflow-y: auto;
    padding: 20px 20px 46px;
    border-radius: 28px 28px 0 0;
    background: var(--bg);
    color: var(--ink);
    display: flex;
    flex-direction: column;
    gap: 10px;
    box-shadow: 0 -10px 40px rgba(0, 0, 0, 0.3);
  }
  header {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .bt {
    width: 42px;
    height: 42px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: #3b82f6;
    color: #fff;
  }
  h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
  }
  p {
    margin: 0;
    font-size: 13.5px;
    color: var(--ink-3);
    line-height: 1.4;
  }
  .empty,
  .warn {
    padding: 14px 4px;
    font-size: 14px;
  }
  .warn {
    color: #e0a21e;
    font-weight: 600;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .who {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 10px;
    border-radius: 14px;
    background: var(--surface);
    color: var(--accent);
    text-align: left;
  }
  .who:hover {
    background: var(--accent-soft);
  }
  .text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    color: var(--ink);
  }
  .name {
    font-size: 15.5px;
    font-weight: 600;
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .err {
    color: #e5484d;
    font-weight: 600;
  }
  .btn {
    margin-top: 4px;
    padding: 12px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 14.5px;
    font-weight: 700;
    color: var(--ink);
  }
  .spin {
    align-self: center;
    width: 34px;
    height: 34px;
    margin-top: 6px;
    border-radius: 50%;
    border: 3px solid var(--line);
    border-top-color: var(--accent);
    animation: spin 0.8s linear infinite;
  }
  .sheet > h3,
  .sheet > p {
    text-align: center;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
