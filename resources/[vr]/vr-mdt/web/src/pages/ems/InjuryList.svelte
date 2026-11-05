<script>
  import Badge from '../../components/Badge.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import { regions, kinds, severities, labelOf, severityTone } from './meta.js';

  let { injuries = [], onremove = null } = $props();
</script>

{#if injuries.length}
  <ul class="list">
    {#each injuries as i, n}
      <li>
        <span class="region">{regions[i.region] || i.region}</span>
        <span class="kind">{labelOf(kinds, i.kind)}</span>
        <Badge tone={severityTone(i.severity)} solid={i.severity === 'critical'}>{labelOf(severities, i.severity)}</Badge>
        {#if onremove}<IconButton icon="x" label="Remove {labelOf(kinds, i.kind).toLowerCase()} on {(regions[i.region] || '').toLowerCase()}" size={26} variant="danger" onclick={() => onremove(n)} />{/if}
      </li>
    {/each}
  </ul>
{:else}
  <p class="none">No injuries recorded.</p>
{/if}

<style>
  .list { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; }
  li { display: flex; align-items: center; gap: 10px; min-height: 34px; border-bottom: 1px solid var(--line); }
  li:last-child { border-bottom: 0; }
  .region { width: 96px; flex: none; font-weight: 600; }
  .kind { flex: 1; color: var(--text-2); }
  .none { color: var(--faint); font-size: 13px; }
</style>
