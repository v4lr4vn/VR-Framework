<script>
  import { untrack } from 'svelte';
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import IaFile from './department/IaFile.svelte';
  import IaFileModal from './department/IaFileModal.svelte';
  import { request, can, go } from '../lib/state.svelte.js';
  import { on } from '../lib/nui.js';
  import { agoWords } from '../lib/format.js';
  import { iaStatus, fileNo } from './department/labels.js';

  let { params = {} } = $props();

  let items = $state([]);
  let counts = $state({});
  let filter = $state('active');
  let q = $state('');
  let page = $state(1);
  let more = $state(false);
  let loading = $state(true);
  let failed = $state(false);
  let creating = $state(false);
  let seq = 0;
  let timer;

  async function load(p = 1, quiet = false) {
    const mine = ++seq;
    if (!quiet) loading = true;
    const res = await request('ia.list', { status: filter === 'all' ? undefined : filter, q: q.trim(), page: p }, { quiet: true });
    if (mine !== seq) return;
    loading = false;
    failed = !res.ok;
    if (res.ok) {
      items = res.data.items;
      counts = res.data.counts || {};
      more = res.data.more;
      page = p;
    }
  }

  $effect(() => {
    if (params.id) return;
    untrack(() => load());
    const off = on('ia:changed', () => {
      clearTimeout(timer);
      timer = setTimeout(() => load(page, true), 250);
    });
    return () => {
      off();
      clearTimeout(timer);
    };
  });

  const tabs = $derived([
    { id: 'active', label: 'Active', n: counts.active ?? 0 },
    { id: 'resolved', label: 'Resolved', n: counts.resolved ?? 0 },
    { id: 'all', label: 'All', n: (counts.active ?? 0) + (counts.resolved ?? 0) },
  ]);

  function pick(id) {
    filter = id;
    load();
  }

  function open(id) {
    go('ia', { id });
  }

  function key(e, id) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      open(id);
    }
  }
</script>

{#if params.id}
  {#key params.id}
    <IaFile id={Number(params.id)} />
  {/key}
{:else}
  <div class="page">
    <header class="ph">
      <div>
        <h1>Internal Affairs</h1>
        <p class="muted">Complaints and investigations. Files about you are never shown to you.</p>
      </div>
      {#if can('ia.manage')}
        <Button variant="primary" icon="folder" onclick={() => (creating = true)}>New file</Button>
      {/if}
    </header>

    <div class="tools">
      <div class="chips" role="tablist" aria-label="Filter files">
        {#each tabs as t}
          <button type="button" role="tab" class="chip" class:on={filter === t.id} aria-selected={filter === t.id} onclick={() => pick(t.id)}>{t.label}<span class="n mono">{t.n}</span></button>
        {/each}
      </div>
      <div class="search"><SearchBox bind:value={q} placeholder="Search subject, complainant, investigator or #number" onsearch={() => load()} /></div>
      <span class="grow"></span>
      {#if page > 1 || more}
        <div class="pager">
          <Button size="sm" icon="back" disabled={page <= 1} onclick={() => load(page - 1)}>Newer</Button>
          <Button size="sm" iconRight="chevron" disabled={!more} onclick={() => load(page + 1)}>Older</Button>
        </div>
      {/if}
    </div>

    <div class="body scroll">
      {#if loading && !items.length}
        <Spinner label="Loading files" />
      {:else if failed}
        <Empty icon="alert" title="Couldn't load files">
          <Button icon="refresh" onclick={() => load()}>Try again</Button>
        </Empty>
      {:else if !items.length}
        <Empty icon="shieldcheck" title={q ? 'Nothing matches' : filter === 'active' ? 'No open investigations' : 'No files'} text={q ? 'Try a name or a file number.' : filter === 'active' ? 'Open a file when a complaint comes in.' : ''} />
      {:else}
        <table>
          <thead>
            <tr><th class="no">File</th><th>Subject</th><th>Complainant</th><th>Allegation</th><th>Status</th><th>Investigator</th><th class="num">Notes</th><th class="up">Updated</th></tr>
          </thead>
          <tbody>
            {#each items as f (f.id)}
              {@const st = iaStatus[f.status] || { label: f.status, tone: 'muted' }}
              <tr tabindex="0" onclick={() => open(f.id)} onkeydown={(e) => key(e, f.id)}>
                <td class="no mono">{fileNo(f.id)}</td>
                <td class="strong">{f.subjectName}</td>
                <td class="muted clip">{f.complainant || 'Internal referral'}</td>
                <td class="clip sum">{f.summary}</td>
                <td><Badge tone={st.tone}>{st.label}</Badge></td>
                <td class:faint={!f.assignedName}>{f.assignedName || 'Unassigned'}</td>
                <td class="num mono">{f.notes || 0}</td>
                <td class="up muted">{agoWords(f.updatedAt)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  </div>

  <IaFileModal bind:open={creating} onsaved={(f) => open(f.id)} />
{/if}

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 14px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .tools { display: flex; align-items: center; gap: 12px; }
  .chips { display: flex; gap: 4px; }
  .chip { height: 32px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--muted); font-size: 13px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
  .chip:hover { color: var(--text); }
  .chip.on { background: var(--panel); border-color: var(--line-2); color: var(--text); }
  .chip .n { font-size: 12px; color: var(--faint); }
  .chip.on .n { color: var(--accent); }
  .search { width: 380px; }
  .grow { flex: 1; }
  .pager { display: flex; gap: 6px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding-bottom: 20px; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; }
  thead th { position: sticky; top: 0; background: var(--bg); text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 10px; border-bottom: 1px solid var(--line-2); }
  td { padding: 0 10px; height: 44px; border-bottom: 1px solid var(--line); vertical-align: middle; white-space: nowrap; }
  tbody tr { cursor: pointer; }
  tbody tr:hover td { background: var(--bg-2); }
  tbody tr:focus-visible { outline: 2px solid var(--accent); outline-offset: -2px; }
  .no { width: 96px; color: var(--text); font-weight: 600; }
  .strong { font-weight: 600; width: 170px; overflow: hidden; text-overflow: ellipsis; }
  .clip { overflow: hidden; text-overflow: ellipsis; }
  .sum { color: var(--text-2); width: 34%; }
  .num { width: 70px; text-align: right; }
  .up { width: 120px; }
</style>
