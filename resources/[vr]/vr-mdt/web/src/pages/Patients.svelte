<script>
  import Empty from '../components/Empty.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Icon from '../components/Icon.svelte';
  import PatientView from './ems/PatientView.svelte';
  import { api } from '../lib/nui.js';
  import { go } from '../lib/state.svelte.js';
  import { agoWords } from '../lib/format.js';
  import { ageOf } from './ems/meta.js';

  let { params = {} } = $props();

  let q = $state('');
  let result = $state(null);
  let error = $state('');
  let loading = $state(false);
  let seq = 0;

  const selected = $derived(params.cid || null);

  async function run(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('patients.search', { q: term });
    if (mine !== seq) return;
    loading = false;
    if (res.ok) {
      result = res.data;
      error = '';
    } else {
      error = res.error;
    }
  }

  $effect(() => {
    run('');
  });

  function search(term) {
    run(term.length >= 2 ? term : '');
  }
</script>

<div class="patients">
  <section class="finder" aria-label="Find a patient">
    <div class="head">
      <h1>Patients</h1>
      <SearchBox bind:value={q} placeholder="Name, phone or citizen ID" onsearch={search} autofocus />
    </div>
    <span class="eyebrow label">{result?.recent ? 'Recent patients' : `Results · ${result?.list?.length ?? 0}`}</span>
    <div class="list scroll">
      {#if error}
        <Empty icon="alert" title="Search failed" text="Try again in a moment." />
      {:else if !result}
        <Spinner label="Loading patients" />
      {:else}
        {#each result.list as p (p.cid)}
          {@const age = ageOf(p.dob)}
          <button type="button" class="p" class:on={p.cid === selected} aria-current={p.cid === selected ? 'true' : undefined} onclick={() => go('patients', { cid: p.cid })}>
            <span class="pn">{p.name}</span>
            {#if p.profile}<span class="dot" title="Has a medical profile"><Icon name="heart" size={12} /></span>{/if}
            <span class="ps">
              <span class="mono">{p.cid}</span>
              {#if result.recent && p.lastSeen}<span>seen {agoWords(p.lastSeen)}</span>{:else if p.dob}<span class="mono">{p.dob}{#if age != null}{' · '}{age}{/if}</span>{/if}
            </span>
          </button>
        {:else}
          <Empty icon={result.recent ? 'heart' : 'search'} title={result.recent ? 'No recent patients' : 'No one found'} text={result.recent ? 'Search for a patient by name, phone number or citizen ID.' : 'Check the spelling, or try a phone number.'} />
        {/each}
      {/if}
    </div>
  </section>

  <div class="detail">
    {#if selected}
      {#key selected}<PatientView cid={selected} />{/key}
    {:else}
      <Empty icon="heart" title="Pick a patient" text="Their blood type, allergies, conditions and medical history show up here." />
    {/if}
  </div>
</div>

<style>
  .patients { flex: 1; display: flex; min-height: 0; }
  .finder { width: 340px; flex: none; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--bg-2); min-height: 0; }
  .head { display: flex; flex-direction: column; gap: 12px; padding: 18px 16px 12px; }
  h1 { font-size: 22px; font-weight: 700; }
  .label { padding: 4px 16px 8px; }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 4px; padding: 0 10px 12px; }
  .p { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: 2px 8px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text); text-align: left; flex: none; }
  .p:hover { background: var(--panel); border-color: var(--line-2); }
  .p.on { background: var(--panel-2); border-color: var(--line-3); }
  .pn { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .p.on .pn { color: var(--ems-text); }
  .dot { color: var(--ems); display: flex; }
  .ps { grid-column: span 2; display: flex; gap: 10px; color: var(--muted); font-size: 12px; }
  .detail { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: 0; }
</style>
