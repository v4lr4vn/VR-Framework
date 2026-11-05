<script>
  import Badge from '../../components/Badge.svelte';
  import { ago } from '../../lib/format.js';
  import { priorityTone } from '../../lib/status.js';
  import { streetOf } from '../../lib/state.svelte.js';

  let { call, selected = false, mine = false, showDepts = false, onselect } = $props();
  const tone = $derived(priorityTone(call.priority));
  const closed = $derived(call.status === 'closed');
</script>

<button type="button" class="card {tone}" class:selected class:closed onclick={() => onselect?.(call)} aria-pressed={selected}>
  <div class="row">
    <Badge tone={tone} solid={!closed} mono>P{call.priority}</Badge>
    <span class="code mono {tone}">{call.code}</span>
    <span class="title">{call.title}</span>
    <span class="age mono">{ago(call.createdAt)}</span>
  </div>
  {#if showDepts}
    <div class="depts">
      {#if call.jobs.includes('leo')}<span class="dt mono police">POLICE</span>{/if}
      {#if call.jobs.includes('ems')}<span class="dt mono ems">EMS</span>{/if}
    </div>
  {/if}
  <span class="street">{streetOf(call)}</span>
  {#if call.caller?.name || call.caller?.anonymous}
    <span class="caller">{call.caller.anonymous ? 'Anonymous caller' : call.caller.name}{call.description ? ` · "${call.description}"` : ''}</span>
  {:else if call.description}
    <span class="caller">{call.description}</span>
  {/if}
  {#if call.units.length}
    <div class="units">
      {#each call.units.slice(0, 4) as u}
        <span class="unit mono" class:ems={u.dept === 'ems'} class:me={mine && u.me}>{u.callsign || u.name}</span>
      {/each}
      {#if call.units.length > 4}<span class="unit mono">+{call.units.length - 4}</span>{/if}
    </div>
  {:else if !closed}
    <span class="none">No units yet</span>
  {/if}
</button>

<style>
  .depts { display: flex; gap: 6px; }
  .dt { font-size: 10px; letter-spacing: 0.1em; padding: 1px 6px; border-radius: 4px; font-weight: 600; }
  .dt.police { background: var(--info-bg); color: var(--info-text); }
  .dt.ems { background: var(--ems-bg); color: var(--ems-text); }
  .card { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: var(--text); width: 100%; flex: none; }
  .card:hover { border-color: var(--line-3); background: #141c29; }
  .selected, .selected:hover { background: var(--panel-2); }
  .selected.p1 { border-color: var(--p1); }
  .selected.p2 { border-color: var(--p2); }
  .selected.p3 { border-color: var(--p3); }
  .closed { opacity: 0.7; }
  .row { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .code { font-weight: 600; flex: none; }
  .code.p1 { color: var(--p1-text); }
  .code.p2 { color: var(--p2-text); }
  .code.p3 { color: var(--p3-text); }
  .title { font-weight: 600; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; min-width: 0; }
  .age { color: var(--muted); font-size: 12px; flex: none; }
  .street { color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .caller { color: var(--muted); font-size: 13px; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
  .units { display: flex; flex-wrap: wrap; gap: 6px; }
  .unit { font-size: 12px; padding: 1px 6px; border-radius: 4px; background: var(--panel-3); color: var(--p3-text); }
  .unit.ems { background: var(--ems-bg); color: var(--ems-text); }
  .none { font-size: 13px; color: var(--p1-text); }
</style>
