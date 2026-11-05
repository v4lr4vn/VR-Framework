<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';

  let game = $state(null);
  let angle = $state(0);
  let state = $state('idle');
  let frame = 0;
  let last = 0;

  const R = 46;
  const C = 2 * Math.PI * R;
  const BASE = 225;

  const arc = (size) => `${(size / 360) * C} ${C}`;

  const finish = (success) => {
    if (!game || state !== 'running') return;
    cancelAnimationFrame(frame);
    state = success ? 'hit' : 'miss';
    const id = game.id;
    setTimeout(() => post('skill:result', { id, success }), success ? 160 : 260);
  };

  const loop = (t) => {
    if (!game || state !== 'running') return;
    const dt = last ? (t - last) / 1000 : 0;
    last = t;
    angle = Math.min(360, angle + BASE * game.speed * dt);
    if (angle > game.start + game.size + 2) return finish(false);
    frame = requestAnimationFrame(loop);
  };

  const begin = (d) => {
    cancelAnimationFrame(frame);
    const size = Math.max(6, Math.min(180, Number(d?.difficulty?.areaSize) || 50));
    const speed = Math.max(0.2, Math.min(5, Number(d?.difficulty?.speedMultiplier) || 1));
    const lo = 110;
    const hi = 360 - size - 14;
    game = {
      id: d?.id,
      key: String(d?.key || 'e').toLowerCase(),
      keys: (d?.inputs || [d?.key || 'e']).map((k) => String(k).toLowerCase()),
      size,
      speed,
      start: lo + Math.random() * Math.max(0, hi - lo),
      round: Number(d?.round) || 1,
      total: Number(d?.total) || 1,
    };
    angle = 0;
    last = 0;
    state = 'running';
    frame = requestAnimationFrame(loop);
  };

  const onKey = (e) => {
    if (!game || state !== 'running') return;
    const k = e.key.toLowerCase();
    if (k === game.key) {
      e.preventDefault();
      finish(angle >= game.start && angle <= game.start + game.size);
    } else if (game.keys.includes(k)) {
      e.preventDefault();
      finish(false);
    }
  };

  onMount(() => {
    const a = on('skill:start', begin);
    const b = on('skill:stop', () => {
      cancelAnimationFrame(frame);
      game = null;
      state = 'idle';
    });
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if game}
  <div class="sc {state}">
    <div class="ring">
      <svg viewBox="0 0 120 120" width="132" height="132">
        <circle class="trk" cx="60" cy="60" r={R} />
        <circle class="zone" cx="60" cy="60" r={R} stroke-dasharray={arc(game.size)} transform="rotate({game.start - 90} 60 60)" />
        <g transform="rotate({angle} 60 60)">
          <line class="needle" x1="60" y1={60 - R - 7} x2="60" y2={60 - R + 7} />
        </g>
      </svg>
      <span class="key">{game.key.toUpperCase()}</span>
    </div>
    {#if game.total > 1}
      <div class="dots">
        {#each Array(game.total) as _, i}
          <span class:done={i < game.round - 1} class:cur={i === game.round - 1}></span>
        {/each}
      </div>
    {/if}
  </div>
{/if}

<style>
  .sc { position: fixed; left: 50%; top: 60%; transform: translate(-50%, -50%); z-index: 55; display: flex; flex-direction: column; align-items: center; gap: 12px; pointer-events: none; animation: pop 0.16s var(--ease); }
  .ring { position: relative; width: 132px; height: 132px; border-radius: 50%; background: radial-gradient(circle, rgba(13, 18, 26, 0.94) 58%, transparent 60%); filter: drop-shadow(0 10px 24px rgba(0, 0, 0, 0.5)); }
  .trk { fill: none; stroke: var(--panel-2); stroke-width: 9; }
  .zone { fill: none; stroke: var(--accent); stroke-width: 9; transition: stroke 0.1s; }
  .needle { stroke: var(--text); stroke-width: 3.5; stroke-linecap: round; }
  .key {
    position: absolute; inset: 0; margin: auto; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center;
    border-radius: 8px; border: 1px solid var(--line-3); border-bottom-width: 3px; background: var(--panel-2);
    font-family: var(--mono); font-size: 22px; font-weight: 600; color: var(--accent-2);
  }
  .hit .zone { stroke: var(--ok); }
  .hit .key { color: var(--ok); border-color: var(--ok-line); }
  .miss .zone { stroke: var(--danger); }
  .miss .key { color: var(--danger-text); border-color: var(--danger-line); }
  .miss .ring { animation: shake 0.26s; }
  .dots { display: flex; gap: 6px; padding: 5px 8px; border-radius: 10px; background: var(--card); border: 1px solid var(--line-2); }
  .dots span { width: 8px; height: 8px; border-radius: 50%; background: var(--panel-3); }
  .dots span.done { background: var(--ok); }
  .dots span.cur { background: var(--accent); }
  @keyframes pop { from { opacity: 0; scale: 0.92; } to { opacity: 1; scale: 1; } }
  @keyframes shake { 0%, 100% { translate: 0 0; } 25% { translate: -6px 0; } 50% { translate: 6px 0; } 75% { translate: -3px 0; } }
</style>
