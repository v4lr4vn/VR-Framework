<script>
  import './records.css';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import KeyValue from '../../components/KeyValue.svelte';
  import Panel from '../../components/Panel.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import FlagEditor from './FlagEditor.svelte';
  import NotesEditor from './NotesEditor.svelte';
  import OwnerCard from './OwnerCard.svelte';
  import { api, on } from '../../lib/nui.js';
  import { can, go, back, request } from '../../lib/state.svelte.js';
  import { date, agoWords } from '../../lib/format.js';
  import { errorText } from '../../lib/lang.js';
  import { flagTone, vehicleState, vehicleStateTone } from './shared.js';

  let { plate } = $props();

  let data = $state(null);
  let error = $state('');

  async function load() {
    const res = await api('vehicles.get', { plate });
    if (res.ok) {
      data = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    plate;
    load();
  });

  $effect(() => on('bolos:changed', () => load()));

  async function saveFlags(flags) {
    const res = await request('vehicles.flags', { plate: data.plate, flags }, { success: 'Flags saved' });
    if (res.ok) data.flags = res.data.flags;
    return res.ok;
  }

  async function saveNotes(notes) {
    const res = await request('vehicles.notes', { plate: data.plate, notes }, { success: 'Notes saved' });
    if (res.ok) Object.assign(data, { notes: res.data.notes, updatedBy: res.data.updatedBy, updatedAt: res.data.updatedAt });
    return res.ok;
  }

  const hot = $derived(data ? data.flags.filter((f) => f === 'Stolen' || f === 'BOLO') : []);
</script>

<div class="page">
  <div class="crumbs">
    <Button size="sm" variant="ghost" icon="back" onclick={() => back('vehicles')}>Back</Button>
    <span class="faint">Vehicles</span>
    <Icon name="chevron" size={12} />
    <span class="mono muted">{plate}</span>
  </div>

  {#if error}
    <Empty icon="alert" title="Couldn't load this vehicle" text={errorText(error)}>
      <Button onclick={() => go('vehicles')}>Back to search</Button>
    </Empty>
  {:else if !data}
    <Spinner label="Loading vehicle" />
  {:else}
    <header class="hero">
      <span class="rec-plate lg">{data.plate}</span>
      <div class="ident">
        <div class="titleline">
          <h1>{data.registered ? data.label || data.model : 'Unregistered plate'}</h1>
          {#each hot as f}<Badge tone={flagTone(f)} solid>{f}</Badge>{/each}
          {#if !data.registered}<Badge tone="p2">No registration on file</Badge>{/if}
        </div>
        <div class="facts">
          <KeyValue label="Model" value={data.model} mono />
          <KeyValue label="Garage" value={data.garage} />
          <KeyValue label="State">{#if data.state != null}<Badge tone={vehicleStateTone(data.state)}>{vehicleState(data.state)}</Badge>{:else}—{/if}</KeyValue>
          <KeyValue label="Registered owner" value={data.owner?.name || 'None'} />
        </div>
      </div>
    </header>

    <div class="grid scroll">
      <div class="col">
        <Panel title="Registered owner">
          {#if data.owner}
            <OwnerCard person={data.owner} />
          {:else}
            <p class="faint">No owner on file. Flags and notes still follow this plate.</p>
          {/if}
        </Panel>
        <Panel title="Flags">
          <FlagEditor flags={data.flags} options={data.flagOptions} editable={can('records.edit')} onsave={saveFlags} idPrefix="vflag" />
        </Panel>
        <Panel title="Notes">
          <NotesEditor notes={data.notes} editable={can('records.edit')} onsave={saveNotes} updatedBy={data.updatedBy} updatedAt={data.updatedAt} id="vehicle-notes" placeholder="Damage, sightings, who usually drives it" />
        </Panel>
      </div>
      <div class="col">
        <Panel title={data.bolos.length ? `Active BOLOs · ${data.bolos.length}` : 'Active BOLOs'}>
          {#each data.bolos as b (b.id)}
            <button type="button" class="bolo" onclick={() => go('warrants', { tab: 'bolos', id: b.id })}>
              <Icon name="alert" size={16} />
              <span class="bt"><span class="rec-strong">{b.title}</span>{#if b.details}<span class="rec-sub">{b.details}</span>{/if}</span>
              <span class="rec-sub">{agoWords(b.created_at)}</span>
            </button>
          {:else}
            <p class="faint">No BOLOs for this plate.</p>
          {/each}
        </Panel>
        <Panel title="Reports">
          {#if data.reports.length}
            <div class="rec-rows">
              {#each data.reports as r (r.id)}
                <button type="button" class="rec-row" style:grid-template-columns="64px minmax(0, 1fr) 110px" onclick={() => go('reports', { id: r.id })}>
                  <span class="mono faint">#{r.id}</span>
                  <span class="rec-strong rec-clip">{r.title}</span>
                  <span class="mono">{date(r.created_at)}</span>
                </button>
              {/each}
            </div>
          {:else}
            <p class="faint">This plate isn't in any reports.</p>
          {/if}
        </Panel>
      </div>
    </div>
  {/if}
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 14px 24px 20px; gap: 14px; }
  .crumbs { display: flex; align-items: center; gap: 8px; font-size: 13px; margin-left: -6px; color: var(--faint); }
  .hero { display: flex; gap: 24px; align-items: center; padding: 18px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .ident { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; }
  .titleline { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  h1 { font-size: 26px; font-weight: 700; line-height: 1.1; margin-right: 4px; }
  .facts { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px 24px; }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 14px; align-content: start; padding-right: 4px; }
  .col { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
  .bolo { display: flex; align-items: flex-start; gap: 10px; padding: 10px; border-radius: var(--radius); border: 1px solid var(--accent-line); background: var(--accent-soft); color: var(--accent); text-align: left; width: 100%; }
  .bolo + .bolo { margin-top: 8px; }
  .bolo:hover { border-color: var(--accent); }
  .bt { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
</style>
