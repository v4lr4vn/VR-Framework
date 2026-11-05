<script>
  import { em } from '../lib/state.svelte.js';

  const req = $derived(em.request);
</script>

{#if req}
  {#key req.at}
    <div class="req card">
      <div class="ico"><i class="fa-solid fa-user-group"></i></div>
      <div class="txt">
        <div class="who"><b>{req.who || 'Someone'}</b> wants to do <b>{req.label}</b> with you</div>
        <div class="keys"><span><kbd class="key">Y</kbd> accept</span><span><kbd class="key">L</kbd> decline</span></div>
      </div>
      <div class="bar"><div style:animation-duration="{req.seconds}s"></div></div>
    </div>
  {/key}
{/if}

<style>
  .req { position: fixed; top: 4vh; left: 50%; transform: translateX(-50%); z-index: 80; display: flex; align-items: center; gap: 12px; padding: 12px 16px 16px; min-width: 380px; overflow: hidden; border-color: var(--info-line); animation: drop 0.2s var(--ease); }
  @keyframes drop { from { transform: translate(-50%, -12px); opacity: 0; } to { transform: translateX(-50%); opacity: 1; } }
  .ico { width: 38px; height: 38px; border-radius: var(--radius-lg); display: flex; align-items: center; justify-content: center; background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); }
  .txt { display: flex; flex-direction: column; gap: 6px; }
  .who { font-size: 14px; color: var(--text-2); }
  .who b { color: var(--text); }
  .keys { display: flex; gap: 14px; color: var(--muted); font-size: 12px; }
  .bar { position: absolute; left: 0; right: 0; bottom: 0; height: 3px; background: rgba(0, 0, 0, 0.3); }
  .bar div { height: 100%; background: var(--info); transform-origin: left; animation: shrink linear forwards; }
  @keyframes shrink { from { transform: scaleX(1); } to { transform: scaleX(0); } }
</style>
