<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { callback } from '../../lib/nui.js';
  import { session, toast, go, dispatch } from '../../lib/state.svelte.js';
  import { errorText } from '../../lib/lang.js';
  import { statusTone } from '../../lib/status.js';

  let { officers = null, error = '', filter = '', onretry } = $props();

  let opening = $state(null);

  const shown = $derived.by(() => {
    if (!officers) return [];
    const term = filter.trim().toLowerCase();
    return term ? officers.filter((o) => `${o.callsign || ''} ${o.name}`.toLowerCase().includes(term)) : officers;
  });

  function statusLabel(id) {
    return session.statuses.find((s) => s.id === id)?.label || id;
  }

  function callOf(o) {
    return o.callId ? dispatch.calls.find((c) => c.id === o.callId) : null;
  }

  async function watch(o) {
    if (opening) return;
    opening = o.cid;
    const res = await callback('viewBodycam', { cid: o.cid });
    opening = null;
    if (!res || !res.ok) toast(errorText(res?.error || 'unit_unavailable'), 'error');
  }
</script>

{#if error}
  <Empty icon="alert" title="Couldn't load bodycams" text="Try again in a moment.">
    <Button icon="refresh" onclick={onretry}>Retry</Button>
  </Empty>
{:else if !officers}
  <Spinner label="Loading bodycams" />
{:else if !shown.length}
  <Empty icon="bodycam" title={filter ? 'No matching officers' : 'No other officers on duty'} text={filter ? `Nobody matches "${filter}".` : 'Bodycams of on-duty officers show up here.'} />
{:else}
  <table>
    <thead>
      <tr><th class="c-cs">Callsign</th><th>Officer</th><th class="c-rk">Rank</th><th class="c-st">Status</th><th>Call</th><th class="c-act"><span class="sr-only">Watch</span></th></tr>
    </thead>
    <tbody>
      {#each shown as o (o.cid)}
        {@const call = callOf(o)}
        <tr>
          <td class="mono strong">{o.callsign || '—'}</td>
          <td>{o.name}</td>
          <td class="muted">{o.gradeName || ''}</td>
          <td><Badge tone={statusTone(o.status)}>{statusLabel(o.status)}</Badge></td>
          <td>
            {#if call}
              <button type="button" class="call" onclick={() => go('dispatch', { id: call.id })}><span class="mono">{call.code}</span> {call.title}</button>
            {:else if o.callId}<span class="mono muted">#{o.callId}</span>{:else}<span class="faint">—</span>{/if}
          </td>
          <td class="act"><Button size="sm" icon="eye" busy={opening === o.cid} disabled={opening != null && opening !== o.cid} onclick={() => watch(o)}>Watch</Button></td>
        </tr>
      {/each}
    </tbody>
  </table>
{/if}

<style>
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 8px 12px; border-bottom: 1px solid var(--line-2); }
  .c-cs { width: 160px; }
  .c-rk { width: 150px; }
  .c-st { width: 160px; }
  .c-act { width: 110px; }
  td { padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  .strong { font-weight: 600; }
  .act { text-align: right; }
  .call { border: 0; background: transparent; padding: 0; color: var(--text-2); text-align: left; }
  .call:hover { color: var(--accent); }
</style>
