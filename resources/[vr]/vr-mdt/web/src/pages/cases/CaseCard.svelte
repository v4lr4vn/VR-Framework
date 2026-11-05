<script>
  import Badge from '../../components/Badge.svelte';
  import Icon from '../../components/Icon.svelte';
  import { agoWords } from '../../lib/format.js';
  import { statusLabel, statusTone } from './util.js';

  let { item, selected = false, onselect } = $props();
</script>

<button type="button" class="card" class:selected class:dim={item.status === 'closed'} onclick={() => onselect?.(item)} aria-pressed={selected}>
  <div class="row">
    <span class="id mono">#{item.id}</span>
    <Badge tone={statusTone(item.status)}>{statusLabel(item.status)}</Badge>
    <span class="grow"></span>
    <span class="age">{agoWords(item.updatedAt)}</span>
  </div>
  <span class="title">{item.title}</span>
  <div class="foot">
    <span class="lead"><Icon name="shield" size={12} /> {item.lead ? item.lead.name : 'No lead'}</span>
    <span class="cnt mono" title="Linked reports"><Icon name="report" size={12} /> {item.reports ?? 0}</span>
    <span class="cnt mono" title="Evidence"><Icon name="evidence" size={12} /> {item.evidence ?? 0}</span>
  </div>
</button>

<style>
  .card { display: flex; flex-direction: column; gap: 6px; padding: 11px 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: var(--text); width: 100%; flex: none; }
  .card:hover { border-color: var(--line-3); background: #141c29; }
  .selected, .selected:hover { background: var(--panel-2); border-color: var(--accent); }
  .dim { opacity: 0.75; }
  .row { display: flex; align-items: center; gap: 8px; }
  .id { color: var(--muted); font-size: 12px; font-weight: 600; }
  .grow { flex: 1; }
  .age { color: var(--faint); font-size: 12px; }
  .title { font-weight: 600; font-size: 15px; line-height: 1.25; }
  .foot { display: flex; align-items: center; gap: 12px; color: var(--muted); font-size: 12px; }
  .lead { flex: 1; min-width: 0; display: inline-flex; align-items: center; gap: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cnt { display: inline-flex; align-items: center; gap: 4px; }
</style>
