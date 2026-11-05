<script>
  import Badge from '../../components/Badge.svelte';
  import Icon from '../../components/Icon.svelte';
  import { agoWords } from '../../lib/format.js';
  import { typeLabel, typeTone } from './util.js';

  let { report, selected = false, onselect } = $props();
  const more = $derived(report.peopleCount - report.suspects.length);
</script>

<button type="button" class="card" class:selected onclick={() => onselect?.(report)} aria-pressed={selected}>
  <div class="row">
    <span class="id mono">#{report.id}</span>
    <Badge tone={typeTone(report.type)}>{typeLabel(report.type)}</Badge>
    <span class="grow"></span>
    {#if report.sentenced}<span class="ico ok" title="Sentence applied"><Icon name="gavel" size={13} /></span>{/if}
    {#if report.caseId}<span class="ico" title="Linked to case #{report.caseId}"><Icon name="folder" size={13} /></span>{/if}
    {#if report.locked}<span class="ico lock" title="Locked"><Icon name="lock" size={13} /></span>{/if}
  </div>
  <span class="title">{report.title}</span>
  <span class="people">
    {#if report.suspects.length}
      {report.suspects.join(', ')}{#if more > 0}<span class="faint">{' '}+{more}</span>{/if}
    {:else if report.peopleCount}
      <span class="faint">{report.peopleCount} {report.peopleCount === 1 ? 'person' : 'people'}, no suspects</span>
    {:else}
      <span class="faint">Nobody listed</span>
    {/if}
  </span>
  <div class="foot">
    <span class="mono cs">{report.author.callsign || report.author.name}</span>
    <span class="faint">{agoWords(report.createdAt)}</span>
  </div>
</button>

<style>
  .card { display: flex; flex-direction: column; gap: 5px; padding: 11px 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: var(--text); width: 100%; flex: none; }
  .card:hover { border-color: var(--line-3); background: #141c29; }
  .selected, .selected:hover { background: var(--panel-2); border-color: var(--accent); }
  .row { display: flex; align-items: center; gap: 8px; }
  .id { color: var(--muted); font-size: 12px; font-weight: 600; }
  .grow { flex: 1; }
  .ico { color: var(--muted); display: flex; }
  .ico.ok { color: var(--ok); }
  .ico.lock { color: var(--danger-text); }
  .title { font-weight: 600; font-size: 15px; line-height: 1.25; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
  .people { color: var(--text-2); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .foot { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 12px; }
  .cs { color: var(--p3-text); }
</style>
