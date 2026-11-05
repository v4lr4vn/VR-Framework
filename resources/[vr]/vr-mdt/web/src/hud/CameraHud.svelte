<script>
  import { onMessage } from '../lib/nui.js';
  import { clock } from '../lib/state.svelte.js';

  let cam = $state(null);

  $effect(() => {
    const off = onMessage('camera', (msg) => {
      cam = msg.show ? { ...(cam || {}), ...msg } : null;
    });
    return off;
  });

  const pad = (n) => String(n ?? 0).padStart(2, '0');
  const at = $derived(new Date(clock.now * 1000));
  const stamp = $derived(`${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`);
  const time = $derived(`${pad(at.getHours())}:${pad(at.getMinutes())}:${pad(at.getSeconds())}`);
  const body = $derived(cam?.mode === 'bodycam');
  const camId = $derived(typeof cam?.id === 'number' ? `CAM ${String(cam.id).padStart(3, '0')}` : 'CAM');
</script>

{#if cam}
  <div class="hud" class:body role="status" aria-label={body ? `Watching the bodycam of ${cam.label}` : `Watching camera ${cam.label}`}>
    <div class="scan" aria-hidden="true"></div>
    <div class="vignette" aria-hidden="true"></div>
    <span class="corner tl" aria-hidden="true"></span>
    <span class="corner tr" aria-hidden="true"></span>
    <span class="corner bl" aria-hidden="true"></span>
    <span class="corner br" aria-hidden="true"></span>

    <header class="top">
      <div class="who">
        <div class="tagline mono">
          <span class="rec"><span class="dot"></span>REC</span>
          <span class="tag">{body ? 'BODYCAM' : camId}</span>
          {#if body}
            <span class="sig" class:weak={!cam.live}>{cam.live ? 'LIVE' : 'SIGNAL WEAK'}</span>
          {/if}
        </div>
        <h1 class:mono={body}>{cam.label || 'Unknown'}</h1>
        {#if cam.location}<p>{cam.location}</p>{/if}
      </div>
      <div class="when mono">
        <span class="date">{stamp}</span>
        <span class="clock">{time}</span>
      </div>
    </header>

    {#if !body}<span class="reticle" aria-hidden="true"></span>{/if}

    {#if cam.busy}<div class="switching mono">SWITCHING FEED</div>{/if}

    <footer class="bottom">
      <div class="meta mono">
        {#if body}
          <span>BODY-WORN CAMERA</span>
          <span class="sep">/</span>
          <span>{cam.location || ''}</span>
        {:else}
          <span>{pad(cam.index)} / {pad(cam.count)}</span>
          <span class="sep">/</span>
          <span>ZOOM {Number(cam.zoom || 1).toFixed(1)}x</span>
        {/if}
      </div>
      <div class="keys">
        {#if !body}
          <span class="hint"><kbd>Mouse</kbd><kbd>Arrows</kbd> Look</span>
          <span class="hint"><kbd>Scroll</kbd><kbd>Q</kbd><kbd>E</kbd> Zoom</span>
          {#if cam.count > 1}<span class="hint"><kbd>A</kbd><kbd>D</kbd> Switch camera</span>{/if}
        {/if}
        <span class="hint"><kbd>Backspace</kbd> Exit</span>
      </div>
    </footer>
  </div>
{/if}

<style>
  .hud { position: fixed; inset: 0; pointer-events: none; color: var(--text); text-shadow: 0 1px 2px rgba(0, 0, 0, 0.85); z-index: 5; }
  .scan { position: absolute; inset: 0; background: repeating-linear-gradient(to bottom, rgba(255, 255, 255, 0) 0, rgba(255, 255, 255, 0) 2px, rgba(255, 255, 255, 0.035) 2px, rgba(255, 255, 255, 0.035) 3px); }
  .vignette { position: absolute; inset: 0; background: radial-gradient(ellipse at center, rgba(0, 0, 0, 0) 58%, rgba(0, 0, 0, 0.5) 100%); }
  .body .vignette { background: radial-gradient(circle at center, rgba(0, 0, 0, 0) 46%, rgba(0, 0, 0, 0.72) 100%); }
  .corner { position: absolute; width: 34px; height: 34px; border: 2px solid rgba(230, 237, 245, 0.72); }
  .tl { top: 28px; left: 28px; border-right: 0; border-bottom: 0; }
  .tr { top: 28px; right: 28px; border-left: 0; border-bottom: 0; }
  .bl { bottom: 28px; left: 28px; border-right: 0; border-top: 0; }
  .br { bottom: 28px; right: 28px; border-left: 0; border-top: 0; }
  .top { position: absolute; top: 48px; left: 56px; right: 56px; display: flex; justify-content: space-between; align-items: flex-start; gap: 24px; }
  .who { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  .tagline { display: flex; align-items: center; gap: 10px; font-size: 13px; letter-spacing: 0.08em; }
  .rec { display: inline-flex; align-items: center; gap: 6px; color: var(--p1-text); font-weight: 600; }
  .dot { width: 10px; height: 10px; border-radius: 50%; background: var(--p1); box-shadow: 0 0 8px rgba(255, 90, 82, 0.8); animation: blink 1.2s steps(2, start) infinite; }
  .tag { padding: 1px 7px; border-radius: 4px; background: rgba(10, 14, 20, 0.72); border: 1px solid rgba(43, 58, 80, 0.9); }
  .sig { padding: 1px 7px; border-radius: 4px; background: rgba(15, 42, 30, 0.85); color: var(--ok); border: 1px solid var(--ok-line); }
  .sig.weak { background: rgba(42, 18, 20, 0.85); color: var(--danger-text); border-color: var(--danger-line); }
  h1 { font-size: 24px; font-weight: 700; letter-spacing: 0.01em; max-width: 720px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  h1.mono { letter-spacing: 0.04em; }
  p { color: var(--text-2); font-size: 15px; }
  .when { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; }
  .date { color: var(--text-2); font-size: 13px; letter-spacing: 0.08em; }
  .clock { font-size: 26px; font-weight: 500; letter-spacing: 0.04em; }
  .reticle { position: absolute; left: 50%; top: 50%; width: 34px; height: 34px; transform: translate(-50%, -50%); background: linear-gradient(rgba(230, 237, 245, 0.55), rgba(230, 237, 245, 0.55)) center / 1px 100% no-repeat, linear-gradient(rgba(230, 237, 245, 0.55), rgba(230, 237, 245, 0.55)) center / 100% 1px no-repeat; }
  .switching { position: absolute; left: 50%; top: 50%; transform: translate(-50%, 34px); padding: 4px 12px; border-radius: 4px; background: rgba(10, 14, 20, 0.8); border: 1px solid var(--accent-line); color: var(--accent); font-size: 13px; letter-spacing: 0.12em; }
  .bottom { position: absolute; left: 56px; right: 56px; bottom: 48px; display: flex; justify-content: space-between; align-items: flex-end; gap: 24px; }
  .meta { display: flex; gap: 10px; font-size: 14px; letter-spacing: 0.08em; color: var(--text-2); }
  .sep { color: var(--faint); }
  .keys { display: flex; gap: 14px; flex-wrap: wrap; justify-content: flex-end; }
  .hint { display: inline-flex; align-items: center; gap: 5px; padding: 5px 10px; border-radius: var(--radius); background: rgba(10, 14, 20, 0.72); border: 1px solid rgba(43, 58, 80, 0.9); color: var(--text-2); font-size: 13px; text-shadow: none; }
  kbd { font-family: var(--mono); font-size: 12px; padding: 0 6px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--panel-2); color: var(--accent); }
  @keyframes blink { to { visibility: hidden; } }
</style>
