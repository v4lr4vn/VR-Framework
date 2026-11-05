<script>
  import { untrack, onMount } from 'svelte';
  import { api } from '../lib/nui.js';
  import Tabs from '../components/Tabs.svelte';
  import WarrantsView from './records/WarrantsView.svelte';
  import BolosView from './records/BolosView.svelte';

  let { params = {} } = $props();

  let tab = $state(untrack(() => (params.tab === 'bolos' ? 'bolos' : 'warrants')));
  let pending = $state(null);
  let bolos = $state(null);

  onMount(() => {
    api('bolos.list', {}).then((res) => { if (res.ok && bolos === null) bolos = res.data.items.length; });
  });

  const tabs = $derived([
    { id: 'warrants', label: 'Warrants', count: pending || null },
    { id: 'bolos', label: 'BOLOs', count: bolos || null },
  ]);
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Warrants & BOLOs</h1>
      <p class="muted">Arrest warrants need a judge's approval. BOLOs go straight to every officer.</p>
    </div>
  </header>
  <Tabs {tabs} bind:value={tab} />
  <div class="body">
    {#if tab === 'warrants'}
      <WarrantsView focusId={params.tab === 'bolos' ? null : params.id} oncounts={(c) => (pending = c.pending)} />
    {:else}
      <BolosView focusId={params.tab === 'bolos' ? params.id : null} oncount={(n) => (bolos = n)} />
    {/if}
  </div>
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 20px; gap: 14px; }
  h1 { font-size: 24px; font-weight: 700; }
  .body { flex: 1; min-height: 0; display: flex; }
</style>
