<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Badge from '../../components/Badge.svelte';
  import SearchBox from '../../components/SearchBox.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { api } from '../../lib/nui.js';
  import { request } from '../../lib/state.svelte.js';
  import { date } from '../../lib/format.js';
  import { typeLabel, typeTone } from '../reports/util.js';

  let { open = $bindable(false), caseId, linked = [], onlinked } = $props();

  let q = $state('');
  let items = $state([]);
  let loading = $state(false);
  let busy = $state(0);
  let seq = 0;

  async function search(term) {
    const mine = ++seq;
    loading = true;
    const res = await api('reports.list', { q: term || '' });
    if (mine !== seq) return;
    loading = false;
    items = res.ok ? res.data.items : [];
  }

  $effect(() => {
    if (!open) return;
    untrack(() => {
      q = '';
      search('');
    });
  });

  async function link(r) {
    busy = r.id;
    const res = await request('cases.link', { caseId, reportId: r.id }, { success: `Report #${r.id} linked` });
    busy = 0;
    if (res.ok) {
      onlinked?.(res.data);
      open = false;
    }
  }
</script>

<Modal bind:open title="Link a report" width={620}>
  <SearchBox bind:value={q} placeholder="Search reports by title, person or #number" onsearch={search} autofocus />
  <div class="list">
    {#if loading && !items.length}
      <Spinner label="Searching reports" />
    {:else}
      {#each items as r (r.id)}
        {@const here = linked.includes(r.id)}
        <div class="row">
          <span class="id mono">#{r.id}</span>
          <Badge tone={typeTone(r.type)}>{typeLabel(r.type)}</Badge>
          <div class="t">
            <span class="title">{r.title}</span>
            <span class="sub">{r.author.callsign || r.author.name} · {date(r.createdAt)}{r.caseId && !here ? ` · on case #${r.caseId}` : ''}</span>
          </div>
          {#if here}
            <Badge tone="ok">Linked</Badge>
          {:else}
            <Button size="sm" icon="link" busy={busy === r.id} onclick={() => link(r)}>{r.caseId ? 'Move here' : 'Link'}</Button>
          {/if}
        </div>
      {:else}
        <p class="none">No reports match.</p>
      {/each}
    {/if}
  </div>
</Modal>

<style>
  .list { display: flex; flex-direction: column; min-height: 200px; max-height: 420px; overflow-y: auto; }
  .row { display: flex; align-items: center; gap: 10px; padding: 8px 4px; border-bottom: 1px solid var(--line); }
  .id { color: var(--muted); font-size: 12px; width: 44px; flex: none; }
  .t { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .title { color: var(--text); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 12px; }
  .none { color: var(--faint); padding: 20px 4px; }
</style>
