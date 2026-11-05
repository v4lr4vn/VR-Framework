<script>
  import CitizenSearch from './records/CitizenSearch.svelte';
  import CitizenProfile from './records/CitizenProfile.svelte';

  let { params = {} } = $props();
  const cid = $derived(typeof params.cid === 'string' ? params.cid : typeof params.id === 'string' ? params.id : null);
</script>

{#if cid}
  {#key cid}<CitizenProfile {cid} />{/key}
{:else}
  <CitizenSearch />
{/if}
