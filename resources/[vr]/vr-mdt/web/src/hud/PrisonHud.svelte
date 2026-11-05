<script>
  import Icon from '../components/Icon.svelte';
  import { onMessage } from '../lib/nui.js';

  let active = $state(false);
  let endsAt = $state(0);
  let total = $state(0);
  let months = $state(0);
  let reason = $state('');
  let now = $state(Date.now());

  $effect(() => {
    const off = onMessage('prison', (msg) => {
      active = msg.active === true;
      if (!active) return;
      const seconds = Math.max(0, Number(msg.seconds) || 0);
      endsAt = Date.now() + seconds * 1000;
      months = Number(msg.months) || 0;
      total = Math.max(seconds, months * (Number(msg.perMonth) || 60));
      reason = typeof msg.reason === 'string' ? msg.reason : '';
      now = Date.now();
    });
    return off;
  });

  $effect(() => {
    if (!active) return;
    const t = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(t);
  });

  const left = $derived(Math.max(0, Math.ceil((endsAt - now) / 1000)));
  const pct = $derived(total > 0 ? Math.min(100, Math.max(0, 100 - (left / total) * 100)) : 0);
  const monthsLeft = $derived(total > 0 && months > 0 ? Math.max(0, Math.ceil((left / total) * months)) : 0);

  function text(s) {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const r = s % 60;
    const mm = String(m).padStart(2, '0');
    const ss = String(r).padStart(2, '0');
    return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
  }
</script>

{#if active}
  <aside class="hud" aria-live="polite" aria-label="Prison sentence">
    <span class="ico"><Icon name="lock" size={18} /></span>
    <div class="main">
      <span class="eyebrow">Bolingbroke Penitentiary</span>
      <div class="row">
        <span class="time mono">{text(left)}</span>
        <span class="left">{left > 0 ? 'left' : 'Release pending'}</span>
        {#if months}<span class="months mono">{monthsLeft}/{months} mo</span>{/if}
      </div>
      {#if reason}<span class="reason">{reason}</span>{/if}
    </div>
    <span class="bar" aria-hidden="true"><span class="fill" style:width="{pct}%"></span></span>
  </aside>
{/if}

<style>
  .hud { position: fixed; top: 22px; left: 50%; transform: translateX(-50%); width: 380px; display: flex; gap: 12px; align-items: center; padding: 12px 16px 16px 12px; border-radius: var(--radius-lg); background: rgba(13, 18, 26, 0.94); border: 1px solid var(--accent-line); box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); overflow: hidden; pointer-events: none; animation: drop 0.25s ease-out; }
  @keyframes drop { from { transform: translate(-50%, -10px); opacity: 0; } to { transform: translateX(-50%); opacity: 1; } }
  .ico { width: 40px; height: 40px; border-radius: var(--radius); background: var(--accent-soft); color: var(--accent); display: flex; align-items: center; justify-content: center; flex: none; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .row { display: flex; align-items: baseline; gap: 8px; }
  .time { font-size: 26px; font-weight: 600; color: var(--text); line-height: 1.1; }
  .left { color: var(--muted); font-size: 13px; }
  .months { margin-left: auto; color: var(--p2-text); font-size: 13px; }
  .reason { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bar { position: absolute; left: 0; right: 0; bottom: 0; height: 3px; background: var(--panel-2); }
  .fill { display: block; height: 100%; background: var(--accent); transition: width 1s linear; }
</style>
