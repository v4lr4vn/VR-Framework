<script>
  import './records.css';
  import Badge from '../../components/Badge.svelte';
  import Empty from '../../components/Empty.svelte';
  import Icon from '../../components/Icon.svelte';
  import { go } from '../../lib/state.svelte.js';
  import { date, money, months_, agoWords } from '../../lib/format.js';
  import { flagTone, warrantTone, warrantLabel, vehicleState, vehicleStateTone, chargeText, boloIcon } from './shared.js';

  let { data, tab } = $props();
</script>

{#if tab === 'record'}
  <section class="rec-section">
    <h3 class="eyebrow">Convictions</h3>
    {#if data.sentences?.length}
      <div class="rec-rows">
        <div class="rec-head" style:grid-template-columns="110px minmax(0, 1fr) 120px 110px 150px" aria-hidden="true">
          <span>Date</span><span>Charges</span><span>Jail</span><span>Fine</span><span>Officer</span>
        </div>
        {#each data.sentences as s (s.id)}
          <button type="button" class="rec-row" style:grid-template-columns="110px minmax(0, 1fr) 120px 110px 150px" disabled={!s.reportId} onclick={() => go('reports', { id: s.reportId })}>
            <span class="mono">{date(s.at)}</span>
            <span class="charges">
              {#each s.charges || [] as c}
                <span class="charge"><span class="rec-strong">{chargeText(c)}</span>{#if c.class}<span class="cls {c.class}">{c.class}</span>{/if}</span>
              {/each}
            </span>
            <span class="mono">{s.months ? months_(s.months) : '—'}</span>
            <span class="mono">{s.fine ? money(s.fine) : '—'}</span>
            <span class="rec-clip">{s.officer || '—'}</span>
          </button>
        {/each}
      </div>
    {:else}
      <p class="none">No convictions on record.</p>
    {/if}
  </section>
  <section class="rec-section">
    <h3 class="eyebrow">Reports</h3>
    {#if data.reports?.length}
      <div class="rec-rows">
        {#each data.reports as r (r.id)}
          <button type="button" class="rec-row" style:grid-template-columns="70px minmax(0, 1fr) 110px 110px 120px" onclick={() => go('reports', { id: r.id })}>
            <span class="mono faint">#{r.id}</span>
            <span class="rec-strong rec-clip">{r.title}</span>
            <span>{#if r.role}<Badge tone={r.role === 'suspect' ? 'danger' : r.role === 'victim' ? 'info' : 'muted'}>{r.role}</Badge>{/if}</span>
            <span class="mono">{date(r.created_at)}</span>
            <span class="rec-clip muted">{r.author || ''}</span>
          </button>
        {/each}
      </div>
    {:else}
      <p class="none">Not named in any reports.</p>
    {/if}
  </section>
{:else if tab === 'warrants'}
  <section class="rec-section">
    <h3 class="eyebrow">Warrants</h3>
    {#if data.warrants.length}
      <div class="rec-rows">
        {#each data.warrants as w (w.id)}
          <button type="button" class="rec-row" style:grid-template-columns="64px 90px minmax(0, 1fr) 170px" onclick={() => go('warrants', { id: w.id })}>
            <span class="mono faint">#{w.id}</span>
            <span><Badge tone={warrantTone(w.status)} solid={w.status === 'active'}>{warrantLabel(w.status)}</Badge></span>
            <span class="stack">
              <span class="rec-strong rec-clip">{w.reason}</span>
              {#if w.charges?.length}<span class="rec-sub rec-clip">{w.charges.map(chargeText).join(' · ')}</span>{/if}
            </span>
            <span class="stack right">
              <span class="mono">{date(w.created_at)}</span>
              <span class="rec-sub">{w.status === 'active' ? `Expires ${date(w.expires_at)}` : w.created_by_name}</span>
            </span>
          </button>
        {/each}
      </div>
    {:else}
      <p class="none">No warrants.</p>
    {/if}
  </section>
  <section class="rec-section">
    <h3 class="eyebrow">Active BOLOs</h3>
    {#if data.bolos.length}
      <div class="rec-rows">
        {#each data.bolos as b (b.id)}
          <button type="button" class="rec-row" style:grid-template-columns="28px minmax(0, 1fr) 150px" onclick={() => go('warrants', { tab: 'bolos', id: b.id })}>
            <Icon name={boloIcon(b.kind)} size={16} />
            <span class="stack"><span class="rec-strong rec-clip">{b.title}</span>{#if b.details}<span class="rec-sub rec-clip">{b.details}</span>{/if}</span>
            <span class="rec-sub right">{b.created_by_name} · {agoWords(b.created_at)}</span>
          </button>
        {/each}
      </div>
    {:else}
      <p class="none">No active BOLOs.</p>
    {/if}
  </section>
{:else if tab === 'vehicles'}
  {#if data.vehicles.length}
    <div class="rec-rows">
      <div class="rec-head" style:grid-template-columns="120px minmax(0, 1fr) 150px 110px minmax(0, 1fr)" aria-hidden="true">
        <span>Plate</span><span>Vehicle</span><span>Garage</span><span>State</span><span>Flags</span>
      </div>
      {#each data.vehicles as v (v.plate)}
        <button type="button" class="rec-row" style:grid-template-columns="120px minmax(0, 1fr) 150px 110px minmax(0, 1fr)" onclick={() => go('vehicles', { plate: v.plate })}>
          <span><span class="rec-plate">{v.plate}</span></span>
          <span class="rec-strong rec-clip">{v.label || v.model}</span>
          <span class="rec-clip">{v.garage || '—'}</span>
          <span><Badge tone={vehicleStateTone(v.state)}>{vehicleState(v.state)}</Badge></span>
          <span class="rec-chips">{#each v.flags as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}</span>
        </button>
      {/each}
    </div>
  {:else}
    <Empty icon="car" title="No registered vehicles" />
  {/if}
{:else if tab === 'weapons'}
  {#if data.weapons.length}
    <div class="rec-rows">
      <div class="rec-head" style:grid-template-columns="190px minmax(0, 1fr) 130px minmax(0, 1fr)" aria-hidden="true">
        <span>Serial</span><span>Weapon</span><span>Registered</span><span>Flags</span>
      </div>
      {#each data.weapons as w (w.serial)}
        <button type="button" class="rec-row" style:grid-template-columns="190px minmax(0, 1fr) 130px minmax(0, 1fr)" onclick={() => go('weapons', { serial: w.serial })}>
          <span class="mono rec-strong rec-clip">{w.serial}</span>
          <span class="rec-clip">{w.label}</span>
          <span class="mono">{date(w.registeredAt)}</span>
          <span class="rec-chips">{#each w.flags as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}</span>
        </button>
      {/each}
    </div>
  {:else}
    <Empty icon="crosshair" title="No registered weapons" />
  {/if}
{:else if tab === 'properties'}
  {#if data.properties.length}
    <div class="rec-rows">
      {#each data.properties as p (p.id)}
        <div class="rec-row" style:grid-template-columns="28px minmax(0, 1fr) 160px 110px">
          <Icon name="home" size={16} />
          <span class="rec-strong rec-clip">{p.label}</span>
          <span class="rec-clip muted">{p.region || p.apartment || ''}</span>
          <span><Badge tone={p.role === 'owner' ? 'accent' : 'muted'}>{p.role === 'owner' ? 'Owner' : 'Key holder'}</Badge></span>
        </div>
      {/each}
    </div>
  {:else}
    <Empty icon="home" title="No properties" text="This citizen doesn't own or hold keys to a property." />
  {/if}
{/if}

<style>
  .none { color: var(--faint); padding: 6px 12px 0; }
  .charges { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .charge { display: flex; align-items: center; gap: 8px; }
  .cls { font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--faint); }
  .cls.felony { color: var(--p1-text); }
  .cls.misdemeanor { color: var(--p2-text); }
  .stack { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
  .right { align-items: flex-end; text-align: right; }
  button.rec-row:disabled { opacity: 1; cursor: default; }
  button.rec-row:disabled:hover { background: transparent; }
</style>
