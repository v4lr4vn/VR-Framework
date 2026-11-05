<script>
  import { untrack } from 'svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import SearchBox from '../../components/SearchBox.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { date, time, agoWords } from '../../lib/format.js';
  import { auditName, auditTone } from './labels.js';

  const PAGE = 50;

  let rows = $state([]);
  let page = $state(1);
  let q = $state('');
  let loading = $state(true);
  let failed = $state(false);
  let seq = 0;

  async function load(p = page) {
    const mine = ++seq;
    loading = true;
    const res = await request('audit.list', { page: p, q: q.trim() }, { quiet: true });
    if (mine !== seq) return;
    loading = false;
    failed = !res.ok;
    if (res.ok) {
      rows = res.data;
      page = p;
    }
  }

  $effect(() => {
    untrack(() => load(1));
  });

  function fmt(v) {
    if (v === null || v === undefined || v === '') return '—';
    if (v === true) return 'yes';
    if (v === false) return 'no';
    if (Array.isArray(v)) return v.length ? v.join(', ') : 'none';
    if (typeof v === 'object') return JSON.stringify(v);
    return String(v);
  }

  function aboutKey(r) {
    const d = r.details || {};
    if (d.name) return 'name';
    if (d.subject) return 'subject';
    if (r.action.startsWith('permissions.') && d.rank) return 'rank';
    if (r.action.startsWith('bulletin.') && d.title) return 'title';
    return null;
  }

  function details(r) {
    const d = r.details;
    if (!d || typeof d !== 'object') return [];
    const skip = aboutKey(r);
    return Object.entries(d)
      .filter(([k]) => k !== skip)
      .map(([k, v]) => ({ k: k.replace(/([A-Z])/g, ' $1').toLowerCase(), v: fmt(v) }));
  }

  function who(r) {
    const k = aboutKey(r);
    return k ? r.details[k] : null;
  }
</script>

<div class="wrap">
  <div class="toolbar">
    <div class="search"><SearchBox bind:value={q} placeholder="Search by person, action or target" onsearch={() => load(1)} /></div>
    <span class="grow"></span>
    <div class="pager">
      <IconButton icon="back" label="Newer entries" variant="outline" disabled={page <= 1 || loading} onclick={() => load(page - 1)} />
      <span class="pg mono">Page {page}</span>
      <IconButton icon="chevron" label="Older entries" variant="outline" disabled={rows.length < PAGE || loading} onclick={() => load(page + 1)} />
    </div>
  </div>

  <div class="scroller scroll">
    {#if loading && !rows.length}
      <Spinner label="Loading the audit log" />
    {:else if failed}
      <Empty icon="alert" title="Couldn't load the audit log">
        <Button icon="refresh" onclick={() => load(page)}>Try again</Button>
      </Empty>
    {:else if !rows.length}
      <Empty icon="history" title={q ? 'Nothing matches' : 'Nothing logged yet'} text={q ? 'Try a name, a citizen ID or an action like roster.hire.' : 'Hires, promotions, permission changes and other writes show up here.'} />
    {:else}
      <table class:dim={loading}>
        <thead>
          <tr><th class="when">When</th><th class="by">By</th><th class="act">Action</th><th class="tg">About</th><th>Details</th></tr>
        </thead>
        <tbody>
          {#each rows as r (r.id)}
            <tr>
              <td class="when"><span class="mono">{time(r.at)}</span><span class="d">{date(r.at)}</span></td>
              <td class="by">{r.name || 'System'}</td>
              <td class="act">
                <span class="an {auditTone(r.action)}">{auditName(r.action)}</span>
                <span class="ak mono">{r.action}</span>
              </td>
              <td class="tg">
                {#if who(r)}<span class="tn">{who(r)}</span>{/if}
                <span class="mono faint">{r.target || '—'}</span>
              </td>
              <td>
                <div class="det">
                  {#each details(r) as d}
                    <span class="kv"><span class="k">{d.k}</span> {d.v}</span>
                  {/each}
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="foot faint">Newest first. Showing {rows.length} entries{page > 1 ? ` on page ${page}` : ''}{rows[0] ? `, latest ${agoWords(rows[0].at)}` : ''}.</p>
    {/if}
  </div>
</div>

<style>
  .wrap { flex: 1; min-height: 0; display: flex; flex-direction: column; }
  .toolbar { display: flex; align-items: center; gap: 10px; padding: 14px 24px 12px; }
  .search { width: 360px; }
  .grow { flex: 1; }
  .pager { display: flex; align-items: center; gap: 8px; }
  .pg { color: var(--text-2); font-size: 13px; min-width: 64px; text-align: center; }
  .scroller { flex: 1; min-height: 0; padding: 0 24px 20px; display: flex; flex-direction: column; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; }
  table.dim { opacity: 0.6; }
  thead th { position: sticky; top: 0; z-index: 1; background: var(--bg); text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 10px; border-bottom: 1px solid var(--line-2); }
  td { padding: 7px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }
  .when { width: 120px; }
  .when .mono { display: block; color: var(--text); }
  .when .d { color: var(--faint); font-size: 12px; }
  .by { width: 170px; color: var(--text-2); }
  .act { width: 210px; }
  .an { display: inline-block; font-weight: 600; color: var(--text); }
  .an.danger { color: var(--danger-text); }
  .an.ok { color: var(--ok); }
  .an.accent { color: var(--accent); }
  .an.doj { color: var(--doj-text); }
  .ak { display: block; color: var(--faint); font-size: 11px; }
  .tg { width: 190px; }
  .tn { display: block; color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tg .mono { font-size: 12px; }
  .det { display: flex; flex-wrap: wrap; gap: 4px 6px; }
  .kv { font-size: 12px; color: var(--text-2); background: var(--panel); border: 1px solid var(--line); border-radius: 4px; padding: 1px 6px; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .k { color: var(--faint); }
  .foot { font-size: 12px; padding: 10px 2px 0; }
</style>
