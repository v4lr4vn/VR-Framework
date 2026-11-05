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
  import { api } from '../../lib/nui.js';
  import { can, go, back, request } from '../../lib/state.svelte.js';
  import { dateTime } from '../../lib/format.js';
  import { errorText } from '../../lib/lang.js';
  import { flagTone } from './shared.js';

  let { serial } = $props();

  let data = $state(null);
  let error = $state('');

  async function load() {
    const res = await api('weapons.get', { serial });
    if (res.ok) {
      data = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    serial;
    load();
  });

  async function saveFlags(flags) {
    const res = await request('weapons.flags', { serial: data.serial, flags }, { success: 'Flags saved' });
    if (res.ok) data.flags = res.data.flags;
    return res.ok;
  }

  async function saveNotes(notes) {
    const res = await request('weapons.notes', { serial: data.serial, notes }, { success: 'Notes saved' });
    if (res.ok) Object.assign(data, { notes: res.data.notes, updatedBy: res.data.updatedBy, updatedAt: res.data.updatedAt });
    return res.ok;
  }
</script>

<div class="page">
  <div class="crumbs">
    <Button size="sm" variant="ghost" icon="back" onclick={() => back('weapons')}>Back</Button>
    <span>Weapons</span>
    <Icon name="chevron" size={12} />
    <span class="mono muted">{serial}</span>
  </div>

  {#if error}
    <Empty icon={error === 'not_found' ? 'crosshair' : 'alert'} title={error === 'not_found' ? 'No weapon with that serial' : "Couldn't load this weapon"} text={error === 'not_found' ? 'It may not be registered yet. Officers with record access can register it.' : errorText(error)}>
      <Button onclick={() => go('weapons')}>Back to search</Button>
    </Empty>
  {:else if !data}
    <Spinner label="Loading weapon" />
  {:else}
    <header class="hero">
      <span class="ico"><Icon name="crosshair" size={30} /></span>
      <div class="ident">
        <div class="titleline">
          <h1>{data.label}</h1>
          {#each data.flags as f}<Badge tone={flagTone(f)} solid>{f}</Badge>{/each}
        </div>
        <div class="facts">
          <KeyValue label="Serial number" value={data.serial} mono />
          <KeyValue label="Item" value={data.item} mono />
          <KeyValue label="Registered" value={dateTime(data.registeredAt)} />
          <KeyValue label="Source" value={data.source === 'manual' ? 'Registered by an officer' : 'Automatic at purchase'} />
        </div>
      </div>
    </header>

    <div class="grid scroll">
      <Panel title="Registered owner">
        {#if data.ownerProfile}
          <OwnerCard person={data.ownerProfile}>
            <span class="lic" class:ok={data.ownerProfile.weaponLicence}>
              <Icon name={data.ownerProfile.weaponLicence ? 'check' : 'ban'} size={14} />
              {data.ownerProfile.weaponLicence ? 'Holds a weapon licence' : 'No weapon licence'}
            </span>
          </OwnerCard>
        {:else if data.owner}
          <p class="muted">{data.owner} <span class="mono faint">{data.ownerCid}</span></p>
        {:else}
          <p class="faint">Owner unknown.</p>
        {/if}
      </Panel>
      <div class="col">
        <Panel title="Flags">
          <FlagEditor flags={data.flags} options={data.flagOptions} editable={can('records.edit')} onsave={saveFlags} idPrefix="wflag" />
        </Panel>
        <Panel title="Notes">
          <NotesEditor notes={data.notes} editable={can('records.edit')} onsave={saveNotes} updatedBy={data.updatedBy} updatedAt={data.updatedAt} id="weapon-notes" placeholder="Where it was found, ballistics, chain of custody" />
        </Panel>
      </div>
    </div>
  {/if}
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 14px 24px 20px; gap: 14px; }
  .crumbs { display: flex; align-items: center; gap: 8px; font-size: 13px; margin-left: -6px; color: var(--faint); }
  .hero { display: flex; gap: 20px; align-items: center; padding: 18px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .ico { width: 72px; height: 72px; border-radius: 8px; background: var(--panel-2); border: 1px solid var(--line-3); display: flex; align-items: center; justify-content: center; color: var(--accent); flex: none; }
  .ident { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; }
  .titleline { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  h1 { font-size: 26px; font-weight: 700; line-height: 1.1; margin-right: 4px; }
  .facts { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px 24px; }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 14px; align-content: start; padding-right: 4px; }
  .grid > :global(.panel) { align-self: start; }
  .col { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
  .lic { display: inline-flex; align-items: center; gap: 6px; margin-top: 6px; font-size: 13px; font-weight: 600; color: var(--danger-text); }
  .lic.ok { color: var(--ok); }
</style>
