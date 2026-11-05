<script>
  import Icon from '../components/Icon.svelte';
  import { session, dispatch, request, upsertUnit } from '../lib/state.svelte.js';
  import { statusTone } from '../lib/status.js';

  let open = $state(false);
  let busy = $state(false);

  const current = $derived(session.statuses.find((s) => s.id === (dispatch.me?.status || 'available')) || session.statuses[0]);

  async function pick(s) {
    open = false;
    if (busy || s.id === current?.id) return;
    busy = true;
    const res = await request('units.status', { status: s.id });
    busy = false;
    if (res.ok) upsertUnit(res.data);
  }

  function outside(e) {
    if (open && !e.target.closest('.status')) open = false;
  }
</script>

<svelte:window onmousedown={outside} />

<div class="status">
  {#if current}
    <button type="button" class="btn {statusTone(current.id)}" aria-haspopup="menu" aria-expanded={open} disabled={busy} onclick={() => (open = !open)}>
      <span class="dot"></span>
      <span class="mono code">{current.code}</span>
      <span>{current.label}</span>
      <Icon name="chevrondown" size={14} />
    </button>
  {/if}
  {#if open}
    <div class="menu" role="menu">
      {#each session.statuses as s}
        <button type="button" role="menuitem" class="opt {statusTone(s.id)}" class:on={s.id === current?.id} onclick={() => pick(s)}>
          <span class="dot"></span>
          <span class="mono code">{s.code}</span>
          <span>{s.label}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .status { position: relative; }
  .btn { display: flex; align-items: center; gap: 8px; height: 34px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); font-weight: 600; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; flex: none; }
  .code { font-size: 12px; opacity: 0.85; }
  .ok { color: var(--ok); }
  .btn.ok { background: var(--ok-bg); border-color: var(--ok-line); }
  .accent { color: var(--accent); }
  .btn.accent { background: var(--accent-soft); border-color: var(--accent-line); }
  .info { color: var(--info); }
  .btn.info { background: var(--info-bg); border-color: var(--info-line); }
  .muted { color: var(--text-2); }
  .menu { position: absolute; right: 0; top: 40px; width: 220px; padding: 6px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--bg-2); box-shadow: var(--shadow); z-index: 40; display: flex; flex-direction: column; gap: 2px; }
  .opt { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 0; background: transparent; text-align: left; }
  .opt span:last-child { color: var(--text); }
  .opt:hover, .opt.on { background: var(--panel-2); }
</style>
