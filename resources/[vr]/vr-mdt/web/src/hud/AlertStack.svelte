<script>
  import Icon from '../components/Icon.svelte';
  import { onMessage } from '../lib/nui.js';
  import { priorityTone } from '../lib/status.js';

  let alerts = $state([]);
  let respondKey = $state('');

  function remove(id) {
    alerts = alerts.filter((a) => a.id !== id);
  }

  $effect(() => {
    const offAlert = onMessage('alert', (msg) => {
      const call = msg.call;
      if (!call) return;
      respondKey = msg.key || '';
      const seconds = msg.seconds || 8;
      remove(call.id);
      alerts = [{ ...call, street: msg.street || call.street, seconds, shownAt: Date.now() }, ...alerts].slice(0, 4);
      setTimeout(() => remove(call.id), seconds * 1000);
    });
    const offResponded = onMessage('alertResponded', (msg) => {
      alerts = alerts.map((a) => (a.id === msg.id ? { ...a, responded: true } : a));
      setTimeout(() => remove(msg.id), 1500);
    });
    const offClear = onMessage('alertsClear', () => (alerts = []));
    return () => {
      offAlert();
      offResponded();
      offClear();
    };
  });
</script>

<div class="stack" aria-live="assertive">
  {#each alerts as a, i (a.id)}
    {@const tone = priorityTone(a.priority)}
    <article class="alert {tone}" class:latest={i === 0}>
      <div class="row">
        <span class="p mono {tone}">P{a.priority}</span>
        <span class="code mono {tone}">{a.code}</span>
        <span class="title">{a.title}</span>
      </div>
      <span class="street"><Icon name="pin" size={13} /> {a.street || 'Unknown location'}</span>
      {#if a.description}<span class="desc">{a.description}</span>{/if}
      {#if a.info?.length}
        <span class="info">{a.info.slice(0, 3).map((x) => `${x.label}: ${x.value}`).join(' · ')}</span>
      {/if}
      <div class="foot">
        {#if a.responded}
          <span class="ok">Responding</span>
        {:else if i === 0 && respondKey}
          <span class="key"><kbd>{respondKey}</kbd> Respond</span>
        {/if}
        <span class="id mono">#{a.id}</span>
      </div>
      <span class="bar" style:animation-duration="{a.seconds}s"></span>
    </article>
  {/each}
</div>

<style>
  .stack { position: fixed; right: 24px; top: 24vh; width: 340px; display: flex; flex-direction: column; gap: 10px; pointer-events: none; }
  .alert { position: relative; overflow: hidden; display: flex; flex-direction: column; gap: 5px; padding: 12px 14px 14px; border-radius: var(--radius-lg); background: rgba(13, 18, 26, 0.94); border: 1px solid var(--line-2); box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); animation: slide 0.22s ease-out; }
  .alert.latest.p1 { border-color: var(--p1); }
  .alert.latest.p2 { border-color: var(--p2); }
  .alert.latest.p3 { border-color: var(--p3); }
  @keyframes slide { from { transform: translateX(24px); opacity: 0; } to { transform: none; opacity: 1; } }
  .row { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .p { font-size: 12px; font-weight: 600; padding: 1px 6px; border-radius: 4px; color: var(--accent-ink); }
  .p.p1 { background: var(--p1); }
  .p.p2 { background: var(--p2); }
  .p.p3 { background: var(--p3); }
  .code { font-weight: 600; }
  .code.p1 { color: var(--p1-text); }
  .code.p2 { color: var(--p2-text); }
  .code.p3 { color: var(--p3-text); }
  .title { font-weight: 700; font-size: 16px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .street { display: flex; align-items: center; gap: 6px; color: var(--text-2); }
  .desc { color: var(--muted); font-size: 13px; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
  .info { color: var(--muted); font-size: 12px; }
  .foot { display: flex; align-items: center; justify-content: space-between; margin-top: 2px; }
  .key { color: var(--text-2); font-size: 13px; display: flex; align-items: center; gap: 6px; }
  kbd { font-family: var(--mono); font-size: 12px; padding: 1px 7px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--panel-2); color: var(--accent); }
  .ok { color: var(--ok); font-weight: 600; font-size: 13px; }
  .id { color: var(--faint); font-size: 12px; }
  .bar { position: absolute; left: 0; bottom: 0; height: 2px; width: 100%; background: var(--accent); transform-origin: left; animation-name: shrink; animation-timing-function: linear; animation-fill-mode: forwards; }
  .alert.p1 .bar { background: var(--p1); }
  .alert.p3 .bar { background: var(--p3); }
  @keyframes shrink { from { transform: scaleX(1); } to { transform: scaleX(0); } }
</style>
