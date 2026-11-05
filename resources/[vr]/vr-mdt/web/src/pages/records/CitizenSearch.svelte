<script>
  import SearchPage from './SearchPage.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import Badge from '../../components/Badge.svelte';
  import { go } from '../../lib/state.svelte.js';
  import { age } from '../../lib/format.js';
  import { flagTone } from './shared.js';
</script>

<SearchPage
  title="Citizens"
  subtitle="Search by name, citizen ID or phone number."
  placeholder="Search citizens"
  action="citizens.search"
  recentAction="citizens.recent"
  recentLabel="Recently updated"
  memory="citizens"
  icon="person"
  startTitle="Find a citizen"
  startText="Type at least two letters of a name, a citizen ID or a phone number."
  emptyTitle="No citizens found"
  columns="minmax(0, 2.2fr) minmax(0, 1.1fr) minmax(0, 1fr) minmax(0, 2fr) 90px"
  key={(c) => c.cid}
  onpick={(c) => go('citizens', { cid: c.cid })}
>
  {#snippet head()}<span>Citizen</span><span>Date of birth</span><span>Phone</span><span>Flags</span><span>Status</span>{/snippet}
  {#snippet row(c)}
    {@const years = age(c.dob)}
    <span class="who">
      <Mugshot id={c.mugshot} name={c.name} size={40} />
      <span class="names">
        <span class="rec-strong rec-clip nm">{c.name}</span>
        <span class="mono faint small">{c.cid}</span>
      </span>
    </span>
    <span class="mono nowrap">{c.dob || '—'}{#if years != null}<span class="faint">{' · '}{years}</span>{/if}</span>
    <span class="mono">{c.phone || '—'}</span>
    <span class="rec-chips">
      {#each c.flags.slice(0, 2) as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}
      {#if c.flags.length > 2}<Badge>+{c.flags.length - 2}</Badge>{/if}
    </span>
    <span>{#if c.hasWarrant}<Badge tone="danger" solid>Wanted</Badge>{:else}<span class="faint">—</span>{/if}</span>
  {/snippet}
</SearchPage>

<style>
  .who { display: flex; align-items: center; gap: 12px; min-width: 0; }
  .names { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
  .nm { font-size: 15px; }
  .small { font-size: 12px; }
  .nowrap { white-space: nowrap; }
</style>
