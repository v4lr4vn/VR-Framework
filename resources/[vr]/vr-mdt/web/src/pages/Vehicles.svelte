<script>
  import VehicleSearch from './records/VehicleSearch.svelte';
  import VehicleProfile from './records/VehicleProfile.svelte';

  let { params = {} } = $props();
  const plate = $derived(typeof params.plate === 'string' ? params.plate : typeof params.id === 'string' ? params.id : null);
</script>

{#if plate}
  {#key plate}<VehicleProfile {plate} />{/key}
{:else}
  <VehicleSearch />
{/if}
