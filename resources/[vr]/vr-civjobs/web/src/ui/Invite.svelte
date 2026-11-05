<script>
  let { from, label, seconds = 30 } = $props();
</script>

<div class="inv card" role="alert">
  <span class="ic"><i class="fa-solid fa-people-group"></i></span>
  <div class="txt">
    <b>{from}</b> invited you to join their <b>{label}</b> crew
    <div class="keys"><kbd class="key">Y</kbd> Accept <kbd class="key">N</kbd> Decline</div>
  </div>
  <div class="bar"><span style="animation-duration:{seconds}s"></span></div>
</div>

<style>
  .inv { position: fixed; top: 18px; left: 50%; transform: translateX(-50%); width: 400px; padding: 12px 14px 16px; display: grid; grid-template-columns: 38px 1fr; gap: 12px; align-items: center; animation: drop 0.2s var(--ease); overflow: hidden; }
  @keyframes drop { from { transform: translate(-50%, -10px); opacity: 0; } }
  .ic { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); }
  .txt { font-size: 13px; line-height: 1.45; color: var(--text-2); }
  .txt b { color: var(--text); font-weight: 600; }
  .keys { margin-top: 5px; font-size: 12px; color: var(--muted); }
  .bar { position: absolute; left: 0; right: 0; bottom: 0; height: 3px; border-radius: 0; }
  .bar > span { width: 100%; transform-origin: left; animation: drain linear forwards; border-radius: 0; }
  @keyframes drain { from { transform: scaleX(1); } to { transform: scaleX(0); } }
</style>
