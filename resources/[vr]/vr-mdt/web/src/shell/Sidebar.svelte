<script>
  import Icon from '../components/Icon.svelte';
  import { groups, groupOf } from '../routes.js';
  import { ui, session, go, dispatch } from '../lib/state.svelte.js';
  import { badges } from '../lib/badges.svelte.js';

  let { routes = [] } = $props();

  const sections = $derived.by(() => {
    const dept = session.dept?.id;
    return (groups[dept] || []).map((g) => ({ name: g, items: routes.filter((r) => groupOf(r, dept) === g) })).filter((s) => s.items.length);
  });

  function count(id) {
    if (id === 'dispatch') return dispatch.calls.length || null;
    return badges[id] || null;
  }
</script>

<nav class="side scroll" aria-label="Sections">
  {#each sections as s}
    <span class="eyebrow group">{s.name}</span>
    {#each s.items as r}
      {@const n = count(r.id)}
      <button type="button" class="item" class:on={ui.route.page === r.id} aria-current={ui.route.page === r.id ? 'page' : undefined} onclick={() => go(r.id)}>
        <Icon name={r.icon} size={16} />
        <span class="label">{r.label}</span>
        {#if n}<span class="n mono" class:hot={r.id === 'dispatch'}>{n}</span>{/if}
      </button>
    {/each}
  {/each}
</nav>

<style>
  .side { width: 200px; flex: none; display: flex; flex-direction: column; gap: 2px; padding: 12px 10px; border-right: 1px solid var(--line); background: var(--bg-2); }
  .group { padding: 14px 10px 6px; }
  .group:first-child { padding-top: 4px; }
  .item { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 0; background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .item:hover { background: var(--panel); color: var(--text); }
  .on, .on:hover { background: var(--panel-2); color: var(--accent); font-weight: 600; }
  .label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .n { font-size: 12px; color: var(--p1-text); }
  .hot { background: var(--accent); color: var(--accent-ink); border-radius: 4px; padding: 0 6px; font-weight: 600; }
</style>
