<script>
  import { onMount, onDestroy } from 'svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { post, on, off, inGame } from '../../lib/nui.js';
  import { phone, goHome, openApp } from '../../lib/store.svelte.js';
  import { media, savePhoto, mediaError } from '../../lib/media.svelte.js';
  import { t } from '../../lib/i18n.js';

  // The viewfinder. The game's own picture is behind this page, so this page draws only the controls.
  // In the game the mouse turns the camera and the keys on the hints work the controls (see client/modules/camera.lua).
  // The on-screen buttons do the same job, for a mouse that is free and for the browser preview.
  let ready = $state(false);
  let error = $state('');
  let front = $state(false);
  let zoom = $state(0); // 0 to 100
  let timer = $state(0); // seconds, 0 = off
  let count = $state(0); // the countdown number on screen
  let hidden = $state(false); // the controls hide for the moment of the shot
  let flash = $state(false);
  let grid = $state(true);
  let notice = $state('');
  let busy = $state(false);
  let noticeTimer = 0;

  const flex = $derived(phone.fold === 'flex');
  const cover = $derived(phone.fold === 'cover');
  const timers = $derived(media.limits.timerSeconds);

  function say(text, ms = 2600) {
    notice = text;
    clearTimeout(noticeTimer);
    noticeTimer = setTimeout(() => (notice = ''), ms);
  }

  async function onShot(data) {
    flash = true;
    setTimeout(() => (flash = false), 140);
    if (typeof data !== 'string') return;
    busy = true;
    const r = await savePhoto(data);
    busy = false;
    say(r.ok ? t('camera.saved') : mediaError(r.reason));
  }

  function onFail() {
    say(t('camera.captureFailed'));
  }

  onMount(async () => {
    const r = await post('cameraStart');
    if (!r?.ok) {
      error = r?.reason ?? 'timeout';
      return;
    }
    ready = true;
    if (typeof r.zoom === 'number') zoom = r.zoom;
    on('cameraShot', onShot);
    on('cameraFail', onFail);
    on('cameraCount', (n) => (count = Number(n) || 0));
    on('cameraHide', (h) => (hidden = h === true));
    on('cameraSide', (f) => (front = f === true));
    on('cameraZoom', (z) => (zoom = Number(z) || 0));
    on('cameraTimer', (s) => (timer = Number(s) || 0));
    on('cameraExit', () => goHome());
  });

  onDestroy(() => {
    post('cameraStop');
    for (const a of ['cameraShot', 'cameraFail', 'cameraCount', 'cameraHide', 'cameraSide', 'cameraZoom', 'cameraTimer', 'cameraExit']) off(a);
    clearTimeout(noticeTimer);
  });

  function shoot() {
    if (!ready || busy || count > 0) return;
    post('cameraShoot');
  }

  async function flip() {
    const r = await post('cameraFlip');
    if (r && typeof r.front === 'boolean') front = r.front;
  }

  async function cycleTimer() {
    const r = await post('cameraTimer');
    if (r && typeof r.seconds === 'number') timer = r.seconds;
  }

  function openGallery() {
    goHome();
    openApp('gallery');
  }

  const errorText = $derived(error === 'no_screenshot' ? t('camera.noScreenshot') : error ? t('camera.unavailable') : '');
</script>

<div class="cam" class:dev={!inGame} class:flex class:cover class:hide={hidden} class:front>
  {#if flash}<div class="flash"></div>{/if}

  {#if error}
    <div class="down">
      <Glyph name="camera" size={40} stroke={1.6} />
      <h2>{t('app.camera')}</h2>
      <p>{errorText}</p>
      <button class="plain" onclick={() => goHome()}>{t('common.close')}</button>
    </div>
  {:else}
    {#if grid}
      <div class="grid"><span></span><span></span><i></i><i></i></div>
    {/if}

    {#if count > 0}<div class="count" aria-live="polite">{count}</div>{/if}

    <div class="top">
      <button class="chip" onclick={() => goHome()} aria-label={t('common.close')}><Glyph name="close" size={20} stroke={2.2} /></button>
      <div class="mid">
        {#if notice}<span class="note">{notice}</span>{/if}
        {#if !notice && !front && zoom > 0}<span class="note">{t('camera.zoom', { value: zoom })}</span>{/if}
      </div>
      <div class="row">
        <button class="chip" class:on={timer > 0} onclick={cycleTimer} aria-label={t('camera.timer')}>
          <Glyph name="timer" size={19} />{#if timer > 0}<b>{timer}s</b>{/if}
        </button>
        <button class="chip" class:on={grid} onclick={() => (grid = !grid)} aria-label={t('camera.grid')}>
          <Glyph name="gridlines" size={19} />
        </button>
      </div>
    </div>

    <div class="bar">
      <button class="last" onclick={openGallery} aria-label={t('app.gallery')}>
        {#if media.last}<img src={media.last} alt="" />{:else}<Glyph name="gallery" size={22} />{/if}
      </button>
      <button class="shutter" onclick={shoot} disabled={!ready || busy || count > 0} aria-label={t('camera.shoot')}>
        <span></span>
      </button>
      <button class="chip big" onclick={flip} aria-label={front ? t('camera.back') : t('camera.front')}>
        <Glyph name="flip" size={24} />
      </button>
    </div>

    {#if inGame}
      <div class="keys">
        <span><kbd>Enter</kbd> {t('camera.keyShoot')}</span>
        <span><kbd>R</kbd> {t('camera.keyFlip')}</span>
        <span><kbd>T</kbd> {t('camera.keyTimer')}</span>
        <span><kbd>{t('camera.wheel')}</kbd> {t('camera.keyZoom')}</span>
        <span><kbd>Esc</kbd> {t('camera.keyExit')}</span>
      </div>
    {/if}
  {/if}
</div>

<style>
  .cam {
    position: fixed;
    inset: 0;
    z-index: 20;
    pointer-events: none;
    color: #fff;
    font-family: var(--font);
  }
  /* The browser preview has no game behind it, so it paints a stand-in view. */
  .cam.dev {
    background: linear-gradient(180deg, #88b4e8 0%, #cfe0f2 46%, #6e8a62 47%, #3e5a3b 100%);
  }
  .cam.hide .top,
  .cam.hide .bar,
  .cam.hide .keys,
  .cam.hide .grid,
  .cam.hide .count {
    visibility: hidden;
  }
  button {
    pointer-events: auto;
    color: inherit;
  }
  .flash {
    position: absolute;
    inset: 0;
    background: #fff;
    opacity: 0.85;
    animation: fade 0.14s ease-out forwards;
  }
  @keyframes fade {
    to {
      opacity: 0;
    }
  }
  .grid span,
  .grid i {
    position: absolute;
    background: rgba(255, 255, 255, 0.35);
  }
  .grid span {
    top: 0;
    bottom: 0;
    width: 1px;
  }
  .grid span:nth-child(1) {
    left: 33.33%;
  }
  .grid span:nth-child(2) {
    left: 66.66%;
  }
  .grid i {
    left: 0;
    right: 0;
    height: 1px;
  }
  .grid i:nth-of-type(1) {
    top: 33.33%;
  }
  .grid i:nth-of-type(2) {
    top: 66.66%;
  }
  .count {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    font-size: 140px;
    font-weight: 700;
    text-shadow: 0 4px 24px rgba(0, 0, 0, 0.55);
  }

  .top {
    position: absolute;
    top: 22px;
    left: 24px;
    right: 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  .mid {
    flex: 1;
    display: flex;
    justify-content: center;
    min-width: 0;
  }
  .note {
    padding: 6px 14px;
    border-radius: 14px;
    background: rgba(0, 0, 0, 0.55);
    font-size: 14px;
    font-weight: 600;
    text-align: center;
  }
  .row {
    display: flex;
    gap: 8px;
  }
  .chip {
    min-width: 42px;
    height: 42px;
    padding: 0 12px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    border-radius: 21px;
    background: rgba(0, 0, 0, 0.5);
    font-size: 13px;
  }
  .chip.on {
    background: var(--accent);
    color: var(--on-accent);
  }
  .chip b {
    font-weight: 700;
  }
  .chip.big {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    padding: 0;
  }

  .bar {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    padding: 18px 40px 26px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    max-width: 560px;
    margin: 0 auto;
  }
  /* half open: the controls take the bottom half */
  .flex .bar {
    max-width: none;
    height: 34%;
    padding: 0 12%;
    background: rgba(8, 8, 14, 0.62);
  }
  .cover .bar {
    padding-left: 24px;
    padding-right: 24px;
  }
  .last {
    width: 56px;
    height: 56px;
    display: grid;
    place-items: center;
    overflow: hidden;
    border-radius: 14px;
    background: rgba(0, 0, 0, 0.5);
    border: 2px solid rgba(255, 255, 255, 0.7);
  }
  .last img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .shutter {
    width: 78px;
    height: 78px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    border: 4px solid #fff;
  }
  .shutter span {
    width: 58px;
    height: 58px;
    border-radius: 50%;
    background: #fff;
    transition: transform 0.12s var(--ease);
  }
  .shutter:active span {
    transform: scale(0.88);
  }
  .shutter:disabled {
    opacity: 0.55;
  }

  .keys {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 128px;
    display: flex;
    justify-content: center;
    gap: 14px;
    flex-wrap: wrap;
    font-size: 12.5px;
    text-shadow: 0 1px 6px rgba(0, 0, 0, 0.7);
  }
  .flex .keys {
    bottom: calc(34% + 10px);
  }
  kbd {
    padding: 2px 7px;
    border-radius: 6px;
    background: rgba(0, 0, 0, 0.55);
    font-family: var(--mono);
    font-size: 12px;
  }

  .down {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 40px;
    text-align: center;
    background: rgba(12, 10, 22, 0.88);
  }
  .down h2 {
    margin: 6px 0 0;
    font-size: 22px;
  }
  .down p {
    margin: 0;
    max-width: 320px;
    font-size: 14px;
    line-height: 1.5;
    color: #c4bfdc;
  }
  .plain {
    margin-top: 14px;
    padding: 10px 20px;
    border-radius: 14px;
    background: rgba(255, 255, 255, 0.14);
    font-weight: 700;
  }
</style>
