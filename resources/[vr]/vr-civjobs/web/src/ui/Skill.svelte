<script>
  let { label = 'Reel it in', zone = 0.22, speed = 1, rounds = 1, ondone } = $props();

  let round = $state(1);
  let pos = $state(0);
  let center = $state(0.5);
  let state = $state('run');
  let t0 = 0;
  let raf = 0;
  let timer;
  let finished = false;

  const draw = () => 0.2 + Math.random() * 0.6;

  function tick(now) {
    if (state !== 'run') return;
    const period = 1600 / Math.max(0.4, speed);
    const phase = ((now - t0) % period) / period;
    pos = phase < 0.5 ? phase * 2 : 2 - phase * 2;
    raf = requestAnimationFrame(tick);
  }

  function begin() {
    center = draw();
    state = 'run';
    t0 = performance.now();
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(tick);
    clearTimeout(timer);
    timer = setTimeout(() => settle(false), 8000);
  }

  function settle(ok) {
    if (finished || state !== 'run') return;
    clearTimeout(timer);
    cancelAnimationFrame(raf);
    if (ok && round < rounds) {
      state = 'hit';
      setTimeout(() => {
        round += 1;
        begin();
      }, 450);
      return;
    }
    state = ok ? 'win' : 'miss';
    finished = true;
    setTimeout(() => ondone?.(ok), 650);
  }

  function press() {
    if (state !== 'run') return;
    settle(Math.abs(pos - center) <= zone / 2);
  }

  $effect(() => {
    begin();
    const k = (e) => {
      if (e.code === 'KeyE' || e.code === 'Space' || e.code === 'Enter') {
        e.preventDefault();
        press();
      }
    };
    window.addEventListener('keydown', k);
    return () => {
      window.removeEventListener('keydown', k);
      clearTimeout(timer);
      cancelAnimationFrame(raf);
    };
  });
</script>

<div class="skill card" class:win={state === 'win' || state === 'hit'} class:miss={state === 'miss'}>
  <div class="row">
    <span class="t">{label}</span>
    {#if rounds > 1}<span class="r num">{round} / {rounds}</span>{/if}
  </div>
  <div class="track">
    <span class="zone" style="left:{(center - zone / 2) * 100}%; width:{zone * 100}%"></span>
    <span class="cursor" style="left:{pos * 100}%"></span>
  </div>
  <div class="hint"><kbd class="key">E</kbd> when the marker is in the amber zone</div>
</div>

<style>
  .skill { position: fixed; left: 50%; bottom: 150px; transform: translateX(-50%); width: 380px; padding: 14px 16px; display: flex; flex-direction: column; gap: 10px; animation: rise 0.18s var(--ease); }
  @keyframes rise { from { transform: translate(-50%, 8px); opacity: 0; } }
  .row { display: flex; justify-content: space-between; align-items: center; }
  .t { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-2); }
  .r { color: var(--accent-2); font-size: 12px; }
  .track { position: relative; height: 16px; border-radius: 8px; background: var(--bg); border: 1px solid var(--line-3); overflow: hidden; }
  .zone { position: absolute; top: 0; bottom: 0; background: var(--accent-soft); border-left: 2px solid var(--accent); border-right: 2px solid var(--accent); }
  .cursor { position: absolute; top: -1px; bottom: -1px; width: 4px; margin-left: -2px; background: var(--text); border-radius: 2px; box-shadow: 0 0 8px rgba(230, 237, 245, 0.7); }
  .hint { text-align: center; font-size: 12px; color: var(--muted); }
  .win { border-color: var(--ok-line); }
  .win .zone { background: var(--ok-bg); border-color: var(--ok); }
  .miss { border-color: var(--danger-line); }
  .miss .zone { background: var(--danger-bg); border-color: var(--danger); }
</style>
