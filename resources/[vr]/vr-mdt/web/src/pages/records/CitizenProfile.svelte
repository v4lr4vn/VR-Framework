<script>
  import './records.css';
  import Mugshot from '../../components/Mugshot.svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import KeyValue from '../../components/KeyValue.svelte';
  import Panel from '../../components/Panel.svelte';
  import Tabs from '../../components/Tabs.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Empty from '../../components/Empty.svelte';
  import FlagEditor from './FlagEditor.svelte';
  import NotesEditor from './NotesEditor.svelte';
  import LicenceList from './LicenceList.svelte';
  import WarrantModal from './WarrantModal.svelte';
  import CitizenRecord from './CitizenRecord.svelte';
  import { api, callback, on } from '../../lib/nui.js';
  import { session, can, go, back, request, toast } from '../../lib/state.svelte.js';
  import { age, date, months_ } from '../../lib/format.js';
  import { errorText } from '../../lib/lang.js';
  import { rememberImage } from '../../lib/images.js';
  import { genderLabel, dobText } from './shared.js';

  let { cid } = $props();

  let data = $state(null);
  let error = $state('');
  let tab = $state('record');
  let warrantOpen = $state(false);
  let shooting = $state(false);
  let licenceBusy = $state('');

  async function load() {
    const res = await api('citizens.get', { cid });
    if (res.ok) {
      data = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    cid;
    data = null;
    error = '';
    load();
  });

  $effect(() => {
    const offs = [
      on('warrants:changed', (p) => { if (!p || !p.cid || p.cid === cid) load(); }),
      on('prison:changed', (p) => { if (p?.cid === cid) load(); }),
      on('bolos:changed', () => load()),
    ];
    return () => offs.forEach((off) => off());
  });

  const activeWarrants = $derived((data?.warrants || []).filter((w) => w.status === 'active'));
  const pendingWarrants = $derived((data?.warrants || []).filter((w) => w.status === 'pending'));
  const years = $derived(data ? age(data.dob) : null);
  const tabs = $derived(data ? [
    { id: 'record', label: 'Record', count: (data.sentences?.length || 0) + (data.reports?.length || 0) },
    { id: 'warrants', label: 'Warrants', count: data.warrants.length + data.bolos.length },
    { id: 'vehicles', label: 'Vehicles', count: data.vehicles.length },
    { id: 'weapons', label: 'Weapons', count: data.weapons.length },
    { id: 'properties', label: 'Properties', count: data.properties.length },
  ] : []);

  async function saveFlags(flags) {
    const res = await request('citizens.flags', { cid, flags }, { success: 'Flags saved' });
    if (res.ok) data.flags = res.data.flags;
    return res.ok;
  }

  async function saveNotes(notes) {
    const res = await request('citizens.notes', { cid, notes }, { success: 'Notes saved' });
    if (res.ok) Object.assign(data, { notes: res.data.notes, updatedBy: res.data.updatedBy, updatedAt: res.data.updatedAt });
    return res.ok;
  }

  async function toggleLicence(l) {
    licenceBusy = l.key;
    const res = await request('citizens.licence', { cid, licence: l.key, value: !l.value }, { success: `${l.label} ${l.value ? 'revoked' : 'granted'}` });
    licenceBusy = '';
    if (res.ok) data.licences = data.licences.map((x) => (x.key === l.key ? { ...x, value: res.data.value } : x));
  }

  async function takeMugshot() {
    if (shooting) return;
    shooting = true;
    const shot = await callback('capture', { kind: 'mugshot', cid });
    if (!shot || !shot.ok) {
      shooting = false;
      if (shot?.error !== 'cancelled') toast(errorText(shot?.error), 'error');
      return;
    }
    rememberImage(shot.data.id, shot.data.url);
    const res = await request('citizens.mugshot', { cid, imageId: shot.data.id }, { success: 'Mugshot saved' });
    shooting = false;
    if (res.ok) data.mugshot = res.data.mugshot;
  }
</script>

<div class="page">
  <div class="crumbs">
    <Button size="sm" variant="ghost" icon="back" onclick={() => back('citizens')}>Back</Button>
    <span class="faint">Citizens</span>
    <Icon name="chevron" size={12} class="faint" />
    <span class="mono muted">{cid}</span>
  </div>

  {#if error}
    <Empty icon={error === 'not_found' ? 'person' : 'alert'} title={error === 'not_found' ? 'Citizen not found' : "Couldn't load this profile"} text={errorText(error)}>
      <Button onclick={() => go('citizens')}>Back to search</Button>
    </Empty>
  {:else if !data}
    <Spinner label="Loading profile" />
  {:else}
    <header class="hero">
      <div class="photo">
        <Mugshot id={data.mugshot} name={data.name} size={132} radius={8} />
        {#if can('mugshots.take')}
          <button type="button" class="snap" onclick={takeMugshot} disabled={shooting} aria-label="Take a new mugshot">
            <Icon name="camera2" size={15} />{shooting ? 'Waiting…' : data.mugshot ? 'Retake' : 'Take photo'}
          </button>
        {/if}
      </div>
      <div class="ident">
        <div class="titleline">
          <h1>{data.name}</h1>
          {#if activeWarrants.length}<Badge tone="danger" solid>Wanted</Badge>{/if}
          {#if pendingWarrants.length}<Badge tone="accent">Warrant pending</Badge>{/if}
          {#if data.prison}<Badge tone="accent" solid>In prison</Badge>{/if}
          {#if data.online}<Badge tone="ok">In the city</Badge>{/if}
        </div>
        <div class="facts">
          <KeyValue label="Citizen ID" value={data.cid} mono />
          <KeyValue label="Date of birth">{data.dob ? `${dobText(data.dob)}${years != null ? ` · ${years} yrs` : ''}` : '—'}</KeyValue>
          <KeyValue label="Gender" value={genderLabel(data.gender)} />
          <KeyValue label="Phone" value={data.phone} mono />
          <KeyValue label="Nationality" value={data.nationality} />
          <KeyValue label="Occupation" value={[data.jobLabel, data.gradeName].filter(Boolean).join(' · ')} />
        </div>
      </div>
      {#if can('reports.create') || can('warrants.create')}
      <div class="acts">
        {#if can('reports.create')}
          <Button variant="primary" icon="report" onclick={() => go('reports', { new: 1, cid })}>New report</Button>
        {/if}
        {#if can('warrants.create')}
          <Button icon="alert" onclick={() => (warrantOpen = true)}>Request warrant</Button>
        {/if}
      </div>
      {/if}
    </header>

    {#if data.prison}
      <div class="banner prison">
        <Icon name="lock" size={16} />
        <span><b>Serving {months_(data.prison.months)}</b> at Bolingbroke{' · '}{months_(data.prison.monthsLeft)} left{data.prison.online ? '' : ' (paused while away)'}</span>
        <span class="grow muted rec-clip">{data.prison.reason}</span>
        <Button size="sm" variant="ghost" iconRight="chevron" onclick={() => go('prison')}>Prison</Button>
      </div>
    {/if}
    {#each activeWarrants.slice(0, 1) as w}
      <div class="banner wanted">
        <Icon name="wanted" size={16} />
        <span><b>Active warrant #{w.id}</b>{' · '}expires {date(w.expires_at)}</span>
        <span class="grow rec-clip">{w.reason}</span>
        <Button size="sm" variant="ghost" iconRight="chevron" onclick={() => go('warrants', { id: w.id })}>Open</Button>
      </div>
    {/each}

    <div class="cols">
      <aside class="side scroll">
        <Panel title="Flags">
          <FlagEditor flags={data.flags} options={session.flags} editable={can('records.edit')} onsave={saveFlags} idPrefix="cflag" />
        </Panel>
        <Panel title="Licences">
          <LicenceList licences={data.licences} editable={can('licences.edit')} busy={licenceBusy} ontoggle={toggleLicence} />
        </Panel>
        <Panel title="Identification">
          <div class="idgrid">
            <KeyValue label="Fingerprint" value={data.fingerprint} mono />
            <KeyValue label="Blood type" value={data.bloodtype} mono />
          </div>
        </Panel>
        <Panel title="Notes">
          <NotesEditor notes={data.notes} editable={can('records.edit')} onsave={saveNotes} updatedBy={data.updatedBy} updatedAt={data.updatedAt} id="citizen-notes" />
        </Panel>
      </aside>

      <section class="main">
        <div class="tabbar"><Tabs {tabs} bind:value={tab} /></div>
        <div class="tabbody scroll">
          <CitizenRecord {data} {tab} />
        </div>
      </section>
    </div>

    <WarrantModal bind:open={warrantOpen} person={{ cid: data.cid, name: data.name }} oncreated={load} />
  {/if}
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 14px 24px 20px; gap: 14px; }
  .crumbs { display: flex; align-items: center; gap: 8px; font-size: 13px; margin-left: -6px; }
  .crumbs :global(.faint) { color: var(--faint); }
  .hero { display: flex; gap: 22px; align-items: flex-start; padding: 16px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .photo { position: relative; flex: none; }
  .snap { position: absolute; left: 6px; right: 6px; bottom: 6px; height: 26px; display: flex; align-items: center; justify-content: center; gap: 6px; border-radius: 5px; border: 1px solid var(--line-3); background: rgba(10, 14, 20, 0.82); color: var(--text); font-size: 12px; font-weight: 600; }
  .snap:hover:not(:disabled) { border-color: var(--accent); color: var(--accent); }
  .ident { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 16px; }
  .titleline { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  h1 { font-size: 28px; font-weight: 700; line-height: 1.1; margin-right: 4px; }
  .facts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px 24px; }
  .acts { display: flex; flex-direction: column; gap: 8px; width: 190px; flex: none; }
  .acts :global(.btn) { width: 100%; justify-content: flex-start; }
  .banner { display: flex; align-items: center; gap: 10px; min-height: 40px; padding: 0 6px 0 14px; border-radius: var(--radius); border: 1px solid; }
  .banner b { font-weight: 700; }
  .banner .grow { flex: 1; min-width: 0; }
  .prison { background: var(--accent-soft); border-color: var(--accent-line); color: var(--p2-text); }
  .prison span { color: var(--text); }
  .prison :global(svg) { color: var(--accent); }
  .wanted { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  .wanted span { color: var(--text); }
  .wanted :global(svg) { color: var(--danger); }
  .cols { flex: 1; min-height: 0; display: flex; gap: 14px; }
  .side { width: 360px; flex: none; display: flex; flex-direction: column; gap: 12px; padding-right: 4px; }
  .side :global(.panel) { flex: none; }
  .idgrid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .main { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius-lg); }
  .tabbar { padding: 6px 12px 0; }
  .tabbody { flex: 1; min-height: 0; padding: 12px 14px 16px; }
</style>
