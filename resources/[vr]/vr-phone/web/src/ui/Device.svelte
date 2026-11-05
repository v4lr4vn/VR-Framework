<script>
  import { fly } from 'svelte/transition';
  import Screen from './Screen.svelte';
  import FoldSwitch from './FoldSwitch.svelte';
  import { phone, lockPhone } from '../lib/store.svelte.js';
  import { shade } from '../lib/color.js';
  import { t } from '../lib/i18n.js';
  import { dur } from '../lib/motion.js';

  // The phone body: frame, screen, crease and hinge. Its size follows the fold state.
  // (cover = closed and tall, flex = half open with the crease across, open = flat with the crease down the middle)
  const SIZES = {
    cover: { w: 300, h: 640 },
    flex: { w: 820, h: 740 },
    open: { w: 820, h: 740 },
  };
  const BEZEL = 11;

  const size = $derived(SIZES[phone.fold] ?? SIZES.open);
  // Brightness dims the screen with a dark layer on top of it.
  const dim = $derived((1 - Math.max(0.25, Math.min(1, Number(phone.settings.quick.brightness) || 1))) * 0.8);
  const frame = $derived(phone.settings.frame.color || '#2b2a33');
  const scale = $derived(Math.max(0.6, Math.min(1.2, Number(phone.settings.theme.scale) || 0.85)));
  const style = $derived(
    [
      `width:${size.w + BEZEL * 2}px`,
      `height:${size.h + BEZEL * 2}px`,
      `--frame:${frame}`,
      `--frame-hi:${shade(frame, 0.28)}`,
      `--frame-lo:${shade(frame, -0.45)}`,
      `--bezel:${BEZEL}px`,
      `transform:scale(${scale})`,
    ].join(';'),
  );
</script>

<div class="stage" {style} data-fold={phone.fold}>
  <div class="inner" in:fly={{ y: 90, duration: dur(320) }} out:fly={{ y: 90, duration: dur(220) }}>
    <FoldSwitch />

    <div class="body">
      <div class="screen">
        <Screen />
        <div class="dim" style:opacity={dim}></div>

        {#if phone.fold === 'open'}
          <div class="crease v"></div>
        {:else if phone.fold === 'flex'}
          <div class="crease h"></div>
        {:else}
          <div class="hole"></div>
        {/if}
      </div>
    </div>

    {#if phone.fold === 'open'}
      <span class="knuckle top"></span>
      <span class="knuckle bottom"></span>
    {:else if phone.fold === 'flex'}
      <span class="knuckle left"></span>
      <span class="knuckle right"></span>
    {/if}

    <button class="key" onclick={lockPhone} aria-label={t('lock.lockNow')} title={t('lock.lockNow')}></button>
  </div>
</div>

<style>
  .stage {
    position: fixed;
    right: 44px;
    bottom: 30px;
    transform-origin: right bottom;
    transition: width 0.46s var(--ease), height 0.46s var(--ease);
    pointer-events: auto;
  }
  .inner {
    position: absolute;
    inset: 0;
  }
  .body {
    position: absolute;
    inset: 0;
    padding: var(--bezel);
    border-radius: 46px;
    background: linear-gradient(145deg, var(--frame-hi) 0%, var(--frame) 38%, var(--frame-lo) 100%);
    box-shadow:
      0 0 0 1.5px rgba(0, 0, 0, 0.55),
      0 12px 30px rgba(0, 0, 0, 0.45),
      inset 0 0 0 1.5px rgba(255, 255, 255, 0.12);
  }
  .screen {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    border-radius: 36px;
    background: var(--bg);
    color: var(--ink);
    transition: border-radius 0.46s var(--ease);
  }

  .dim {
    position: absolute;
    inset: 0;
    z-index: 60;
    background: #000;
    pointer-events: none;
  }

  /* the crease: a soft shadow where the screen bends */
  .crease {
    position: absolute;
    z-index: 40;
    pointer-events: none;
  }
  .crease.v {
    top: 0;
    bottom: 0;
    left: 50%;
    width: 22px;
    margin-left: -11px;
    background: linear-gradient(
      90deg,
      rgba(0, 0, 0, 0) 0%,
      rgba(0, 0, 0, 0.13) 40%,
      rgba(255, 255, 255, 0.05) 50%,
      rgba(0, 0, 0, 0.1) 60%,
      rgba(0, 0, 0, 0) 100%
    );
  }
  .crease.h {
    left: 0;
    right: 0;
    top: 50%;
    height: 22px;
    margin-top: -11px;
    background: linear-gradient(
      180deg,
      rgba(0, 0, 0, 0) 0%,
      rgba(0, 0, 0, 0.13) 40%,
      rgba(255, 255, 255, 0.05) 50%,
      rgba(0, 0, 0, 0.1) 60%,
      rgba(0, 0, 0, 0) 100%
    );
  }

  /* the camera hole on the cover screen */
  .hole {
    position: absolute;
    top: 14px;
    left: 50%;
    width: 13px;
    height: 13px;
    margin-left: -6.5px;
    border-radius: 50%;
    background: #05050a;
    box-shadow: inset 0 0 0 2px #1a1a24, 0 0 0 1px rgba(255, 255, 255, 0.06);
    z-index: 40;
    pointer-events: none;
  }

  /* hinge knuckles sit on the frame at each end of the crease */
  .knuckle {
    position: absolute;
    border-radius: 6px;
    background: linear-gradient(180deg, var(--frame-hi), var(--frame-lo));
    box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.5);
    pointer-events: none;
  }
  .knuckle.top,
  .knuckle.bottom {
    left: 50%;
    width: 46px;
    height: calc(var(--bezel) + 2px);
    margin-left: -23px;
  }
  .knuckle.top {
    top: -1px;
  }
  .knuckle.bottom {
    bottom: -1px;
  }
  .knuckle.left,
  .knuckle.right {
    top: 50%;
    width: calc(var(--bezel) + 2px);
    height: 46px;
    margin-top: -23px;
  }
  .knuckle.left {
    left: -1px;
  }
  .knuckle.right {
    right: -1px;
  }

  /* the side key locks the phone */
  .key {
    position: absolute;
    right: -4px;
    top: 150px;
    width: 5px;
    height: 70px;
    border-radius: 0 4px 4px 0;
    background: linear-gradient(90deg, var(--frame-lo), var(--frame-hi));
    box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.45);
  }
  .key:hover {
    background: var(--accent);
  }
</style>
