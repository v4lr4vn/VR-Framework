<script>
  let { label, ms } = $props();
</script>

<div class="prog card" role="progressbar" aria-label={label}>
  <div class="row"><span class="t">{label}</span><span class="x"><kbd class="key">X</kbd> cancel</span></div>
  <div class="bar"><span style="animation-duration:{ms}ms"></span></div>
</div>

<style>
  .prog { position: fixed; left: 50%; bottom: 96px; transform: translateX(-50%); width: 340px; padding: 11px 14px; display: flex; flex-direction: column; gap: 8px; }
  .row { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
  .t { font-size: 13px; font-weight: 600; }
  .x { font-size: 11px; color: var(--muted); }
  .bar { height: 8px; }
  .bar > span { width: 100%; transform-origin: left; animation: fill linear forwards; }
  @keyframes fill { from { transform: scaleX(0); } to { transform: scaleX(1); } }
</style>
