<script>
  import WeaponSearch from './records/WeaponSearch.svelte';
  import WeaponProfile from './records/WeaponProfile.svelte';

  let { params = {} } = $props();
  const serial = $derived(typeof params.serial === 'string' ? params.serial : typeof params.id === 'string' ? params.id : null);
</script>

{#if serial}
  {#key serial}<WeaponProfile {serial} />{/key}
{:else}
  <WeaponSearch />
{/if}
