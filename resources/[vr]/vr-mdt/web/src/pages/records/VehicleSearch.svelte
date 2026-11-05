<script>
  import SearchPage from './SearchPage.svelte';
  import Badge from '../../components/Badge.svelte';
  import { go } from '../../lib/state.svelte.js';
  import { flagTone } from './shared.js';
</script>

<SearchPage
  title="Vehicles"
  subtitle="Run a plate, or search by make and model."
  placeholder="Plate, make or model"
  action="vehicles.search"
  recentAction="vehicles.recent"
  recentLabel="Flagged vehicles"
  memory="vehicles"
  icon="car"
  startTitle="Run a plate"
  startText="Type at least two characters of a plate, or a make or model."
  emptyTitle="No vehicles found"
  columns="130px minmax(0, 1.4fr) minmax(0, 1.2fr) minmax(0, 1.6fr)"
  key={(v) => v.plate}
  onpick={(v) => go('vehicles', { plate: v.plate })}
>
  {#snippet head()}<span>Plate</span><span>Vehicle</span><span>Registered owner</span><span>Flags</span>{/snippet}
  {#snippet row(v)}
    <span><span class="rec-plate">{v.plate}</span></span>
    <span class="rec-clip">{#if v.unregistered}<span class="faint">Unregistered</span>{:else}<span class="rec-strong">{v.label || v.model}</span>{/if}</span>
    <span class="rec-clip">{v.owner || '—'}</span>
    <span class="rec-chips">{#each v.flags as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}</span>
  {/snippet}
</SearchPage>
