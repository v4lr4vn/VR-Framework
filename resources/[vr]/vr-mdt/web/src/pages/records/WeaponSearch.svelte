<script>
  import SearchPage from './SearchPage.svelte';
  import RegisterWeaponModal from './RegisterWeaponModal.svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import { go, can } from '../../lib/state.svelte.js';
  import { date } from '../../lib/format.js';
  import { flagTone } from './shared.js';

  let registering = $state(false);
</script>

<SearchPage
  title="Weapons"
  subtitle="Look up a serial number, owner or weapon type."
  placeholder="Serial, owner or weapon"
  action="weapons.search"
  recentAction="weapons.recent"
  recentLabel="Recently registered"
  memory="weapons"
  icon="crosshair"
  startTitle="Trace a weapon"
  startText="Type at least two characters of a serial number, an owner's name or a weapon type."
  emptyTitle="No weapons found"
  columns="200px minmax(0, 1.2fr) minmax(0, 1.2fr) 120px minmax(0, 1.2fr)"
  key={(w) => w.serial}
  onpick={(w) => go('weapons', { serial: w.serial })}
>
  {#snippet actions()}
    {#if can('records.edit')}<Button icon="plus" onclick={() => (registering = true)}>Register weapon</Button>{/if}
  {/snippet}
  {#snippet head()}<span>Serial</span><span>Weapon</span><span>Owner</span><span>Registered</span><span>Flags</span>{/snippet}
  {#snippet row(w)}
    <span class="mono rec-strong rec-clip">{w.serial}</span>
    <span class="rec-clip">{w.label}</span>
    <span class="rec-clip">{#if w.owner}{w.owner}{:else}<span class="faint">Unknown</span>{/if}</span>
    <span class="mono">{date(w.registeredAt)}</span>
    <span class="rec-chips">{#each w.flags as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}</span>
  {/snippet}
</SearchPage>

<RegisterWeaponModal bind:open={registering} oncreated={(w) => go('weapons', { serial: w.serial })} />
