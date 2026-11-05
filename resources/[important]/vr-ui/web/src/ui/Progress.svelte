<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { plain } from '../lib/md.js';
  import { settings } from '../lib/settings.svelte.js';

  let active = $state(null);
  let pct = $state(0);
  let frame = 0;
  let hideTimer = 0;
  let run = 0;

  const R = 34;
  const C = 2 * Math.PI * R;

  const tick = () => {
    if (!active || active.state !== 'running') return;
    pct = Math.min(100, ((performance.now() - active.start) / active.duration) * 100);
    if (pct < 100) frame = requestAnimationFrame(tick);
  };

  const start = (d) => {
    cancelAnimationFrame(frame);
    clearTimeout(hideTimer);
    pct = 0;
    active = {
      run: ++run,
      kind: d?.kind === 'circle' ? 'circle' : 'bar',
      label: plain(d?.label || ''),
      duration: Math.max(1, Number(d?.duration) || 1),
      position: d?.position === 'middle' ? 'middle' : d?.position === 'bottom' ? 'bottom' : settings.progress.position || 'bottom',
      start: performance.now(),
      state: 'running',
    };
    frame = requestAnimationFrame(tick);
  };

  const stop = (d) => {
    if (!active) return;
    cancelAnimationFrame(frame);
    const mine = active.run;
    if (d?.cancelled) {
      active.state = 'cancelled';
    } else {
      pct = 100;
      active.state = 'done';
    }
    hideTimer = setTimeout(() => {
      if (active && active.run === mine) active = null;
    }, d?.cancelled ? 700 : 260);
  };

  onMount(() => {
    const a = on('progress:start', start);
    const b = on('progress:stop', stop);
    return () => (a(), b());
  });
</script>

{#if active}
  {#key active.run}
    <div class="wrap {active.position}" class:cancelled={active.state === 'cancelled'} class:done={active.state === 'done'}>
      {#if active.kind === 'bar'}
        <div class="bar card">
          <div class="head">
            <span class="label">{active.state === 'cancelled' ? 'Cancelled' : active.label}</span>
            <span class="pct">{Math.floor(pct)}%</span>
          </div>
          <div class="track"><span class="fill" style:transform="scaleX({pct / 100})"></span></div>
        </div>
      {:else}
        <div class="circle">
          <div class="ring">
            <svg viewBox="0 0 80 80" width="84" height="84">
              <circle class="trk" cx="40" cy="40" r={R} />
              <circle class="arc" cx="40" cy="40" r={R} stroke-dasharray={C} stroke-dashoffset={C * (1 - pct / 100)} />
            </svg>
            <span class="num">{Math.floor(pct)}<small>%</small></span>
          </div>
          {#if active.label || active.state === 'cancelled'}
            <span class="clabel card">{active.state === 'cancelled' ? 'Cancelled' : active.label}</span>
          {/if}
        </div>
      {/if}
    </div>
  {/key}
{/if}

<style>
  .wrap { position: fixed; left: 50%; transform: translateX(-50%); z-index: 35; pointer-events: none; animation: rise 0.2s var(--ease); transition: opacity 0.25s; }
  .wrap.bottom { bottom: 9vh; }
  .wrap.middle { top: 50%; transform: translate(-50%, -50%); }
  .wrap.cancelled { animation: shake 0.32s; }
  .wrap.done { opacity: 0; transition-delay: 0.08s; }

  .bar { width: 360px; padding: 11px 14px 13px; display: flex; flex-direction: column; gap: 9px; }
  .head { display: flex; align-items: baseline; gap: 10px; }
  .label { flex: 1; min-width: 0; font-size: 15px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pct { flex: none; font-family: var(--mono); font-size: 13px; font-weight: 600; color: var(--p2-text); }
  .track { height: 6px; border-radius: 6px; background: var(--panel-2); overflow: hidden; }
  .fill { display: block; height: 100%; background: linear-gradient(90deg, var(--accent), var(--accent-2)); transform-origin: left; border-radius: 6px; }
  .cancelled .fill { background: var(--danger); }
  .cancelled .pct, .cancelled .label { color: var(--danger-text); }
  .cancelled.bar, .cancelled .bar { border-color: var(--danger-line); }

  .circle { display: flex; flex-direction: column; align-items: center; gap: 10px; }
  .ring { position: relative; width: 84px; height: 84px; border-radius: 50%; background: var(--card); box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); }
  .ring svg { transform: rotate(-90deg); }
  .trk { fill: none; stroke: var(--panel-2); stroke-width: 5; }
  .arc { fill: none; stroke: var(--accent); stroke-width: 5; stroke-linecap: round; }
  .cancelled .arc { stroke: var(--danger); }
  .num { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-family: var(--mono); font-weight: 600; font-size: 18px; color: var(--text); }
  .num small { font-size: 11px; color: var(--muted); margin-left: 1px; margin-top: 4px; }
  .clabel { padding: 6px 12px; font-size: 14px; font-weight: 600; white-space: nowrap; }
  .cancelled .clabel { color: var(--danger-text); border-color: var(--danger-line); }

  @keyframes rise { from { opacity: 0; translate: 0 6px; } to { opacity: 1; translate: 0 0; } }
  @keyframes shake { 0%, 100% { translate: 0 0; } 25% { translate: -6px 0; } 50% { translate: 6px 0; } 75% { translate: -3px 0; } }
</style>
