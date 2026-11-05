<script>
  import { dispatch, session, go } from '../../lib/state.svelte.js';
  import { statusTone } from '../../lib/status.js';
</script>

<div class="strip">
  <button type="button" class="eyebrow link" onclick={() => go('units')}>On duty · {dispatch.units.length}</button>
  <div class="chips">
    {#each dispatch.units as u (u.cid)}
      <span class="chip mono {u.dept === 'ems' ? 'ems' : statusTone(u.status)}" class:me={u.cid === session.me?.cid} title="{u.name} · {session.statuses.find((s) => s.id === u.status)?.label || u.status}">{u.callsign || u.name}</span>
    {/each}
  </div>
</div>

<style>
  .strip { border-top: 1px solid var(--line); padding: 10px 14px 12px; display: flex; flex-direction: column; gap: 8px; max-height: 150px; }
  .link { border: 0; background: transparent; padding: 0; text-align: left; cursor: pointer; }
  .link:hover { color: var(--text); }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; overflow: hidden; }
  .chip { font-size: 12px; padding: 2px 6px; border-radius: 4px; border: 1px solid; }
  .ok { border-color: var(--ok-line); color: var(--ok); }
  .accent { border-color: var(--accent-line); color: var(--accent); }
  .info { border-color: var(--info-line); color: var(--info); }
  .muted { border-color: var(--line-3); color: var(--muted); }
  .ems { border-color: #5B2A3A; color: var(--ems); }
  .me { background: var(--panel-2); }
</style>
