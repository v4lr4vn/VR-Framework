<script>
  let { depth = 0, heat = 0, jam = false } = $props();
  const hot = $derived(heat > 70);
  const cold = $derived(heat < 35);
</script>

<div class="drill card" class:jam role="status" aria-label="Drilling">
  <div class="head">
    <span class="t"><i class="fa-solid fa-screwdriver-wrench"></i>Drilling</span>
    <span class="k">{#if jam}<b class="bad">Jammed</b>{:else}Hold <kbd class="key">E</kbd> · <kbd class="key">X</kbd> stop{/if}</span>
  </div>

  <div class="row">
    <span class="label">Depth</span>
    <div class="bar"><span style="width:{Math.min(100, depth)}%"></span></div>
    <span class="v num">{Math.floor(depth)}%</span>
  </div>

  <div class="row">
    <span class="label">Heat</span>
    <div class="heat">
      <span class="zone" style="left:35%;width:35%"></span>
      <span class="needle" class:hot class:cold style="left:{Math.min(100, Math.max(0, heat))}%"></span>
    </div>
    <span class="v num" class:bad={hot || jam}>{Math.floor(heat)}</span>
  </div>

  <p class="hint">{#if jam}Wait for the bit to cool down{:else if hot}Too hot. Let go of E for a moment{:else if cold}Cold bit. Drills slowly{:else}In the sweet spot{/if}</p>
</div>

<style>
  .drill { position: fixed; left: 50%; bottom: 96px; transform: translateX(-50%); width: 380px; padding: 12px 14px; display: flex; flex-direction: column; gap: 10px; }
  .drill.jam { border-color: var(--danger-line); }
  .head { display: flex; justify-content: space-between; align-items: center; }
  .t { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; display: flex; gap: 8px; align-items: center; color: var(--accent-2); }
  .k { font-size: 11px; color: var(--muted); }
  .bad { color: var(--danger-text); }
  .row { display: grid; grid-template-columns: 44px 1fr 38px; align-items: center; gap: 10px; }
  .v { text-align: right; font-size: 12px; }
  .bar { height: 10px; border-radius: 5px; background: var(--line-2); overflow: hidden; }
  .bar > span { display: block; height: 100%; background: var(--accent); transition: width 0.06s linear; }
  .heat { position: relative; height: 10px; border-radius: 5px; background: linear-gradient(90deg, #1b2a40, #2a2a2a 55%, #4a1d1a); overflow: visible; }
  .zone { position: absolute; top: 0; bottom: 0; background: var(--ok-bg); border: 1px solid var(--ok); border-radius: 3px; opacity: 0.85; }
  .needle { position: absolute; top: -4px; width: 4px; height: 18px; margin-left: -2px; border-radius: 2px; background: var(--text); box-shadow: 0 0 6px rgba(0, 0, 0, 0.6); transition: left 0.06s linear; }
  .needle.hot { background: var(--danger); }
  .needle.cold { background: var(--info); }
  .hint { font-size: 11.5px; color: var(--muted); text-align: center; }
</style>
