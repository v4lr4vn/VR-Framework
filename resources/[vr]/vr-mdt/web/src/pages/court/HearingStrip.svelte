<script>
  import Icon from '../../components/Icon.svelte';
  import { go } from '../../lib/state.svelte.js';
  import { hearingParts } from './meta.js';

  let { hearings = [], days = 14, loading = false } = $props();
</script>

<section class="strip" aria-label="Upcoming hearings">
  <div class="label">
    <span class="eyebrow">Upcoming hearings</span>
    <span class="count mono">{hearings.length}</span>
    <span class="sub">next {days} days</span>
  </div>
  <div class="list scroll-x">
    {#if loading}
      <span class="none">Loading the court calendar…</span>
    {:else}
      {#each hearings as h (h.id)}
        {@const p = hearingParts(h.hearingAt)}
        <button type="button" class="h" class:live={h.status === 'in_session'} class:mine={h.mine} onclick={() => go('court', { id: h.id })}>
          <span class="when">
            <span class="d mono">{h.status === 'in_session' ? 'NOW' : p.day}</span>
            <span class="t mono">{p.time}</span>
          </span>
          <span class="info">
            <span class="top"><span class="num mono">{h.number}</span>{#if h.mine}<span class="you">You</span>{/if}</span>
            <span class="title">{h.title}</span>
            <span class="room"><Icon name="court" size={12} /> {h.courtroom}{' · '}{p.rel || p.date}</span>
          </span>
        </button>
      {:else}
        <span class="none">No hearings in the next {days} days.</span>
      {/each}
    {/if}
  </div>
</section>

<style>
  .strip { display: flex; align-items: stretch; gap: 14px; padding: 12px 14px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--bg-2); }
  .label { width: 112px; flex: none; display: flex; flex-direction: column; justify-content: center; gap: 2px; }
  .count { font-size: 22px; font-weight: 600; color: var(--info-text); }
  .sub { color: var(--faint); font-size: 12px; }
  .list { flex: 1; min-width: 0; display: flex; gap: 8px; overflow-x: auto; scrollbar-width: thin; scrollbar-color: var(--line-3) transparent; padding-bottom: 2px; }
  .h { display: flex; gap: 10px; align-items: stretch; width: 248px; flex: none; padding: 8px 10px 8px 8px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); text-align: left; }
  .h:hover { border-color: var(--line-3); background: var(--panel-2); }
  .h.mine { border-color: var(--doj-bg); }
  .when { width: 52px; flex: none; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; border-radius: 4px; background: var(--info-bg); }
  .d { font-size: 11px; font-weight: 600; color: var(--info-text); letter-spacing: 0.06em; }
  .t { font-size: 14px; font-weight: 600; }
  .live .when { background: var(--accent-soft); }
  .live .d { color: var(--accent); }
  .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
  .top { display: flex; align-items: center; gap: 6px; }
  .num { font-size: 11px; color: var(--doj-text); }
  .you { font-size: 10px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; color: var(--doj-text); background: var(--doj-bg); padding: 0 5px; border-radius: 3px; }
  .title { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .room { display: flex; align-items: center; gap: 5px; color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .none { align-self: center; color: var(--faint); font-size: 13px; }
</style>
