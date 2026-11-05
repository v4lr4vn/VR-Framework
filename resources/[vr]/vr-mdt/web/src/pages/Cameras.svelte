<script>
  import Button from '../components/Button.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Tabs from '../components/Tabs.svelte';
  import CctvTab from './cameras/CctvTab.svelte';
  import BodycamTab from './cameras/BodycamTab.svelte';
  import AddCameraModal from './cameras/AddCameraModal.svelte';
  import { api, on } from '../lib/nui.js';
  import { can, dispatch, loadDispatch } from '../lib/state.svelte.js';

  let { params = {} } = $props();

  const cctv = $derived(can('cameras.view'));
  const bodycams = $derived(can('bodycams.view'));
  const manage = $derived(can('cameras.manage'));

  let tab = $state('cctv');
  let filter = $state('');
  let cameras = $state(null);
  let limits = $state(null);
  let camError = $state('');
  let officers = $state(null);
  let bodyError = $state('');
  let adding = $state(false);

  $effect(() => {
    if ((params.tab === 'bodycams' || !cctv) && bodycams) tab = 'bodycams';
  });

  async function loadCameras() {
    const res = await api('cameras.list', {});
    if (res.ok) {
      cameras = res.data.cameras;
      limits = res.data.limits;
      camError = '';
    } else {
      camError = res.error;
    }
  }

  async function loadOfficers() {
    const res = await api('bodycams.list', {});
    if (res.ok) {
      officers = res.data;
      bodyError = '';
    } else {
      bodyError = res.error;
    }
  }

  $effect(() => {
    if (cctv) loadCameras();
    if (bodycams) loadOfficers();
    if (!dispatch.loaded) loadDispatch();
  });

  $effect(() => on('cameras:changed', () => { if (cctv) loadCameras(); }));

  $effect(() => {
    if (tab !== 'bodycams' || !bodycams) return;
    const t = setInterval(loadOfficers, 10000);
    return () => clearInterval(t);
  });

  const tabs = $derived([
    ...(cctv ? [{ id: 'cctv', label: 'Security cameras', count: cameras?.length }] : []),
    ...(bodycams ? [{ id: 'bodycams', label: 'Bodycams', count: officers?.length }] : []),
  ]);

  const locations = $derived([...new Set((cameras || []).map((c) => c.location))].sort());
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Cameras & bodycams</h1>
      <p class="muted">
        {#if tab === 'cctv'}{cameras ? `${cameras.length} cameras in ${locations.length} areas` : 'Loading cameras'}{:else}{officers ? `${officers.length} other officers on duty` : 'Loading bodycams'}{/if}
      </p>
    </div>
    <div class="tools">
      <div class="search"><SearchBox bind:value={filter} placeholder={tab === 'cctv' ? 'Filter cameras by name or area' : 'Filter by callsign or name'} /></div>
      {#if tab === 'cctv' && manage}
        <Button variant="primary" icon="plus" onclick={() => (adding = true)}>Add camera</Button>
      {/if}
    </div>
  </header>

  {#if tabs.length > 1}<Tabs {tabs} bind:value={tab} />{/if}

  <div class="body scroll">
    {#if tab === 'cctv'}
      <CctvTab {cameras} error={camError} canManage={manage} {filter} onchanged={loadCameras} onretry={loadCameras} />
    {:else}
      <BodycamTab {officers} error={bodyError} {filter} onretry={loadOfficers} />
    {/if}
  </div>
</div>

<AddCameraModal bind:open={adding} {locations} {limits} onsaved={loadCameras} />

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 14px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .tools { display: flex; align-items: center; gap: 12px; }
  .search { width: 300px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 20px; padding-bottom: 24px; }
</style>
